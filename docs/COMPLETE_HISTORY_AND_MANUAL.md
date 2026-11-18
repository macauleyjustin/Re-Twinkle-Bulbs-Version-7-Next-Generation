# Re: Twinkle Bulbs — Version 7: Next Generation
## Complete History, System Manual & Freeware Tribute

---

### Original Author Credit & Freeware Notice

> **All credit goes to the original authors: Don Metzler and Barefoot Productions.**
>
> This software is distributed out of love for the original Twinkle Bulbs program, to keep the memory and love for Twinkle Bulbs alive for a new era.
>
> **License:** Distributed freely as **Freeware** and may be used, copied, studied, shared, and modified as desired.

---

## 1. The Full Restoration Chronicle (Bringing Twinkle Bulbs Back From the Dead)

For generations of PC users, **Twinkle Bulbs** (by **Don Metzler** and **Barefoot Productions**) was a holiday desktop staple: miniature Christmas bulbs glowing along the monitor frame, classic chase rhythms, festive MIDI carols, seasonal screen savers, and holiday wallpapers. As Windows evolved beyond Win16/32-bit GDI desktop hooks, legacy `.blb`/`.icl` binary resource icons, and aging MIDI sequencers, Twinkle Bulbs gradually stopped working on modern systems and risked being lost forever.

This restored **Version 7: Next Generation** edition brings Twinkle Bulbs back from the dead and expands it across **macOS**, **Windows**, and **Ubuntu Linux**:

1. **2025 — Revival Started with Google Antigravity**
   Initial work to resurrect Twinkle Bulbs began in 2025 alongside **Google Antigravity**. While proving the desire to bring back the holiday icon, those first versions did not meet expectations in timing fidelity, lighting behavior, or overall craft.
2. **April of 2026 — Intermediate Builds**
   Updated recreations were produced in **April of 2026**. Although they explored more of the concept, they still did not function like the authentic original Twinkle Bulbs.
3. **November of 2026 — Full Authentic Recreation & Version 7: Next Generation**
   Finally, in **November of 2026**, a full engineering recreation was completed that functions like the real original Twinkle Bulbs — faithfully reconstructing the exact **50 ms** master timing loop, **9 Classic Flashing Modes**, **6 Flash Rates**, **21 Classic Color Palettes**, strided Chase math, inward screen-edge sprite rotation math, vintage XP 7-tab interface, stereo General MIDI synthesis, and seasonal screensavers/wallpapers — and expanded into **Version 7: Next Generation** across macOS, Windows, and Ubuntu Linux.

---

## 2. How Every Subsystem Works

### A. Authentic Classic v6.0 Engine
- **Master Cadence:** Runs at `50 ms` per tick (preserving original timer behavior).
- **6 Flash Rates:** Slow (`1200 ms`), Slow/Medium (`800 ms`), Medium (`500 ms`), Medium/Fast (`350 ms`), Fast (`200 ms`), Very Fast (`80 ms`).
- **9 Classic Flashing Modes:** `None (Always On)`, `Random`, `All Together`, `Chase` (strided groups computed from bulb count lookup table), `Alternating`, `Some Bulbs Flash`, `Single`, `Pairs`, and `Ping-Pong`.
- **21 Classic Color Modes:** Deterministic palette sequences (`colorSequence`) plus zero-repeat `Random`. Default: `Chase + Medium + Red/Green + Top + 32px + BareWire + NoCorners + SparseSpacing`.
- **Inward Edge Rotation:** Top (`0 deg`), Right (`+90 deg`), Bottom (`180 deg`), Left (`-90 deg`) so cords hug the display bevel and bulbs always hang inward.
- **Physical Defect Simulation:** Optional burned-out, missing, and flicker/broken bulb realism, plus multi-monitor layout and Bulb Changer rotation.

### B. 265+ Bulb Sets & Clean-Room Binary Importer
- **15 Classic Sets + 250 Holiday Edition Designs:** Rendered cleanly at both `32x32` Normal and `48x48` Large scales with 50% highlight dim blending when unlit.
- **User PE/NE Importer (macOS):** Parses user-supplied `.blb`, `.icl`, `.ico`, and `.blz` files safely in pure Swift without executing legacy Windows code.

### C. Self-Contained Audio & General MIDI Synthesizer (`TwinkleNativeGMSynth` / `TwinkleSynth`)
- **macOS (`TwinkleNativeGMSynth`):** 64-voice General MIDI DSP synthesizer + Schroeder stereo reverb inside `AVAudioSourceNode`, loading 105 built-in carols and user `.mid`/`.midi`/`.rmi`/`.sf2` banks with zero external audio installs.
- **Windows (`winmm.dll waveOut`) & Ubuntu (`pw-play`/`paplay`/`aplay`):** Shared `TwinkleSynth` Pure-Go stereo 44.1 kHz synthesizer generating bell/celesta lead, harmony pad, bassline, and sleigh bells.

### D. Seasonal Screen Savers, 130 Wallpapers & 24-Door Advent Calendar (macOS)
- 25 screen savers (4 Classic + Wallpaper Slideshow + 20 Seasonal modules + Swift plugin protocol), 130 seasonal wallpapers across 11 collections, and a persistent December 1–24 Advent Calendar.

### E. Version 7 Next-Generation Platform
1. **Modern 60 FPS Lighting Engine:** 15 modern shaders (`Gentle Twinkle`, `Twinklefox`, `Slow Glow`, `Color Wave`, `Rainbow Chase`, `Meteor`, `Candle Flicker`, `Fireworks`, `Glitter`, `Ripple`, `Candy Cane`, `Heartbeat`, `Scanner`, `Soft Random Fade`, `Auto-Cycle`) and 9 palettes.
2. **16 Built-In Holiday Scenes:** Atomic one-click scenes (`Classic Christmas`, `Victorian Christmas`, `Winter Wonderland`, `Christmas Fireplace`, `Snowy Village`, `New Year's Celebration`, `Valentine's Romance`, `St. Patrick's Day`, `Easter Garden`, `Spring Awakening`, `Summer Nights`, `Fourth of July`, `Autumn Harvest`, `Haunted Halloween`, `Thanksgiving`, `Peaceful Winter Evening`) plus save/duplicate/rename/export/import/restore/classic reset.
3. **Seasonal Automation Engine:** Opt-in date rules, Dec->Jan wraparound, weekday rules, quiet hours dimming, temporary manual overrides, vacation safe blackout, and offline NOAA solar sunrise/sunset calculations.
4. **Lighting Effect Studio (`.twinklefx`) & MIDI Light Show Composer:** Keyframe timeline sequencer and single-clock 7-mode MIDI light show sync on macOS.
5. **Interactive Desktop & Virtual Layout Designer (`.twinklelayout`):** Pointer proximity/sparkle effects and custom 2D geometric bulb shapes.
6. **Full Remote Web Command Center & Developer API:** Localhost-first (optional LAN) HTTP REST + RFC 6455 WebSocket server (`http://127.0.0.1:19697/remote` on Windows/Ubuntu; configurable port on macOS) with 6-digit PIN pairing, bearer tokens, real-time HTML5 visualizer, full light/scene/music/automation control, safe blackout, `TWKL` v1 binary LED telemetry, and WLED/Art-Net/DDP protocol encoders.
