# Twinkle Bulbs v6.0 — Reverse Engineering Behavioral Specification

**Target Software:** Barefoot Productions Twinkle Bulbs v6.0 (`tbulbs.exe`, PrivateBuild `12-Oct-2005`, build timestamp `Oct 24 2005 11:08:41`)  
**Source Archive:** `/Users/renseven/Downloads/TBULBS.tar` (`SHA-256: 5c4df7c40f7a266b460fc01dbe2f5ef52ab505663d799d038c3db488e9d840c4`, preserved unmodified)  
**Analysis Basis:** Static unpacking of Wise installer (`tbulbs5x setup.exe`) -> ASPack 2.12 unpacked PE images (`tbulbs.mem`, `TBIdle.mem`, `WndHook.mem`), Win32 `.blb`/`.tss` inspection, resource extraction, string/dialog/help analysis, and Capstone x86 disassembly.

---

## 1. Extracted Components & Architecture

### 1.1 Main Modules
- `tbulbs.exe` (unpacked `tbulbs.mem`, ImageBase `0x00400000`, OEP `0x004C90BC`, MSVC++ MFC Win32 GUI application)
- `TBIdle.dll` (global mouse/keyboard/idle detection hook used to trigger the built-in screen saver after `DelayMinutes`)
- `WndHook.dll` (window/desktop/taskbar hook support for Taskbar light placement & desktop subclassing)
- `Unzdll.dll`, `Zipdll.dll` (diagnostic/archive utilities)
- `bulbs/*.blb` (25 Win32 PE resource-only DLL bulb libraries) + `bulbs/Big Bulbs.icl` (icon library)
- `scrnsave/*.tss` (4 Win32 PE DLL built-in screen saver engines: `Blank Screen.tss`, `Clock.tss`, `Fireworks.tss`, `Snowfall.tss`)
- `music/*.mid` (10 Standard MIDI carol files)
- `wallpaper/*.jpg` (9 holiday desktop wallpaper images)
- `Readme.txt`, `license.txt`, `order.txt`

### 1.2 Embedded UI & Sound Resources (`tbulbs.exe`)
- **20 RTF Help Topics** (`RTF` resources `7998..8015`, `8100`, `9000`) documenting every Preferences tab, `.blb` format (`8009`), command-line flags, Advanced Settings (`8015`), and Tip of the Day (`TEXT/281`: 38 tips).
- **9 WAV Sound Effects**:
  - Mapped via `PlayUIEffect` (`0x00472f30`) when `SoundFX == 1`:
    - `case 0, 10`: `wave_165.wav` (22050 Hz 16-bit, 0.034s — click / UI switch)
    - `case 1`: `wave_253.wav` (22254 Hz 8-bit, 0.013s — soft tick)
    - `case 2, 3`: `wave_254.wav` (22050 Hz 16-bit, 0.019s — alternate UI tick)
    - `case 11`: `wave_257.wav` (11025 Hz 8-bit, 0.002s — pop)
    - `case 5`: `wave_253.wav` if `arg2 != 0`, else silent
    - `case 9`: `wave_166.wav` (22050 Hz 16-bit, 0.031s — menu/tab sound)
    - `case 12`: `wave_388.wav` (22050 Hz 16-bit, 0.307s — chime / notification)
  - Plus event/startup/calendar WAVs (`wave_256.wav` 0.483s, `wave_258.wav` 0.151s, `wave_262.wav` 0.133s).

---

## 2. Exact Default Configuration (`LoadSettings` @ `0x0047b670..0x0047e400`)

### 2.1 General Preferences (`DIALOG/139`)
- `TrayIcon`: `0` (Default yellow/multicolor icon; multiple tray icon styles selectable)
- `TrayLeftClick`: `1` (`Configuration` — open Settings)
- `TrayRightClick`: `0` (`Popup Menu`)
- `TrayMiddleClick`: `0` (`Popup Menu`)
  - Tray Click Action enum (`COMBOBOX` items from `DLGINIT/139`):
    - `0`: Popup Menu
    - `1`: Configuration
    - `2`: Toggle Music
    - `3`: Exit Program
    - `4`: Play Next Music
    - `5`: Start Screensaver
    - `6`: View Calendar
