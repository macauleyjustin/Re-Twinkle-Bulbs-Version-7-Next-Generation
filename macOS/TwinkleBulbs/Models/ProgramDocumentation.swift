import Foundation

// MARK: - Canonical In-App History, Complete System Manual & Tribute Documentation

public enum ProgramDocumentation {
    public static let editionTitle = "Re: Twinkle Bulbs — Version 7: Next Generation"
    public static let versionString = "7.0.0"

    public static let tributeAndFreewareBanner = """
    DISTRIBUTED WITH LOVE FOR THE ORIGINAL PROGRAM

    This software is distributed out of love for the original Twinkle Bulbs program, to keep \
    the memory and love for Twinkle Bulbs alive for a new era.

    ALL CREDIT GOES TO THE ORIGINAL AUTHORS:
      • Don Metzler
      • Barefoot Productions

    FREEWARE LICENSE:
    This restored and expanded edition is distributed freely as Freeware and may be studied, \
    shared, and modified as desired. Proprietary original commercial assets remain the property \
    of their respective authors and are never bundled with this release.
    """

    public static let restorationHistoryText = """
    THE HISTORY & RESTORATION OF RE: TWINKLE BULBS

    1. THE ORIGINAL ERA (Don Metzler & Barefoot Productions)
    Twinkle Bulbs was originally created for Microsoft Windows by Don Metzler and Barefoot \
    Productions. For countless holiday seasons, its miniature Christmas bulbs framing the \
    desktop perimeter, classic chasing lights, MIDI carols, wallpapers, and screen savers \
    brought warmth to family computers. Over time, 16-bit/32-bit Windows dependencies, GDI \
    desktop hooks, legacy bitmap `.blb`/`.icl` libraries, and abandoned MIDI sequencers made \
    the original software harder to run on modern computers. Twinkle Bulbs risked disappearing \
    altogether.

    2. BRINGING TWINKLE BULBS BACK FROM THE DEAD
    This version is a restored, ground-up recreation bringing Twinkle Bulbs back from the dead \
    and into a new cross-platform era (macOS, Windows, and Ubuntu Linux).

    • 2025 — First Revival Efforts with Google Antigravity:
      Work on resurrecting Twinkle Bulbs began in 2025 alongside Google Antigravity. However, \
      early experimental builds did not meet expectations in visual authenticity, timing behavior, \
      or overall polish.

    • April 2026 — Intermediate Builds:
      Updated versions were created in April of 2026. While they explored parts of the concept, \
      they still did not function like the authentic original Twinkle Bulbs — falling short of \
      the true flashing cadence, chase math, desktop layering, UI character, and holiday audio \
      that defined Barefoot Productions' release.

    • November 2026 — True Original Recreation & Next Generation:
      Finally, in November of 2026, a full engineering recreation of the original was completed. \
      By faithfully reconstructing the exact 50 ms master cadence, Flashing Mode algorithms, \
      fixed interval and chase stride lookup tables, 21 classic color palettes, sprite geometry, \
      inward edge rotation transforms, classic Windows XP 7-tab Settings dialog, and authentic \
      holiday jukebox + screensavers, the software once again functioned like the real \
      Twinkle Bulbs. From that rock-solid authentic core grew the Complete Holiday Edition \
      and finally Version 7: Next Generation — keeping classic v6.0 100% intact while adding \
      modern 60fps effects, Holiday Scenes, Automation, Effect & MIDI Show Studios, Virtual \
      Layouts, Remote Web/API Control, and cross-platform Windows & Ubuntu ports.
    """

