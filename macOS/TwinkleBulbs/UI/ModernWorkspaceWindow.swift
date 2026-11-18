import Cocoa
import UniformTypeIdentifiers

// MARK: - Part XIII & II/IX/X/XI/XII/XIV: Optional Modern Studio Workspace Window

public final class ModernWorkspaceWindowController: NSWindowController, NSWindowDelegate {
    private let tabView = NSTabView()
    private let lightsCheck = NSButton(checkboxWithTitle: "Desktop Holiday Lights Active", target: nil, action: nil)
    private let categorySeg = NSSegmentedControl(labels: ["Classic v6.0", "Modern 60fps"], trackingMode: .selectOne, target: nil, action: nil)
    private let speedSlider = NSSlider(value: 1.0, minValue: 0.2, maxValue: 3.0, target: nil, action: nil)
    private let brightSlider = NSSlider(value: 1.0, minValue: 0.1, maxValue: 1.0, target: nil, action: nil)
    private let quickScenePopup = NSPopUpButton()

    // Automation controls
    private let autoEnableCheck = NSButton(checkboxWithTitle: "Enable Seasonal Schedule Automation", target: nil, action: nil)
    private let vacationCheck = NSButton(checkboxWithTitle: "Vacation Mode (Paused / Away)", target: nil, action: nil)
    private let quietCheck = NSButton(checkboxWithTitle: "Quiet Hours Dimming & Mute (22:30 – 07:00)", target: nil, action: nil)
    private let autoShutdownCheck = NSButton(checkboxWithTitle: "Scheduled Nightly Auto-Shutdown (23:59 – 07:00)", target: nil, action: nil)
    private let solarLatField = NSTextField(string: "64.7511")
    private let solarLonField = NSTextField(string: "-147.3494")
    private let autoStatusLabel = NSTextField(labelWithString: "")

    // Atmosphere & Interactive & Screen Sync
    private let interactiveCheck = NSButton(checkboxWithTitle: "Enable Interactive Desktop Effects (Proximity Glow & Ripple)", target: nil, action: nil)
    private let proxGlowCheck = NSButton(checkboxWithTitle: "Pointer Proximity Glow", target: nil, action: nil)
    private let rippleCheck = NSButton(checkboxWithTitle: "Strand Sweep Wave / Ripple", target: nil, action: nil)
    private let sparkleCheck = NSButton(checkboxWithTitle: "Subtle Pointer Sparkle Trail", target: nil, action: nil)
    private let todCheck = NSButton(checkboxWithTitle: "Time-of-Day Brightness Curve (Morning/Evening/Night)", target: nil, action: nil)
    private let weatherEnableCheck = NSButton(checkboxWithTitle: "Enable Weather-Reactive Lighting Modulation", target: nil, action: nil)
    private let weatherSimPopup = NSPopUpButton()
    private let weatherNetworkCheck = NSButton(checkboxWithTitle: "Allow Optional Network Weather Lookup (Open-Meteo)", target: nil, action: nil)
    private let screenSyncBtn = NSButton(title: "Start Ambient Screen Sync (Opt-In)", target: nil, action: nil)
    private let stopScreenSyncBtn = NSButton(title: "STOP Screen Sync", target: nil, action: nil)
    private let screenSyncStatusLbl = NSTextField(labelWithString: "Screen Sync: Off (Privacy Protected)")

    // Performance & UI Mode
    private let adaptivePerfCheck = NSButton(checkboxWithTitle: "Adaptive Battery & Thermal Power Management", target: nil, action: nil)
    private let batteryThrottleCheck = NSButton(checkboxWithTitle: "Reduce FPS on Battery Power", target: nil, action: nil)
    private let highContrastCheck = NSButton(checkboxWithTitle: "Accessibility High-Contrast Labels", target: nil, action: nil)
    private let uiDefaultPopup = NSPopUpButton()
    private let perfTelemetryLbl = NSTextField(labelWithString: "")

    private let settingsStore: SettingsStore
    private let stateStore: NextGenStateStore
    private let sceneManager: HolidaySceneManager