- `SplashScreen`: `1` (show splash at startup)
- `ToolTips`: `1`
- `WarningMsgs`: `1`
- `CPUPriority`: `2` (Normal)
- `ConfirmExit`: `1` ("Exit Twinkle Bulbs?")
- `StartupOptions`: `0`
- `StartupCalendar`: `0`
- `RunSSOnly`: `0`
- `SoundFX`: `1`
- `BulbGen`: `0` (Progress dialog during bulb set loading)
- `FlashIcon`: `0` (Flash menu bar / tray icon synced with `bulb[0]`)
- `Zoom`: `0` (Animate dialog show/close)
- `QuickAccess`: `0` (Floating Quick Access mini-bar window)
- `EnhancedMenu`: `1`
- `DetectBulbChanges`: `0`
- `SysColorHighlight`: `1`
- `HighlightColor`: `0` (RGB `0x000000`)

### 2.2 Bulbs Preferences (`DIALOG/131`)
- `BulbSet`: `"outdoor.blb"`
- `FlashMode`: `3` (**Chase**)
- `Rate`: `2` (**Medium**)
- `Color`: `8` (**Red/Green**)
- `DrawMode`: `0` (**On the Desktop**, `1` = **Always On Top**, `2` = **Taskbar / Menu Bar strip**)
- `Transparency`: `0` (Windows layered overlay toggle — Always On Top overlays on macOS use per-pixel alpha click-through `NSWindow`)
- `Location`: `0` (**Top**, `1` = Top/Bottom, `2` = Around Screen, `3` = Sides Only, `4` = Top and Sides, `5` = Bottom Only)
- `BulbSize`: `0` (**Normal 32x32**, `1` = **Large 48x48**) (`GetBulbSizePixels` @ `0x00488f80`)
- `BareWire`: `1` (Connect spaced bulbs with bare wire)
- `NoCorners`: `1` (Leave corners blank & center strips in `Around Screen`)
- `NotSoMany`: `1` (Place fewer bulbs — every 2nd slot with bare wire in between)
- `Broken`: `0` (Randomly break ~16% of bulbs)
- `BurnedOut`: `0` (Randomly burn out ~30% of bulbs)
- `Missing`: `0` (Randomly omit ~20% of bulbs)
- `MixBulbs`: `0` (Shuffle/mix bulb icons from multiple enabled sets)
- `Random`: `0` (Randomize bulb properties / random sequences)
- `Reverse`: `0` (Reverse chase direction)
- `Inward`: `0` (Point side & bottom bulbs toward center of screen)
- `NoFlicker`: `0` (Double-buffered drawing)
- `UseAllMonitors`: `0` (Span/place bulbs across all active displays)
- `DrawMonitor`: `0` (Target monitor index when `UseAllMonitors == 0`)
- `BulbChanger`: `0` (Auto-rotate bulb sets on timer)
- `BulbChangeOrder`: `0` (`0` Sequential, `1` Random)
- `BulbChangeFreq`: `4` (30 minutes)

### 2.3 Screen Saver Preferences (`DIALOG/134`)
- `Module`: `"blank"` (`Blank Screen`, `Clock`, `Fireworks`, `Snowfall`)
- `Enable`: `0`
- `DelayMinutes`: `10`
- `SSLights`: `1` (Show twinkle lights around screen saver edges)
- `KeyLights`: `0` (Keyboard Caps/Num/Scroll Lock LED flashing)
- `SSMusicOnly`: `0`
- `SSLogo`: `1` (Show "Twinkle Bulbs 6.0" logo)
- `SSUsePassword`: `0`, `WinSS`: `0`, `IgnoreWinSS`: `1`
- `MouseClick`: `1`, `MouseMove`: `1`, `MouseWheel`: `1`, `Keyboard`: `1`, `UseHotCorners`: `0`
- `EnableMsg`: `1`, `SSMsg`: `"YOUR MESSAGE HERE"`, `MsgColor`: `0xFF` (Red), `MsgSize`: `14`, `MsgFont`: `"Arial"`, `MsgStyle`: `1` (Bold), `ScrollMsg`: `0`, `BottomTextAboveBulbs`: `0`, `SSClearTime`: `0`

