import Foundation
import Network
import CryptoKit

// MARK: - Part VII & VIII: Localhost-First Developer & Full Remote Control API (HTTP REST + Bidirectional RFC 6455 WebSocket)

public struct TwinkleAPIControlRequest: Codable {
    public var action: String

    // Scene & Timeline fields
    public var sceneID: String?
    public var timelineID: String?
    public var name: String?
    public var applyWallpaper: Bool?

    // Generic boolean / scalar values
    public var enabled: Bool?
    public var value: Double?
    public var intValue: Int?
    public var text: String?

    // Lighting engine & classic/modern fields
    public var lightingCategory: String? // "classic" | "modern"
    public var bulbSetID: String?
    public var bulbSize: Int?            // 0 = Normal (32px), 1 = Large (48px)
    public var flashMode: Int?
    public var rate: Int?
    public var colorMode: Int?
    public var effectID: Int?
    public var paletteID: Int?
    public var location: Int?
    public var drawMode: Int?
    public var bareWire: Bool?
    public var noCorners: Bool?
    public var notSoMany: Bool?
    public var reverse: Bool?
    public var inward: Bool?
    public var useAllMonitors: Bool?
    public var broken: Bool?
    public var burnedOut: Bool?
    public var missing: Bool?

    // Music & MIDI show fields
    public var trackID: String?
    public var trackIndex: Int?
    public var midiMode: Int?
    public var sensitivity: Double?

    // Screensaver / Wallpaper / Automation / Atmosphere / Interactive fields
    public var moduleID: String?
    public var scrollMessage: Bool?
    public var ssLights: Bool?
    public var wallpaperID: String?
    public var wallpaperStyle: Int?
    public var celebration: String?
    public var condition: String?
    public var vacationMode: Bool?
    public var quietHoursEnabled: Bool?
    public var autoShutdownEnabled: Bool?
    public var mouseProximityGlow: Bool?
    public var mouseRipple: Bool?
    public var sparkleTrail: Bool?
    public var particlePointerInteraction: Bool?
    public var timeOfDayEnabled: Bool?

    public init(action: String) {
        self.action = action
    }
}

public final class TwinkleLightingAPIService {
    public static let shared = TwinkleLightingAPIService()

    public private(set) var isRunning: Bool = false
    public private(set) var boundPort: UInt16 = 0
    public private(set) var connectedWebSocketCount: Int = 0
    public private(set) var activeAddressDescription: String = "Stopped"

    public var onApplyAppSettings: ((AppSettings) -> Void)?
    public var onTriggerCelebration: ((String) -> Void)?
    public var onStartScreenSaver: (() -> Void)?
    public var onStopScreenSaver: (() -> Void)?
    public var onSetTimelineID: ((String?) -> Void)?
    public var isScreenSaverActiveProvider: (() -> Bool)?
    public var onLogEvent: ((String) -> Void)?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.twinklebulbs.api.listener")
    private let stateLock = NSLock()

    private final class WSClient {
        let id = UUID()
        let connection: NWConnection
        let useJSON: Bool
        let canControl: Bool
        var sendInFlight: Bool = false
        var wsRxBuffer = Data()

        init(connection: NWConnection, useJSON: Bool, canControl: Bool) {
            self.connection = connection
            self.useJSON = useJSON
            self.canControl = canControl
        }
    }

    private var wsClients: [UUID: WSClient] = [:]
    private var receiveBuffers: [ObjectIdentifier: Data] = [:]
    private var upgradedConnections: Set<ObjectIdentifier> = []
    private var frameSequence: UInt32 = 0
    private var lastFramePushTime: CFAbsoluteTime = 0
    private var lastBulbCount: Int = 40

    private var controlTimestamps: [CFAbsoluteTime] = []
    private let maxControlReqPerMin = 300
    private let maxRequestBodyBytes = 65_536

    private let stateStore: NextGenStateStore
    private let settingsStore: SettingsStore
    private let sceneManager: HolidaySceneManager
    private let remoteService: RemoteControlService

    public init(
        stateStore: NextGenStateStore = .shared,
        settingsStore: SettingsStore = .shared,
        sceneManager: HolidaySceneManager = .shared,
        remoteService: RemoteControlService = .shared
    ) {
        self.stateStore = stateStore
        self.settingsStore = settingsStore
        self.sceneManager = sceneManager
        self.remoteService = remoteService
    }

    deinit {
        stop()
    }

    public func startIfConfigured() {
        let cfg = stateStore.state.apiConfig
        if cfg.enabled || cfg.webRemoteEnabled {
            try? start(config: cfg)
        } else {
            stop()
        }
    }

    public func start(config: TwinkleAPIConfig, overridePort: UInt16? = nil) throws {
        stop()

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let useLAN = config.allowLANAccess && !config.bindLocalhostOnly && config.webRemoteEnabled
        let chosenPort = overridePort ?? config.port
        if !useLAN {
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: .ipv4(.loopback),
                port: NWEndpoint.Port(rawValue: chosenPort) ?? .any
            )
        }

