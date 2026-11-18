# Re: Twinkle Bulbs Next Generation — Feature Guide (v2.0)

Re: Twinkle Bulbs Next Generation expands the authentic Re: Twinkle Bulbs macOS experience into a complete year-round programmable lighting and desktop holiday platform while keeping the classic Windows XP-era 7-tab Settings window, 9 classic flashing modes, 21 color palettes, and 50 ms rendering engine intact and optional.

## 1. Classic v6.0 Compatibility Mode

Every modern feature is opt-in and non-destructive:
- **Return to Classic Twinkle Bulbs** in the Holiday Scenes Browser or Studio Workspace immediately restores authentic v6.0 defaults (`Outdoor` bulbs, `Chase`, `Red & Green`, 50 ms cadence, XP Settings UI) while keeping your playlists, favorites, and Advent doors intact.

## 2. Holiday Scenes (`HolidaySceneManager` & Browser)

- **16 Built-In Complete Holiday Scenes**:
  Classic Christmas, Victorian Christmas, Winter Wonderland, Christmas Fireplace, Snowy Village, New Year's Celebration, Valentine's Romance, St. Patrick's Day, Easter Garden, Spring Awakening, Summer Nights, Fourth of July, Autumn Harvest, Haunted Halloween, Thanksgiving, and Peaceful Winter Evening.
- Full management: **Preview Live**, **1-Click Activate**, **Save Current**, **Duplicate**, **Rename**, **Delete** (built-in scenes protected), **Favorites**, **Restore Previous Scene**, and **Export / Import `.twinklescene`**.

## 3. Seasonal Automation & Countdowns (`SeasonalScheduleService`)

- Opt-in rule engine (`automationEnabled` disabled by default) with priorities (`Manual Temporary Override > Rule Priority`) supporting Specific Dates, Date Ranges (including Dec→Jan wraparound), Weekdays, Daily Times, Annual Holidays, and local offline **NOAA Solar Sunrise / Sunset Offsets**.
- Includes **Vacation Mode**, **Quiet Hours Dimming/Muting**, **Auto-Shutdown**, system wake / DST / timezone recovery, and milestone **Countdown Celebrations**.

## 4. Lighting Effect Studio (`.twinklefx`)

- Visual multi-track keyframe timeline editor with draggable playhead, scrubbable preview strand driven by `EffectTimelineEngine`, **Undo/Redo**, **13 event types**, and **6 interpolation curves** (Linear, Ease In, Ease Out, Ease In-Out, Step, Custom Cubic Bezier).
- Frame-rate independent evaluation (`seconds`-based keyframes) and versioned `.twinklefx` export/import.

## 5. MIDI Light Show Composer (`.twinklemidi`)

- Synchronizes directly to `AudioEngineService.shared` / `MIDISynthPlayer.currentPositionSeconds` (zero separate clock drift).
- Supports **all 7 reactive modes**: Beat Pulse, Notes Along Strand, Channel Colors, Velocity Brightness, Tempo-Synced Chase, **Instrument Mapping**, and **Percussion Effects**, plus timed cue markers and opt-in internal PCM mixer-level sync for MP3/WAV files (zero microphone permission required).

## 6. Interactive Desktop Decorations & Celebrations

- Disabled by default; desktop overlays always remain `ignoresMouseEvents = true` (zero Accessibility permissions needed).
- Supports **Pointer Proximity Glow**, **Moving Strand Ripples**, **Subtle Sparkle Trails**, **Particle Pointer Interaction**, and 1-click **Celebration Bursts** (Christmas, New Year, Halloween, Birthday).

## 7. Virtual Lighting Layout Designer (`.twinklelayout`)

- Interactive 2D drag/resize canvas with **9 strand geometries** (Straight Line, Roofline Gables, Christmas Tree, Holiday Wreath, Window Outline, Door Frame, Porch Railing, Yard Border, Custom Curve), zone tags, per-strand bulb counts/sets/effects, and optional local-only reference background photo import.

## 8. Full Web Command Center, External Control API & Mobile Remote (`TwinkleLightingAPIService`)

- Disabled and localhost-bound (`127.0.0.1`) by default; open **Web & External Remote Control...** from the menu bar to enable full LAN/localhost remote control in one click.
- Full responsive HTML5 + Canvas + WebSocket Control Center at `/` and `/remote` (secured via rotating **6-digit PIN** or **Control Token**) provides real-time live bulb strand visualization plus remote control over all 265+ bulb sets, 9 classic & 15 modern effects, placement & defects, 16+ scenes, `.twinklefx` timelines, 105+ jukebox tracks & 7 MIDI light modes, 25 screen savers, 130 wallpapers, seasonal automation, weather, interactive modes, celebration bursts, and Emergency Blackout.
- Supports both HTTP `POST /v1/control` and **bidirectional RFC 6455 WebSocket** JSON commands (`GET /v1/stream`) for control-authorized clients.

## 9. Weather Atmosphere, Time-of-Day & Ambient Screen Sync

- Offline NOAA solar evening cue + simulated weather modes (`Snowfall`, `Rainy`, `Windy`, `Clear Night`, `Overcast`), optional disclosed Open-Meteo lookup, 4-segment **Time-of-Day Brightness Curve**, and strictly opt-in downsampled **Ambient Screen Color Sync** with immediate Stop control.

## 10. Portable `.twinklepack` Bundles & Animation Exporter

- **`.twinklepack` Manager**: pure-Swift Store ZIP packager with SHA-256 manifest digest verification, rejecting path traversal (`..`), absolute paths, symbolic links, oversized archives, and executable files.
- **Animation Exporter**: renders straight from the live lighting engine to **Animated GIF**, **H.264 MP4**, and **`.twinkleframes`** JSON.

## 11. Adaptive Performance & Accessibility

- `PerformanceCoordinator` queries AC vs. Battery (`IOKit.ps`), Low Power Mode, Thermal State, OS Reduce Motion, and Increase Contrast to dynamically scale Modern frame rate (`60 → 30 → 20 → 15 fps`) without ever altering Classic 50 ms timing.