### 2.4 Music (`DIALOG/133`), Wallpaper (`DIALOG/135`), Calendar (`DIALOG/132`)
- Music: `MusicEnabled=0`, `EnablePause=0`, `PauseMinutes=10`, `ResetMusic=1`, `SSMusic=0`, `PlayMode=0` (Sequential; `1` = Random)
- Wallpaper: `Type=0` (Tile; Center/Stretch/Fit), `ChangeFrequency=5`, `ChangeOrder=0`, `ChangeFlag=0`, `Preview=1`
- Calendar: `EventMsgs=1`, `sMM=-1`, `sDD=-1`, Holiday Countdown selector `[2600..2608]`:
  - None, Christmas (`Dec 25`), Thanksgiving (US 4th Thursday of Nov), Hanukkah, Valentine's Day (`Feb 14`), Halloween (`Oct 31`), Independence Day (`Jul 4`), St. Patrick's Day (`Mar 17`), New Year's Day (`Jan 1`)

---

## 3. Bulb Placement, Geometry & Rotation Engine

### 3.1 Placement Grid (`InitLights` @ `0x004822c4..0x004826e4`)
Let `sz = (BulbSize == 1) ? 48 : 32`, `W = targetRect.width`, `H = targetRect.height`:
- Horizontal columns: `cols = W / sz`
  - Exception: if `Location == 2` (`Around Screen`) **AND** `NoCorners == 1`: `cols = (W - 2*sz) / sz`
- Vertical rows:
  - If `Location == 3` (`Sides Only`): `rows = H / sz`
  - Else: `rows = (H - 2*sz) / sz`
- Stripped edges generated in order:
  - Edge `0` (Top): `y = 0`, `x = centerOffsetX + i * sz` (`0 <= i < cols`) when `Location in {0, 1, 2, 4}`
  - Edge `1` (Bottom): `y = H - sz`, `x = centerOffsetX + i * sz` (`0 <= i < cols`) when `Location in {1, 2, 5}`
  - Edge `2` (Left): `x = 0`, `y = topOffsetY + i * sz` (`0 <= i < rows`) when `Location in {2, 3, 4}`
  - Edge `3` (Right): `x = W - sz`, `y = topOffsetY + i * sz` (`0 <= i < rows`) when `Location in {2, 3, 4}`
- Centering (`DrawBulbs` @ `0x00483987..0x4840cb`):
  - When `NoCorners == 1`: strips are centered inside `W` (`(W - cols * sz) / 2`) and `(H - 2*sz - rows * sz) / 2 + sz` (or `(H - rows * sz)/2` for `Sides Only`).
  - Maximum logical bulbs tracked in `CTBulbsApp` fixed array = `80` (`0x50`) or dynamically extended for wide modern Retina/4K/5K macOS displays while keeping exact step/stride math (`step = NotSoMany + 1`)!
- **`NotSoMany == 1` ("Fewer bulbs"):**
  - Logical active bulb indices are `0, 2, 4, ...` (`step = 2`); odd indices `1, 3, 5, ...` hold either **Bare Wire** (`6001` if `BareWire == 1`) or empty gap.
  - Note for Side edges (`2`, `3`): odd-slot wire draws along the vertical axis rotated cleanly when `Inward == 1`.

