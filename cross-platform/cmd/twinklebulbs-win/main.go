//go:build windows

package main

import (
	"flag"
	"fmt"
	"math"
	"os"
	"runtime"
	"sync"
	"syscall"
	"time"
	"unsafe"

	"github.com/macauleyjustin/re-twinkle-bulbs-v7/pkg/core"
)

var (
	user32   = syscall.NewLazyDLL("user32.dll")
	gdi32    = syscall.NewLazyDLL("gdi32.dll")
	kernel32 = syscall.NewLazyDLL("kernel32.dll")
	shell32  = syscall.NewLazyDLL("shell32.dll")
	winmm    = syscall.NewLazyDLL("winmm.dll")

	pGetModuleHandleW      = kernel32.NewProc("GetModuleHandleW")
	pRegisterClassExW      = user32.NewProc("RegisterClassExW")
	pCreateWindowExW       = user32.NewProc("CreateWindowExW")
	pDefWindowProcW        = user32.NewProc("DefWindowProcW")
	pGetMessageW           = user32.NewProc("GetMessageW")
	pTranslateMessage      = user32.NewProc("TranslateMessage")
	pDispatchMessageW      = user32.NewProc("DispatchMessageW")
	pPostQuitMessage       = user32.NewProc("PostQuitMessage")
	pShowWindow            = user32.NewProc("ShowWindow")
	pSetTimer              = user32.NewProc("SetTimer")
	pGetSystemMetrics      = user32.NewProc("GetSystemMetrics")
	pUpdateLayeredWindow   = user32.NewProc("UpdateLayeredWindow")
	pGetDC                 = user32.NewProc("GetDC")
	pReleaseDC             = user32.NewProc("ReleaseDC")
	pSetForegroundWindow   = user32.NewProc("SetForegroundWindow")
	pGetCursorPos          = user32.NewProc("GetCursorPos")
	pCreatePopupMenu       = user32.NewProc("CreatePopupMenu")
	pAppendMenuW           = user32.NewProc("AppendMenuW")
	pTrackPopupMenu        = user32.NewProc("TrackPopupMenu")
	pDestroyMenu           = user32.NewProc("DestroyMenu")
	pMessageBoxW           = user32.NewProc("MessageBoxW")
	pCreateIconIndirect    = user32.NewProc("CreateIconIndirect")
	pDestroyIcon           = user32.NewProc("DestroyIcon")

	pCreateCompatibleDC = gdi32.NewProc("CreateCompatibleDC")
	pDeleteDC           = gdi32.NewProc("DeleteDC")
	pCreateDIBSection   = gdi32.NewProc("CreateDIBSection")
	pSelectObject       = gdi32.NewProc("SelectObject")
	pDeleteObject       = gdi32.NewProc("DeleteObject")
	pCreateBitmap       = gdi32.NewProc("CreateBitmap")

	pShellNotifyIconW = shell32.NewProc("Shell_NotifyIconW")
	pShellExecuteW    = shell32.NewProc("ShellExecuteW")

	pWaveOutOpen          = winmm.NewProc("waveOutOpen")
	pWaveOutPrepareHeader = winmm.NewProc("waveOutPrepareHeader")
	pWaveOutWrite         = winmm.NewProc("waveOutWrite")
	pWaveOutUnprepareHdr  = winmm.NewProc("waveOutUnprepareHeader")
	pWaveOutReset         = winmm.NewProc("waveOutReset")
	pWaveOutClose         = winmm.NewProc("waveOutClose")
)

