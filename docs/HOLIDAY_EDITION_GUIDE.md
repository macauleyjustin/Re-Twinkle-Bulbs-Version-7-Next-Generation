# Twinkle Bulbs — Complete Holiday Edition (macOS)

Native Apple Silicon Swift / AppKit / CoreGraphics / AVFoundation reconstruction of **Twinkle Bulbs**, expanded into the Complete Holiday Edition while preserving 100% of original Windows v6.0 baseline behavior.

---

## 1. Preserved Original Baseline
- **Original v6.0 defaults preserved verbatim:**
  - `BulbSet`: `Outdoor` (`32×32` px normal size)
  - `FlashMode`: `Chase` (`3`)
  - `Rate`: `Medium` (`2`, 500 ms interval)
  - `ColorMode`: `Red/Green` (`8`, indices `[3, 2]`)
  - `DrawMode`: `Desktop` (`0`)
  - `Location`: `Top` (`0`)
  - `Show Bare Wire`, `No Corner Bulbs`, `Not So Many` default `true`; defect toggles (`Burned Out`, `Broken`, `Missing`, `Random`) default `false`.
- **Original engines intact:** All 9 historical `FlashMode` algorithms, all 21 `ColorMode` sequences (`tbulbs.mem 0x0048289a..0x0048366c`), 50 ms main timer tick, inward edge rotation (`RotateIcon`), 50% highlight dim blend (`#000080`), 4 classic screen savers (`Blank Screen`, `Clock`, `Fireworks`, `Snowfall`), and the v2 Advanced/Modern 15-effect lighting engine + multi-track GM MIDI Jukebox (`gs_instruments.dls`).
- **Scope exclusions honored:** No Bulb Set Builder authoring utility and no integrated screen saver authoring utility are included.

---

## 2. What Was Added in Complete Holiday Edition

### A. 250 Distinct Holiday Bulb Sets (25 Collections × 10 Designs)
Implemented cleanly in [`Holiday250Catalog.swift`](../TwinkleBulbs/Assets/Holiday250Catalog.swift) and [`Holiday250ArtPart1.swift`](../TwinkleBulbs/Assets/Holiday250ArtPart1.swift)–[`Holiday250ArtPart4.swift`](../TwinkleBulbs/Assets/Holiday250ArtPart4.swift), registered lazily in [`BulbArtworkRenderer.swift`](../TwinkleBulbs/Assets/BulbArtworkRenderer.swift):
1. Classic Christmas Lights (1–10)
2. Christmas Decorations (11–20)
3. Winter Wonderland (21–30)
4. Traditional Christmas Symbols (31–40)
5. Santa's Workshop (41–50)
6. Christmas Candy (51–60)
7. Valentine's Day (61–70)
8. St. Patrick's Day (71–80)
9. Easter (81–90)
10. Spring Garden (91–100)
11. Spring Rain (101–110)
12. Summer Beach (111–120)
13. Summer Outdoors (121–130)
14. Flags and Patriotic (131–140)
15. Birthdays and Celebrations (141–150)
16. Autumn Leaves (151–160)
17. Autumn Harvest (161–170)
18. Halloween Classics (171–180)
19. Haunted Halloween (181–190)
20. Thanksgiving (191–200)
21. New Year's Eve (201–210)
22. Celestial Lights (211–220)
23. Animals (221–230)
24. Flowers and Plants (231–240)
25. Retro & Novelty Lighting (241–250)

Every design synthesizes full `32×32` and `48×48` sprites across `ON`, `OFF` (with `#000080` / highlight dim blend), `Broken`, `Bare Wire`, `Sample`, and rotated perimeter edges (`.left`, `.right`, `.bottom`, inverted `.inward`), plus fast `24×24` thumbnail caching.

### B. Restored Windows XP-Era Settings UI & Live Previews
- [`PreferencesWindowController.swift`](../TwinkleBulbs/UI/PreferencesWindowController.swift) & [`PreferencesSecondaryTabs.swift`](../TwinkleBulbs/UI/PreferencesSecondaryTabs.swift):
  - Classic royal-blue banner (`XPClassicHeaderView` without unlicensed warning strips), warm Luna `#ECE9D8` background, explicit Aqua appearance lock for consistent crisp text rendering in macOS Dark Mode, recessed white Bulb Sets `NSTableView` with search bar, collection/favorites/recent filter, and traditional bottom `Reset Defaults`, `OK`, `Cancel`, `Apply` buttons.
  - Exact 7 historical tabs in order: **General**, **Bulbs**, **Music**, **Screen Saver**, **Wallpaper**, **Calendar**, **Help**.
  - Advanced Modern Effects (15 effects, custom palettes, MIDI reactivity) accessible via the **Modern FX...** button inside `Bulbs -> Flashing` ([`ModernEffectsTabCoordinator.swift`](../TwinkleBulbs/UI/ModernEffectsTabCoordinator.swift)) without cluttering the classic tab bar.
- Live reusable previews ([`PreviewComponents.swift`](../TwinkleBulbs/UI/PreviewComponents.swift)):
  - `BulbSetPreviewView`: live ON/OFF/burned/broken/wire sample strip.
  - `FlashingModePreviewView`: engine-driven 33 ms / 50 ms live strand preview reacting immediately to classic FlashMode, Reverse, Rate, Modern Effects, or ColorMode changes.
  - `ColorModeSwatchRenderer`: inline 7-bead palette swatches inside color dropdowns.