### 3.2 Icon Rotation (`RotateIcon` @ `0x0043de50..0x0043e2cc`, `DrawSingleBulb` @ `0x00484130`)
When `Inward == 1` (`BuildRotatedIcons` @ `0x00481810`):
- **Edge `0` (Top):** `0°` (original top-down icon, hangs downward)
- **Edge `1` (Bottom):** `180°` (`(x, y) -> (W - 1 - x, H - 1 - y)` — socket at bottom, tip points UP)
- **Edge `2` (Left):** `-90°` (`(x, y) -> (y, H - 1 - x)` — socket at left, tip points RIGHT)
- **Edge `3` (Right):** `+90°` (`(x, y) -> (W - 1 - y, x)` — socket at right, tip points LEFT)
When `Inward == 0`, all edges draw at `0°`.

### 3.3 Faults & Defects (`InitLights` @ `0x00482cf0..0x00482e00`)
Applied per active bulb:
- **Burned Out (`BurnedOut == 1`):** `(rand() % 101) < 30` (~29.7%) — forced permanently OFF
- **Broken (`Broken == 1`):** `(rand() % 101) < 16` (~15.8%) — renders `7xx2` broken icon (if present in set) & forced OFF
- **Missing (`Missing == 1`):** `(rand() % 101) < 20` (~19.8%) — bulb omitted (renders bare wire if `BareWire == 1`, else blank)

---

## 4. Exact `.blb` Resource Schema & Dimming Rules

From `RTF/8009` and binary inspection of all 25 `.blb` files + `Big Bulbs.icl`:
- **Color indices (`c`):** `0` Purple, `1` Blue, `2` Red, `3` Green, `4` Yellow, `5` Light Blue, `6` White
- **Icon Resource IDs:**
  - `6000`: Sample / Preview bulb
  - `6001`: Bare Wire tile
  - `70c0`: Bulb Off (color `c`)
  - `70c1`: Bulb On (color `c`)
  - `70c2`: Bulb Broken (color `c`)
- **String Table Metadata (`5000..5014`):**
  - `5000` Author, `5001` Title, `5002` Version, `5003` Comment, `5004` Creation Date, `5005` E-mail, `5006` Web Page
  - `5010 == "1"`: Monochrome set (`aware`, `pizza`, `santa`, `tree`) — single bulb type
  - `5012 == "1"`: Bitmap set (`photoreal`) — BMP resources with `#000000` colorkey transparency
  - `5014 == "1"`: On-only set (`CoolBulb`, `bare`, `outdoor`) — no `70c0` resources; OFF state generated by `COMCTL32!ImageList_GetIcon(..., ILD_TRANSPARENT | ILD_BLEND50)` (`0x421490`), 50% blending opaque pixels toward the highlight color (`COLOR_HIGHLIGHT` classic dark navy `#000080` / custom `HighlightColor` if `SysColorHighlight == 0`).

---

## 5. Exact 21 Color Modes (`Color` `0..20` @ `0x0048289a..0x0048366c`)

For each sequential bulb slot `i = 0, 1, 2, ...`, initialized with `c2 = 0` (`1 - c2` runs first -> `c2` = `1, 0, 1, 0, ...`), `c6 = 0` (`+1 % 6` first -> `1, 2, 3, 4, 5, 0, ...`), `c7 = -1` (`+1 % 7` first -> `0, 1, 2, 3, 4, 5, 6, 0, ...`), `c3 = 0` (post-inc mod 3 -> `0, 1, 2, ...`), `c4 = 0` (post-inc mod 4 -> `0, 1, 2, 3, ...`):