const (
	wsExLayered     = 0x00080000
	wsExTransparent = 0x00000020
	wsExTopMost     = 0x00000008
	wsExToolWindow  = 0x00000080
	wsExNoActivate  = 0x08000000
	wsPopup         = 0x80000000

	swShowNoActivate = 4
	smCXScreen       = 0
	smCYScreen       = 1
	ulwAlpha         = 0x00000002

	wmDestroy    = 0x0002
	wmTimer      = 0x0113
	wmCommand    = 0x0111
	wmRButtonUp  = 0x0205
	wmLButtonUp  = 0x0202
	wmLButtonDbl = 0x0203
	wmTrayIcon   = 0x8000 + 77

	nimAdd    = 0x00000000
	nimModify = 0x00000001
	nimDelete = 0x00000002
	nifMsg    = 0x00000001
	nifIcon   = 0x00000002
	nifTip    = 0x00000004

	mfString    = 0x00000000
	mfPopup     = 0x00000010
	mfSeparator = 0x00000800
	mfChecked   = 0x00000008
	tpmRightBtn = 0x0002
)

const (
	cmdToggleLights = 1001
	cmdOpenRemote   = 1002
	cmdToggleMusic  = 1003
	cmdNextCarol    = 1004
	cmdClassicMode  = 1005
	cmdAboutHistory = 1006
	cmdExitApp      = 1007
	cmdSceneBase    = 2000
	cmdFlashBase    = 2100
	cmdEffectBase   = 2200
)

type wndClassExW struct {
	cbSize        uint32
	style         uint32
	lpfnWndProc   uintptr
	cbClsExtra    int32
	cbWndExtra    int32
	hInstance     uintptr
	hIcon         uintptr
	hCursor       uintptr
	hbrBackground uintptr
	lpszMenuName  *uint16
	lpszClassName *uint16
	hIconSm       uintptr
}

type point struct{ X, Y int32 }
type size struct{ CX, CY int32 }
type msg struct {
	hwnd    uintptr
	message uint32
	wParam  uintptr
	lParam  uintptr
	time    uint32
	pt      point
}

type blendFunction struct {
	BlendOp             byte
	BlendFlags          byte
	SourceConstantAlpha byte
	AlphaFormat         byte
}

type bitmapInfoHeader struct {
	biSize          uint32
	biWidth         int32
	biHeight        int32
	biPlanes        uint16
	biBitCount      uint16
	biCompression   uint32
	biSizeImage     uint32
	biXPelsPerMeter int32
	biYPelsPerMeter int32
	biClrUsed       uint32
	biClrImportant  uint32
}

type bitmapInfo struct {
	bmiHeader bitmapInfoHeader
	bmiColors [1]uint32
}

type notifyIconDataW struct {
	cbSize           uint32
	hWnd             uintptr
	uID              uint32
	uFlags           uint32
	uCallbackMsg     uint32
	hIcon            uintptr
	szTip            [128]uint16
	dwState          uint32
	dwStateMask      uint32
	szInfo           [256]uint16
	uVersion         uint32
	szInfoTitle      [64]uint16
	dwInfoFlags      uint32
	guidItem         [16]byte
	hBalloonIcon     uintptr
}

type iconInfo struct {
	fIcon    int32
	xHotspot uint32
	yHotspot uint32
	hbmMask  uintptr
	hbmColor uintptr
}

type waveFormatEx struct {
	wFormatTag      uint16
	nChannels       uint16
	nSamplesPerSec  uint32
	nAvgBytesPerSec uint32
	nBlockAlign     uint16
	wBitsPerSample  uint16
	cbSize          uint16
}

type waveHdr struct {
	lpData          uintptr
	dwBufferLength  uint32
	dwBytesRecorded uint32
	dwUser          uintptr
	dwFlags         uint32
	dwLoops         uint32
	lpNext          uintptr
	reserved        uintptr
}

var (
	gEngine  *core.Engine
	gSynth   *core.TwinkleSynth
	gWeb     *core.WebServer
	gPort    int
	gScreenW int
	gScreenH int
	gTrayIco uintptr
	gHWnd    uintptr
)

func utf16Ptr(s string) *uint16 {
	p, _ := syscall.UTF16PtrFromString(s)
	return p
}

func openURL(url string) {
	_, _, _ = pShellExecuteW.Call(0, uintptr(unsafe.Pointer(utf16Ptr("open"))), uintptr(unsafe.Pointer(utf16Ptr(url))), 0, 0, 1)
}

