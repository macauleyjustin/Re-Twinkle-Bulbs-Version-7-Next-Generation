# Twinkle Bulbs Version 2 — MIDI Restoration & Advanced Lighting Architecture

## 1. Phase 2.1 Diagnosis of Version 1 Audio Engine
Inspection of the Version 1 `AudioEngineService.swift` established four primary causes for missing authentic Twinkle Bulbs jukebox behavior:
1. **Built-in carols were monophonic single-note chimes:** `builtInCarols()` held single-note `(midi, beats)` melody arrays stepped by a `Timer` into a bare `AVAudioUnitSampler` with zero harmony, bass, or percussion channels.
2. **No General MIDI sound bank configured:** `AVMIDIPlayer(contentsOf: url, soundBankURL: nil)` and `AVAudioUnitSampler` did not configure Apple's Roland GS Wavetable bank (`/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls`) or allow selecting external `.dls`/`.sf2` sound banks.
3. **Silent error handling:** Load failures (`try?` / `catch`) fell into `playBuiltInCarolFallback` which silently returned on imported tracks (`builtInNotes == nil`) while leaving `isPlaying == true`.
4. **Incomplete Jukebox controls:** No live volume slider, pause/resume/previous/restart transport, `.rmi` unwrapping, custom folder scanning, repeat modes (`Stop After Playlist`, `Repeat All`, `Repeat One`), inter-track delay, or sound-bank selection UI.

## 2. Version 2 Restored MIDI Engine & Jukebox (`StandardMIDIPlayer.swift` + `AudioEngineService.swift`)
- **Pure-Swift SMF & RIFF `.rmi` Parser (`StandardMIDIFileParser`):** Parses SMF Format 0, 1, and 2 files as well as Windows RIFF `.rmi` containers, honoring multi-track merges, running status, VLQ deltas, Meta tempo maps (`0xFF 0x51`), Time Signatures, Program Changes, Bank Select (`CC 0/32`), Volume (`CC 7`), Pan (`CC 10`), Expression (`CC 11`), Sustain (`CC 64`), Pitch Bend (`0xE0`), and Channel 10 Percussion (`ch == 9`).
- **GS Wavetable Synthesizer (`MIDISynthPlayer`):** Uses `AVAudioEngine` + `AVAudioUnitMIDIInstrument` (`kAudioUnitSubType_MIDISynth`) loaded with `/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls` (Apple's Roland Sound Canvas GS Wavetable bank, matching historical Windows GS Wavetable instrumentation without bundling proprietary Roland/Microsoft binaries) or any user-selected `.sf2` / `.dls` file.
- **Built-in Multi-Track GM Carols (`BuiltInCarolMIDIBuilder`):** Generates genuine Format 1 multi-track Standard MIDI arrangements (Lead Melody + Strings Harmony + Bass + Channel 10 Sleigh Bells/Tambourine/Hi-Hat) for all 8 built-in carols.
- **Programmable Jukebox:** Recursive folder discovery (`.mid`, `.midi`, `.rmi`, `.wav`, `.mp3`, `.m4a`, `.aiff`, `.aac`, `.caf`), Sequential / Shuffle, Repeat (`Stop After Playlist`, `Repeat All`, `Repeat One`), configurable inter-track delay, live volume control, Pause/Resume/Previous/Next, Screen Saver-only music gating, and visible error reporting.

## 3. Advanced / Modern Lighting Engine (`ModernLightingEngine.swift` & `ModernEffectsTabCoordinator.swift`)
- **Strict Separation from Classic v6.0:** Default `lightingCategory` remains `.classic`. Classic `BulbEngine` (`50 ms` fixed timer, 9 FlashModes, 21 ColorModes, v6 defaults) is untouched. Returning to `Original / Classic` immediately restores classic behavior without overwriting any classic settings.
- **15 Programmable Modern Patterns:**
  1. Gentle Twinkle
  2. Twinklefox
  3. Slow Glow
  4. Color Wave
  5. Rainbow Chase
  6. Meteor
  7. Candle Flicker
  8. Fireworks
  9. Glitter
  10. Ripple
  11. Candy Cane
  12. Heartbeat
  13. Scanner
  14. Soft Random Fade
  15. Combination / Automatic Cycle
- **Sprite-Preserving 30–60 FPS Renderer:** `BulbArtworkRegistry.modernImages(for:settings:)` draws the authentic base sprite (preserving wire, socket, and silhouette) with a quantized cached RGB-tinted illuminated sprite layered via alpha (`0.0 ... 1.0`), preserving `RotateIcon` inward rotation and multi-monitor edge geometry.
- **Optional MIDI-Reactive Modes (`Phase 6`):** Synchronizes directly with live dispatched MIDI notes/velocities/channels (`Beat Pulse`, `Notes Along Strand`, `Channel Colors`, `Velocity Brightness`, `Tempo-Synced Chase`).

## 4. Known Limitations
- **SysEx GS Effects:** System Exclusive reverb/chorus SysEx parameters are safely skipped by the pure-Swift SMF parser; standard MIDI Channel Voice controllers (Bank Select, Volume, Pan, Expression, Sustain, Pitch Bend, Program Change) handle expressive synthesis cleanly.
- **Proprietary Sound Banks:** Microsoft's proprietary `gm.dls` is not bundled; macOS's built-in GS bank (`gs_instruments.dls`) is used by default and users may browse to any custom `.sf2` or `.dls` sound bank in **Settings → Music**.
- **Sandboxed Folder Bookmarks:** Folder paths selected via `NSOpenPanel` work immediately in the non-sandboxed native `.app` bundle; re-granting folder permission via **Choose Folder...** may be required if macOS TCC prompts are declined.
