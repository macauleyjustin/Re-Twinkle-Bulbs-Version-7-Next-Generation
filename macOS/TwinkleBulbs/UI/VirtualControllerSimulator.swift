import Cocoa

// MARK: - Developer API Console & Virtual Hardware Controller Simulator

public final class VirtualBulbStripView: NSView {
    public var packet: TwinkleBulbFramePacket? {
        didSet { needsDisplay = true }
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor(srgbRed: 0.04, green: 0.05, blue: 0.08, alpha: 1).cgColor)
        ctx.fill(bounds)

        guard let pkt = packet, pkt.bulbCount > 0 else {
            let s = "Waiting for TWKL v1 lighting stream..." as NSString
            s.draw(at: CGPoint(x: 12, y: bounds.midY - 7), withAttributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: 12)])
            return
        }

        let count = min(80, pkt.bulbCount)
        let pad: CGFloat = 10
        let step = (bounds.width - pad * 2) / CGFloat(count)
        let sz = min(22.0, max(6.0, step - 3.0))
        let y = bounds.midY - sz * 0.5

        for i in 0..<count {
            let off = i * 3
            let r = CGFloat(pkt.rgbBytes[off]) / 255.0
            let g = CGFloat(pkt.rgbBytes[off + 1]) / 255.0
            let b = CGFloat(pkt.rgbBytes[off + 2]) / 255.0
            let rect = CGRect(x: pad + CGFloat(i) * step, y: y, width: sz, height: sz)
            ctx.setFillColor(NSColor(srgbRed: r, green: g, blue: b, alpha: 1).cgColor)
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.25).cgColor)
            ctx.strokeEllipse(in: rect)
        }
    }
}

public final class VirtualControllerSimulatorWindowController: NSWindowController {
    private let enableAPICheck = NSButton(checkboxWithTitle: "Enable Developer API (HTTP + WebSocket)", target: nil, action: nil)
    private let allowCtrlCheck = NSButton(checkboxWithTitle: "Allow External Control Commands (POST /v1/control)", target: nil, action: nil)
    private let webRemoteCheck = NSButton(checkboxWithTitle: "Enable Phone/Tablet Web Remote (/remote)", target: nil, action: nil)
    private let allowLANCheck = NSButton(checkboxWithTitle: "Bind LAN Interface (Remote Opt-In)", target: nil, action: nil)
    private let safetyCheck = NSButton(checkboxWithTitle: "Acknowledge Electrical Safety for Physical Adapters", target: nil, action: nil)

    private let statusLabel = NSTextField(labelWithString: "Server Stopped")
    private let tokenField = NSTextField(labelWithString: "")
    private let remoteInfoLabel = NSTextField(labelWithString: "")
    private let stripView = VirtualBulbStripView()
    private let logView = NSTextView()

    private let stateStore: NextGenStateStore
    private let apiService: TwinkleLightingAPIService
    private let remoteService: RemoteControlService

