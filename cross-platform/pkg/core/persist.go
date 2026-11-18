package core

import (
	"encoding/json"
	"os"
	"path/filepath"
)

func SettingsFilePath() string {
	dir, err := os.UserConfigDir()
	if err != nil || dir == "" {
		dir = "."
	}
	return filepath.Join(dir, "TwinkleBulbsV7", "settings.json")
}

func (e *Engine) LoadOrInitPersisted() {
	p := SettingsFilePath()
	b, err := os.ReadFile(p)
	if err != nil {
		return
	}
	var s Settings
	if json.Unmarshal(b, &s) == nil {
		e.UpdateSettings(func(dst *Settings) {
			*dst = s
		})
	}
}

func (e *Engine) SavePersisted() {
	p := SettingsFilePath()
	_ = os.MkdirAll(filepath.Dir(p), 0755)
	b, err := json.MarshalIndent(e.Config(), "", "  ")
	if err == nil {
		_ = os.WriteFile(p, b, 0644)
	}
}