        let newListener: NWListener
        if !useLAN {
            newListener = try NWListener(using: params)
        } else {
            newListener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: chosenPort) ?? .any)
        }

        newListener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                let p = newListener.port?.rawValue ?? chosenPort
                self.stateLock.lock()
                self.boundPort = p
                self.isRunning = true
                let hostStr = useLAN ? "0.0.0.0 (LAN)" : "127.0.0.1 (Localhost)"
                self.activeAddressDescription = "Listening on \(hostStr):\(p)"
                self.stateLock.unlock()
                self.log("API/Remote Server started at \(hostStr):\(p)")
            case .failed(let err):
                self.stateLock.lock()
                self.isRunning = false
                self.activeAddressDescription = "Failed: \(err.localizedDescription)"
                self.stateLock.unlock()
                self.log("API Listener error: \(err.localizedDescription)")
            case .cancelled:
                self.stateLock.lock()
                self.isRunning = false
                self.boundPort = 0
                self.activeAddressDescription = "Stopped"
                self.stateLock.unlock()
            default:
                break
            }
        }

        newListener.newConnectionHandler = { [weak self] conn in
            self?.handleNewConnection(conn)
        }
        self.listener = newListener
        newListener.start(queue: queue)

        if config.externalHardwareEnabled && config.electricalSafetyAcknowledged {
            try? ReferenceVirtualAdapter.shared.connect()
        }
    }

    public func stop() {
        broadcastBlackoutFrame()
        if ReferenceVirtualAdapter.shared.isConnected {
            ReferenceVirtualAdapter.shared.disconnect()
        }

        stateLock.lock()
        let clients = Array(wsClients.values)
        wsClients.removeAll()
        connectedWebSocketCount = 0
        receiveBuffers.removeAll()
        upgradedConnections.removeAll()
        isRunning = false
        boundPort = 0
        activeAddressDescription = "Stopped"
        stateLock.unlock()

        for c in clients {
            c.connection.cancel()
        }
        listener?.cancel()
        listener = nil
    }

    public func publishLightingFrame(states: [ModernBulbState], maxFPSOverride: Int? = nil) {
        guard !states.isEmpty else { return }
        let cfg = stateStore.state.apiConfig
        let shouldStream = cfg.enabled || cfg.webRemoteEnabled || (cfg.externalHardwareEnabled && cfg.electricalSafetyAcknowledged)
        guard shouldStream else { return }

        let maxHz = max(1, min(60, maxFPSOverride ?? cfg.maxFrameRateHz))
        let now = CFAbsoluteTimeGetCurrent()
        let minInterval = 1.0 / Double(maxHz)

        stateLock.lock()
        if (now - lastFramePushTime) < minInterval {
            stateLock.unlock()
            return
        }
        lastFramePushTime = now
        frameSequence &+= 1
        let seq = frameSequence
        lastBulbCount = states.count
        let clients = Array(wsClients.values)
        stateLock.unlock()

        let tsMs = UInt32(truncatingIfNeeded: UInt64(max(0, Date().timeIntervalSince1970 * 1000.0)))
        let packet = TwinkleBulbFramePacket(sequence: seq, timestampMs: tsMs, states: states)

        if cfg.externalHardwareEnabled && cfg.electricalSafetyAcknowledged && ReferenceVirtualAdapter.shared.isConnected {
            try? ReferenceVirtualAdapter.shared.sendFrame(packet)
        }

        guard !clients.isEmpty else { return }
        let binPayload = wrapWebSocketFrame(opcode: 0x02, payload: packet.encodeBinaryFrame())
        let jsonPayload = wrapWebSocketFrame(opcode: 0x01, payload: packet.encodeJSON())

        for client in clients {
            stateLock.lock()
            if client.sendInFlight {
                stateLock.unlock()
                continue
            }
            client.sendInFlight = true
            stateLock.unlock()

            let wireData = client.useJSON ? jsonPayload : binPayload
            client.connection.send(content: wireData, completion: .contentProcessed { [weak self, weak client] err in
                guard let self, let client else { return }
                self.stateLock.lock()
                client.sendInFlight = false
                if err != nil {
                    self.wsClients.removeValue(forKey: client.id)
                    self.connectedWebSocketCount = self.wsClients.count
                }
                self.stateLock.unlock()
            })
        }
    }

    public func broadcastBlackoutFrame() {
        stateLock.lock()
        frameSequence &+= 1
        let seq = frameSequence
        let count = lastBulbCount
        let clients = Array(wsClients.values)
        stateLock.unlock()

        let packet = TwinkleBulbFramePacket.blackout(
            sequence: seq,
            timestampMs: UInt32(truncatingIfNeeded: UInt64(max(0, Date().timeIntervalSince1970 * 1000.0))),
            bulbCount: count
        )
        if ReferenceVirtualAdapter.shared.isConnected {
            try? ReferenceVirtualAdapter.shared.blackoutAll()
        }
        let binWire = wrapWebSocketFrame(opcode: 0x02, payload: packet.encodeBinaryFrame())
        let jsonWire = wrapWebSocketFrame(opcode: 0x01, payload: packet.encodeJSON())
        for c in clients {
            c.connection.send(content: c.useJSON ? jsonWire : binWire, completion: .idempotent)
        }
    }

    // MARK: - HTTP + WebSocket Request Handling

    private func handleNewConnection(_ conn: NWConnection) {
        conn.stateUpdateHandler = { [weak self] st in
            if case .cancelled = st {
                self?.cleanupConnection(conn)
            } else if case .failed = st {
                self?.cleanupConnection(conn)
            }
        }
        conn.start(queue: queue)
        receiveLoop(conn)
    }

    private func cleanupConnection(_ conn: NWConnection) {
        stateLock.lock()
        let key = ObjectIdentifier(conn)
        receiveBuffers.removeValue(forKey: key)
        upgradedConnections.remove(key)
        wsClients = wsClients.filter { $0.value.connection !== conn }
        connectedWebSocketCount = wsClients.count
        stateLock.unlock()
    }

    private func receiveLoop(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                let key = ObjectIdentifier(conn)
                self.stateLock.lock()
                var buf = self.receiveBuffers[key] ?? Data()
                buf.append(data)
                if buf.count > self.maxRequestBodyBytes + 8192 {
                    self.receiveBuffers.removeValue(forKey: key)
                    self.stateLock.unlock()
                    self.sendHTTPResponse(conn, status: 413, statusText: "Payload Too Large", contentType: "application/json", body: Data("{\"error\":\"Payload too large\"}".utf8))
                    return
                }
                self.receiveBuffers[key] = buf
                self.stateLock.unlock()

                self.tryProcessHTTPBuffer(for: conn)
            }
            if isComplete || error != nil {
                self.cleanupConnection(conn)
            } else {
                let isWS: Bool = {
                    self.stateLock.lock()
                    defer { self.stateLock.unlock() }
                    let key = ObjectIdentifier(conn)
                    return self.upgradedConnections.contains(key) || self.wsClients.values.contains { $0.connection === conn }
                }()
                if !isWS {
                    self.receiveLoop(conn)
                }
            }
        }
    }

    private func tryProcessHTTPBuffer(for conn: NWConnection) {
        let key = ObjectIdentifier(conn)
        stateLock.lock()
        guard let buf = receiveBuffers[key] else { stateLock.unlock(); return }
        guard let headerEndRange = buf.range(of: Data("\r\n\r\n".utf8)) else {
            stateLock.unlock()
            return
        }
        let headerData = buf.subdata(in: 0..<headerEndRange.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            receiveBuffers.removeValue(forKey: key)
            stateLock.unlock()
            sendHTTPResponse(conn, status: 400, statusText: "Bad Request", contentType: "application/json", body: Data("{\"error\":\"Bad header\"}".utf8))
            return
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            stateLock.unlock(); return
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colon = line.firstIndex(of: ":") {
                let k = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let v = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                headers[k] = v
            }
        }
        let contentLen = Int(headers["content-length"] ?? "0") ?? 0
        if contentLen > maxRequestBodyBytes {
            receiveBuffers.removeValue(forKey: key)
            stateLock.unlock()
            sendHTTPResponse(conn, status: 413, statusText: "Payload Too Large", contentType: "application/json", body: Data("{\"error\":\"Payload Too Large\"}".utf8))
            return
        }
        let bodyStart = headerEndRange.upperBound
        guard buf.count >= bodyStart + contentLen else {
            stateLock.unlock()
            return
        }
        let bodyData = buf.subdata(in: bodyStart..<(bodyStart + contentLen))
        receiveBuffers.removeValue(forKey: key)
        stateLock.unlock()

        routeHTTPRequest(conn: conn, requestLine: requestLine, headers: headers, body: bodyData)
    }

    private func routeHTTPRequest(conn: NWConnection, requestLine: String, headers: [String: String], body: Data) {
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendHTTPResponse(conn, status: 400, statusText: "Bad Request", contentType: "application/json", body: Data("{\"error\":\"Malformed request\"}".utf8))
            return
        }
        let method = String(parts[0]).uppercased()
        let rawTarget = String(parts[1])
        let comps = URLComponents(string: "http://localhost" + rawTarget)
        let path = comps?.path ?? rawTarget
        let queryItems = comps?.queryItems ?? []
        let queryToken = queryItems.first(where: { $0.name == "token" })?.value
        let bearerToken: String? = {
            if let auth = headers["authorization"], auth.lowercased().hasPrefix("bearer ") {
                return String(auth.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            }
            return queryToken
        }()

        let cfg = stateStore.state.apiConfig

        // Web Remote HTML entry point
        if method == "GET" && (path == "/" || path == "/remote" || path == "/remote/") {
            guard cfg.webRemoteEnabled else {
                sendHTTPResponse(conn, status: 403, statusText: "Forbidden", contentType: "text/plain", body: Data("Web Remote Control is disabled in Settings.".utf8))
                return
            }
            sendHTTPResponse(conn, status: 200, statusText: "OK", contentType: "text/html; charset=utf-8", body: Data(RemoteControlService.renderMobileWebAppHTML().utf8))
            return
        }

        // PIN or Control-Token pairing exchange
        if method == "POST" && path == "/v1/remote/auth" {
            guard cfg.webRemoteEnabled else {
                sendJSON(conn, status: 403, obj: ["ok": false, "error": "Web remote disabled"])
                return
            }
            if !consumeRateLimitSlot() {
                sendJSON(conn, status: 429, obj: ["ok": false, "error": "Rate limit exceeded"])
                return
            }
            if let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] {
                if let pin = json["pin"] as? String, !pin.isEmpty,
                   let sessionTok = remoteService.issueSessionIfPINMatches(pin) {
                    log("Web Remote session paired via 6-digit PIN.")
                    sendJSON(conn, status: 200, obj: ["ok": true, "sessionToken": sessionTok])
                    return
                }
                if let tok = json["controlToken"] as? String, !tok.isEmpty,
                   cfg.allowControlCommands && isControlAuthorized(token: tok, cfg: cfg) {
                    log("Web Remote unlocked via Control Token.")
                    sendJSON(conn, status: 200, obj: ["ok": true, "sessionToken": tok])
                    return
                }
            }
            sendJSON(conn, status: 401, obj: ["ok": false, "error": "Invalid pairing PIN or token"])
            return
        }

        // WebSocket Upgrade (/v1/stream)
        if method == "GET" && path == "/v1/stream",
           let upgrade = headers["upgrade"], upgrade.lowercased() == "websocket",
           let wsKey = headers["sec-websocket-key"] {
            let canReadWS = (cfg.enabled && isReadAuthorized(token: bearerToken, cfg: cfg)) ||
                            (cfg.webRemoteEnabled && (remoteService.isSessionValid(bearerToken) || isReadAuthorized(token: bearerToken, cfg: cfg)))
            guard canReadWS else {
                sendHTTPResponse(conn, status: 401, statusText: "Unauthorized", contentType: "application/json", body: Data("{\"error\":\"Unauthorized\"}".utf8))
                return
            }
            let canCtrlWS = (cfg.enabled && cfg.allowControlCommands && isControlAuthorized(token: bearerToken, cfg: cfg)) ||
                            (cfg.webRemoteEnabled && (remoteService.isSessionValid(bearerToken) || (cfg.allowControlCommands && isControlAuthorized(token: bearerToken, cfg: cfg))))
            let useJSON = (queryItems.first(where: { $0.name == "format" })?.value?.lowercased() == "json")
            performWebSocketUpgrade(conn: conn, key: wsKey, useJSON: useJSON, canControl: canCtrlWS)
            return
        }

        // Control Endpoints (POST /v1/control or POST /v1/remote/action)
        if method == "POST" && (path == "/v1/control" || path == "/v1/remote/action") {
            let authorizedControl: Bool
            if path == "/v1/remote/action" {
                authorizedControl = cfg.webRemoteEnabled && (remoteService.isSessionValid(bearerToken) || isControlAuthorized(token: bearerToken, cfg: cfg))
            } else {
                authorizedControl = cfg.enabled && cfg.allowControlCommands && isControlAuthorized(token: bearerToken, cfg: cfg)
            }
            guard authorizedControl else {
                sendJSON(conn, status: 401, obj: ["ok": false, "error": "Unauthorized or control commands disabled"])
                return
            }
            guard consumeRateLimitSlot() else {
                sendJSON(conn, status: 429, obj: ["ok": false, "error": "Rate limit exceeded"])
                return
            }
            guard let req = try? JSONDecoder().decode(TwinkleAPIControlRequest.self, from: body) else {
                sendJSON(conn, status: 400, obj: ["ok": false, "error": "Invalid JSON command body"])
                return
            }
            let summary = executeControlAction(req)
            sendJSON(conn, status: 200, obj: ["ok": true, "action": req.action, "detail": summary])
            return
        }

        // Read-Only REST Endpoints (GET /v1/*)
        guard method == "GET" && (cfg.enabled || cfg.webRemoteEnabled) else {
            sendJSON(conn, status: 404, obj: ["error": "Endpoint not found or API disabled"])
            return
        }
        guard isReadAuthorized(token: bearerToken, cfg: cfg) || (cfg.webRemoteEnabled && remoteService.isSessionValid(bearerToken)) else {
            sendJSON(conn, status: 401, obj: ["error": "Unauthorized: missing or invalid bearer token"])
            return
        }

        switch path {
        case "/v1/status":
            sendJSON(conn, status: 200, obj: buildFullStatusSnapshot(cfg: cfg))
        case "/v1/scenes":
            let list = sceneManager.allScenes.map { sc -> [String: Any] in
                ["id": sc.id, "name": sc.name, "subtitle": sc.subtitle, "season": sc.season.rawValue, "favorite": sc.isFavorite, "builtIn": sc.isBuiltIn]
            }
            sendJSON(conn, status: 200, obj: ["scenes": list, "activeSceneID": stateStore.state.activeSceneID ?? ""])
        case "/v1/effects":
            let classic = FlashMode.allCases.map { ["id": $0.rawValue, "name": $0.displayName, "engine": "classic"] }
            let modern = ModernEffectID.allCases.map { ["id": $0.rawValue, "name": $0.displayName, "engine": "modern"] }
            let rates = FlashRate.allCases.map { ["id": $0.rawValue, "name": $0.displayName] }
            let midiModes = MIDIReactiveMode.allCases.map { ["id": $0.rawValue, "name": $0.displayName] }
            sendJSON(conn, status: 200, obj: ["classic": classic, "modern": modern, "rates": rates, "midiModes": midiModes])
        case "/v1/palettes":
            let classic = ColorMode.allCases.map { ["id": $0.rawValue, "name": $0.displayName] }
            let modern = ModernColorPalette.allCases.map { ["id": $0.rawValue, "name": $0.displayName] }
            sendJSON(conn, status: 200, obj: ["classic": classic, "modern": modern])
        case "/v1/bulbs":
            let sets = BulbArtworkRegistry.shared.availableSets.map { b -> [String: Any] in
                ["id": b.id, "title": b.title, "collection": b.collection.displayName, "tintable": b.supportsColorModes, "holiday250": b.isHoliday250]
            }
            sendJSON(conn, status: 200, obj: ["bulbs": sets, "count": sets.count])
        case "/v1/music":
            let aud = AudioEngineService.shared
            let tracks = aud.tracks.enumerated().map { idx, t -> [String: Any] in
                ["index": idx, "id": t.id, "title": t.title, "bpm": t.tempoBPM, "isBuiltIn": t.url == nil]
            }
            let clock = aud.currentPlaybackClockAndEnergy()
            sendJSON(conn, status: 200, obj: [
                "tracks": tracks,
                "currentTrackIndex": aud.currentTrackIndex,
                "currentTrackTitle": aud.currentTrackTitle,
                "isPlaying": aud.isPlaying,
                "isPaused": aud.isPaused,
                "positionSeconds": clock.positionSeconds,
                "durationSeconds": clock.durationSeconds
            ])
        case "/v1/screensavers":
            let savers = ScreenSaverModuleID.allCases.map { m -> [String: Any] in
                ["id": m.rawValue, "name": m.displayName, "isClassic": m.isClassicModule]
            }
            sendJSON(conn, status: 200, obj: ["screensavers": savers])
        case "/v1/wallpapers":
            let wps = WallpaperService.shared.items.map { w -> [String: Any] in
                ["id": w.id, "title": w.title, "category": w.category.rawValue]
            }
            sendJSON(conn, status: 200, obj: ["wallpapers": wps])
        case "/v1/timelines":
            var docs = EffectTimelineEngine.builtInSampleTimelines()
            for t in stateStore.state.timelines where !docs.contains(where: { $0.id == t.id }) { docs.append(t) }
            let list = docs.map { ["id": $0.id, "name": $0.name, "durationSeconds": $0.durationSeconds] }
            sendJSON(conn, status: 200, obj: ["timelines": list, "activeTimelineID": stateStore.state.activeTimelineID ?? ""])
        case "/v1/layouts":
            let layouts = (VirtualLightingLayoutEngine.builtInSampleLayouts() + stateStore.state.layouts).map { lay -> [String: Any] in
                ["id": lay.id, "name": lay.name, "strandCount": lay.strands.count]
            }
            sendJSON(conn, status: 200, obj: ["layouts": layouts])
        case "/v1/capabilities":
            sendJSON(conn, status: 200, obj: [
                "apiVersion": "2.0",
                "app": "Re: Twinkle Bulbs Next Generation",
                "localhostOnly": !useLANMode(cfg),
                "controlEnabled": cfg.allowControlCommands,
                "webRemoteEnabled": cfg.webRemoteEnabled,
                "bidirectionalWebSocket": true,
                "maxBulbs": 512,
                "maxFrameRateHz": cfg.maxFrameRateHz,
                "streamFormats": ["twkl-binary-v1", "json"],
                "adapters": ["virtual_simulator", "wled_drgb", "artnet_dmx", "ddp_rgb"]
            ])
        default:
            sendJSON(conn, status: 404, obj: ["error": "Unknown API endpoint \(path)"])
        }
    }

    private func buildFullStatusSnapshot(cfg: TwinkleAPIConfig) -> [String: Any] {
        let s = settingsStore.settings
        let ng = stateStore.state
        let aud = AudioEngineService.shared
        let tel = PerformanceCoordinator.shared.currentTelemetry(settings: s, policy: ng.performance)
        return [
            "lightsEnabled": s.lightsEnabled,
            "activeSceneID": ng.activeSceneID ?? "",
            "activeTimelineID": ng.activeTimelineID ?? "",
            "hasPreviousScene": ng.previousSnapshot != nil,
            "lightingCategory": s.lightingCategory.rawValue,
            "lightingCategoryName": s.lightingCategory.displayName,
            "bulbSet": s.bulbSetName,
            "bulbSize": s.bulbSize.rawValue,
            "flashMode": s.flashMode.rawValue,
            "rate": s.rate.rawValue,
            "colorMode": s.colorMode.rawValue,
            "effectID": s.modernEffects.effect.rawValue,
            "effectName": s.modernEffects.effect.displayName,
            "paletteID": s.modernEffects.palette.rawValue,
            "brightness": s.modernEffects.brightness,
            "speed": s.modernEffects.speed,
            "smoothness": s.modernEffects.smoothness,
            "location": s.location.rawValue,
            "drawMode": s.drawMode.rawValue,
            "bareWire": s.bareWire,
            "noCorners": s.noCorners,
            "notSoMany": s.notSoMany,
            "reverse": s.reverse,
            "inward": s.inward,
            "useAllMonitors": s.useAllMonitors,
            "broken": s.broken,
            "burnedOut": s.burnedOut,
            "missing": s.missing,
            "musicPlaying": aud.isPlaying,
            "musicPaused": aud.isPaused,
            "currentTrack": aud.currentTrackTitle,
            "currentTrackIndex": aud.currentTrackIndex,
            "musicVolume": s.musicVolume,
            "musicPlayMode": s.musicPlayMode,
            "musicRepeatMode": s.musicRepeatMode.rawValue,
            "midiReactiveEnabled": s.modernEffects.midiReactiveEnabled,
            "midiReactiveMode": s.modernEffects.midiReactiveMode.rawValue,
            "midiSensitivity": s.modernEffects.midiSensitivity,
            "ssModule": s.ssModule.rawValue,
            "ssMsg": s.ssMsg,
            "ssScrollMsg": s.ssScrollMsg,
            "ssLights": s.ssLights,
            "screenSaverActive": isScreenSaverActiveProvider?() ?? false,
            "activeWallpaperID": s.activeWallpaperID,
            "wallpaperStyle": s.wallpaperType.rawValue,
            "automationEnabled": ng.automation.automationEnabled,
            "vacationMode": ng.automation.vacationMode,
            "quietHoursEnabled": ng.automation.quietHours.enabled,
            "autoShutdownEnabled": ng.automation.autoShutdownEnabled,
            "interactiveEnabled": ng.interactive.enabled,
            "mouseProximityGlow": ng.interactive.mouseProximityGlow,
            "mouseRipple": ng.interactive.mouseRipple,
            "sparkleTrail": ng.interactive.sparkleTrail,
            "particlePointerInteraction": ng.interactive.particlePointerInteraction,
            "weatherEnabled": ng.weatherConfig.enabled,
            "weatherCondition": ng.weatherConfig.simulatedOverride.rawValue,
            "timeOfDayEnabled": ng.timeOfDay.enabled,
            "screenSyncActive": ScreenColorSyncService.shared.isSyncActive,
            "recommendedFPS": tel.recommendedModernFPS,
            "performanceSummary": tel.summaryText,
            "bulbCount": lastBulbCount,
            "apiRateCapHz": cfg.maxFrameRateHz
        ]
    }

    private func useLANMode(_ cfg: TwinkleAPIConfig) -> Bool {
        cfg.allowLANAccess && !cfg.bindLocalhostOnly && cfg.webRemoteEnabled
    }

    /// Executes any API / Web Remote / WebSocket control action cleanly on the main thread.
    @discardableResult
    public func executeControlAction(_ req: TwinkleAPIControlRequest) -> String {
        log("Remote Control executed action=\(req.action)")
        let performBlock = { [weak self] in
            guard let self else { return }
            var s = self.settingsStore.settings
            var ng = self.stateStore.state

            switch req.action {
            // 1. Lights / Engine / Patterns / Palettes / Bulbs / Placement
            case "setLights":
                s.lightsEnabled = req.enabled ?? !s.lightsEnabled
                self.settingsStore.settings = s
                self.onApplyAppSettings?(s)
                if !s.lightsEnabled { self.broadcastBlackoutFrame() }
            case "blackout":
                s.lightsEnabled = false
                self.settingsStore.settings = s
                self.onApplyAppSettings?(s)
                self.broadcastBlackoutFrame()
            case "setLightingCategory":
                if let cat = req.lightingCategory?.lowercased() {
                    s.lightingCategory = (cat == "classic") ? .classic : .modern
                } else if let iv = req.intValue, let c = LightingEngineCategory(rawValue: iv) {
                    s.lightingCategory = c
                }
                s.lightsEnabled = true
                self.settingsStore.settings = s
                self.onApplyAppSettings?(s)
            case "setBulbSet":
                if let bid = req.bulbSetID, !bid.isEmpty {
                    s.bulbSetName = bid
                    self.settingsStore.settings = s
                    self.onApplyAppSettings?(s)
                }
            case "setBulbSize":
                if let sz = req.bulbSize, let opt = BulbSizeOption(rawValue: sz) {
                    s.bulbSize = opt
                    self.settingsStore.settings = s
                    self.onApplyAppSettings?(s)
                }
            case "setFlashMode":
                if let fm = req.flashMode, let mode = FlashMode(rawValue: fm) {
                    s.flashMode = mode
                    self.settingsStore.settings = s
                    self.onApplyAppSettings?(s)
                }
            case "setRate":
                if let r = req.rate, let rate = FlashRate(rawValue: r) {
                    s.rate = rate
                    self.settingsStore.settings = s
                    self.onApplyAppSettings?(s)
                }
            case "setColorMode":
                if let cmID = req.colorMode, let cm = ColorMode(rawValue: cmID) {
                    s.colorMode = cm
                    self.settingsStore.settings = s
                    self.onApplyAppSettings?(s)
                }
            case "setEffect", "setModernEffect":
                if let eid = req.effectID, let fx = ModernEffectID(rawValue: eid) {
                    s.lightingCategory = .modern
                    s.modernEffects.effect = fx
                    self.settingsStore.settings = s
                    self.onApplyAppSettings?(s)
                }
            case "setModernPalette":
                if let pid = req.paletteID, let pal = ModernColorPalette(rawValue: pid) {
                    s.lightingCategory = .modern
                    s.modernEffects.palette = pal
                    self.settingsStore.settings = s
                    self.onApplyAppSettings?(s)
                }
            case "setBrightness":
                if let v = req.value {
                    s.lightingCategory = .modern
                    s.modernEffects.brightness = max(0.05, min(1.0, v))
                    self.settingsStore.settings = s
                    self.onApplyAppSettings?(s)
                }
            case "setSpeed":
                if let v = req.value {
                    s.lightingCategory = .modern
                    s.modernEffects.speed = max(0.1, min(3.0, v))
                    self.settingsStore.settings = s
                    self.onApplyAppSettings?(s)
                }
            case "setSmoothness":
                if let v = req.value {
                    s.modernEffects.smoothness = max(0.0, min(1.0, v))
                    self.settingsStore.settings = s
                    self.onApplyAppSettings?(s)
                }
            case "setReverse":
                if let e = req.enabled {
                    s.reverse = e
                    s.modernEffects.reverseDirection = e
                    self.settingsStore.settings = s
                    self.onApplyAppSettings?(s)
                }
            case "setStaggered":
                if let e = req.enabled {
                    s.modernEffects.staggered = e
                    self.settingsStore.settings = s
                    self.onApplyAppSettings?(s)
                }
            case "setPlacement":
                if let loc = req.location, let l = BulbLocation(rawValue: loc) { s.location = l }
                if let dm = req.drawMode, let d = DrawMode(rawValue: dm) { s.drawMode = d }
                if let b = req.bareWire { s.bareWire = b }
                if let nc = req.noCorners { s.noCorners = nc }
                if let nsm = req.notSoMany { s.notSoMany = nsm }
                if let r = req.reverse { s.reverse = r; s.modernEffects.reverseDirection = r }
                if let inw = req.inward { s.inward = inw }
                if let allM = req.useAllMonitors { s.useAllMonitors = allM }
                if let brk = req.broken { s.broken = brk }
                if let bo = req.burnedOut { s.burnedOut = bo }
                if let ms = req.missing { s.missing = ms }
                self.settingsStore.settings = s
                self.onApplyAppSettings?(s)

            // 2. Holiday Scenes & Effect Studio Timelines
            case "activateScene":
                if let sid = req.sceneID {
                    _ = self.sceneManager.activateScene(id: sid, settingsStore: self.settingsStore, applyWallpaper: req.applyWallpaper ?? false)
                    self.onApplyAppSettings?(self.settingsStore.settings)
                }
            case "restorePreviousScene":
                if self.sceneManager.restorePreviousScene(settingsStore: self.settingsStore) {
                    self.onApplyAppSettings?(self.settingsStore.settings)
                }
            case "returnToClassic":
                self.sceneManager.returnToClassicTwinkleBulbs(settingsStore: self.settingsStore)
                self.onApplyAppSettings?(self.settingsStore.settings)
            case "toggleFavoriteScene":
                if let sid = req.sceneID { self.sceneManager.toggleFavorite(id: sid) }
            case "saveCurrentAsScene":
                let scName = (req.name ?? req.text ?? "Remote Saved Scene").trimmingCharacters(in: .whitespacesAndNewlines)
                if !scName.isEmpty {
                    let snap = self.sceneManager.snapshotCurrentSettings(name: scName, season: .custom, from: s)
                    _ = self.sceneManager.saveUserScene(snap)
                }
            case "setActiveTimeline":
                if let tid = req.timelineID, !tid.isEmpty {
                    var docs = EffectTimelineEngine.builtInSampleTimelines()
                    for t in ng.timelines where !docs.contains(where: { $0.id == t.id }) { docs.append(t) }
                    if let doc = docs.first(where: { $0.id == tid }) {
                        ng.activeTimelineID = doc.id
                        self.stateStore.state = ng
                        s.lightingCategory = .modern
                        self.settingsStore.settings = s
                        self.onSetTimelineID?(doc.id)
                        self.onApplyAppSettings?(s)
                    }
                } else {
                    ng.activeTimelineID = nil
                    self.stateStore.state = ng
                    self.onSetTimelineID?(nil)
                }

            // 3. Music Jukebox & MIDI Light Show Sync
            case "musicPlay":
                s.musicEnabled = true
                self.settingsStore.settings = s
                if let idx = req.trackIndex {
                    AudioEngineService.shared.play(trackIndex: idx, settings: s)
                } else if let tid = req.trackID, let idx = AudioEngineService.shared.tracks.firstIndex(where: { $0.id == tid }) {
                    AudioEngineService.shared.play(trackIndex: idx, settings: s)
                } else {
                    AudioEngineService.shared.play(settings: s)
                }
                self.onApplyAppSettings?(s)
            case "musicStop":
                s.musicEnabled = false
                self.settingsStore.settings = s
                AudioEngineService.shared.stop()
                self.onApplyAppSettings?(s)
            case "musicPause":
                AudioEngineService.shared.pause()
            case "musicResume":
                AudioEngineService.shared.resume(settings: s)
            case "musicToggle":
                AudioEngineService.shared.togglePause(settings: s)
            case "musicNext":
                AudioEngineService.shared.playNext(settings: s)
            case "musicPrev":
                AudioEngineService.shared.playPrevious(settings: s)
            case "setMusicVolume":
                if let v = req.value {
                    s.musicVolume = max(0.0, min(1.0, v))
                    self.settingsStore.settings = s
                    AudioEngineService.shared.setVolume(s.musicVolume)
                }
            case "setMusicPlayMode":
                if let iv = req.intValue ?? req.value.map(Int.init) {
                    s.musicPlayMode = (iv == 1) ? 1 : 0
                    self.settingsStore.settings = s
                }
            case "setMusicRepeatMode":
                if let iv = req.intValue ?? req.value.map(Int.init), let rm = MusicRepeatMode(rawValue: iv) {
                    s.musicRepeatMode = rm
                    self.settingsStore.settings = s
                }
            case "setMIDIReactive":
                if let e = req.enabled { s.modernEffects.midiReactiveEnabled = e }
                if let mm = req.midiMode, let m = MIDIReactiveMode(rawValue: mm) {
                    s.lightingCategory = .modern
                    s.modernEffects.midiReactiveMode = m
                }
                if let sens = req.sensitivity { s.modernEffects.midiSensitivity = max(0.2, min(2.0, sens)) }
                self.settingsStore.settings = s
                self.onApplyAppSettings?(s)

            // 4. Screen Saver & Wallpaper
            case "startScreenSaver":
                if let mid = req.moduleID, let mod = ScreenSaverModuleID(rawValue: mid) {
                    s.ssModule = mod
                    self.settingsStore.settings = s
                }
                self.onStartScreenSaver?()
            case "stopScreenSaver":
                self.onStopScreenSaver?()
            case "setScreenSaverConfig":
                if let mid = req.moduleID, let mod = ScreenSaverModuleID(rawValue: mid) { s.ssModule = mod }
                if let msg = req.text { s.ssMsg = msg }
                if let scr = req.scrollMessage { s.ssScrollMsg = scr }
                if let sl = req.ssLights { s.ssLights = sl }
                self.settingsStore.settings = s
                self.onApplyAppSettings?(s)
            case "setWallpaper":
                if let wid = req.wallpaperID, !wid.isEmpty { s.activeWallpaperID = wid }
                if let stInt = req.wallpaperStyle, let st = WallpaperStyle(rawValue: stInt) { s.wallpaperType = st }
                self.settingsStore.settings = s
                _ = WallpaperService.shared.applyWallpaper(id: s.activeWallpaperID, style: s.wallpaperType)
                self.onApplyAppSettings?(s)

            // 5. Automation, Atmosphere, Interactive, Sync & Celebrations
            case "setAutomation":
                if let e = req.enabled { ng.automation.automationEnabled = e }
                if let v = req.vacationMode { ng.automation.vacationMode = v }
                if let q = req.quietHoursEnabled { ng.automation.quietHours.enabled = q }
                if let asd = req.autoShutdownEnabled { ng.automation.autoShutdownEnabled = asd }
                self.stateStore.state = ng
                if req.text == "clearOverride" { SeasonalScheduleService.shared.clearTemporaryManualOverride() }
                SeasonalScheduleService.shared.evaluateAndScheduleNext(at: Date())
            case "setWeatherAtmosphere":
                if let e = req.enabled { ng.weatherConfig.enabled = e }
                if let condStr = req.condition,
                   let cond = SimulatedWeatherCondition.allCases.first(where: { $0.rawValue.lowercased().contains(condStr.lowercased()) || String(describing: $0).lowercased() == condStr.lowercased() }) {
                    ng.weatherConfig.simulatedOverride = cond
                }
                if let tod = req.timeOfDayEnabled { ng.timeOfDay.enabled = tod }
                self.stateStore.state = ng
            case "setInteractive":
                if let e = req.enabled { ng.interactive.enabled = e }
                if let g = req.mouseProximityGlow { ng.interactive.mouseProximityGlow = g }
                if let r = req.mouseRipple { ng.interactive.mouseRipple = r }
                if let sp = req.sparkleTrail { ng.interactive.sparkleTrail = sp }
                if let pp = req.particlePointerInteraction { ng.interactive.particlePointerInteraction = pp }
                self.stateStore.state = ng
            case "triggerCelebration":
                self.onTriggerCelebration?(req.celebration ?? "christmas")
            case "stopScreenColorSync":
                ScreenColorSyncService.shared.stopSync()
            default:
                break
            }
        }
        if Thread.isMainThread {
            performBlock()
        } else {
            DispatchQueue.main.async(execute: performBlock)
        }
        return "Dispatched \(req.action)"
    }

    // MARK: - Bidirectional WebSocket Upgrade, Framing & Receive Loop (RFC 6455)

    private func performWebSocketUpgrade(conn: NWConnection, key: String, useJSON: Bool, canControl: Bool) {
        stateLock.lock()
        upgradedConnections.insert(ObjectIdentifier(conn))
        stateLock.unlock()

        let magic = key.trimmingCharacters(in: .whitespacesAndNewlines) + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let digest = Insecure.SHA1.hash(data: Data(magic.utf8))
        let accept = Data(digest).base64EncodedString()

        let handshake = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(accept)\r\n\r\n"
        conn.send(content: Data(handshake.utf8), completion: .contentProcessed { [weak self] err in
            guard let self, err == nil else { return }
            let client = WSClient(connection: conn, useJSON: useJSON, canControl: canControl)
            self.stateLock.lock()
            self.wsClients[client.id] = client
            self.connectedWebSocketCount = self.wsClients.count
            self.stateLock.unlock()
            self.log("WebSocket client subscribed (json=\(useJSON), control=\(canControl)).")
            self.startWebSocketReceiveLoop(client)
        })
    }

    private func startWebSocketReceiveLoop(_ client: WSClient) {
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self, weak client] data, _, isComplete, err in
            guard let self, let client else { return }
            if let data, !data.isEmpty {
                client.wsRxBuffer.append(data)
                if client.wsRxBuffer.count > self.maxRequestBodyBytes {
                    client.connection.cancel()
                    self.cleanupConnection(client.connection)
                    return
                }
                self.processIncomingWSFrames(client)
            }
            if isComplete || err != nil {
                self.cleanupConnection(client.connection)
            } else {
                self.startWebSocketReceiveLoop(client)
            }
        }
    }

    private func processIncomingWSFrames(_ client: WSClient) {
        while client.wsRxBuffer.count >= 2 {
            let b0 = client.wsRxBuffer[0]
            let b1 = client.wsRxBuffer[1]
            let opcode = b0 & 0x0F
            let masked = (b1 & 0x80) != 0
            var payLen = Int(b1 & 0x7F)
            var idx = 2

            if payLen == 126 {
                guard client.wsRxBuffer.count >= idx + 2 else { return }
                payLen = (Int(client.wsRxBuffer[idx]) << 8) | Int(client.wsRxBuffer[idx + 1])
                idx += 2
            } else if payLen == 127 {
                // Reject oversized >64KB control payloads cleanly
                client.connection.cancel()
                cleanupConnection(client.connection)
                return
            }
            if payLen > maxRequestBodyBytes {
                client.connection.cancel()
                cleanupConnection(client.connection)
                return
            }

            let maskLen = masked ? 4 : 0
            guard client.wsRxBuffer.count >= idx + maskLen + payLen else { return }

            var payload = client.wsRxBuffer.subdata(in: (idx + maskLen)..<(idx + maskLen + payLen))
            if masked {
                let maskStart = idx
                for i in 0..<payLen {
                    payload[i] ^= client.wsRxBuffer[maskStart + (i & 3)]
                }
            }
            client.wsRxBuffer.removeSubrange(0..<(idx + maskLen + payLen))

            switch opcode {
            case 0x08: // Close
                let closeFrame = wrapWebSocketFrame(opcode: 0x08, payload: Data())
                client.connection.send(content: closeFrame, completion: .contentProcessed { [weak self] _ in
                    client.connection.cancel()
                    self?.cleanupConnection(client.connection)
                })
                return
            case 0x09: // Ping -> Pong
                client.connection.send(content: wrapWebSocketFrame(opcode: 0x0A, payload: payload), completion: .idempotent)
            case 0x01: // JSON Command Frame
                guard client.canControl else {
                    let msg = Data("{\"ok\":false,\"error\":\"Unauthorized: WebSocket is read-only\"}".utf8)
                    client.connection.send(content: wrapWebSocketFrame(opcode: 0x01, payload: msg), completion: .idempotent)
                    continue
                }
                guard consumeRateLimitSlot() else {
                    let msg = Data("{\"ok\":false,\"error\":\"Rate limit exceeded\"}".utf8)
                    client.connection.send(content: wrapWebSocketFrame(opcode: 0x01, payload: msg), completion: .idempotent)
                    continue
                }
                if let req = try? JSONDecoder().decode(TwinkleAPIControlRequest.self, from: payload) {
                    _ = executeControlAction(req)
                    let ack = (try? JSONSerialization.data(withJSONObject: ["ok": true, "wsAck": req.action])) ?? Data("{\"ok\":true}".utf8)
                    client.connection.send(content: wrapWebSocketFrame(opcode: 0x01, payload: ack), completion: .idempotent)
                }
            default:
                break
            }
        }
    }

    private func wrapWebSocketFrame(opcode: UInt8, payload: Data) -> Data {
        var frame = Data([0x80 | (opcode & 0x0F)])
        let len = payload.count
        if len < 126 {
            frame.append(UInt8(len))
        } else if len <= Int(UInt16.max) {
            frame.append(126)
            frame.append(UInt8((len >> 8) & 0xFF))
            frame.append(UInt8(len & 0xFF))
        } else {
            frame.append(127)
            var big = UInt64(len).bigEndian
            withUnsafeBytes(of: &big) { frame.append(contentsOf: $0) }
        }
        frame.append(payload)
        return frame
    }

    // MARK: - Auth & Rate Limit Helpers

    private func isReadAuthorized(token: String?, cfg: TwinkleAPIConfig) -> Bool {
        guard let t = token, !t.isEmpty else { return false }
        return constantTimeEquals(t, cfg.readOnlyToken) || constantTimeEquals(t, cfg.controlToken)
    }

    private func isControlAuthorized(token: String?, cfg: TwinkleAPIConfig) -> Bool {
        guard let t = token, !t.isEmpty else { return false }
        return constantTimeEquals(t, cfg.controlToken)
    }

    private func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let da = Array(a.utf8), db = Array(b.utf8)
        guard da.count == db.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<da.count { diff |= da[i] ^ db[i] }
        return diff == 0
    }

    private func consumeRateLimitSlot() -> Bool {
        let now = CFAbsoluteTimeGetCurrent()
        stateLock.lock()
        controlTimestamps = controlTimestamps.filter { (now - $0) < 60.0 }
        let ok = controlTimestamps.count < maxControlReqPerMin
        if ok { controlTimestamps.append(now) }
        stateLock.unlock()
        return ok
    }

    private func sendJSON(_ conn: NWConnection, status: Int, obj: Any) {
        let data = (try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])) ?? Data("{}".utf8)
        let txt = status == 200 ? "OK" : (status == 401 ? "Unauthorized" : (status == 403 ? "Forbidden" : (status == 429 ? "Too Many Requests" : "Error")))
        sendHTTPResponse(conn, status: status, statusText: txt, contentType: "application/json", body: data)
    }

    private func sendHTTPResponse(_ conn: NWConnection, status: Int, statusText: String, contentType: String, body: Data) {
        let hdr = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n"
        var full = Data(hdr.utf8)
        full.append(body)
        conn.send(content: full, completion: .contentProcessed { _ in
            conn.cancel()
        })
    }

    private func log(_ msg: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onLogEvent?(msg)
        }
    }
}