func createTrayHolidayIcon() uintptr {
	const w, h = 16, 16
	px := make([]uint32, w*h)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			dx := float64(x) - 7.5
			dy := float64(y) - 8.5
			if y >= 1 && y <= 2 {
				px[y*w+x] = 0xFF1B5E20
			} else if y >= 3 && y <= 5 && math.Abs(dx) <= 2.5 {
				px[y*w+x] = 0xFFD4AF37
			} else if dx*dx/(5.5*5.5)+dy*dy/(6.2*6.2) <= 1.0 && y > 4 {
				px[y*w+x] = 0xFFE53935
				if x < 7 && y < 10 {
					px[y*w+x] = 0xFFFF9E80
				}
			}
		}
	}
	hColor, _, _ := pCreateBitmap.Call(w, h, 1, 32, uintptr(unsafe.Pointer(&px[0])))
	mask := make([]uint16, h)
	hMask, _, _ := pCreateBitmap.Call(w, h, 1, 1, uintptr(unsafe.Pointer(&mask[0])))
	ii := iconInfo{fIcon: 1, hbmMask: hMask, hbmColor: hColor}
	hIcon, _, _ := pCreateIconIndirect.Call(uintptr(unsafe.Pointer(&ii)))
	_, _, _ = pDeleteObject.Call(hColor)
	_, _, _ = pDeleteObject.Call(hMask)
	return hIcon
}

func startAudioLoop(synth *core.TwinkleSynth, stopCh <-chan struct{}) {
	go func() {
		const sampleRate = 44100
		const framesPerBuf = 2048
		wf := waveFormatEx{
			wFormatTag:      1,
			nChannels:       2,
			nSamplesPerSec:  sampleRate,
			nAvgBytesPerSec: sampleRate * 4,
			nBlockAlign:     4,
			wBitsPerSample:  16,
		}
		var hWave uintptr
		ret, _, _ := pWaveOutOpen.Call(uintptr(unsafe.Pointer(&hWave)), ^uintptr(0), uintptr(unsafe.Pointer(&wf)), 0, 0, 0)
		if ret != 0 {
			return
		}
		defer func() {
			_, _, _ = pWaveOutReset.Call(hWave)
			_, _, _ = pWaveOutClose.Call(hWave)
		}()

		const numBufs = 3
		bufs := make([][]int16, numBufs)
		hdrs := make([]waveHdr, numBufs)
		for i := 0; i < numBufs; i++ {
			bufs[i] = make([]int16, framesPerBuf*2)
			hdrs[i] = waveHdr{
				lpData:         uintptr(unsafe.Pointer(&bufs[i][0])),
				dwBufferLength: uint32(len(bufs[i]) * 2),
			}
			_, _, _ = pWaveOutPrepareHeader.Call(hWave, uintptr(unsafe.Pointer(&hdrs[i])), unsafe.Sizeof(hdrs[i]))
			synth.RenderPCM(bufs[i])
			_, _, _ = pWaveOutWrite.Call(hWave, uintptr(unsafe.Pointer(&hdrs[i])), unsafe.Sizeof(hdrs[i]))
		}

		ticker := time.NewTicker(20 * time.Millisecond)
		defer ticker.Stop()
		for {
			select {
			case <-stopCh:
				for i := 0; i < numBufs; i++ {
					_, _, _ = pWaveOutUnprepareHdr.Call(hWave, uintptr(unsafe.Pointer(&hdrs[i])), unsafe.Sizeof(hdrs[i]))
				}
				return
			case <-ticker.C:
				for i := 0; i < numBufs; i++ {
					if hdrs[i].dwFlags&0x00000001 != 0 { // WHDR_DONE
						synth.RenderPCM(bufs[i])
						_, _, _ = pWaveOutWrite.Call(hWave, uintptr(unsafe.Pointer(&hdrs[i])), unsafe.Sizeof(hdrs[i]))
					}
				}
			}
		}
	}()
}

