# Re: Twinkle Bulbs — Version 7: Next Generation

**Bringing Twinkle Bulbs back from the dead for a new era — macOS, Windows, and Ubuntu Linux.**

> **Distributed with love for the original program.**
> All credit goes to the original authors: **Don Metzler** and **Barefoot Productions**.
> This software is distributed freely as **Freeware** and may be used, shared, and modified as desired.

---

## The Story & Restoration Chronicle

**Twinkle Bulbs** was originally created for Microsoft Windows by **Don Metzler** and **Barefoot Productions**, bringing festive perimeter holiday lights, classic chase patterns, holiday MIDI music, wallpapers, and screen savers to desktops around the world. As modern operating systems evolved away from Win16/Win32 desktop hooks and legacy `.blb` / `.icl` / MIDI infrastructure, the original program became nearly impossible to run.

This restored and expanded **Version 7: Next Generation** edition brings Twinkle Bulbs back from the dead and into a modern cross-platform era:

- **2025 — First Revival Efforts with Google Antigravity:** Work on resurrecting Twinkle Bulbs began in 2025 alongside **Google Antigravity**. However, those early versions did not meet expectations in timing accuracy, desktop behavior, or visual authenticity.
- **April of 2026 — Intermediate Builds:** New versions were built in April of 2026. While progressing parts of the vision, they still did not function like the authentic original Twinkle Bulbs.
- **November of 2026 — True Original Recreation & Version 7: Next Generation:** Finally, in November of 2026, a complete, ground-up recreation was engineered that functions like the authentic original — faithfully reconstructing the exact 50 ms master heartbeat, 9 Classic Flashing Modes, 6 Flash Rates, 21 Classic Color Palettes, Chase stride math (`N <= 50` lookup table and wide-screen scaling), inward edge bulb rotation, stereo General MIDI synthesis, and vintage 7-tab interface ergonomics — and expanded into **Version 7: Next Generation** across **macOS**, **Windows**, and **Ubuntu Linux**.

---

## Platforms & Downloads (`v7.0.0`)

| Platform | Package / Binary | Key Capabilities |
| :--- | :--- | :--- |
| **macOS** (13.0+ Apple Silicon ARM64) | `Re-Twinkle-Bulbs-v7.0.0-NextGen-macOS-arm64-UNSIGNED.dmg` (`macOS/`) | Full native Swift/AppKit edition: 265 bulb sets, PE/NE `.blb`/`.icl` user importer, 25 Screen Savers, 130 Wallpapers, 24-Door Advent Calendar, 105 carols on `TwinkleNativeGMSynth` 64-voice DSP + SF2 SoundFonts, 16 Holiday Scenes, Seasonal Automation + NOAA solar math, Effect Studio (`.twinklefx`), MIDI Light Show Composer, Interactive Desktop, Virtual Layout Designer (`.twinklelayout`), Web/REST/WebSocket Command Center, WLED/Art-Net/DDP adapters, GIF/MP4 export. |
| **Windows** (x64, self-contained) | `Re-Twinkle-Bulbs-v7.0.0-Windows-x64.zip` (`cross-platform/cmd/twinklebulbs-win`) | Single zero-dependency PE32+ GUI `.exe`: layered click-through desktop bulbs (`UpdateLayeredWindow`), System Tray menu, `TwinkleSynth` stereo `winmm` waveOut carols, all Classic + Modern + 16 Scenes + Automation + Remote Web Command Center (`/remote`). |
| **Ubuntu / Debian** (`amd64` & `arm64`) | `re-twinkle-bulbs_7.0.0_amd64.deb` / `re-twinkle-bulbs_7.0.0_arm64.deb` (`linux-ubuntu/`, `cross-platform/cmd/twinklebulbs-linux`) | Native static Go ELF binary (`/usr/bin/twinklebulbs`), GTK3/Cairo transparent click-through overlay & 3-tab Control Panel (`twinkle-overlay.py`), PipeWire/PulseAudio/ALSA audio streaming, `.desktop` menu integration, and full Web Command Center (`/remote`). |

---

## Everything Inside Re: Twinkle Bulbs Version 7 (How It Works)

1. **Authentic Classic v6.0 Engine**: 50 ms master timer, exact 6 rates (`1200/800/500/350/200/80 ms`), all 9 Flashing Modes (`None`, `Random`, `All Together`, `Chase`, `Alternating`, `Some Flash`, `Single`, `Pairs`, `Ping-Pong`), all 21 color sequences, bare-wire spacers, corner clearances, burned/missing/broken bulb simulation, multi-monitor span, and exact 90/180/-90 inward edge rotation.
2. **265+ Bulb Sets & Clean-Room Geometry**: 15 Classic bulb sets plus 250 Holiday Edition sets across 25 collections, with Normal (`32x32`) and Large (`48x48`) sprites.
3. **TwinkleSynth Built-In Stereo Music & MIDI Engine**: Zero-dependency synthesizer playing classic holiday carols directly through OS audio (`AVAudioSourceNode` on macOS, `waveOut` on Windows, `pw-play`/`paplay`/`aplay` on Ubuntu).
4. **Modern 60 FPS Effects & 16 Holiday Scenes**: 15 animated shaders (`Gentle Twinkle`, `Twinklefox`, `Slow Glow`, `Color Wave`, `Rainbow Chase`, `Meteor`, `Candle Flicker`, `Fireworks`, `Glitter`, `Ripple`, `Candy Cane`, `Heartbeat`, `Scanner`, `Soft Random Fade`, `Auto-Cycle`), 9 palettes, and one-click Holiday Scenes.
5. **Seasonal Automation**: Opt-in holiday calendar schedules, midnight quiet hours dimming, manual overrides, vacation safe blackout, and offline NOAA solar sunrise/sunset times.
6. **Full Remote Web Command Center & Developer API**: Built-in HTTP REST + RFC 6455 WebSocket server with 6-digit PIN pairing (`122570` default on cross-platform builds), bearer session tokens, live HTML5 visualizer, complete light/scene/music/automation control, safe blackout, and `TWKL` v1 binary LED telemetry.

---

## Building from Source

- **macOS (`macOS/`)**:
  ```bash
  cd macOS
  swift run TwinkleBulbsVerifier
  ./build_release.sh
  ```
- **Windows x64 (`cross-platform/`)**:
  ```bash
  cd cross-platform
  GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -H=windowsgui" -o Re-Twinkle-Bulbs-v7.0.0-Windows-x64.exe ./cmd/twinklebulbs-win
  ```
- **Ubuntu `.deb` (`linux-ubuntu/`)**:
  ```bash
  ./linux-ubuntu/build_deb.sh
  sudo apt install ./dist-artifacts/re-twinkle-bulbs_7.0.0_amd64.deb
  ```

See [docs/COMPLETE_HISTORY_AND_MANUAL.md](docs/COMPLETE_HISTORY_AND_MANUAL.md) for full architecture specifications.