| ID | Name (`STRING/8500+id`) | Color Index Rule |
|---:|---|---|
| 0 | Random | `rand() % 7`, re-rolled until `!= prevColor` |
| 1 | Purple | Solid `0` (Purple) |
| 2 | Blue | Solid `1` (Blue) |
| 3 | Red | Solid `2` (Red) |
| 4 | Green | Solid `3` (Green) |
| 5 | Yellow | Solid `4` (Yellow) |
| 6 | Light Blue | Solid `5` (Light Blue) |
| 7 | White | Solid `6` (White) |
| 8 | Red/Green | `[3, 2]` (Green, Red alternating since `c2` starts at `1`: `c2 != 0 ? 3 : 2`? Wait: `c2` flip `1 - 0 = 1` first -> `1 -> 3 (Green)` or `c2+2` -> `3, 2`) |
| 9 | Multi-Color | Cycle `1, 2, 3, 4, 5, 0` (`c6` mod 6) |
| 10 | Blues | `c2 * 4 + 1` -> `5, 1` (Light Blue, Blue) |
| 11 | All Colors (+ white) | Cycle `0, 1, 2, 3, 4, 5, 6` (`c7` mod 7) |
| 12 | Red/Blue | `c2 + 1` -> `2, 1` (Red, Blue) |
| 13 | Purple/Green | `c2 == 0 ? 3 : 0` -> `0, 3` (Purple, Green) |
| 14 | Red/Yellow/Green | `c3`: `[2, 4, 3]` (Red, Yellow, Green) |
| 15 | Red/Green/Blue | `c3`: `[2, 3, 1]` (Red, Green, Blue) |
| 16 | Cool Colors | `c3`: `[0, 1, 3]` (Purple, Blue, Green) |
| 17 | Yellow/White | `c2 == 0 ? 4 : 6` -> `6, 4` (White, Yellow) |
| 18 | Red/Yellow | `c2 == 0 ? 2 : 4` -> `4, 2` (Yellow, Red) |
| 19 | Red/Green/Yellow/Blue | `c4`: `[2, 3, 4, 1]` (Red, Green, Yellow, Blue) |
| 20 | Red/White/Blue | `c3`: `[2, 6, 1]` (Red, White, Blue) |

---

## 6. Exact 9 Flashing Modes & Timing Constants (`0x00484bd0..0x004852a0`)

**Master Animation Timer:** `50 ms` (`SetTimer(..., 5, 50, ...)`, `20 Hz` check against `GetTickCount()`).

### 6.1 Exact Millisecond Timing Tables
- **Fixed Step Interval (`Rate` `0..5` @ `0x00484fd0`):**
  - `0` Slow: `1200 ms`
  - `1` Slow/Med: `800 ms`
  - `2` Medium: `500 ms` (Default)
  - `3` Med/Fast: `350 ms`
  - `4` Fast: `200 ms`
  - `5` Very Fast: `80 ms`
- **Random Per-Bulb Hold Duration (`Rate` `0..5` @ `0x00485260`):**
  - `0` Slow: `2000 + rand() % 701` ms (`2000..2700 ms`)
  - `1` Slow/Med: `1600 + rand() % 601` ms (`1600..2200 ms`)
  - `2` Medium: `1000 + rand() % 601` ms (`1000..1600 ms`)
  - `3` Med/Fast: `600 + rand() % 401` ms (`600..1000 ms`)
  - `4` Fast: `150 + rand() % 301` ms (`150..450 ms`)
  - `5` Very Fast: `50 + rand() % 71` ms (`50..120 ms`)

### 6.2 Exact Pattern Algorithms (`UpdateLights` @ `0x00484640`)
Let `step = NotSoMany + 1` (`2` when `NotSoMany == 1`, else `1`), `N = bulbCount`.
- **`0` None (Always On):** All valid bulbs remain `ON`.
- **`1` Random:** Each bulb independently toggles `state ^= 1` when `now >= bulb.nextTick`, scheduling next toggle with random hold duration above.
- **`2` All Together:** Every `fixedInterval` ms, all bulbs toggle together (`state ^= 1`).
- **`3` Chase (Default):** Groups of stride `s`:
  - `N <= 20 -> 4`, `<= 25 -> 5`, `<= 32 -> 8`, `<= 36 -> 6`, `<= 40 -> 8`, `<= 50 -> 10`, `else -> 2` (scaled/preserved cleanly for wider multi-monitor strips so chase pattern remains legible).
  - Active bulb head advances by `+step` (or `-step` when `Reverse == 1`); every `s`-th position is lit simultaneously.