    public var onApplyAppSettings: ((AppSettings) -> Void)?
    public var onOpenClassicSettings: (() -> Void)?
    public var onOpenSceneBrowser: (() -> Void)?
    public var onOpenEffectStudio: (() -> Void)?
    public var onOpenMIDIComposer: (() -> Void)?
    public var onOpenLayoutDesigner: (() -> Void)?
    public var onOpenAPISimulator: (() -> Void)?
    public var onTriggerCelebration: ((CelebrationEffectPreset) -> Void)?

    public init(
        settingsStore: SettingsStore = .shared,
        stateStore: NextGenStateStore = .shared,
        sceneManager: HolidaySceneManager = .shared
    ) {
        self.settingsStore = settingsStore
        self.stateStore = stateStore
        self.sceneManager = sceneManager

        let win = NSWindow(
            contentRect: NSRect(x: 160, y: 110, width: 780, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Re: Twinkle Bulbs — Next-Generation Modern Studio"
        win.minSize = NSSize(width: 720, height: 470)
        win.appearance = NSAppearance(named: .aqua)
        win.isReleasedWhenClosed = false
        super.init(window: win)
        win.delegate = self

        buildUI()
        syncFromStores()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showAndReload() {
        syncFromStores()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let root = window?.contentView else { return }

        tabView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            tabView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            tabView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12)
        ])

        tabView.addTabViewItem(makeOverviewTab())
        tabView.addTabViewItem(makeAutomationTab())
        tabView.addTabViewItem(makeAtmosphereTab())
        tabView.addTabViewItem(makePacksExportPerfTab())
    }

    private func mkBtn(_ t: String, _ a: Selector) -> NSButton {
        let b = NSButton(title: t, target: self, action: a)
        b.bezelStyle = .rounded
        return b
    }

