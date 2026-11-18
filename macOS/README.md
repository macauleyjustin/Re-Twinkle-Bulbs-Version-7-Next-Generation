# Re: Twinkle Bulbs 1.0.5 for Mac (Complete Holiday Edition)

Native Swift + AppKit reconstruction of Barefoot Productions **Twinkle Bulbs v6.0**, faithfully reproducing its bulb layout math, all 21 color modes, 9 flashing algorithms, exact millisecond timings, inward rotation transforms, built-in screen savers, desktop/floating/menu-bar overlay integration, native self-contained multi-track GM MIDI player, holiday countdown calendar, tips, and wallpaper rotation.

---

## What's New in Re: Twinkle Bulbs 1.0.5 for Mac (Internal Build `1.0.6 / 106`)

- **Self-Contained 64-Voice Native MIDI Synthesizer (`TwinkleNativeGMSynth`):** Multi-channel Format-1 GM carol arrangements + built-in Schroeder hall reverb + in-house RIFF `.sf2` SoundFont 2 loader with zero dependency on Apple `MIDISynth` or `gs_instruments.dls`, plus custom folder discovery for `.mid`, `.midi`, `.rmi`, `.wav`, `.mp3`, `.aiff`, and `.m4a`.
- **250 Distinct Holiday Bulb Sets:** 25 themed collections × 10 original vector bulb designs rendered in both 32×32 and 48×48 px, complete with distinct ON, OFF (with highlight dim blend), Broken, and Bare Wire states plus inward rotation for all screen edges.
- **20 New Seasonal Screen Savers + Extensible Plugin API:** From *Twinkling Holiday Wreath* and *Falling Autumn Leaves* to *Glowing Halloween Pumpkin* and *Beach Sunset*, plus external plugin support via `TwinkleScreenSaverPlugin`.
- **Restored Historical Windows XP-Era Settings UI:** Faithful 7-tab layout (`General`, `Bulbs`, `Music`, `Screen Saver`, `Wallpaper`, `Calendar`, `Help`) with `#ECE9D8` dialog styling, searchable/categorized Bulb Sets table with favorites and recently used filtering, plus live interactive previews (`BulbSetPreviewView`, `FlashingModePreviewView`, `ColorModeSwatchRenderer`).
- **130 Seasonal Desktop Wallpapers:** High-resolution procedural seasonal desktop wallpapers across 11 themed collections with per-monitor configuration.
- **105 Multi-Track GM MIDI Library:** Built-in Christmas carol and seasonal MIDI library ready out of the box.
- **Interactive 24-Door Advent Calendar:** Count down the days of December with unlockable holiday greetings and art, persisting across launches with an optional preview mode.
- **Advanced Modern Christmas Lighting Engine:** 15 modern programmable effects, customizable color palettes, and MIDI-reactive illumination modes while keeping original classic behavior as the default.
- **Drag-and-Drop DMG Builder (`build_release.sh`):** Builds standalone ARM64 `Re Twinkle Bulbs.app` and styled `.dmg` installer with Hardened Runtime / Developer ID / `notarytool` support.

---

## Project Layout

```text
TwinkleBulbsMac/
├── Package.swift                           # SwiftPM package (TwinkleBulbsCore, TwinkleBulbs, TwinkleBulbsVerifier)
├── build_app.sh                            # Builds standalone signed build/TwinkleBulbs.app bundle
├── TwinkleBulbs.xcodeproj/                 # Native Xcode project & scheme
├── TwinkleBulbs/                           # Main macOS application sources & Info.plist
│   ├── AppDelegate.swift
│   ├── main.swift
│   ├── Models/AppSettings.swift
│   ├── Engine/BulbEngine.swift
│   ├── Assets/BLBResourceLoader.swift      # Clean-room Win32 PE/NE .blb / .icl / .ico parser
│   ├── Assets/BulbArtworkRenderer.swift    # Clean-room built-in sprite renderer + RotateIcon
│   ├── Services/AudioEngineService.swift   # Clean-room SFX & polyphonic carol player
│   ├── Services/CalendarService.swift      # Holiday countdowns, events, 38 Tips of the Day
│   ├── Services/WallpaperService.swift     # Holiday wallpapers & macOS NSWorkspace integration
│   └── UI/
│       ├── OverlayWindowController.swift
│       ├── ScreenSaverWindowController.swift
│       ├── MonitorPreviewView.swift
│       ├── StatusBarController.swift
│       ├── DialogsAndPanels.swift
│       ├── PreferencesWindowController.swift
│       └── PreferencesSecondaryTabs.swift
├── TwinkleBulbsTests/                      # Unit tests (XCTest + Swift Testing)
├── TwinkleBulbsVerifier/                   # Standalone verification & pixel comparison runner
├── docs/
│   ├── REVERSE_ENGINEERING_SPEC.md         # Full binary RE findings from Twinkle Bulbs v6.0
│   ├── COMPATIBILITY_REPORT.md             # Windows -> macOS adaptation notes
│   └── FEATURE_COMPARISON.md               # Feature parity matrix
└── research/                               # Local-only RE artifacts (never bundled into TwinkleBulbs.app)
```

---

## Build, Verify & Run

### 1. Run the Verification Suite (Command Line Tools or Xcode)
```bash
cd macOS
swift run TwinkleBulbsVerifier
```

### 2. Build the Standalone `Re Twinkle Bulbs.app` Bundle & DMG
```bash
cd macOS
./build_release.sh
open "dist/Re Twinkle Bulbs.app"
```
Or launch directly to Settings:
```bash
./build/TwinkleBulbs.app/Contents/MacOS/TwinkleBulbs --open-settings
```

### 3. Open in Xcode IDE
Open `TwinkleBulbs.xcodeproj` in Xcode and build/run scheme `TwinkleBulbs` (`Cmd+R`) or run `TwinkleBulbsTests` (`Cmd+U`).

---

## Importing Your Own Windows Assets

Out of respect for copyright and licensing, proprietary Windows binaries, bulb libraries, MIDIs, and wallpapers are kept strictly isolated in `research/` for local analysis and are not bundled into `TwinkleBulbs.app`.

If you own the original Windows files, you can import `.blb`, `.icl`, `.ico`, `.mid`, `.wav`, or wallpaper images into `TwinkleBulbs.app` at runtime:
- Open **Settings → Bulbs → Import .BLB/.ICO...**, or
- Place files in:
  - `~/Library/Application Support/TwinkleBulbs/ImportedBulbs/`
  - `~/Library/Application Support/TwinkleBulbs/ImportedMusic/`
  - `~/Library/Application Support/TwinkleBulbs/ImportedWallpapers/`

## Startup Shortcut Modifiers
- Hold **Shift** during launch to mute startup sound effects and music.
- Hold **Option** during launch to reset settings to Twinkle Bulbs v6.0 defaults.
