import Cocoa
import CoreGraphics

// MARK: - Bulb Canvas View (Flipped Top-Down Coordinate Space)

public final class BulbCanvasView: NSView {
    public override var isFlipped: Bool { true }
    public override var isOpaque: Bool { false }

    var engine: BulbEngine?
    var modernEngine: ModernLightingEngine?
    var overrideStates: [ModernBulbState]?
    var interactiveEngine: InteractiveDesktopEffectsEngine?
    var currentSettings: AppSettings = .defaultSettings()

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              currentSettings.lightsEnabled else { return }
        if currentSettings.lightingCategory == .modern {
            if let states = overrideStates ?? modernEngine?.states {
                Self.drawModernStates(states, settings: currentSettings, in: ctx, clipRect: dirtyRect)
            }
            interactiveEngine?.drawParticles(in: ctx)
        } else if let engine = engine {
            Self.drawSlots(engine.slots, settings: currentSettings, in: ctx, clipRect: dirtyRect)
            interactiveEngine?.drawParticles(in: ctx)
        }
    }

    static func drawModernStates(_ states: [ModernBulbState], settings: AppSettings, in ctx: CGContext, clipRect: CGRect? = nil) {
        let registry = BulbArtworkRegistry.shared
        ctx.saveGState()
        ctx.interpolationQuality = .none
        for state in states {
            if let clip = clipRect, !state.frame.intersects(clip) { continue }
            let pair = registry.modernImages(for: state, settings: settings)
            if pair.base == nil && pair.lit == nil { continue }
            ctx.saveGState()
            ctx.translateBy(x: state.frame.minX, y: state.frame.maxY)
            ctx.scaleBy(x: 1, y: -1)
            let target = CGRect(x: 0, y: 0, width: state.frame.width, height: state.frame.height)
            if let base = pair.base {
                ctx.setAlpha(1.0)
                ctx.draw(base, in: target)
            }
            if let lit = pair.lit, state.intensity > 0.01 {
                ctx.setAlpha(CGFloat(max(0.0, min(1.0, state.intensity))))
                ctx.draw(lit, in: target)
            }
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    static func drawSlots(_ slots: [BulbSlot], settings: AppSettings, in ctx: CGContext, clipRect: CGRect? = nil) {
        let registry = BulbArtworkRegistry.shared
        ctx.saveGState()
        ctx.interpolationQuality = .none
        for slot in slots {
            if let clip = clipRect, !slot.frame.intersects(clip) { continue }
            guard let img = registry.image(for: slot, settings: settings) else { continue }
            // Since canvas is top-down flipped (origin top-left), CoreGraphics ctx.draw(img) draws upside-down unless locally flipped per tile
            ctx.saveGState()
            ctx.translateBy(x: slot.frame.minX, y: slot.frame.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: slot.frame.width, height: slot.frame.height))
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    /// Offscreen pixel-exact snapshot helper used by Monitor Preview & Automated Reference Tests
    public static func renderSnapshot(width: Int, height: Int, engine: BulbEngine, settings: AppSettings, backgroundColor: NSColor? = nil) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Top-down flipped root coordinate transform matching macOS flipped NSView
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)

        if let bg = backgroundColor {
            ctx.setFillColor(bg.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        drawSlots(engine.slots, settings: settings, in: ctx)
        return ctx.makeImage()
    }

    public static func renderModernSnapshot(width: Int, height: Int, modernEngine: ModernLightingEngine, settings: AppSettings, backgroundColor: NSColor? = nil) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)

        if let bg = backgroundColor {
            ctx.setFillColor(bg.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        drawModernStates(modernEngine.states, settings: settings, in: ctx)
        return ctx.makeImage()
    }
}

// MARK: - Transparent Click-Through Overlay Controller

final class OverlayWindowController {
    private struct DisplayOverlay {
        let screen: NSScreen
        let window: NSWindow
        let canvas: BulbCanvasView
        let engine: BulbEngine
        let modernEngine: ModernLightingEngine
    }

    private var overlays: [DisplayOverlay] = []
    private var animationTimer: Timer?
    private var changerTimer: Timer?
    private var activeTimelineEngine: EffectTimelineEngine?
    private var lastModernTickMs: UInt64 = 0
    public var scheduleBrightnessMultiplier: Double = 1.0
    private var settings: AppSettings = .defaultSettings()

    var onTraySyncTick: ((Bool) -> Void)?
    var isPausedForScreenSaver: Bool = false {
        didSet { updateWindowVisibility() }
    }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenConfigChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreenConfigChange),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        animationTimer?.invalidate()
        changerTimer?.invalidate()
    }

    @objc private func handleScreenConfigChange() {
        rebuildOverlays(with: settings)
    }

    func applySettings(_ newSettings: AppSettings) {
        let old = settings
        self.settings = newSettings

        let needsRebuild = overlays.isEmpty
            || old.location != newSettings.location
            || old.bulbSize != newSettings.bulbSize
            || old.drawMode != newSettings.drawMode
            || old.useAllMonitors != newSettings.useAllMonitors
            || old.drawMonitorIndex != newSettings.drawMonitorIndex
            || old.colorMode != newSettings.colorMode
            || old.flashMode != newSettings.flashMode
            || old.noCorners != newSettings.noCorners
            || old.notSoMany != newSettings.notSoMany
            || old.bareWire != newSettings.bareWire
            || old.broken != newSettings.broken
            || old.burnedOut != newSettings.burnedOut
            || old.missing != newSettings.missing
            || old.reverse != newSettings.reverse
            || old.inward != newSettings.inward
            || old.bulbSetName != newSettings.bulbSetName
            || old.mixBulbs != newSettings.mixBulbs
            || old.sysColorHighlight != newSettings.sysColorHighlight
            || old.highlightColorHex != newSettings.highlightColorHex
            || old.rate != newSettings.rate
            || old.lightsEnabled != newSettings.lightsEnabled
            || old.modernEffects.seed != newSettings.modernEffects.seed
            || old.modernEffects.perMonitorPhaseOffset != newSettings.modernEffects.perMonitorPhaseOffset

        if needsRebuild {
            rebuildOverlays(with: newSettings)
        } else {
            for item in overlays {
                item.canvas.currentSettings = newSettings
                item.modernEngine.updateConfigOnly(newSettings.modernEffects)
                item.canvas.needsDisplay = true
            }
            updateWindowVisibility()
        }

        ensureTimers()
    }

    func handleMIDIEvent(_ evt: MIDILightEvent) {
        guard settings.lightingCategory == .modern,
              settings.modernEffects.midiReactiveEnabled,
              !isPausedForScreenSaver else { return }
        activeTimelineEngine?.triggerMIDINoteImpulse(evt.note, velocity: evt.velocity)
        for item in overlays {
            MIDILightShowComposer.shared.dispatchMIDIEvent(evt, to: item.modernEngine)
        }
    }

    public func setActiveTimelineDocument(_ doc: TimelineEffectDocument?) {
        activeTimelineEngine = doc.map { EffectTimelineEngine(document: $0) }
    }

    public func triggerCelebration(_ preset: CelebrationEffectPreset) {
        let bounds = overlays.first?.canvas.bounds ?? CGRect(x: 0, y: 0, width: 1280, height: 120)
        InteractiveDesktopEffectsEngine.shared.triggerCelebration(preset, inCanvasBounds: bounds)
    }

    func rebuildOverlays(with newSettings: AppSettings) {
        tearDownWindows()
        self.settings = newSettings
        guard !newSettings.runSSOnly, newSettings.lightsEnabled else {
            onTraySyncTick?(true)
            return
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let targetScreens: [NSScreen]
        if newSettings.useAllMonitors {
            targetScreens = screens
        } else {
            let idx = min(max(0, newSettings.drawMonitorIndex), screens.count - 1)
            targetScreens = [screens[idx]]
        }

        let nowMs = currentMonotonicMs()
        for (monIdx, scr) in targetScreens.enumerated() {
            let winFrame = targetRect(for: scr, settings: newSettings)
            let win = NSWindow(
                contentRect: winFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: scr
            )
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = false
            win.ignoresMouseEvents = true
            win.isReleasedWhenClosed = false
            win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            win.level = windowLevel(for: newSettings.drawMode)

            let engine = BulbEngine(settings: newSettings)
            let localBounds = CGRect(origin: .zero, size: winFrame.size)
            engine.configure(bounds: localBounds, settings: newSettings, nowMs: nowMs)

            let modern = ModernLightingEngine(seed: newSettings.modernEffects.seed)
            modern.configure(bounds: localBounds, settings: newSettings, monitorOffset: monIdx, nowMs: nowMs)

            let canvas = BulbCanvasView(frame: localBounds)
            canvas.engine = engine
            canvas.modernEngine = modern
            canvas.currentSettings = newSettings
            win.contentView = canvas

            if !isPausedForScreenSaver {
                win.orderFrontRegardless()
            }
            overlays.append(DisplayOverlay(screen: scr, window: win, canvas: canvas, engine: engine, modernEngine: modern))
        }

        ensureTimers()
    }

    private func targetRect(for screen: NSScreen, settings: AppSettings) -> CGRect {
        let vf = screen.visibleFrame
        let full = screen.frame
        switch settings.drawMode {
        case .desktop:
            // Respect menu bar height so bulbs aren't hidden underneath macOS menu bar
            return CGRect(x: vf.minX, y: full.minY, width: vf.width, height: vf.maxY - full.minY)
        case .alwaysOnTop:
            return CGRect(x: vf.minX, y: vf.minY, width: vf.width, height: vf.height)
        case .menuBarTaskbar:
            // Hang directly from the top screen band (Menu Bar level) or full edges when Around Screen / Bottom Only
            if settings.location == .top {
                let stripH = CGFloat(settings.bulbSize.pixels)
                return CGRect(x: full.minX, y: full.maxY - stripH, width: full.width, height: stripH)
            }
            return full
        }
    }

    private func windowLevel(for mode: DrawMode) -> NSWindow.Level {
        switch mode {
        case .desktop:
            return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        case .alwaysOnTop:
            return .floating
        case .menuBarTaskbar:
            return .statusBar
        }
    }

    private func updateWindowVisibility() {
        for item in overlays {
            if settings.lightsEnabled && !settings.runSSOnly && !isPausedForScreenSaver {
                item.window.orderFrontRegardless()
            } else {
                item.window.orderOut(nil)
            }
        }
    }

    private func tearDownWindows() {
        for item in overlays {
            item.window.orderOut(nil)
            item.window.close()
        }
        overlays.removeAll()
    }

    private func ensureTimers() {
        animationTimer?.invalidate()
        animationTimer = nil

        if settings.lightsEnabled && !settings.runSSOnly {
            if settings.lightingCategory == .modern {
                let tel = PerformanceCoordinator.shared.currentTelemetry(settings: settings)
                let baseFps = settings.modernEffects.smoothness >= 0.5 ? (1.0 / 60.0) : (1.0 / 30.0)
                let fpsInterval = max(baseFps, tel.effectiveFrameIntervalSeconds)
                let timer = Timer(timeInterval: fpsInterval, repeats: true) { [weak self] _ in
                    self?.stepAnimation()
                }
                RunLoop.main.add(timer, forMode: .common)
                animationTimer = timer
            } else {
                // Exact 50 ms master animation poll matching SetTimer(..., 5, 50)
                let timer = Timer(timeInterval: 0.050, repeats: true) { [weak self] _ in
                    self?.stepAnimation()
                }
                RunLoop.main.add(timer, forMode: .common)
                animationTimer = timer
            }
        }

        changerTimer?.invalidate()
        changerTimer = nil
        if settings.bulbChanger && settings.bulbChangeFreqMinutes > 0 {
            let secs = TimeInterval(settings.bulbChangeFreqMinutes * 60)
            let ct = Timer(timeInterval: secs, repeats: true) { [weak self] _ in
                self?.advanceBulbSetChanger()
            }
            RunLoop.main.add(ct, forMode: .common)
            changerTimer = ct
        }
    }

    private func stepAnimation() {
        guard !isPausedForScreenSaver, settings.lightsEnabled else { return }
        let nowMs = currentMonotonicMs()
        if settings.lightingCategory == .modern {
            let dt = lastModernTickMs > 0 && nowMs >= lastModernTickMs
                ? min(0.1, max(0.005, Double(nowMs - lastModernTickMs) / 1000.0))
                : 0.033
            lastModernTickMs = nowMs

            let ng = NextGenStateStore.shared.state
            let audioClock = AudioEngineService.shared.currentPlaybackClockAndEnergy()
            _ = MIDILightShowComposer.shared.synchronizeWithAudioClock(positionSeconds: audioClock.positionSeconds)
            let atmo = WeatherAtmosphereService.shared.currentModulation()
            let totalBrightScale = max(0.05, min(1.5, atmo.brightnessMultiplier * scheduleBrightnessMultiplier))

            for (ovIdx, item) in overlays.enumerated() {
                MIDILightShowComposer.shared.applyAudioBufferEnergyIfEnabled(
                    energyLevel: audioClock.energyLevel,
                    isAudioFilePlayback: audioClock.isAudioFilePlayback,
                    to: item.modernEngine
                )

                var workingStates: [ModernBulbState]
                if let tl = activeTimelineEngine, ovIdx == 0 {
                    workingStates = tl.evaluateStates(dt: dt, bounds: item.canvas.bounds, settings: settings)
                } else {
                    item.modernEngine.tick(nowMs: nowMs)
                    workingStates = item.modernEngine.states
                }

                // Apply optional Weather / Time-of-Day / Quiet-Hours / Screen Sync modulation
                let screenSyncActive = ScreenColorSyncService.shared.isSyncActive
                let syncCol = ScreenColorSyncService.shared.smoothedColor
                if abs(totalBrightScale - 1.0) > 0.01 || abs(atmo.warmthShift) > 0.01 || screenSyncActive {
                    for i in workingStates.indices {
                        var st = workingStates[i]
                        if atmo.warmthShift > 0.01 {
                            st.r = min(1.0, st.r + atmo.warmthShift * 0.20)
                            st.b = max(0.0, st.b - atmo.warmthShift * 0.15)
                        } else if atmo.warmthShift < -0.01 {
                            st.b = min(1.0, st.b + abs(atmo.warmthShift) * 0.25)
                        }
                        if screenSyncActive {
                            st.r = st.r * 0.40 + syncCol.r * 0.60
                            st.g = st.g * 0.40 + syncCol.g * 0.60
                            st.b = st.b * 0.40 + syncCol.b * 0.60
                        }
                        st.intensity = max(0.0, min(1.0, st.intensity * totalBrightScale))
                        workingStates[i] = st
                    }
                }

                // Step non-intrusive interactive desktop glow / ripples / celebrations when active
                if ovIdx == 0 && (ng.interactive.enabled || !InteractiveDesktopEffectsEngine.shared.sparkleParticles.isEmpty) {
                    InteractiveDesktopEffectsEngine.shared.step(
                        dt: dt,
                        config: ng.interactive,
                        screenFrame: item.screen.frame,
                        canvasBounds: item.canvas.bounds,
                        bulbStates: &workingStates
                    )
                    item.canvas.interactiveEngine = InteractiveDesktopEffectsEngine.shared
                } else {
                    item.canvas.interactiveEngine = nil
                }

                item.canvas.overrideStates = workingStates
                item.canvas.needsDisplay = true

                if ovIdx == 0 {
                    TwinkleLightingAPIService.shared.publishLightingFrame(states: workingStates)
                }
            }
            onTraySyncTick?(true)
        } else {
            let apiCfg = NextGenStateStore.shared.state.apiConfig
            let shouldPublish = apiCfg.enabled || apiCfg.webRemoteEnabled || (apiCfg.externalHardwareEnabled && apiCfg.electricalSafetyAcknowledged)
            for (ovIdx, item) in overlays.enumerated() {
                item.canvas.overrideStates = nil
                item.canvas.interactiveEngine = nil
                if item.engine.tick(nowMs: nowMs) {
                    item.canvas.needsDisplay = true
                }
                if ovIdx == 0 && shouldPublish {
                    let states = item.engine.slots.map { slot -> ModernBulbState in
                        let cIdx = max(0, min(6, slot.colorIndex))
                        let col = slot.isLit ? BulbArtworkRegistry.slotColors[cIdx].onGlow : BulbArtworkRegistry.slotColors[cIdx].offCore
                        return ModernBulbState(
                            index: slot.index,
                            frame: slot.frame,
                            edge: slot.edge,
                            isBareWire: slot.isBareWire,
                            isMissing: slot.isMissing,
                            isBroken: slot.isBroken,
                            isBurnedOut: slot.isBurnedOut,
                            r: Double(col.0) / 255.0,
                            g: Double(col.1) / 255.0,
                            b: Double(col.2) / 255.0,
                            intensity: slot.isLit ? 1.0 : 0.18
                        )
                    }
                    TwinkleLightingAPIService.shared.publishLightingFrame(states: states)
                }
            }
            if let first = overlays.first {
                onTraySyncTick?(first.engine.traySyncLitState)
            }
        }
    }

    private func advanceBulbSetChanger() {
        let sets = BulbArtworkRegistry.shared.availableSets
        guard sets.count > 1 else { return }
        var s = SettingsStore.shared.settings
        if s.bulbChangeOrder == 1 {
            let others = sets.filter { $0.id != s.bulbSetName }
            s.bulbSetName = (others.randomElement() ?? sets[0]).id
        } else {
            let idx = sets.firstIndex(where: { $0.id == s.bulbSetName }) ?? 0
            s.bulbSetName = sets[(idx + 1) % sets.count].id
        }
        SettingsStore.shared.settings = s
    }

    private func currentMonotonicMs() -> UInt64 {
        UInt64(ProcessInfo.processInfo.systemUptime * 1000.0)
    }
}