    public init(
        stateStore: NextGenStateStore = .shared,
        apiService: TwinkleLightingAPIService = .shared,
        remoteService: RemoteControlService = .shared
    ) {
        self.stateStore = stateStore
        self.apiService = apiService
        self.remoteService = remoteService

        let win = NSWindow(
            contentRect: NSRect(x: 170, y: 120, width: 790, height: 555),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Re: Twinkle Bulbs — Web Remote, API & External Control Center"
        win.minSize = NSSize(width: 680, height: 460)
        win.appearance = NSAppearance(named: .aqua)
        win.isReleasedWhenClosed = false
        super.init(window: win)

        buildUI()
        wireCallbacks()
        refreshUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showAndRefresh() {
        refreshUI()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let root = window?.contentView else { return }

        for chk in [enableAPICheck, allowCtrlCheck, webRemoteCheck, allowLANCheck, safetyCheck] {
            chk.target = self
            chk.action = #selector(toggleChanged)
        }

        let enableFullRemoteBtn = NSButton(title: "One-Click Enable Full Remote (Web + API)", target: self, action: #selector(enableFullRemoteMode))
        enableFullRemoteBtn.bezelStyle = .rounded
        let openBrowserBtn = NSButton(title: "Open Web Remote in Browser", target: self, action: #selector(openWebRemoteInBrowser))
        openBrowserBtn.bezelStyle = .rounded
        let copyReadBtn = NSButton(title: "Copy Read Token", target: self, action: #selector(copyReadToken))
        copyReadBtn.bezelStyle = .rounded
        let copyCtrlBtn = NSButton(title: "Copy Control Token", target: self, action: #selector(copyControlToken))
        copyCtrlBtn.bezelStyle = .rounded
        let pinBtn = NSButton(title: "New Remote PIN", target: self, action: #selector(rotatePIN))
        pinBtn.bezelStyle = .rounded
        let blackoutBtn = NSButton(title: "Test Blackout All", target: self, action: #selector(testBlackout))
        blackoutBtn.bezelStyle = .rounded

        let btnRow = NSStackView(views: [enableFullRemoteBtn, openBrowserBtn, pinBtn, copyCtrlBtn, copyReadBtn, blackoutBtn])
        btnRow.orientation = .horizontal
        btnRow.spacing = 8

        tokenField.isSelectable = true
        tokenField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        remoteInfoLabel.isSelectable = true
        remoteInfoLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        statusLabel.font = NSFont.boldSystemFont(ofSize: 12)

        stripView.translatesAutoresizingMaskIntoConstraints = false

        let logScroll = NSScrollView()
        logScroll.translatesAutoresizingMaskIntoConstraints = false
        logScroll.hasVerticalScroller = true
        logScroll.borderType = .bezelBorder
        logView.isEditable = false
        logView.font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
        logScroll.documentView = logView

        let topStack = NSStackView(views: [
            statusLabel,
            enableAPICheck, allowCtrlCheck, webRemoteCheck, allowLANCheck, safetyCheck,
            tokenField, remoteInfoLabel, btnRow
        ])
        topStack.translatesAutoresizingMaskIntoConstraints = false
        topStack.orientation = .vertical
        topStack.alignment = .leading
        topStack.spacing = 6
        root.addSubview(topStack)
        root.addSubview(stripView)
        root.addSubview(logScroll)

        NSLayoutConstraint.activate([
            topStack.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            topStack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            topStack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),

            stripView.topAnchor.constraint(equalTo: topStack.bottomAnchor, constant: 10),
            stripView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            stripView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            stripView.heightAnchor.constraint(equalToConstant: 70),

            logScroll.topAnchor.constraint(equalTo: stripView.bottomAnchor, constant: 10),
            logScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            logScroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            logScroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12)
        ])
    }

    private func wireCallbacks() {
        ReferenceVirtualAdapter.shared.onFrameUpdated = { [weak self] pkt in
            self?.stripView.packet = pkt
        }
        apiService.onLogEvent = { [weak self] msg in
            self?.appendLog(msg)
        }
    }

    private func appendLog(_ line: String) {
        let cur = logView.string
        let ts = ISO8601DateFormatter().string(from: Date())
        let updated = cur + "[\(ts)] \(line)\n"
        logView.string = String(updated.suffix(6000))
        logView.scrollToEndOfDocument(nil)
    }

    private func refreshUI() {
        let cfg = stateStore.state.apiConfig
        enableAPICheck.state = cfg.enabled ? .on : .off
        allowCtrlCheck.state = cfg.allowControlCommands ? .on : .off
        webRemoteCheck.state = cfg.webRemoteEnabled ? .on : .off
        allowLANCheck.state = (cfg.allowLANAccess && !cfg.bindLocalhostOnly) ? .on : .off
        safetyCheck.state = cfg.electricalSafetyAcknowledged ? .on : .off

        statusLabel.stringValue = "API: \(apiService.activeAddressDescription)  •  WS Subscribers: \(apiService.connectedWebSocketCount)  •  Simulator Frames: \(ReferenceVirtualAdapter.shared.receivedFrameCount)"
        tokenField.stringValue = "Read Token: \(cfg.readOnlyToken)   |   Control Token: \(cfg.controlToken)"
        let ips = RemoteControlService.localIPv4Addresses()
        let lanHost = !ips.isEmpty ? ips[0] : "127.0.0.1"
        let port = apiService.boundPort > 0 ? apiService.boundPort : cfg.port
        remoteInfoLabel.stringValue = "Web Remote (Local): http://127.0.0.1:\(port)/remote  |  LAN: http://\(lanHost):\(port)/remote  |  Pairing PIN: \(remoteService.activePairingPIN)"
    }

    @objc private func toggleChanged() {
        var next = stateStore.state
        next.apiConfig.enabled = (enableAPICheck.state == .on)
        next.apiConfig.allowControlCommands = (allowCtrlCheck.state == .on)
        next.apiConfig.webRemoteEnabled = (webRemoteCheck.state == .on)
        let lan = (allowLANCheck.state == .on)
        next.apiConfig.allowLANAccess = lan
        next.apiConfig.bindLocalhostOnly = !lan
        let ack = (safetyCheck.state == .on)
        next.apiConfig.electricalSafetyAcknowledged = ack
        next.apiConfig.externalHardwareEnabled = ack
        stateStore.state = next

        apiService.startIfConfigured()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.refreshUI()
        }
    }

    @objc private func copyReadToken() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(stateStore.state.apiConfig.readOnlyToken, forType: .string)
    }

    @objc private func copyControlToken() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(stateStore.state.apiConfig.controlToken, forType: .string)
    }

    @objc private func rotatePIN() {
        _ = remoteService.rotatePairingPIN()
        remoteService.revokeAllSessions()
        refreshUI()
    }

    @objc private func enableFullRemoteMode() {
        var next = stateStore.state
        next.apiConfig.enabled = true
        next.apiConfig.allowControlCommands = true
        next.apiConfig.webRemoteEnabled = true
        next.apiConfig.allowLANAccess = true
        next.apiConfig.bindLocalhostOnly = false
        stateStore.state = next
        apiService.startIfConfigured()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.refreshUI()
        }
    }

    @objc private func openWebRemoteInBrowser() {
        var next = stateStore.state
        if !next.apiConfig.webRemoteEnabled {
            next.apiConfig.webRemoteEnabled = true
            stateStore.state = next
            apiService.startIfConfigured()
        }
        let port = apiService.boundPort > 0 ? apiService.boundPort : next.apiConfig.port
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.refreshUI()
            if let url = URL(string: "http://127.0.0.1:\(port)/remote") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func testBlackout() {
        apiService.broadcastBlackoutFrame()
        appendLog("Manual blackout sent to simulator & connected streams.")
        refreshUI()
    }
}
