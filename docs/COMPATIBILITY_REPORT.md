# Twinkle Bulbs 6.0 for macOS — Compatibility & Adaptation Report

**Project Root:** `/Users/renseven/.gemini/antigravity/scratch/TwinkleBulbsMac`  
**Target Platform:** macOS 13+ (Apple Silicon `arm64` native; universal-ready AppKit / CoreGraphics / AVFoundation)  
**Toolchain Build Target:** macOS SDK (`MacOSX.sdk`), Swift 5/6 mode (`Package.swift` + `TwinkleBulbs.xcodeproj`)

---

## 1. Windows-to-macOS Subsystem Mapping

| Windows v6.0 Component | Original Win32 Mechanism | Native macOS Replacement | Behavioral Notes |
|---|---|---|---|
| Desktop Light Overlay (`DrawMode=0`) | `HWND_DESKTOP` / `WS_EX_LAYERED` bitmap blitting | Transparent click-through borderless `NSWindow` (`ignoresMouseEvents = true`, `isOpaque = false`, `backgroundColor = .clear`) at `CGWindowLevelForKey(.desktopIconWindow) + 1` | Positioned starting cleanly below the macOS Menu Bar so the top light strip is fully visible rather than covered by the translucent Menu Bar. |
| Always On Top Overlay (`DrawMode=1`) | `HWND_TOPMOST` + `UpdateLayeredWindow` | `NSWindow` at `.floating` level over `screen.visibleFrame` with `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]` | Stays visible across macOS Spaces without intercepting clicks or appearing in Mission Control / Cmd+Tab. |
| Taskbar Strand (`DrawMode=2`) | `SHAppBarMessage` + `WndHook.dll` | `NSWindow` at `.statusBar` level pinned to the top Menu Bar edge (or full screen edges) | Mirrors Twinkle Bulbs' Taskbar lighting strip cleanly without modifying macOS Dock processes. |
| System Tray (`Shell_NotifyIconA`) | Win32 Notification Area icon + L/M/R click routing | Native `NSStatusItem` in the macOS Menu Bar | Supports selectable bulb icons, `FlashIcon` blinking synced to `bulb[0]`, and configurable L/R/Middle actions (`TrayLeftClick`, `TrayRightClick`, `TrayMiddleClick`). |
| Idle Screen Saver Trigger | `TBIdle.dll` global mouse/keyboard Windows hook | `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)` | Does not require kernel/injection hooks; polls cleanly once per second. |
| Hot Corners (`UseHotCorners`) | Corner cursor polling in host timer | Screen-edge `NSEvent.mouseLocation` check against active display bounds | Triggers selected corner launch when mouse enters top-left, top-right, bottom-left, or bottom-right 6pt corner. |
| Music Playback (`music/*.mid`) | Win32 MCI `mciSendString` MIDI sequencer | Clean-room polyphonic `AVAudioUnitSampler` synthesizer for built-in carols + `AVMIDIPlayer` & `AVAudioPlayer` for user-imported `.mid`/`.wav`/`.mp3`/`.m4a` | Respects Sequential/Random order, Screen-Saver-only music mode, and automatic Pause Timer. |
| UI Sound Effects | `WINMM!PlaySoundA` WAV resources (`165..388`) | Pre-rendered clean-room WAV SFX buffers played via `AVAudioPlayer` | Matches original v6.0 click/tick/pop/chime timing (`12–307 ms`), controllable via `SoundFX` toggle and `Shift`-at-launch mute. |
| Desktop Wallpaper Changer | `SystemParametersInfo(SPI_SETDESKWALLPAPER)` | `NSWorkspace.shared.setDesktopImageURL(_:for:options:)` | Applies built-in clean-room festive wallpapers or user-imported images across active display(s) using Tile / Center / Stretch / Fit. |
| Bulb Resource Packs (`.blb`/`.icl`/`.ico`) | `LoadLibrary` / `LoadImage` / `ExtractIcon` + `ImageList_GetIcon(..., ILD_BLEND50)` | Clean-room pure-Swift PE/NE binary resource parser (`BLBResourceLoader.swift`) | Decodes Win32 `RT_STRING (5000..5014)`, `RT_GROUP_ICON`, `RT_ICON`, `RT_BITMAP`, NE icon tables, and 50% highlight blending without executing Windows code. |

---

## 2. Unavoidable Platform Differences & Design Refinements

1. **Keyboard Lock LEDs (`KeyLights` toggle):**
   - Original Windows `SetKeyboardState` / `keybd_event` toggled physical Caps Lock / Num Lock / Scroll Lock LEDs while the screen saver ran.
   - Modern macOS user-space apps cannot arbitrarily pulse hardware Caps Lock LEDs via public AppKit without interfering with active keyboard state or requiring restricted HID entitlements. The preference key (`keyLights`) is preserved in configuration schema compatibility, while screen-edge bulbs and screen-saver visual animations remain unaffected.
2. **Ultra-Wide / Retina Display Chase Stride (`N > 50`):**
   - `tbulbs.exe` (`0x004846d8`) mapped bulb counts `<= 50` to strides `[4, 5, 8, 6, 8, 10]` and defaulted `> 50` to `2` (designed for 800×600..1600×1200 monitors capped at 80 slots). On modern wide Retina displays (`>= 1728pt`) when `NotSoMany=true` (`step = 2`), a stride of `2` lights every active bulb simultaneously rather than chasing. `BulbEngine.chaseStride(bulbCount:notSoMany:)` preserves the exact original table for `N <= 50` (and exports `legacyChaseStride` for exact verification) while selecting stride `8` (when `NotSoMany`) or `6` for `N > 50` so high-DPI Mac displays retain the intended Chase wave look.
3. **Screen Saver Password (`ssUsePassword`) & Global Lock Screen:**
   - macOS reserves system lock-screen authentication to `loginwindow` (`pmset displaysleepnow` / Lock Screen). Twinkle Bulbs renders its own `.screenSaver`-level overlay across all connected `NSScreen`s matching Blank Screen, Clock, Fireworks, and Snowfall modules cleanly with customizable dismiss sensitivity.
4. **Menu Bar Safe Area:**
   - Because macOS draws a permanent Menu Bar across the top of the primary display (24–38 pt tall, taller around camera housings), `DrawMode == .desktop` aligns the top strip directly beneath the Menu Bar so lights stay 100% visible, while `DrawMode == .menuBarTaskbar` deliberately renders at `.statusBar` window level over the Menu Bar band itself.
5. **Licensing & Clean-Room Asset Separation:**
   - Per license terms in `research/v6_extracted/license.txt`, no proprietary Barefoot Productions `.exe`, `.dll`, `.blb`, `.icl`, `.mid`, `.jpg`, or extracted bitmap assets are compiled into `TwinkleBulbs.app`. Instead, Twinkle Bulbs ships with clean-room recreated native sprite sets and carol/wallpaper synthesizers, while users who own original Windows Twinkle Bulbs media can import their local files at runtime into `~/Library/Application Support/TwinkleBulbs/`.
