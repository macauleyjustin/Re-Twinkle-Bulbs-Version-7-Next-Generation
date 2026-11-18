package core

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"
	"time"
)

func TestClassicEngineAndChaseStrides(t *testing.T) {
	eng := NewEngine(1440, 900)
	cfg := eng.Config()
	if !cfg.ClassicMode || cfg.FlashMode != FlashChase || cfg.ColorMode != 8 || cfg.BulbSize != 32 {
		t.Fatalf("unexpected default settings: %+v", cfg)
	}
	if ChaseStrideForCount(20) != 4 || ChaseStrideForCount(32) != 8 || ChaseStrideForCount(50) != 10 || ChaseStrideForCount(64) != 2 {
		t.Fatalf("chase stride mismatch")
	}
	bulbs := eng.Step(50, time.Now())
	if len(bulbs) < 20 {
		t.Fatalf("expected >= 20 perimeter bulbs, got %d", len(bulbs))
	}
	// Around corners + inward rotation
	eng.UpdateSettings(func(s *Settings) {
		s.Placement = PlaceAround
		s.NoCorners = true
	})
	around := eng.Step(50, time.Now())
	edges := map[int]int{}
	for _, b := range around {
		edges[b.Edge] = b.RotDegrees
	}
	if edges[0] != 0 || edges[1] != 90 || edges[2] != 180 || edges[3] != -90 {
		t.Fatalf("unexpected edge rotations: %+v", edges)
	}
}

func TestHolidayScenesAndCatalogs(t *testing.T) {
	eng := NewEngine(1280, 800)
	if len(eng.Scenes()) != 16 {
		t.Fatalf("expected 16 built-in scenes, got %d", len(eng.Scenes()))
	}
	if len(eng.Catalog()) != 265 {
		t.Fatalf("expected 265 bulb sets, got %d", len(eng.Catalog()))
	}
	if !eng.ActivateScene("haunted-halloween") {
		t.Fatalf("failed to activate haunted-halloween scene")
	}
	if eng.Config().ModernEffect != EffectMeteor {
		t.Fatalf("expected Meteor effect after Haunted Halloween")
	}
	eng.ReturnToClassic()
	if !eng.Config().ClassicMode || eng.Config().ColorMode != 8 {
		t.Fatalf("ReturnToClassic failed")
	}
}

func TestSpritesSynthNOAAAndWebCommandCenter(t *testing.T) {
	px := RenderBulbSprite(32, 0, RGBA{255, 0, 0, 255}, 1.0, false, 90)
	if len(px) != 32*32*4 {
		t.Fatalf("expected 4096 RGBA bytes, got %d", len(px))
	}
	wav := RenderWAVBytes(0, 0.25, 44100)
	if string(wav[0:4]) != "RIFF" || len(wav) < 44000 {
		t.Fatalf("invalid WAV container: len=%d", len(wav))
	}
	sr, ss, ok := ComputeNOAA(40.71, -74.0, time.Date(2026, 12, 24, 12, 0, 0, 0, time.UTC))
	if !ok || sr >= ss {
		t.Fatalf("expected valid solar times, got %v %v %v", sr, ss, ok)
	}
	if _, _, polarOk := ComputeNOAA(85.0, 0.0, time.Date(2026, 12, 21, 12, 0, 0, 0, time.UTC)); polarOk {
		t.Fatalf("expected polar edge case to return ok=false")
	}

	eng := NewEngine(1280, 800)
	synth := NewTwinkleSynth(44100)
	if len(synth.Tracks()) != 105 {
		t.Fatalf("expected 105 carol tracks, got %d", len(synth.Tracks()))
	}
	ws := NewWebServer(eng, synth)
	port, err := ws.Start(0)
	if err != nil {
		t.Fatalf("ws start failed: %v", err)
	}
	defer ws.Stop()

	base := "http://127.0.0.1:" + itoa(port)
	resp, err := http.Get(base + "/v1/status")
	if err != nil || resp.StatusCode != 401 {
		t.Fatalf("expected 401 unauth, got %v %v", resp, err)
	}
	_ = resp.Body.Close()

	req, _ := http.NewRequest("POST", base+"/v1/control", strings.NewReader(`{"bulbSetId":12,"classicMode":false,"modernEffect":4}`))
	req.Header.Set("X-Twinkle-PIN", eng.Config().PairingPIN)
	resp2, err := http.DefaultClient.Do(req)
	if err != nil || resp2.StatusCode != 200 {
		t.Fatalf("control failed: %v", err)
	}
	var out struct{ Config Settings }
	_ = json.NewDecoder(resp2.Body).Decode(&out)
	_ = resp2.Body.Close()
	if out.Config.BulbSetID != 12 || out.Config.ClassicMode {
		t.Fatalf("remote control did not apply settings: %+v", out.Config)
	}

	doc := FullDocumentationText()
	for _, needle := range []string{"2025", "Google Antigravity", "April of 2026", "November of 2026", "Don Metzler", "Barefoot Productions", "Freeware"} {
		if !strings.Contains(doc, needle) {
			t.Fatalf("documentation missing %q", needle)
		}
	}
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b [20]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	return string(b[i:])
}
