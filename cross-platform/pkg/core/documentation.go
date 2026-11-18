package core

import "strings"

const (
	AppTitle      = "Re: Twinkle Bulbs — Version 7: Next Generation"
	AppVersion    = "7.0.0"
	BuildNumber   = 700
	OriginalCredit = "Don Metzler & Barefoot Productions"
)

const TributeAndFreewareBanner = `DISTRIBUTED WITH LOVE FOR THE ORIGINAL PROGRAM

This software is distributed out of love for the original Twinkle Bulbs program,
to keep the memory and love for Twinkle Bulbs alive for a new era.

ALL CREDIT GOES TO THE ORIGINAL AUTHORS:
  * Don Metzler
  * Barefoot Productions

FREEWARE LICENSE:
This restored and expanded edition is distributed freely as Freeware and may
be used, studied, shared, and modified as desired. Proprietary original Windows CD
commercial binaries remain the property of their respective authors and are not
bundled in this distribution.`

const RestorationHistoryText = `THE HISTORY & RESTORATION OF RE: TWINKLE BULBS

1. THE ORIGINAL ERA (Don Metzler & Barefoot Productions)
Twinkle Bulbs was originally created for Microsoft Windows by Don Metzler and
Barefoot Productions. Its miniature holiday lights framing the desktop perimeter,
chasing bulbs, MIDI carols, seasonal wallpapers, and screen savers brought warmth
to family computers for years. Over time, legacy Win16/Win32 desktop hooks,
binary .blb/.icl icon containers, and vintage MIDI APIs made the original harder
to run on modern operating systems, risking its disappearance altogether.

2. BRINGING TWINKLE BULBS BACK FROM THE DEAD
This release brings Twinkle Bulbs back from the dead for a new cross-platform
era across macOS, Microsoft Windows, and Ubuntu Linux.

  * 2025 — First Revival Attempts with Google Antigravity:
    Work on resurrecting Twinkle Bulbs started in 2025 with Google Antigravity.
    However, those initial versions did not meet expectations in authenticity,
    timing accuracy, desktop integration, or visual fidelity.

  * April of 2026 — Intermediate Recreations:
    New versions were created in April of 2026. Although they moved parts of
    the idea forward, they still did not function like the authentic original
    Twinkle Bulbs.

  * November of 2026 — Faithful Original Recreation & Version 7:
    Finally, in November of 2026, a full recreation of the original was built
    that functions like the real Twinkle Bulbs — reconstructing the exact 50 ms
    heartbeat, 9 Classic Flashing Modes, 6 Flash Rates, 21 Classic Color Palettes,
    strided Chase lookup math, sprite geometry and inward edge rotation, stereo
    General MIDI synthesis, and vintage 7-tab interface aesthetics, and expanding
    into Version 7: Next Generation across macOS, Windows, and Ubuntu Linux.`

const TechnicalArchitectureAndManual = `HOW RE: TWINKLE BULBS VERSION 7 WORKS (CROSS-PLATFORM MANUAL)

1. AUTHENTIC CLASSIC v6.0 ENGINE
   * Master 50 ms clock driving 6 Flash Rates:
     Slow (1200ms), Slow/Med (800ms), Medium (500ms), Med/Fast (350ms), Fast (200ms), Very Fast (80ms)
   * All 9 Classic Flashing Modes:
     None (Always On), Random, All Together, Chase (strided wave), Alternating,
     Some Bulbs Flash, Single, Pairs, and Ping-Pong.
   * All 21 Classic Color Palettes:
     Random, Purple, Blue, Red, Green, Yellow, Light Blue, White, Red/Green,
     Multi-Color, Blues, All Colors + White, Red/Blue, Purple/Green,
     Red/Yellow/Green, Red/Green/Blue, Cool Colors, Yellow/White, Red/Yellow,
     R/G/Y/B, and Red/White/Blue.
   * Placement Modes:
     Top, Top & Bottom, Around Screen, Sides Only, Top & Sides, Bottom Only,
     with bare-wire spacers, sparse spacing, No Corners, Always On Top vs Desktop,
     inward edge rotation, and burned-out / missing / broken bulb simulation.

2. 265 PROCEDURAL BULB SETS
   * 15 Classic sets (Outdoor, Normal, Large, Bare Bulbs, Peppers, Candy Canes,
     Candles, Stars, Holly, Icicles, Minibulbs, Trees, Presents, Stockings, Flowers)
     plus 250 Holiday Edition sets arranged in 25 themed collections (10 sets each).

3. MODERN 60 FPS LIGHTING ENGINE & PALETTES
   * 15 Modern animated shaders: Gentle Twinkle, Twinklefox, Slow Glow, Color Wave,
     Rainbow Chase, Meteor, Candle Flicker, Fireworks, Glitter, Ripple, Candy Cane,
     Heartbeat, Scanner, Soft Random Fade, and Auto-Cycle.
   * 9 curated color palettes plus global Speed (0.25x..3.0x) and Brightness.

4. 16 UNIFIED HOLIDAY SCENES & SEASONAL AUTOMATION
   * One-click complete environments coordinated across Classic or Modern bulbs,
     speed, brightness, music carol, screensaver theme, and ambient glow:
     Classic Christmas, Victorian Christmas, Winter Wonderland, Christmas Fireplace,
     Snowy Village, New Year's Celebration, Valentine's Romance, St. Patrick's Day,
     Easter Garden, Spring Awakening, Summer Nights, Fourth of July, Autumn Harvest,
     Haunted Halloween, Thanksgiving, and Peaceful Winter Evening.
   * Opt-in Automation supporting holiday calendar presets, Dec->Jan schedules,
     weekday filters, daily clock times, and offline NOAA solar sunrise/sunset math.

5. TWINKLESYNTH HOLIDAY CAROLS & AUDIO
   * Self-contained stereo PCM General MIDI-inspired synthesizer generating holiday
     melodies, warm bells, harp/music-box harmonics, bassline, and sleigh bells
     with zero external SoundFont or MIDI daemon dependencies.

6. FULL REMOTE WEB COMMAND CENTER & DEVELOPER HTTP/WEBSOCKET API
   * Runs a localhost-first (optional LAN) HTTP + RFC 6455 WebSocket server with
     6-digit PIN login & bearer session tokens, live real-time HTML5 LED perimeter
     visualizer, Classic/Modern/Scene/Automation/Music/Audio/System controls,
     One-Click Holiday Simulator, Safe Blackout, and binary LED frame telemetry.`

func FullDocumentationText() string {
	var b strings.Builder
	b.WriteString("================================================================================\n")
	b.WriteString(strings.ToUpper(AppTitle) + " (v" + AppVersion + ")\n")
	b.WriteString("Complete History, System Guide & Freeware Tribute\n")
	b.WriteString("================================================================================\n\n")
	b.WriteString(TributeAndFreewareBanner)
	b.WriteString("\n\n--------------------------------------------------------------------------------\n")
	b.WriteString(RestorationHistoryText)
	b.WriteString("\n\n--------------------------------------------------------------------------------\n")
	b.WriteString(TechnicalArchitectureAndManual)
	return b.String()
}
