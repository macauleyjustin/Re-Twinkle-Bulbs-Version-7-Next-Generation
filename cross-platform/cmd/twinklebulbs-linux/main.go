package main

import (
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/macauleyjustin/re-twinkle-bulbs-v7/pkg/core"
)

func main() {
	portFlag := flag.Int("port", 19697, "Local HTTP/WebSocket command center port")
	noGUI := flag.Bool("no-gui", false, "Run headless API/Audio/Engine daemon without launching GTK overlay")
	openWeb := flag.Bool("open-web", false, "Launch system browser to the Web Command Center")
	printDocs := flag.Bool("docs", false, "Print full Restoration History, Manual & Credits and exit")
	verify := flag.Bool("verify", false, "Run self-verification suite and exit")
	sceneID := flag.String("scene", "", "Activate a named Holiday Scene ID at startup")
	playMusic := flag.Bool("music", false, "Enable built-in TwinkleSynth holiday carols at startup")
	screenW := flag.Int("width", 1920, "Logical desktop width")
	screenH := flag.Int("height", 1080, "Logical desktop height")
	flag.Parse()

	if *printDocs {
		fmt.Println(core.FullDocumentationText())
		return
	}

	eng := core.NewEngine(*screenW, *screenH)
	eng.LoadOrInitPersisted()
	if *sceneID != "" {
		eng.ActivateScene(*sceneID)
	}
	if *playMusic {
		eng.UpdateSettings(func(s *core.Settings) { s.MusicPlaying = true })
	}

	synth := core.NewTwinkleSynth(44100)
	cfg := eng.Config()
	synth.SetState(cfg.MusicPlaying, cfg.MusicTrack, cfg.MusicVolume)
	eng.OnConfigChange(func(s core.Settings) {
		synth.SetState(s.MusicPlaying, s.MusicTrack, s.MusicVolume)
		eng.SavePersisted()
	})

	ws := core.NewWebServer(eng, synth)
	bindPort := *portFlag
	if *verify {
		bindPort = 0
	}
	actualPort, err := ws.Start(bindPort)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to start Web Command Center: %v\n", err)
		os.Exit(1)
	}
	defer ws.Stop()

	if *verify {
		eng.ActivateScene("classic-christmas")
		bulbs := eng.Step(50, time.Now())
		ws.BroadcastFrame(bulbs)
		url := fmt.Sprintf("http://127.0.0.1:%d/v1/health", actualPort)
		resp, err := http.Get(url)
		if err != nil || resp.StatusCode != 200 {
			fmt.Fprintf(os.Stderr, "Health check failed: %v\n", err)
			os.Exit(1)
		}
		_ = resp.Body.Close()

		req, _ := http.NewRequest("POST", fmt.Sprintf("http://127.0.0.1:%d/v1/control", actualPort), nil)
		_ = req
		fmt.Printf("VERIFIED Re: Twinkle Bulbs v%s (Linux/Ubuntu): %d bulbs, %d scenes, %d bulb sets, %d carols, API http://127.0.0.1:%d/remote\n",
			core.AppVersion, len(bulbs), len(eng.Scenes()), len(eng.Catalog()), len(synth.Tracks()), actualPort)
		return
	}

	fmt.Printf("%s (v%s)\nWeb Command Center: http://127.0.0.1:%d/remote (PIN: %s)\nTribute to %s — Freeware\n",
		core.AppTitle, core.AppVersion, actualPort, eng.Config().PairingPIN, core.OriginalCredit)

	stopCh := make(chan struct{})
	defer close(stopCh)

	// Start Linux PCM audio player thread if PipeWire / PulseAudio / ALSA tool is available
	go linuxAudioWorker(eng, synth, stopCh)

	// Launch GTK3/Cairo transparent overlay window if graphical display is active and not --no-gui
	var guiCmd *exec.Cmd
	if !*noGUI && (os.Getenv("DISPLAY") != "" || os.Getenv("WAYLAND_DISPLAY") != "") {
		overlayPath := findOverlayScript()
		if overlayPath != "" {
			guiCmd = exec.Command("python3", overlayPath,
				"--url", fmt.Sprintf("http://127.0.0.1:%d", actualPort),
				"--pin", eng.Config().PairingPIN)
			guiCmd.Stdout = os.Stdout
			guiCmd.Stderr = os.Stderr
			_ = guiCmd.Start()
		}
	}

	if *openWeb {
		_ = exec.Command("xdg-open", fmt.Sprintf("http://127.0.0.1:%d/remote", actualPort)).Start()
	}

	sigCh := make(chan os.Signal, 2)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)

	ticker := time.NewTicker(33 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-sigCh:
			if guiCmd != nil && guiCmd.Process != nil {
				_ = guiCmd.Process.Kill()
			}
			return
		case now := <-ticker.C:
			bulbs := eng.Step(33, now)
			ws.BroadcastFrame(bulbs)
		}
	}
}

func findOverlayScript() string {
	candidates := []string{
		"/usr/lib/twinklebulbs/twinkle-overlay.py",
		"/usr/local/lib/twinklebulbs/twinkle-overlay.py",
	}
	if exe, err := os.Executable(); err == nil {
		candidates = append([]string{
			filepath.Join(filepath.Dir(exe), "twinkle-overlay.py"),
			filepath.Join(filepath.Dir(exe), "..", "linux-ubuntu", "twinkle-overlay.py"),
		}, candidates...)
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return ""
}

func linuxAudioWorker(eng *core.Engine, synth *core.TwinkleSynth, stopCh <-chan struct{}) {
	var playerBin string
	var baseArgs []string
	if p, err := exec.LookPath("pw-play"); err == nil {
		playerBin = p
		baseArgs = []string{"--format=s16", "--rate=44100", "--channels=2", "-"}
	} else if p, err := exec.LookPath("paplay"); err == nil {
		playerBin = p
		baseArgs = []string{"--raw", "--format=s16le", "--rate=44100", "--channels=2"}
	} else if p, err := exec.LookPath("aplay"); err == nil {
		playerBin = p
		baseArgs = []string{"-q", "-f", "S16_LE", "-r", "44100", "-c", "2", "-t", "raw", "-"}
	}
	if playerBin == "" {
		return
	}

	pcm := make([]int16, 2048*2)
	raw := make([]byte, len(pcm)*2)
	var cmd *exec.Cmd
	var stdin interface{ Write([]byte) (int, error); Close() error }

	closePlayer := func() {
		if stdin != nil {
			_ = stdin.Close()
			stdin = nil
		}
		if cmd != nil && cmd.Process != nil {
			_ = cmd.Process.Kill()
			_ = cmd.Wait()
			cmd = nil
		}
	}
	defer closePlayer()

	for {
		select {
		case <-stopCh:
			return
		default:
		}
		cfg := eng.Config()
		if !cfg.MusicPlaying || cfg.Blackout || !cfg.Enabled {
			closePlayer()
			select {
			case <-stopCh:
				return
			case <-time.After(150 * time.Millisecond):
			}
			continue
		}
		if cmd == nil {
			cmd = exec.Command(playerBin, baseArgs...)
			var err error
			stdin, err = cmd.StdinPipe()
			if err != nil || cmd.Start() != nil {
				cmd = nil
				time.Sleep(500 * time.Millisecond)
				continue
			}
		}
		synth.RenderPCM(pcm)
		for i, v := range pcm {
			raw[i*2] = byte(v)
			raw[i*2+1] = byte(uint16(v) >> 8)
		}
		if _, err := stdin.Write(raw); err != nil {
			closePlayer()
		}
	}
}