    public static let technicalArchitectureAndManual = """
    COMPLETE TECHNICAL ARCHITECTURE & FEATURE GUIDE (HOW EVERYTHING WORKS)

    1. AUTHENTIC CLASSIC v6.0 ENGINE (`BulbEngine.swift`, `AppSettings.swift`)
       • Master Heartbeat: Polls cleanly every 50 ms on the main RunLoop.
       • Exact Flash Rates: Slow (1200 ms), Slow/Medium (800 ms), Medium (500 ms), \
         Medium/Fast (350 ms), Fast (200 ms), Very Fast (80 ms).
       • All 9 Classic Flashing Modes: None (Always On), Random (hold 2000..2700 ms down \
         to 50..120 ms), All Together, Chase (strided wave groups matching N<=50 table and \
         wide-DPI extension for N>50), Alternating, Some Bulbs Flash, Single, Pairs, and Ping-Pong.
       • All 21 Classic Color Modes: Exact palette index tables (`colorSequence`) spanning \
         Random (zero consecutive repeats), Purple, Blue, Red, Green, Yellow, Light Blue, \
         White, Red/Green, Multi-Color, Blues, All Colors + White, Red/Blue, Purple/Green, \
         Red/Yellow/Green, Red/Green/Blue, Cool Colors, Yellow/White, Red/Yellow, R/G/Y/B, \
         and Red/White/Blue.
       • Layout & Placement: 6 perimeter modes (Top, Top & Bottom, Around Screen, Sides Only, \
         Top & Sides, Bottom Only), Desktop icon level vs Always On Top vs Menu Bar level, \
         Bare Wire spacers, No Corners clearance, Sparse Spacing (`NotSoMany`), Inward edge \
         rotation (-90/+90/180 deg via exact pixel transpose `RotateIcon`), Broken / Burned-Out \
         / Missing defect simulation, Multi-Monitor span, and Bulb Changer auto-rotation.

    2. 265+ BULB SETS & PE/NE BINARY IMPORTER (`BulbArtworkRenderer.swift`, `BLBResourceLoader.swift`, `Holiday250Catalog.swift`)
       • 15 Classic clean-room sets (Outdoor, Normal, Large, Bare Bulbs, Peppers, Candy Canes, \
         Candles, Stars, Holly, Icicles, Minibulbs, Trees, Presents, Stockings, Flowers) plus \
         250 procedural Holiday Edition designs organized into 25 themed collections (10 each).
       • Supports both 32x32 Normal and 48x48 Large high-DPI sprites with authentic 50% dim \
         highlight blending (`blendHalfWithHighlight`).
       • Pure-Swift Windows PE/NE parser decodes user-owned `.blb`, `.icl`, `.ico`, and \
         stored-ZIP `.blz` files safely at runtime without executing any Windows binaries.

    3. SELF-CONTAINED 64-VOICE GENERAL MIDI SYNTHESIZER (`NativeMIDISynthesizer.swift`, `StandardMIDIPlayer.swift`, `AudioEngineService.swift`)
       • Powered by `TwinkleNativeGMSynth`, a custom 64-voice General MIDI DSP synthesizer + \
         Schroeder Stereo Hall Reverb streaming stereo 32-bit float audio into `AVAudioSourceNode`.
       • Includes pianos, electric pianos, FM chromatic bells (Celesta, Music Box, Tubular \
         Bells, Vibraphone), organs, strings, ensembles, brass, reed/flutes, basses, synths, \
         and synthesized Channel 10 holiday percussion (Sleigh Bells, kicks, snares, hats).
       • Parses Format 0/1/2 Standard MIDI & Windows RIFF `.rmi` containers, supports optional \
         custom `.sf2` SoundFont 2 wavetable banks, ships 105 multi-track built-in GM carols, \
         and discovers `.mid`, `.midi`, `.rmi`, `.mp3`, `.wav`, `.aiff`, `.m4a`, `.aac`, `.caf`.

    4. SEASONAL SCREEN SAVERS, 130 WALLPAPERS & 24-DOOR ADVENT CALENDAR
       • 25 Screen Saver modules: 4 Classic (`Blank`, `Clock`, `Fireworks`, `Snowfall`), CD \
         Wallpaper Slideshow, and 20 rich Seasonal Screen Savers plus `TwinkleScreenSaverPlugin` \
         Swift extensibility protocol and Hot-Corner / idle detection.
       • 130 Procedural Seasonal Wallpapers (`WallpaperPack130.swift`) across 11 collections \
         with Tile/Center/Stretch/Fit modes and timed rotation.
       • 24-Door December Advent Calendar with real date locking, Preview toggle, and persistence.

    5. ADVANCED / MODERN LIGHTING ENGINE (`ModernLightingEngine.swift`)
       • Strictly separated from Classic v6.0 mode (`lightingCategory == .modern`).
       • Runs at 15–60 FPS with 15 shaders (Gentle Twinkle, Twinklefox, Slow Glow, Color Wave, \
         Rainbow Chase, Meteor, Candle Flicker, Fireworks, Glitter, Ripple, Candy Cane, \
         Heartbeat, Scanner, Soft Random Fade, Combination Auto-Cycle) across 9 palettes.

    6. VERSION 7 NEXT-GENERATION PLATFORM
       • Unified Holiday Scenes (`HolidaySceneManager.swift`): 16 built-in scenes, live preview, \
         custom CRUD, `.twinklescene` export/import, Restore Previous Scene, Return to Classic.
       • Seasonal Automation (`SeasonalScheduleService.swift`): Opt-in scheduler supporting \
         specific dates, Dec->Jan date ranges, weekdays, daily times, offline NOAA solar \
         sunrise/sunset offsets, manual overrides, Vacation Mode, midnight Quiet Hours, and \
         system wake recovery.
       • Lighting Effect Studio (`EffectTimelineEngine.swift`): Frame-rate independent keyframe \
         sequencer supporting 13 event kinds, 6 curves, Undo/Redo, and `.twinklefx` files.
       • MIDI Light Show Composer (`MIDILightShowComposer.swift`): Synchronizes directly to \
         `MIDISynthPlayer`'s single clock across all 7 reactive modes (including Instrument \
         Mapping & Percussion Effects) plus cue markers and opt-in internal PCM energy.
       • Interactive Desktop (`InteractiveDesktopEffectsEngine`) & Virtual Layout Designer \
         (`VirtualLightingLayoutEngine`): Click-through pointer glow/ripples/sparkles/bursts \
         and 9-shape architectural 2D strand layout canvas (`.twinklelayout`).
       • Full Web Command Center, REST & Bidirectional WebSocket API (`TwinkleLightingAPIService`, \
         `RemoteControlService`, `LightingAdapterProtocol`): Localhost-first server with 6-digit \
         PIN & bearer token auth, real-time LED visualizer canvas, full control over every \
         setting/asset, `TWKL` v1 binary streaming, safe blackout, and WLED/Art-Net/DDP encoders.
       • Weather/Time-of-Day curves, strictly opt-in Screen Color Sync, SHA-256 validated \
         `.twinklepack` ZIP theme packages, GIF/H.264 MP4/frame export, and `PerformanceCoordinator`.

    PREFERENCE & DATA STORAGE (MACOS):
       • Settings: UserDefaults key `com.twinklebulbs.mac.v6.settings`
       • Next-Gen State: `~/Library/Application Support/TwinkleBulbs/NextGen/nextgen_config.json`
       • Imported Bulbs/Music/Wallpapers: `~/Library/Application Support/TwinkleBulbs/`
    """

    public static var fullDocumentText: String {
        """
        ================================================================================
        \(editionTitle.uppercased())
        Complete History, System Architecture, User Guide & Freeware Dedication
        ================================================================================

        \(tributeAndFreewareBanner)

        --------------------------------------------------------------------------------
        \(restorationHistoryText)

        --------------------------------------------------------------------------------
        \(technicalArchitectureAndManual)
        """
    }
}
