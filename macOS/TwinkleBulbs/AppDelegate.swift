import Cocoa

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore.shared
    private let overlayController = OverlayWindowController()
    private let screenSaverController = ScreenSaverWindowController()
    private var statusBarController: StatusBarController?

    private lazy var prefsController = PreferencesWindowController()
    private lazy var modernWorkspaceController = ModernWorkspaceWindowController()
    private lazy var sceneBrowserController = SceneBrowserWindowController()
    private lazy var effectStudioController = LightingEffectStudioWindowController()
    private lazy var midiComposerController = MIDIShowComposerWindowController()
    private lazy var layoutDesignerController = VirtualLayoutDesignerWindowController()
    private lazy var apiSimulatorController = VirtualControllerSimulatorWindowController()
    private lazy var quickAccessController = QuickAccessPanelController()
    private lazy var tipsController = TipOfTheDayWindowController()
    private lazy var aboutController = AboutWindowController()
    private lazy var documentationController = DocumentationWindowController()
    private lazy var calendarController = CalendarViewerController()
    private lazy var adventController = AdventCalendarWindowController()
    private var wallpaperRotationTimer: Timer?

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Check startup modifier keys cleanly matching v6.0 specification
        let mods = NSEvent.modifierFlags
        if mods.contains(.option) {
            settingsStore.resetToDefaults()
        }
        var current = settingsStore.settings
        if mods.contains(.shift) {
            current.musicEnabled = false
            current.soundFX = false
        }

        // Set application menu for keyboard shortcuts (Cmd+Q / Cmd+W)
        configureApplicationMenu()

        // Initialize status bar tray icon & actions
        let status = StatusBarController()
        status.onOpenSettings = { [weak self] in self?.openSettings() }
        status.onOpenModernWorkspace = { [weak self] in self?.openModernWorkspace() }
        status.onOpenSceneBrowser = { [weak self] in self?.openSceneBrowser() }
        status.onOpenEffectStudio = { [weak self] in self?.openEffectStudio() }
        status.onOpenMIDIComposer = { [weak self] in self?.openMIDIComposer() }
        status.onOpenLayoutDesigner = { [weak self] in self?.openLayoutDesigner() }
        status.onOpenAPISimulator = { [weak self] in self?.openAPISimulator() }
        status.onActivateScene = { [weak self] id in self?.activateScene(id: id) }
        status.onTriggerCelebration = { [weak self] preset in self?.triggerCelebration(preset) }
        status.onToggleLights = { [weak self] in self?.toggleLights() }
        status.onToggleMusic = { [weak self] in self?.toggleMusic() }
        status.onTogglePauseMusic = { [weak self] in self?.togglePauseMusic() }
        status.onPreviousMusic = { [weak self] in self?.previousMusic() }
        status.onNextMusic = { [weak self] in self?.nextMusic() }
        status.onStartScreenSaver = { [weak self] in self?.startScreenSaver() }
        status.onOpenCalendar = { [weak self] in self?.openCalendar() }
        status.onOpenAdventCalendar = { [weak self] in self?.openAdventCalendar() }
        status.onOpenTips = { [weak self] in self?.openTips() }
        status.onOpenAbout = { [weak self] in self?.openAbout() }
        status.onOpenDocumentation = { [weak self] in self?.openDocumentation() }
        status.onToggleQuickAccess = { [weak self] in self?.toggleQuickAccess() }
        aboutController.onOpenHistoryAndManual = { [weak self] in self?.openDocumentation(tabIndex: 0) }
        status.onExitRequested = { [weak self] in self?.requestExit() }
        self.statusBarController = status

        // Bind controllers
        overlayController.onTraySyncTick = { [weak self] isLit in
            guard let self else { return }
            self.statusBarController?.updateIcon(lit: isLit, settings: self.settingsStore.settings)
        }
        AudioEngineService.shared.onMIDINoteEvent = { [weak self] evt in
            self?.overlayController.handleMIDIEvent(evt)
        }

        screenSaverController.onActiveStateChanged = { [weak self] active in
            guard let self else { return }
            self.overlayController.isPausedForScreenSaver = active
            AudioEngineService.shared.syncWithSettings(self.settingsStore.settings, isScreenSaverActive: active)
        }

        prefsController.onApplySettings = { [weak self] updated in
            self?.applyAllSettings(updated)
        }
        prefsController.onStartScreenSaverNow = { [weak self] in
            self?.startScreenSaver()
        }
        prefsController.onOpenCalendarViewer = { [weak self] in
            self?.openCalendar()
        }
        prefsController.onOpenAdventCalendar = { [weak self] in
            self?.openAdventCalendar()
        }

        quickAccessController.onOpenSettings = { [weak self] in self?.openSettings() }
        quickAccessController.onStartSaver = { [weak self] in self?.startScreenSaver() }
        quickAccessController.onSettingsChanged = { [weak self] s in self?.applyAllSettings(s) }

        wireNextGenControllers()

        // Apply active configuration
        applyAllSettings(current)

        if current.splashScreen && !current.runSSOnly {
            SplashWindowController.showBriefly()
        }
        if current.showTipsOnStartup && !current.runSSOnly {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.openTips()
            }
        }
        if current.startupOptions {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.openSettings()
            }
        }
        if current.startupCalendar {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openCalendar()
            }
        }
        if current.eventMsgs {
            let todayEvents = CalendarService.shared.matchingEvents(settings: current)
            if let first = todayEvents.first {
                AudioEngineService.shared.playEffect(.celebrate, enabled: current.soundFX)
                let alert = NSAlert()
                alert.messageText = first.title
                alert.informativeText = first.message
                alert.runModal()
            }
        }

        if ProcessInfo.processInfo.arguments.contains("--open-settings") {
            openSettings()
        }
        if ProcessInfo.processInfo.arguments.contains("--open-remote") {
            openAPISimulator()
        }
        if ProcessInfo.processInfo.arguments.contains("--smoke-screensaver") {
            let modules = ScreenSaverModuleID.allCases
            func runNextModule(_ idx: Int) {
                guard idx < modules.count else { return }
                var s = self.settingsStore.settings
                s.ssModule = modules[idx]
                s.ssLights = true
                s.ssEnableMsg = true
                self.screenSaverController.startScreenSaver(settings: s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    guard let self else { return }
                    self.screenSaverController.stopScreenSaver()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        runNextModule(idx + 1)
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                runNextModule(0)
            }
        }
    }

    func applyAllSettings(_ s: AppSettings) {
        BulbArtworkRegistry.shared.reloadAllSets(
            size: s.bulbSize.pixels,
            highlightHex: s.sysColorHighlight ? "#000080" : s.highlightColorHex
        )
        overlayController.applySettings(s)
        screenSaverController.configureMonitoring(settings: s)
        AudioEngineService.shared.syncWithSettings(s, isScreenSaverActive: screenSaverController.isActive)
        statusBarController?.updateIcon(lit: true, settings: s)
        statusBarController?.rebuildMenu(settings: s)

        if s.quickAccess {
            quickAccessController.refresh()
            quickAccessController.showWindow(nil)
        } else {
            quickAccessController.window?.orderOut(nil)
        }

        scheduleWallpaperRotationIfNeeded(s)
    }

    private func scheduleWallpaperRotationIfNeeded(_ s: AppSettings) {
        wallpaperRotationTimer?.invalidate()
        wallpaperRotationTimer = nil
        guard s.wallpaperChangeFlag, s.wallpaperChangeFreqMinutes > 0 else { return }
        wallpaperRotationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(s.wallpaperChangeFreqMinutes * 60), repeats: true) { [weak self] _ in
            guard let self else { return }
            let list = WallpaperService.shared.items
            guard !list.isEmpty else { return }
            var next = self.settingsStore.settings
            if next.wallpaperChangeOrder == 1 {
                next.activeWallpaperID = (list.randomElement() ?? list[0]).id
            } else {
                let idx = list.firstIndex(where: { $0.id == next.activeWallpaperID }) ?? 0
                next.activeWallpaperID = list[(idx + 1) % list.count].id
            }
            self.settingsStore.settings = next
            _ = WallpaperService.shared.applyWallpaper(id: next.activeWallpaperID, style: next.wallpaperType)
        }
    }

    // MARK: - User Actions

    private func openSettings() {
        if NextGenStateStore.shared.state.uiMode == 1 {
            modernWorkspaceController.showAndReload()
        } else {
            prefsController.showAndReload()
        }
    }

    private func openModernWorkspace() {
        modernWorkspaceController.showAndReload()
    }

    private func openSceneBrowser() {
        sceneBrowserController.showAndReload()
    }

    private func openEffectStudio() {
        effectStudioController.showAndStartPreview()
    }

    private func openMIDIComposer() {
        midiComposerController.showAndStart()
    }

    private func openLayoutDesigner() {
        layoutDesignerController.showAndPreview()
    }

    private func openAPISimulator() {
        apiSimulatorController.showAndRefresh()
    }

    private func activateScene(id: String) {
        _ = HolidaySceneManager.shared.activateScene(id: id, settingsStore: settingsStore, applyWallpaper: true)
        applyAllSettings(settingsStore.settings)
    }

    private func triggerCelebration(_ preset: CelebrationEffectPreset) {
        overlayController.triggerCelebration(preset)
        if settingsStore.settings.soundFX {
            AudioEngineService.shared.playEffect(.celebrate, enabled: true)
        }
    }

    private func wireNextGenControllers() {
        HolidaySceneManager.shared.onApplyAppSettings = { [weak self] s in
            self?.applyAllSettings(s)
        }
        sceneBrowserController.onApplyAppSettings = { [weak self] s in
            self?.applyAllSettings(s)
        }
        effectStudioController.onApplyTimelineToDesktop = { [weak self] doc in
            self?.overlayController.setActiveTimelineDocument(doc)
        }
        midiComposerController.onApplyAppSettings = { [weak self] s in
            self?.applyAllSettings(s)
        }

        modernWorkspaceController.onApplyAppSettings = { [weak self] s in self?.applyAllSettings(s) }
        modernWorkspaceController.onOpenClassicSettings = { [weak self] in self?.prefsController.showAndReload() }
        modernWorkspaceController.onOpenSceneBrowser = { [weak self] in self?.openSceneBrowser() }
        modernWorkspaceController.onOpenEffectStudio = { [weak self] in self?.openEffectStudio() }
        modernWorkspaceController.onOpenMIDIComposer = { [weak self] in self?.openMIDIComposer() }
        modernWorkspaceController.onOpenLayoutDesigner = { [weak self] in self?.openLayoutDesigner() }
        modernWorkspaceController.onOpenAPISimulator = { [weak self] in self?.openAPISimulator() }
        modernWorkspaceController.onTriggerCelebration = { [weak self] p in self?.triggerCelebration(p) }

        // Seasonal Automation & Celebration Wiring
        SeasonalScheduleService.shared.onSceneTriggered = { [weak self] sceneID in
            guard let self else { return }
            _ = HolidaySceneManager.shared.activateScene(id: sceneID, settingsStore: self.settingsStore, applyWallpaper: true)
            self.applyAllSettings(self.settingsStore.settings)
        }
        SeasonalScheduleService.shared.onShutdownStateChanged = { [weak self] shouldShutdown in
            guard let self else { return }
            var s = self.settingsStore.settings
            s.lightsEnabled = !shouldShutdown
            self.settingsStore.settings = s
            self.applyAllSettings(s)
        }
        SeasonalScheduleService.shared.onQuietHoursChanged = { [weak self] isQuiet, brightMult, muteMusic in
            guard let self else { return }
            self.overlayController.scheduleBrightnessMultiplier = brightMult
            if isQuiet && muteMusic && AudioEngineService.shared.isPlaying {
                AudioEngineService.shared.pause()
            }
        }
        SeasonalScheduleService.shared.onCelebrationTriggered = { [weak self] evt in
            guard let self else { return }
            let preset = CelebrationEffectPreset.allCases.first { $0.rawValue.lowercased().contains(evt.celebrationKind.lowercased()) } ?? .christmas
            self.triggerCelebration(preset)
        }
        SeasonalScheduleService.shared.startObservingSystemEvents()

        // Developer API & Phone Remote Callbacks
        TwinkleLightingAPIService.shared.onApplyAppSettings = { [weak self] s in
            self?.applyAllSettings(s)
        }
        TwinkleLightingAPIService.shared.onStartScreenSaver = { [weak self] in
            self?.startScreenSaver()
        }
        TwinkleLightingAPIService.shared.onStopScreenSaver = { [weak self] in
            self?.screenSaverController.stopScreenSaver()
        }
        TwinkleLightingAPIService.shared.isScreenSaverActiveProvider = { [weak self] in
            self?.screenSaverController.isActive ?? false
        }
        TwinkleLightingAPIService.shared.onSetTimelineID = { [weak self] tid in
            guard let self else { return }
            if let tid {
                var docs = EffectTimelineEngine.builtInSampleTimelines()
                for t in NextGenStateStore.shared.state.timelines where !docs.contains(where: { $0.id == t.id }) { docs.append(t) }
                self.overlayController.setActiveTimelineDocument(docs.first(where: { $0.id == tid }))
            } else {
                self.overlayController.setActiveTimelineDocument(nil)
            }
        }
        TwinkleLightingAPIService.shared.onTriggerCelebration = { [weak self] raw in
            let p = CelebrationEffectPreset.allCases.first { $0.rawValue.lowercased().contains(raw.lowercased()) } ?? .christmas
            self?.triggerCelebration(p)
        }
        TwinkleLightingAPIService.shared.startIfConfigured()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        TwinkleLightingAPIService.shared.stop()
        ScreenColorSyncService.shared.stopSync()
        SeasonalScheduleService.shared.stop()
    }

    private func toggleLights() {
        var s = settingsStore.settings
        s.lightsEnabled.toggle()
        settingsStore.settings = s
        AudioEngineService.shared.playEffect(.click, enabled: s.soundFX)
        applyAllSettings(s)
    }

    private func toggleMusic() {
        let s = settingsStore.settings
        AudioEngineService.shared.togglePlayStop(settings: s)
        statusBarController?.rebuildMenu(settings: s)
        quickAccessController.refresh()
    }

    private func togglePauseMusic() {
        let s = settingsStore.settings
        AudioEngineService.shared.togglePause(settings: s)
        statusBarController?.rebuildMenu(settings: s)
        quickAccessController.refresh()
    }

    private func previousMusic() {
        let s = settingsStore.settings
        AudioEngineService.shared.playPrevious(settings: s)
        statusBarController?.rebuildMenu(settings: s)
        quickAccessController.refresh()
    }

    private func nextMusic() {
        let s = settingsStore.settings
        AudioEngineService.shared.playNext(settings: s)
        statusBarController?.rebuildMenu(settings: s)
        quickAccessController.refresh()
    }

    private func startScreenSaver() {
        screenSaverController.startScreenSaver(settings: settingsStore.settings)
    }

    private func openCalendar() {
        calendarController.refresh()
        calendarController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openAdventCalendar() {
        adventController.refresh()
        adventController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openTips() {
        tipsController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openAbout() {
        aboutController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openDocumentation(tabIndex: Int = 0) {
        documentationController.showDocumentation(tabIndex: tabIndex)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func toggleQuickAccess() {
        var s = settingsStore.settings
        s.quickAccess.toggle()
        settingsStore.settings = s
        applyAllSettings(s)
    }

    private func requestExit() {
        let s = settingsStore.settings
        if s.confirmExit {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Re: Twinkle Bulbs"
            alert.informativeText = "Exit Re: Twinkle Bulbs?"
            alert.addButton(withTitle: "Exit")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() != .alertFirstButtonReturn {
                return
            }
        }
        NSApp.terminate(nil)
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let sub = NSMenu()
        sub.addItem(withTitle: "About Re: Twinkle Bulbs", action: #selector(menuAbout), keyEquivalent: "")
        sub.addItem(.separator())
        sub.addItem(withTitle: "Settings...", action: #selector(menuSettings), keyEquivalent: ",")
        sub.addItem(.separator())
        sub.addItem(withTitle: "Quit Re: Twinkle Bulbs", action: #selector(menuQuit), keyEquivalent: "q")
        appItem.submenu = sub
        NSApp.mainMenu = mainMenu
    }

    @objc private func menuAbout() { openAbout() }
    @objc private func menuSettings() { openSettings() }
    @objc private func menuQuit() { requestExit() }
}
