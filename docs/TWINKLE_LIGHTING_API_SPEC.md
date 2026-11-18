# Re: Twinkle Bulbs — Developer Lighting API & External Adapter Specification (v1.0)

## 1. Security Model & Defaults

Re: Twinkle Bulbs exposes an optional HTTP REST + RFC 6455 WebSocket API (`TwinkleLightingAPIService`) designed for safe local experimentation, smart-home bridges, and hobby LED hardware integration.

- **Disabled by default** (`TwinkleAPIConfig.enabled == false`).
- **Localhost-only by default** (`127.0.0.1:49152` when `bindLocalhostOnly == true` and `allowLANAccess == false`).
- **Dual-token bearer authorization**:
  - `readOnlyToken` (`tk_ro_...`): permits read-only `GET /v1/*` and WebSocket `/v1/stream` subscriptions.
  - `controlToken` (`tk_ctrl_...`): required for `POST /v1/control` **and** rejected unless `allowControlCommands == true`.
  - Pass via header `Authorization: Bearer <token>` or query parameter `?token=<token>`.
- **Rate Limiting & Payload Caps**:
  - HTTP bodies larger than `65,536` bytes return `413 Payload Too Large`.
  - Control commands are rate-limited to `300` requests per minute (`429 Too Many Requests`).
  - No wildcard CORS headers are emitted.
  - WebSocket streaming uses a per-subscriber in-flight guard so slow consumers drop intermediate frames rather than stalling the macOS renderer.

## 2. HTTP REST Endpoints