var renderMu sync.Mutex

func paintOverlay(hwnd uintptr, bulbs []core.BulbCoord) {
	renderMu.Lock()
	defer renderMu.Unlock()

	screenDC, _, _ := pGetDC.Call(0)
	if screenDC == 0 {
		return
	}
	defer pReleaseDC.Call(0, screenDC)

	memDC, _, _ := pCreateCompatibleDC.Call(screenDC)
	if memDC == 0 {
		return
	}
	defer pDeleteDC.Call(memDC)

	bi := bitmapInfo{
		bmiHeader: bitmapInfoHeader{
			biSize:        uint32(unsafe.Sizeof(bitmapInfoHeader{})),
			biWidth:       int32(gScreenW),
			biHeight:      -int32(gScreenH), // top-down DIB
			biPlanes:      1,
			biBitCount:    32,
			biCompression: 0,
		},
	}
	var bitsPtr unsafe.Pointer
	hBmp, _, _ := pCreateDIBSection.Call(memDC, uintptr(unsafe.Pointer(&bi)), 0, uintptr(unsafe.Pointer(&bitsPtr)), 0, 0)
	if hBmp == 0 || bitsPtr == nil {
		return
	}
	defer pDeleteObject.Call(hBmp)

	oldObj, _, _ := pSelectObject.Call(memDC, hBmp)
	defer pSelectObject.Call(memDC, oldObj)

	totalBytes := gScreenW * gScreenH * 4
	frameBuf := unsafe.Slice((*byte)(bitsPtr), totalBytes)
	clear(frameBuf)

	cfg := gEngine.Config()
	sz := cfg.BulbSize
	if sz != 48 {
		sz = 32
	}
	shape := 0
	if cfg.BulbSetID >= 0 && cfg.BulbSetID < len(gEngine.Catalog()) {
		shape = gEngine.Catalog()[cfg.BulbSetID].ShapeKind
	}

	if cfg.Enabled && !cfg.Blackout && !cfg.Automation.VacationMode {
		for _, b := range bulbs {
			sprite := core.RenderBulbSprite(sz, shape, b.Color, b.Intensity, b.BareSpacer, b.RotDegrees)
			for sy := 0; sy < sz; sy++ {
				dy := b.Y + sy
				if dy < 0 || dy >= gScreenH {
					continue
				}
				for sx := 0; sx < sz; sx++ {
					dx := b.X + sx
					if dx < 0 || dx >= gScreenW {
						continue
					}
					soff := (sy*sz + sx) * 4
					a := sprite[soff+3]
					if a == 0 {
						continue
					}
					doff := (dy*gScreenW + dx) * 4
					// Premultiplied BGRA for UpdateLayeredWindow
					af := uint16(a)
					frameBuf[doff+0] = uint8((uint16(sprite[soff+2]) * af) / 255)
					frameBuf[doff+1] = uint8((uint16(sprite[soff+1]) * af) / 255)
					frameBuf[doff+2] = uint8((uint16(sprite[soff+0]) * af) / 255)
					frameBuf[doff+3] = a
				}
			}
		}
	}

	ptDst := point{0, 0}
	szDst := size{int32(gScreenW), int32(gScreenH)}
	ptSrc := point{0, 0}
	blend := blendFunction{BlendOp: 0, BlendFlags: 0, SourceConstantAlpha: 255, AlphaFormat: 1}
	_, _, _ = pUpdateLayeredWindow.Call(
		hwnd, screenDC,
		uintptr(unsafe.Pointer(&ptDst)),
		uintptr(unsafe.Pointer(&szDst)),
		memDC,
		uintptr(unsafe.Pointer(&ptSrc)),
		0,
		uintptr(unsafe.Pointer(&blend)),
		ulwAlpha,
	)
}