    private func makeOverviewTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "overview")
        item.label = "Studio & Quick Control"
        let view = NSView()

        lightsCheck.target = self; lightsCheck.action = #selector(lightingEdited)
        categorySeg.target = self; categorySeg.action = #selector(lightingEdited)
        speedSlider.target = self; speedSlider.action = #selector(lightingEdited)
        brightSlider.target = self; brightSlider.action = #selector(lightingEdited)
        quickScenePopup.target = self; quickScenePopup.action = #selector(quickActivateScene)

        let studioToolsRow1 = NSStackView(views: [
            mkBtn("🎄 Holiday Scenes Browser...", #selector(openScenes)),
            mkBtn("🎞 Lighting Effect Studio...", #selector(openFXStudio)),
            mkBtn("🎼 MIDI Light Show Composer...", #selector(openMIDI))
        ])
        studioToolsRow1.orientation = .horizontal; studioToolsRow1.spacing = 8

        let studioToolsRow2 = NSStackView(views: [
            mkBtn("🏠 Virtual Layout Designer...", #selector(openLayouts)),
            mkBtn("🔌 Developer API & Simulator...", #selector(openAPI)),
            mkBtn("🪟 Classic XP 7-Tab Settings...", #selector(openClassicXP))
        ])
        studioToolsRow2.orientation = .horizontal; studioToolsRow2.spacing = 8

        let returnClassicBtn = mkBtn("Return to Authentic Classic v6.0 Defaults", #selector(returnClassicDefaults))

        let grid = NSGridView(views: [
            [lightsCheck, categorySeg],
            [NSTextField(labelWithString: "One-Click Scene:"), quickScenePopup],
            [NSTextField(labelWithString: "Effect Speed:"), speedSlider],
            [NSTextField(labelWithString: "Master Brightness:"), brightSlider]
        ])
        grid.rowSpacing = 10; grid.columnSpacing = 12

        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Instant Controls (Synchronized with Classic XP Settings)"),
            grid,
            NSTextField(labelWithString: "Next-Generation Creative Tools"),
            studioToolsRow1,
            studioToolsRow2,
            returnClassicBtn
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14)
        ])
        item.view = view
        return item
    }

    private func makeAutomationTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "auto")
        item.label = "Seasonal Automation & Celebrations"
        let view = NSView()

        for chk in [autoEnableCheck, vacationCheck, quietCheck, autoShutdownCheck] {
            chk.target = self; chk.action = #selector(automationEdited)
        }
        solarLatField.target = self; solarLatField.action = #selector(automationEdited)
        solarLonField.target = self; solarLonField.action = #selector(automationEdited)

        let evalBtn = mkBtn("Evaluate Schedule Now", #selector(evaluateScheduleNow))
        let clearOvrBtn = mkBtn("Clear Manual Override", #selector(clearOverride))
        let celebRow = NSStackView(views: [
            NSTextField(labelWithString: "Launch Celebration:"),
            mkBtn("🎄 Christmas", #selector(burstChristmas)),
            mkBtn("🎆 New Year", #selector(burstNewYear)),
            mkBtn("🎃 Halloween", #selector(burstHalloween)),
            mkBtn("🎂 Birthday", #selector(burstBirthday))
        ])
        celebRow.orientation = .horizontal; celebRow.spacing = 6

        let coordsRow = NSStackView(views: [
            NSTextField(labelWithString: "Solar Lat/Lon (Sunset Triggers):"),
            solarLatField, solarLonField, evalBtn, clearOvrBtn
        ])
        coordsRow.orientation = .horizontal; coordsRow.spacing = 8

        autoStatusLabel.maximumNumberOfLines = 4
        autoStatusLabel.font = NSFont.systemFont(ofSize: 11.5)
        autoStatusLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            autoEnableCheck, vacationCheck, quietCheck, autoShutdownCheck,
            coordsRow, autoStatusLabel, celebRow
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            solarLatField.widthAnchor.constraint(equalToConstant: 80),
            solarLonField.widthAnchor.constraint(equalToConstant: 80)
        ])
        item.view = view
        return item
    }

    private func makeAtmosphereTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "atmo")
        item.label = "Interactive, Weather & Screen Sync"
        let view = NSView()

        for chk in [interactiveCheck, proxGlowCheck, rippleCheck, sparkleCheck, todCheck, weatherEnableCheck, weatherNetworkCheck] {
            chk.target = self; chk.action = #selector(atmosphereEdited)
        }
        weatherSimPopup.addItems(withTitles: SimulatedWeatherCondition.allCases.map(\.rawValue))
        weatherSimPopup.target = self; weatherSimPopup.action = #selector(atmosphereEdited)

        screenSyncBtn.bezelStyle = .rounded
        screenSyncBtn.target = self; screenSyncBtn.action = #selector(requestStartScreenSync)
        stopScreenSyncBtn.bezelStyle = .rounded
        stopScreenSyncBtn.target = self; stopScreenSyncBtn.action = #selector(stopScreenSyncNow)

        let screenRow = NSStackView(views: [screenSyncBtn, stopScreenSyncBtn, screenSyncStatusLbl])
        screenRow.orientation = .horizontal; screenRow.spacing = 8

        let weatherRow = NSStackView(views: [
            NSTextField(labelWithString: "Offline Simulated Weather:"), weatherSimPopup
        ])
        weatherRow.orientation = .horizontal; weatherRow.spacing = 8

        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Interactive Desktop Decorations (Zero Accessibility Prompts, Click-Through)"),
            interactiveCheck, proxGlowCheck, rippleCheck, sparkleCheck,
            NSTextField(labelWithString: "Time-of-Day & Weather Atmosphere"),
            todCheck, weatherEnableCheck, weatherRow, weatherNetworkCheck,
            NSTextField(labelWithString: "Ambient Screen Color Sync (Never Active at Launch — Local Color Only)"),
            screenRow
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14)
        ])
        item.view = view
        return item
    }

    private func makePacksExportPerfTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "export")
        item.label = "Theme Packs, Recording & Performance"
        let view = NSView()

        let packRow = NSStackView(views: [
            mkBtn("Export Theme Pack (.twinklepack)...", #selector(exportThemePack)),
            mkBtn("Verify & Import Theme Pack...", #selector(importThemePack))
        ])
        packRow.orientation = .horizontal; packRow.spacing = 8

        let exportRow = NSStackView(views: [
            mkBtn("Record 3s Animated GIF...", #selector(exportGIF)),
            mkBtn("Record 3s H.264 MP4 Video...", #selector(exportMP4)),
            mkBtn("Export Raw Frame Data (.twinkleframes)...", #selector(exportFramesJSON))
        ])
        exportRow.orientation = .horizontal; exportRow.spacing = 8

        for chk in [adaptivePerfCheck, batteryThrottleCheck, highContrastCheck] {
            chk.target = self; chk.action = #selector(perfEdited)
        }
        uiDefaultPopup.addItems(withTitles: ["Historical Windows XP 7-Tab UI (Default)", "Modern Studio UI"])
        uiDefaultPopup.target = self; uiDefaultPopup.action = #selector(perfEdited)

        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Portable Verified Packages (.twinklepack with SHA-256 Validation)"),
            packRow,
            NSTextField(labelWithString: "Shareable Lighting Animation Recorder"),
            exportRow,
            NSTextField(labelWithString: "Performance Management, Accessibility & Workspace Mode"),
            adaptivePerfCheck, batteryThrottleCheck, highContrastCheck,
            NSStackView(views: [NSTextField(labelWithString: "Preferred UI Mode:"), uiDefaultPopup]),
            perfTelemetryLbl
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14)
        ])
        item.view = view
        return item
    }

    public func syncFromStores() {
        let s = settingsStore.settings
        let st = stateStore.state
        lightsCheck.state = s.lightsEnabled ? .on : .off
        categorySeg.selectedSegment = (s.lightingCategory == .classic) ? 0 : 1
        speedSlider.doubleValue = s.modernEffects.speed
        brightSlider.doubleValue = s.modernEffects.brightness

        quickScenePopup.removeAllItems()
        quickScenePopup.addItems(withTitles: sceneManager.allScenes.map(\.name))
        if let aid = st.activeSceneID, let idx = sceneManager.allScenes.firstIndex(where: { $0.id == aid }) {
            quickScenePopup.selectItem(at: idx)
        }

        autoEnableCheck.state = st.automation.automationEnabled ? .on : .off
        vacationCheck.state = st.automation.vacationMode ? .on : .off
        quietCheck.state = st.automation.quietHours.enabled ? .on : .off
        autoShutdownCheck.state = st.automation.autoShutdownEnabled ? .on : .off
        solarLatField.stringValue = String(format: "%.4f", st.automation.latitude ?? 64.7511)
        solarLonField.stringValue = String(format: "%.4f", st.automation.longitude ?? -147.3494)

        let eval = SeasonalScheduleService.shared.evaluate(at: Date(), automation: st.automation)
        autoStatusLabel.stringValue = "Rule Now: \(eval.activeRuleName ?? "None active")  •  Target: \(eval.targetSceneID ?? "Current")  •  Quiet: \(eval.isQuietHours ? "Yes" : "No")  •  Shutdown: \(eval.shouldShutdownLights ? "Yes" : "No")"

        interactiveCheck.state = st.interactive.enabled ? .on : .off
        proxGlowCheck.state = st.interactive.mouseProximityGlow ? .on : .off
        rippleCheck.state = st.interactive.mouseRipple ? .on : .off
        sparkleCheck.state = st.interactive.sparkleTrail ? .on : .off
        todCheck.state = st.timeOfDay.enabled ? .on : .off
        weatherEnableCheck.state = st.weatherConfig.enabled ? .on : .off
        if let wIdx = SimulatedWeatherCondition.allCases.firstIndex(of: st.weatherConfig.simulatedOverride) {
            weatherSimPopup.selectItem(at: wIdx)
        }
        weatherNetworkCheck.state = st.weatherConfig.networkWeatherDisclosedAndAllowed ? .on : .off
        screenSyncStatusLbl.stringValue = "Screen Sync: \(ScreenColorSyncService.shared.lastStatusNote)"

        adaptivePerfCheck.state = st.performance.adaptiveManagementEnabled ? .on : .off
        batteryThrottleCheck.state = st.performance.throttleOnBattery ? .on : .off
        highContrastCheck.state = st.performance.highContrastMode ? .on : .off
        uiDefaultPopup.selectItem(at: max(0, min(1, st.uiMode)))

        let tel = PerformanceCoordinator.shared.currentTelemetry(settings: s, policy: st.performance)
        perfTelemetryLbl.stringValue = "Power: \(tel.onBatteryPower ? "Battery" : "AC Adapter")  •  CADENCE: \(tel.summaryText)  •  ReduceMotion: \(tel.reduceMotionActive ? "On" : "Off")"
    }

    // MARK: - Actions

    @objc private func lightingEdited() {
        var s = settingsStore.settings
        s.lightsEnabled = (lightsCheck.state == .on)
        s.lightingCategory = (categorySeg.selectedSegment == 0) ? .classic : .modern
        s.modernEffects.speed = speedSlider.doubleValue
        s.modernEffects.brightness = brightSlider.doubleValue
        settingsStore.settings = s
        onApplyAppSettings?(s)
    }

    @objc private func quickActivateScene() {
        let idx = quickScenePopup.indexOfSelectedItem
        if idx >= 0 && idx < sceneManager.allScenes.count {
            let sc = sceneManager.allScenes[idx]
            _ = sceneManager.activateScene(id: sc.id, settingsStore: settingsStore, applyWallpaper: true)
            onApplyAppSettings?(settingsStore.settings)
            syncFromStores()
        }
    }

    @objc private func openScenes() { onOpenSceneBrowser?() }
    @objc private func openFXStudio() { onOpenEffectStudio?() }
    @objc private func openMIDI() { onOpenMIDIComposer?() }
    @objc private func openLayouts() { onOpenLayoutDesigner?() }
    @objc private func openAPI() { onOpenAPISimulator?() }
    @objc private func openClassicXP() { onOpenClassicSettings?() }

    @objc private func returnClassicDefaults() {
        sceneManager.returnToClassicTwinkleBulbs(settingsStore: settingsStore)
        onApplyAppSettings?(settingsStore.settings)
        syncFromStores()
    }

    @objc private func automationEdited() {
        var st = stateStore.state
        st.automation.automationEnabled = (autoEnableCheck.state == .on)
        st.automation.vacationMode = (vacationCheck.state == .on)
        st.automation.quietHours.enabled = (quietCheck.state == .on)
        st.automation.autoShutdownEnabled = (autoShutdownCheck.state == .on)
        st.automation.latitude = Double(solarLatField.stringValue)
        st.automation.longitude = Double(solarLonField.stringValue)
        stateStore.state = st
        SeasonalScheduleService.shared.evaluateAndScheduleNext(at: Date())
        syncFromStores()
    }

    @objc private func evaluateScheduleNow() {
        SeasonalScheduleService.shared.evaluateAndScheduleNext(at: Date())
        syncFromStores()
    }

    @objc private func clearOverride() {
        SeasonalScheduleService.shared.clearTemporaryManualOverride()
        SeasonalScheduleService.shared.evaluateAndScheduleNext(at: Date())
        syncFromStores()
    }

    @objc private func burstChristmas() { onTriggerCelebration?(.christmas) }
    @objc private func burstNewYear() { onTriggerCelebration?(.newYear) }
    @objc private func burstHalloween() { onTriggerCelebration?(.halloween) }
    @objc private func burstBirthday() { onTriggerCelebration?(.birthday) }

    @objc private func atmosphereEdited() {
        var st = stateStore.state
        st.interactive.enabled = (interactiveCheck.state == .on)
        st.interactive.mouseProximityGlow = (proxGlowCheck.state == .on)
        st.interactive.mouseRipple = (rippleCheck.state == .on)
        st.interactive.sparkleTrail = (sparkleCheck.state == .on)
        st.timeOfDay.enabled = (todCheck.state == .on)
        st.weatherConfig.enabled = (weatherEnableCheck.state == .on)
        st.weatherConfig.simulatedOverride = SimulatedWeatherCondition.allCases[max(0, weatherSimPopup.indexOfSelectedItem)]
        st.weatherConfig.networkWeatherDisclosedAndAllowed = (weatherNetworkCheck.state == .on)
        stateStore.state = st
        if st.weatherConfig.enabled && st.weatherConfig.networkWeatherDisclosedAndAllowed {
            WeatherAtmosphereService.shared.refreshLiveWeatherIfAuthorized()
        }
    }

    @objc private func requestStartScreenSync() {
        let alert = NSAlert()
        alert.messageText = "Enable Privacy-Preserving Screen Color Sync?"
        alert.informativeText = "Re: Twinkle Bulbs samples only a tiny downsampled average color in memory to tint your bulbs. No screenshots or window contents are ever saved, analyzed for text, or uploaded."
        alert.addButton(withTitle: "I Understand — Start Sync")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        var st = stateStore.state
        st.screenSync.privacyNoticeAccepted = true
        st.screenSync.enabled = true
        stateStore.state = st
        _ = ScreenColorSyncService.shared.startSyncIfAuthorized()
        syncFromStores()
    }

    @objc private func stopScreenSyncNow() {
        ScreenColorSyncService.shared.stopSync()
        syncFromStores()
    }

    @objc private func exportThemePack() {
        let sp = NSSavePanel()
        sp.nameFieldStringValue = "Holiday_Theme_Bundle.twinklepack"
        guard sp.runModal() == .OK, let url = sp.url else { return }
        let userScenes = stateStore.state.userScenes.isEmpty ? [sceneManager.allScenes[0]] : stateStore.state.userScenes
        let timelines = stateStore.state.timelines.isEmpty ? EffectTimelineEngine.builtInSampleTimelines() : stateStore.state.timelines
        let layouts = stateStore.state.layouts.isEmpty ? VirtualLightingLayoutEngine.builtInSampleLayouts() : stateStore.state.layouts
        if let packData = try? ThemePackManager.shared.createThemePackArchive(
            packageID: "com.twinklebulbs.pack.\(UUID().uuidString.prefix(6))",
            title: "My Holiday Collection",
            author: NSFullUserName(),
            scenes: userScenes,
            timelines: timelines,
            layouts: layouts
        ) {
            try? packData.write(to: url, options: .atomic)
        }
    }

    @objc private func importThemePack() {
        let op = NSOpenPanel()
        op.canChooseFiles = true
        op.allowedContentTypes = [.zip, UTType(filenameExtension: "twinklepack")].compactMap { $0 }
        guard op.runModal() == .OK, let url = op.url, let data = try? Data(contentsOf: url) else { return }
        do {
            let man = try ThemePackManager.shared.importPackIntoStateStore(data: data, stateStore: stateStore, sceneManager: sceneManager)
            let ok = NSAlert()
            ok.messageText = "Verified & Imported Theme Pack: \(man.title)"
            ok.informativeText = "SHA-256 verified cleanly: \(man.scenes.count) scenes, \(man.timelines.count) timelines, \(man.layouts.count) layouts."
            ok.runModal()
        } catch {
            let err = NSAlert()
            err.alertStyle = .critical
            err.messageText = "Theme Pack Rejected (Security Validation)"
            err.informativeText = error.localizedDescription
            err.runModal()
        }
    }

    @objc private func exportGIF() {
        let sp = NSSavePanel(); sp.nameFieldStringValue = "twinkle_bulbs_show.gif"
        guard sp.runModal() == .OK, let url = sp.url else { return }
        let res = AnimationExportService.shared.renderFrames(settings: settingsStore.settings, fps: 15, durationSeconds: 3.0)
        try? AnimationExportService.shared.exportGIF(images: res.images, fps: 15, to: url)
    }

    @objc private func exportMP4() {
        let sp = NSSavePanel(); sp.nameFieldStringValue = "twinkle_bulbs_show.mp4"
        guard sp.runModal() == .OK, let url = sp.url else { return }
        let res = AnimationExportService.shared.renderFrames(settings: settingsStore.settings, fps: 30, durationSeconds: 3.0)
        try? AnimationExportService.shared.exportMP4(images: res.images, fps: 30, to: url)
    }

    @objc private func exportFramesJSON() {
        let sp = NSSavePanel(); sp.nameFieldStringValue = "twinkle_bulbs_frames.twinkleframes"
        guard sp.runModal() == .OK, let url = sp.url else { return }
        let res = AnimationExportService.shared.renderFrames(settings: settingsStore.settings, fps: 15, durationSeconds: 3.0)
        try? AnimationExportService.shared.exportTwinkleFrames(res.frameData, to: url)
    }

    @objc private func perfEdited() {
        var st = stateStore.state
        st.performance.adaptiveManagementEnabled = (adaptivePerfCheck.state == .on)
        st.performance.throttleOnBattery = (batteryThrottleCheck.state == .on)
        st.performance.highContrastMode = (highContrastCheck.state == .on)
        st.uiMode = uiDefaultPopup.indexOfSelectedItem
        stateStore.state = st
        onApplyAppSettings?(settingsStore.settings)
        syncFromStores()
    }
}