| Method | Path | Auth Required | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/v1/status` | Read or Control | Full live telemetry snapshot (lights, classic & modern engines, bulb set, size, placement, music track/volume, MIDI reactive mode, screensaver, wallpaper, automation, interactive, weather, FPS telemetry). |
| `GET` | `/v1/scenes` | Read or Control | Lists built-in (16) and custom scenes (`id`, `name`, `season`, `favorite`, `builtIn`). |
| `GET` | `/v1/effects` | Read or Control | Lists Classic (9), Modern (15), Flash Rates (6), and MIDI Modes (7). |
| `GET` | `/v1/palettes` | Read or Control | Lists Classic (21) and Modern (9) color modes and palettes. |
| `GET` | `/v1/bulbs` | Read or Control | Lists all 265+ built-in & imported bulb sets grouped by collection. |
| `GET` | `/v1/music` | Read or Control | Lists all 105+ built-in & imported music tracks plus active playback state. |
| `GET` | `/v1/screensavers` | Read or Control | Lists all 25 classic & seasonal screensaver modules. |
| `GET` | `/v1/wallpapers` | Read or Control | Lists all 130+ seasonal & imported wallpapers. |
| `GET` | `/v1/timelines` | Read or Control | Lists built-in & custom `.twinklefx` Effect Studio timelines. |
| `GET` | `/v1/layouts` | Read or Control | Lists saved Virtual Lighting Layouts and strand counts. |
| `GET` | `/v1/capabilities` | Read or Control | Reports API version (`2.0`), localhost/LAN bind state, bidirectional WS support, max bulbs (`512`), FPS cap, and wire formats. |
| `POST` | `/v1/control` | Control + `allowControlCommands` | Full JSON command router: `setLights`, `blackout`, `setLightingCategory`, `setBulbSet`, `setBulbSize`, `setFlashMode`, `setRate`, `setColorMode`, `setModernEffect`, `setModernPalette`, `setBrightness`, `setSpeed`, `setSmoothness`, `setReverse`, `setStaggered`, `setPlacement`, `activateScene`, `restorePreviousScene`, `returnToClassic`, `toggleFavoriteScene`, `saveCurrentAsScene`, `setActiveTimeline`, `musicPlay`, `musicStop`, `musicPause`, `musicResume`, `musicToggle`, `musicNext`, `musicPrev`, `setMusicVolume`, `setMusicPlayMode`, `setMusicRepeatMode`, `setMIDIReactive`, `startScreenSaver`, `stopScreenSaver`, `setScreenSaverConfig`, `setWallpaper`, `setAutomation`, `setWeatherAtmosphere`, `setInteractive`, `triggerCelebration`, `stopScreenColorSync`. |
| `GET` | `/` or `/remote` | Opt-in `webRemoteEnabled` | Serves the full-control tabbed HTML5 + Canvas + WebSocket dashboard (`RemoteControlService`). |
| `POST` | `/v1/remote/auth` | PIN or Control Token | Exchanges 6-digit Pairing PIN or valid `controlToken` for an authenticated remote session (`tk_rem_...`). |
| `POST` | `/v1/remote/action` | Remote Session or Control | Executes all full-control commands over HTTP from the web remote UI. |

### Example `POST /v1/control` Request

```json
{
  "action": "activateScene",
  "sceneID": "scene:classic_christmas"
}
```

## 3. WebSocket Frame Streaming (`GET /v1/stream`)

- Upgrade via standard RFC 6455 WebSocket handshake (`Sec-WebSocket-Key` / `Sec-WebSocket-Accept`).
- Rate-capped at `maxFrameRateHz` (default `30` Hz, max `60` Hz).
- **Bidirectional Control (Authorized WebSockets):** Connections upgraded with `controlToken` (when `allowControlCommands == true`) or a PIN-paired remote session may also send masked RFC 6455 JSON text frames matching `/v1/control` schemas over the same WebSocket and receive `{"ok":true,"wsAck":"<action>"}`. Read-only WebSocket clients receive an authorization error.
- **Safe Blackout on Shutdown**: when playback stops, lights turn off, or the server exits, a blackout packet (all RGB channels `0`) is broadcast to subscribers and connected adapters.

### Binary Frame Format (`twkl-binary-v1`, Default WebSocket Opcode `0x02`)

Little-endian 16-byte header followed by `bulbCount * 3` RGB8 bytes:

| Offset | Type | Description |
| :--- | :--- | :--- |
| `0..3` | `char[4]` | Magic signature `"TWKL"` (`0x54 0x57 0x4B 0x4C`) |
| `4..5` | `uint16` | Packet version = `1` |
| `6..7` | `uint16` | `bulbCount` |
| `8..11` | `uint32` | Monotonic `sequence` number |
| `12..15` | `uint32` | Timestamp milliseconds (`uint32`) |
| `16...` | `uint8[]` | Tightly packed `R, G, B` triplets per bulb (`intensity`-scaled) |

### JSON Frame Format (`?format=json`, WebSocket Opcode `0x01`)

```json
{
  "v": 1,
  "seq": 42,
  "tsMs": 1734567890,
  "count": 40,
  "rgb": [[255, 20, 20], [20, 220, 30]]
}
```

## 4. Extensible Hardware & Bridge Adapters (`LightingAdapterProtocol`)

Implemented in `TwinkleBulbs/Services/LightingAdapterProtocol.swift`:

- `ReferenceVirtualAdapter`: local loopback adapter powering the in-app **Virtual Controller Simulator**, validating sequence numbers and verifying blackout on disconnect.
- `ExternalProtocolPacketEncoder`: clean wire encoders for:
  - **WLED DRGB Realtime** (`encodeWLEDDRGB`, UDP `21324`)
  - **Art-Net OpDmx** (`encodeArtNetDMX`, UDP `6454`, Universe LE + ProtVer 14 + DMX512 payload)
  - **DDP v1 RGB** (`encodeDDPPacket`, UDP `4048`)
- Home Assistant / WLED / MQTT / sACN bridges can subscribe directly to `/v1/stream` and map scenes or blackout commands via `/v1/control`.

## 5. Electrical Safety Warning

Never power addressable LED strips (`WS2812B`, `SK6812`, `WS2811`) directly through low-current USB-A/USB-C host ports for large strands. Always use properly rated external UL-listed power supplies, inline fuses matching wire gauge, common ground reference between data controller and LED power supply, and current limiting (`electricalSafetyAcknowledged` opt-in required before enabling external adapter output).