func showTrayPopupMenu(hwnd uintptr) {
	menu, _, _ := pCreatePopupMenu.Call()
	if menu == 0 {
		return
	}
	defer pDestroyMenu.Call(menu)

	cfg := gEngine.Config()
	toggleTxt := "Turn Lights OFF (Blackout)"
	if cfg.Blackout || !cfg.Enabled {
		toggleTxt = "Turn Lights ON"
	}
	_, _, _ = pAppendMenuW.Call(menu, mfString, cmdToggleLights, uintptr(unsafe.Pointer(utf16Ptr(toggleTxt))))

	scenesMenu, _, _ := pCreatePopupMenu.Call()
	for i, sc := range gEngine.Scenes() {
		fl := uintptr(mfString)
		if sc.ID == cfg.ActiveSceneID {
			fl |= mfChecked
		}
		_, _, _ = pAppendMenuW.Call(scenesMenu, fl, uintptr(cmdSceneBase+i), uintptr(unsafe.Pointer(utf16Ptr(sc.Name))))
	}
	_, _, _ = pAppendMenuW.Call(menu, mfPopup, scenesMenu, uintptr(unsafe.Pointer(utf16Ptr("Holiday Scenes (16)"))))

	flashMenu, _, _ := pCreatePopupMenu.Call()
	for i, name := range core.FlashModeNames {
		fl := uintptr(mfString)
		if cfg.ClassicMode && int(cfg.FlashMode) == i {
			fl |= mfChecked
		}
		_, _, _ = pAppendMenuW.Call(flashMenu, fl, uintptr(cmdFlashBase+i), uintptr(unsafe.Pointer(utf16Ptr(name))))
	}
	_, _, _ = pAppendMenuW.Call(menu, mfPopup, flashMenu, uintptr(unsafe.Pointer(utf16Ptr("Classic Flash Modes"))))

	effMenu, _, _ := pCreatePopupMenu.Call()
	for i, name := range core.ModernEffectNames {
		fl := uintptr(mfString)
		if !cfg.ClassicMode && int(cfg.ModernEffect) == i {
			fl |= mfChecked
		}
		_, _, _ = pAppendMenuW.Call(effMenu, fl, uintptr(cmdEffectBase+i), uintptr(unsafe.Pointer(utf16Ptr(name))))
	}
	_, _, _ = pAppendMenuW.Call(menu, mfPopup, effMenu, uintptr(unsafe.Pointer(utf16Ptr("Modern 60fps Effects"))))

	_, _, _ = pAppendMenuW.Call(menu, mfSeparator, 0, 0)
	musicLabel := "Play Holiday Carol (TwinkleSynth)"
	if cfg.MusicPlaying {
		musicLabel = "Stop Holiday Carol"
	}
	_, _, _ = pAppendMenuW.Call(menu, mfString, cmdToggleMusic, uintptr(unsafe.Pointer(utf16Ptr(musicLabel))))
	_, _, _ = pAppendMenuW.Call(menu, mfString, cmdNextCarol, uintptr(unsafe.Pointer(utf16Ptr("Next Carol"))))
	_, _, _ = pAppendMenuW.Call(menu, mfString, cmdClassicMode, uintptr(unsafe.Pointer(utf16Ptr("Return to Classic v6.0"))))
	_, _, _ = pAppendMenuW.Call(menu, mfSeparator, 0, 0)
	_, _, _ = pAppendMenuW.Call(menu, mfString, cmdOpenRemote, uintptr(unsafe.Pointer(utf16Ptr(fmt.Sprintf("Open Command Center & Settings (:%d)", gPort)))))
	_, _, _ = pAppendMenuW.Call(menu, mfString, cmdAboutHistory, uintptr(unsafe.Pointer(utf16Ptr("History, Documentation & Credits..."))))
	_, _, _ = pAppendMenuW.Call(menu, mfSeparator, 0, 0)
	_, _, _ = pAppendMenuW.Call(menu, mfString, cmdExitApp, uintptr(unsafe.Pointer(utf16Ptr("Exit Re: Twinkle Bulbs"))))

	var pt point
	_, _, _ = pGetCursorPos.Call(uintptr(unsafe.Pointer(&pt)))
	_, _, _ = pSetForegroundWindow.Call(hwnd)
	_, _, _ = pTrackPopupMenu.Call(menu, tpmRightBtn, uintptr(pt.X), uintptr(pt.Y), 0, hwnd, 0)
}