- **`4` Alternating:** Initialized as `odd = ON`, `even = OFF`; every `fixedInterval` ms, all bulbs toggle together.
- **`5` Some Bulbs Flash:** On init, `(rand() % 51) < 15` (~29.4%) are marked flashers (`flashFlag = true`); flashers toggle independently using the random hold schedule while remaining bulbs stay steadily `ON`.
- **`6` Single:** One lit bulb advances by `+step` (or `-step` if `Reverse`) every `fixedInterval` ms.
- **`7` Pairs:** Two adjacent active bulbs `(head)` and `(head + step)` lit every `stride` bulbs, advancing each `fixedInterval` ms.
- **`8` Ping-Pong:** One lit bulb bounces `0 -> N-1 -> 0` by `step`, reversing direction at either end (starting downward if `Reverse == 1`).

---

## 7. Built-in Screen Saver Modules (`scrnsave/*.tss`)

All 4 modules run on a `50 ms` frame timer (`SS_GetTimerInterval() == 0` -> host `50 ms` default, plus `50 ms` message scroll / border bulb ticker):
- Screen saver viewport insets automatically for perimeter bulbs (`0x0046de40`) based on `Location` (`0..5`) and optional bottom message strip height.
- **Blank Screen (`Blank Screen.tss`):** Pure black canvas + optional Twinkle Bulbs logo / message / lights.
- **Clock (`Clock.tss`):** Custom-font/color/size time & date readout (`GetLocalTime`) with bouncing/moving position or centered display.
- **Fireworks (`Fireworks.tss`):** Multi-color launching rockets -> bursting particle gravity trails with configurable trail length, particle count, blast rate, optional night-sky city silhouette / backdrop, and sound FX.
- **Snowfall (`Snowfall.tss`):** Multi-layer falling snowflakes (4+ snowflake sprites, wind gust / blizzard modes, snow accumulation along bottom/windows, holiday scene props: decorated tree, snowman, Santa sleigh).

---

## 8. macOS Platform Adaptation Architecture

| Windows v6.0 Mechanism | Faithful macOS Equivalent |
|---|---|
| `HWND_DESKTOP` / `WS_EX_TOPMOST` / `WS_EX_LAYERED` | Borderless transparent click-through `NSWindow` (`isOpaque = false`, `backgroundColor = .clear`, `ignoresMouseEvents = true`, `hasShadow = false`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`) at `.desktop` (`DrawMode=0`) or `.floating`/`.statusBar` (`DrawMode=1`) |
| Taskbar light strip (`SHAppBarMessage`) | `DrawMode=2`: Overlay strip aligned cleanly along the macOS Menu Bar top band and/or Dock edge (`NSStatusItem` + `.statusBar`-level click-through strip) |
| `Shell_NotifyIconA` System Tray Icon | Native `NSStatusItem` in menu bar supporting L/M/R click action config (`TrayLeftClick`, `TrayRightClick`, `TrayMiddleClick`), Flashing Tray Icon (`FlashIcon`), and full Tray Menu (`MENU/383`) |
| `TBIdle.dll` Global Idle Hook | `CGEventSource.secondsSinceLastEventType(.combinedSessionState, ...)` polling + Hot Corners (`CGEvent`/mouse location polling) |
| `PlaySoundA` WAV / MCI MIDI Sequencer | `AVAudioPlayer` for WAV SFX + `AVMIDIPlayer` / Clean-Room `AVAudioEngine` synth sequencer for holiday carols |
| `SystemParametersInfo(SPI_SETDESKWALLPAPER)` | `NSWorkspace.shared.setDesktopImageURL(_:for:options:)` supporting Tile/Center/Fill/Fit per display |
| `.blb` / `.icl` / `.ico` PE DLL loader | Pure-Swift clean-room PE/NE `.blb`, `.ico`, `.icl` resource reader (`BLBResourceLoader.swift`) for user-imported Windows files + clean-room built-in sprite sets matching exact dimensions/palettes |