### C. 20 Seasonal Screen Savers + Wallpaper Slideshow + Plugin API
Implemented in [`SeasonalScreenSavers.swift`](../TwinkleBulbs/UI/SeasonalScreenSavers.swift) & [`ScreenSaverWindowController.swift`](../TwinkleBulbs/UI/ScreenSaverWindowController.swift):
- **Wallpaper Slideshow** + **20 Animated Seasonal Modules**:
  - Christmas/Winter: *Twinkling Holiday Wreath*, *Glowing Christmas Tree*, *Falling Snowfall Village*, *Crackling Fireplace Christmas*, *Frost-Covered Winter Window*, *Gingerbread Holiday Village*
  - Autumn/Halloween: *Falling Autumn Leaves* (configurable wind & background), *Glowing Halloween Pumpkin*, *Spooky Haunted House*, *Quiet Autumn Forest*, *Harvest Pumpkin Patch*
  - Spring/Easter: *Drifting Spring Blossoms*, *Warm Spring Rainstorm*, *Peaceful Easter Garden*
  - Summer/Celebrations: *Summer Evening Fireflies*, *Starry Summer Night Sky*, *Warm Beach Sunset*, *Floating Valentine Hearts*, *New Year's Midnight Celebration*, *Red-White-Blue Fireworks Display*

#### `TwinkleScreenSaverPlugin` Extensibility API
External modules can conform to `TwinkleScreenSaverPlugin` and register at runtime:

```swift
public protocol TwinkleScreenSaverPlugin: AnyObject {
    var moduleID: String { get }
    var displayName: String { get }
    func reset(in rect: CGRect, settings: AppSettings, preview: Bool)
    func step(in rect: CGRect, settings: AppSettings, tick: Int)
    func draw(in ctx: CGContext, rect: CGRect, settings: AppSettings, preview: Bool, tick: Int)
}

ScreenSaverPluginRegistry.shared.register(myPlugin)
```

### D. 130 Seasonal Wallpapers, 105-Track GM MIDI Library, & 24-Door Advent Calendar
- **Wallpapers** ([`WallpaperPack130.swift`](../TwinkleBulbs/Services/WallpaperPack130.swift) & [`WallpaperService.swift`](../TwinkleBulbs/Services/WallpaperService.swift)): 130 procedural wallpapers across 11 seasonal categories (with Center/Tile/Scale-to-Fill modes, favorites, per-monitor apply, and optional auto-rotation timer).
- **Music** ([`HolidayMusicPack105.swift`](../TwinkleBulbs/Services/HolidayMusicPack105.swift), [`NativeMIDISynthesizer.swift`](../TwinkleBulbs/Services/NativeMIDISynthesizer.swift), [`StandardMIDIPlayer.swift`](../TwinkleBulbs/Services/StandardMIDIPlayer.swift), & [`AudioEngineService.swift`](../TwinkleBulbs/Services/AudioEngineService.swift)): 105 multi-track Format-1 General MIDI arrangements synthesized natively via Twinkle Bulbs' own self-contained 64-voice General MIDI DSP & Hall Reverb engine (`TwinkleNativeGMSynth`, with optional custom RIFF `.sf2` wavetable loading — zero Apple `MIDISynth` or `gs_instruments.dls` dependency), plus custom folder `.mid/.rmi/.wav/.mp3` jukebox playback.
- **Interactive 24-Door Advent Calendar** ([`AdventCalendarWindow.swift`](../TwinkleBulbs/UI/AdventCalendarWindow.swift)): Accessible via the **Calendar** Settings tab or menu bar **Advent Calendar...**, persisting opened doors across launches, locking future December dates by default, with an optional **Allow Opening Any Date (Preview Mode)** checkbox.

---

## 3. Building, Installation & Usage

```bash
cd /Users/renseven/.gemini/antigravity/scratch/TwinkleBulbsMac
./build_app.sh
swift run TwinkleBulbsVerifier
open build/TwinkleBulbs.app
```

- **Importing external Windows bulb sets:** Open **Settings -> Bulbs -> Import...** or copy `.blb`, `.icl`, `.ico`, or standard-ZIP/zlib-wrapped `.blz` files into:
  `~/Library/Application Support/TwinkleBulbs/ImportedBulbs/`
- **Importing custom music:** Open **Settings -> Music -> Choose Folder...** and select any directory containing `.mid`, `.rmi`, `.wav`, or `.mp3` files.
- **Resetting defaults cleanly:** Hold `Option` while launching, or click **Reset Defaults** in Settings.

---

## 4. Known Limitations & Reference Disclosure
1. **No user-supplied reference screenshot PNG:** No bitmap screenshot of the Windows Twinkle Bulbs Settings dialog was present in the local workspace (`research/`, `~/Desktop`, or `~/Downloads`), so the Classic XP dialog recreation was reconstructed directly from extracted Win32 `DIALOG/131..142` resource layouts and bitmaps (`research/v6_dump/`) rather than pixel-diffing against an external PNG.
2. **`.blz` proprietary compression format:** [`BLBResourceLoader.swift`](../TwinkleBulbs/Assets/BLBResourceLoader.swift) cleanly unwraps zlib (`0x78`) and stored-PKZIP (`PK\x03\x04`) `.blz` wrappers as well as PE/NE `.blb`/`.icl`/`.ico` binaries. Proprietary compressed `.blz` streams generated by later Bulb Set Builder releases (whose undocumented stream codec cannot be decoded without sample `.blz` fixtures from that tool) return `nil` cleanly without crashing.