func wndProc(hwnd uintptr, uMsg uint32, wParam, lParam uintptr) uintptr {
	switch uMsg {
	case wmTimer:
		bulbs := gEngine.Step(33, time.Now())
		paintOverlay(hwnd, bulbs)
		gWeb.BroadcastFrame(bulbs)
		return 0
	case wmTrayIcon:
		ev := uint32(lParam & 0xFFFF)
		if ev == wmRButtonUp {
			showTrayPopupMenu(hwnd)
		} else if ev == wmLButtonUp || ev == wmLButtonDbl {
			openURL(fmt.Sprintf("http://127.0.0.1:%d/remote", gPort))
		}
		return 0
	case wmCommand:
		id := int(wParam & 0xFFFF)
		scenes := gEngine.Scenes()
		switch {
		case id == cmdToggleLights:
			gEngine.UpdateSettings(func(s *core.Settings) { s.Blackout = !s.Blackout; s.Enabled = true })
		case id == cmdOpenRemote:
			openURL(fmt.Sprintf("http://127.0.0.1:%d/remote", gPort))
		case id == cmdToggleMusic:
			gEngine.UpdateSettings(func(s *core.Settings) { s.MusicPlaying = !s.MusicPlaying })
			cfg := gEngine.Config()
			gSynth.SetState(cfg.MusicPlaying, cfg.MusicTrack, cfg.MusicVolume)
		case id == cmdNextCarol:
			gEngine.UpdateSettings(func(s *core.Settings) { s.MusicTrack = (s.MusicTrack + 1) % 105; s.MusicPlaying = true })
			cfg := gEngine.Config()
			gSynth.SetState(cfg.MusicPlaying, cfg.MusicTrack, cfg.MusicVolume)
		case id == cmdClassicMode:
			gEngine.ReturnToClassic()
		case id == cmdAboutHistory:
			summary := core.TributeAndFreewareBanner + "\n\n" + core.RestorationHistoryText + fmt.Sprintf("\n\nFull Web Command Center & Manual: http://127.0.0.1:%d/remote", gPort)
			_, _, _ = pMessageBoxW.Call(hwnd, uintptr(unsafe.Pointer(utf16Ptr(summary))), uintptr(unsafe.Pointer(utf16Ptr(core.AppTitle))), 0x00000040)
		case id == cmdExitApp:
			_, _, _ = pPostQuitMessage.Call(0)
		case id >= cmdSceneBase && id < cmdSceneBase+len(scenes):
			gEngine.ActivateScene(scenes[id-cmdSceneBase].ID)
			cfg := gEngine.Config()
			gSynth.SetState(cfg.MusicPlaying, cfg.MusicTrack, cfg.MusicVolume)
		case id >= cmdFlashBase && id < cmdFlashBase+len(core.FlashModeNames):
			gEngine.UpdateSettings(func(s *core.Settings) { s.ClassicMode = true; s.FlashMode = core.FlashMode(id - cmdFlashBase) })
		case id >= cmdEffectBase && id < cmdEffectBase+len(core.ModernEffectNames):
			gEngine.UpdateSettings(func(s *core.Settings) { s.ClassicMode = false; s.ModernEffect = core.ModernEffect(id - cmdEffectBase) })
		}
		return 0
	case wmDestroy:
		_, _, _ = pPostQuitMessage.Call(0)
		return 0
	}
	ret, _, _ := pDefWindowProcW.Call(hwnd, uintptr(uMsg), wParam, lParam)
	return ret
}

func main() {
	runtime.LockOSThread()
	verify := flag.Bool("verify", false, "Run headless verification and exit")
	flag.Parse()

	gEngine = core.NewEngine(1920, 1080)
	gEngine.LoadOrInitPersisted()
	gEngine.OnConfigChange(func(s core.Settings) { gEngine.SavePersisted() })
	gSynth = core.NewTwinkleSynth(44100)
	gWeb = core.NewWebServer(gEngine, gSynth)

	if *verify {
		p, err := gWeb.Start(0)
		if err != nil {
			fmt.Fprintf(os.Stderr, "verify failed: %v\n", err)
			os.Exit(1)
		}
		bulbs := gEngine.Step(50, time.Now())
		gWeb.BroadcastFrame(bulbs)
		fmt.Printf("OK Windows v%s verified (%d bulbs, web port %d)\n", core.AppVersion, len(bulbs), p)
		gWeb.Stop()
		return
	}

	cx, _, _ := pGetSystemMetrics.Call(smCXScreen)
	cy, _, _ := pGetSystemMetrics.Call(smCYScreen)
	gScreenW, gScreenH = int(cx), int(cy)
	if gScreenW <= 0 || gScreenH <= 0 {
		gScreenW, gScreenH = 1920, 1080
	}
	gEngine.Resize(gScreenW, gScreenH)

	var err error
	gPort, err = gWeb.Start(19697)
	if err != nil {
		os.Exit(1)
	}
	defer gWeb.Stop()

	stopAudio := make(chan struct{})
	startAudioLoop(gSynth, stopAudio)
	defer close(stopAudio)

	hInst, _, _ := pGetModuleHandleW.Call(0)
	clsName := utf16Ptr("ReTwinkleBulbsV7Overlay")
	gTrayIco = createTrayHolidayIcon()
	defer pDestroyIcon.Call(gTrayIco)

	wcx := wndClassExW{
		cbSize:        uint32(unsafe.Sizeof(wndClassExW{})),
		lpfnWndProc:   syscall.NewCallback(wndProc),
		hInstance:     hInst,
		hIcon:         gTrayIco,
		lpszClassName: clsName,
	}
	_, _, _ = pRegisterClassExW.Call(uintptr(unsafe.Pointer(&wcx)))

	exStyle := uintptr(wsExLayered | wsExTransparent | wsExTopMost | wsExToolWindow | wsExNoActivate)
	gHWnd, _, _ = pCreateWindowExW.Call(
		exStyle,
		uintptr(unsafe.Pointer(clsName)),
		uintptr(unsafe.Pointer(utf16Ptr(core.AppTitle))),
		wsPopup,
		0, 0, uintptr(gScreenW), uintptr(gScreenH),
		0, 0, hInst, 0,
	)
	if gHWnd == 0 {
		os.Exit(1)
	}

	var nid notifyIconDataW
	nid.cbSize = uint32(unsafe.Sizeof(nid))
	nid.hWnd = gHWnd
	nid.uID = 700
	nid.uFlags = nifMsg | nifIcon | nifTip
	nid.uCallbackMsg = wmTrayIcon
	nid.hIcon = gTrayIco
	tipU16, _ := syscall.UTF16FromString("Re: Twinkle Bulbs v7.0 (Right-click for menu, Double-click for Command Center)")
	copy(nid.szTip[:], tipU16)
	_, _, _ = pShellNotifyIconW.Call(nimAdd, uintptr(unsafe.Pointer(&nid)))
	defer pShellNotifyIconW.Call(nimDelete, uintptr(unsafe.Pointer(&nid)))

	_, _, _ = pShowWindow.Call(gHWnd, swShowNoActivate)
	paintOverlay(gHWnd, gEngine.Step(0, time.Now()))
	_, _, _ = pSetTimer.Call(gHWnd, 1, 33, 0)

	var m msg
	for {
		r, _, _ := pGetMessageW.Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0)
		if int32(r) <= 0 {
			break
		}
		_, _, _ = pTranslateMessage.Call(uintptr(unsafe.Pointer(&m)))
		_, _, _ = pDispatchMessageW.Call(uintptr(unsafe.Pointer(&m)))
	}
}
