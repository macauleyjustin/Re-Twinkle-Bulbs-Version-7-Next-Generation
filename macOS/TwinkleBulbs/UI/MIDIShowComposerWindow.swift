import Cocoa
import UniformTypeIdentifiers

// MARK: - MIDI Light Show Composer Window Controller (Part IV)

public final class MIDIShowComposerWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    private let showPopup = NSPopUpButton()
    private let trackPopup = NSPopUpButton()
    private let modePopup = NSPopUpButton()
    private let sensitivitySlider = NSSlider(value: 1.0, minValue: 0.2, maxValue: 2.0, target: nil, action: nil)
    private let audioFallbackCheck = NSButton(checkboxWithTitle: "Allow Internal Buffer Energy Sync for MP3/WAV (No Mic)", target: nil, action: nil)

    private let playStopBtn = NSButton()
    private let clockLabel = NSTextField(labelWithString: "Clock: 0.00s / 0.00s")
    private let cueStatusLabel = NSTextField(labelWithString: "Cue Sync Ready")

    private let previewStrand = TimelineStrandPreviewView()
    private let channelTable = NSTableView()
    private let cueTable = NSTableView()

    private let previewEngine = ModernLightingEngine(seed: 12252026)
    private var uiTimer: Timer?
    private var project: MIDIShowProject
    private let composer: MIDILightShowComposer
    private let stateStore: NextGenStateStore
    private let settingsStore: SettingsStore
    private let audioService: AudioEngineService

    public var onApplyAppSettings: ((AppSettings) -> Void)?

    public init(
        composer: MIDILightShowComposer = .shared,
        stateStore: NextGenStateStore = .shared,
        settingsStore: SettingsStore = .shared,
        audioService: AudioEngineService = .shared
    ) {
        self.composer = composer
        self.stateStore = stateStore
        self.settingsStore = settingsStore
        self.audioService = audioService
        self.project = stateStore.state.midiShows.first ?? composer.activeProject

        let win = NSWindow(
            contentRect: NSRect(x: 150, y: 120, width: 840, height: 570),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Re: Twinkle Bulbs — MIDI Light Show Composer (.twinklemidi)"
        win.minSize = NSSize(width: 740, height: 500)
        win.appearance = NSAppearance(named: .aqua)
        win.isReleasedWhenClosed = false
        super.init(window: win)
        win.delegate = self

        previewEngine.configure(bounds: CGRect(x: 0, y: 0, width: 512, height: 36), settings: settingsStore.settings, nowMs: 0)
        buildUI()
        refreshAllControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showAndStart() {
        refreshAllControls()
        startClockTimer()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        uiTimer?.invalidate()
        uiTimer = nil
    }

    private func buildUI() {
        guard let root = window?.contentView else { return }

        func mkBtn(_ t: String, _ a: Selector) -> NSButton {
            let b = NSButton(title: t, target: self, action: a)
            b.bezelStyle = .rounded
            return b
        }

        showPopup.target = self
        showPopup.action = #selector(selectSavedShow)
        trackPopup.target = self
        trackPopup.action = #selector(trackSelectionChanged)

        modePopup.addItems(withTitles: MIDIReactiveMode.allCases.map(\.displayName))
        modePopup.target = self
        modePopup.action = #selector(modeChanged)

        sensitivitySlider.target = self
        sensitivitySlider.action = #selector(sensitivityChanged)

        audioFallbackCheck.target = self
        audioFallbackCheck.action = #selector(toggleAudioFallback)

        playStopBtn.title = "▶ Play Track + Sync"
        playStopBtn.bezelStyle = .rounded
        playStopBtn.target = self
        playStopBtn.action = #selector(togglePlayback)

        let saveBtn = mkBtn("Save Show", #selector(saveProject))
        let expBtn = mkBtn("Export .twinklemidi...", #selector(exportShowFile))
        let impBtn = mkBtn("Import .twinklemidi...", #selector(importShowFile))
        let activateBtn = mkBtn("Enable MIDI Sync on Desktop", #selector(enableDesktopMIDISync))

        let topRow = NSStackView(views: [
            NSTextField(labelWithString: "Project:"), showPopup,
            saveBtn, expBtn, impBtn, activateBtn
        ])
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.orientation = .horizontal
        topRow.spacing = 6
        root.addSubview(topRow)

        let transportRow = NSStackView(views: [
            NSTextField(labelWithString: "Music:"), trackPopup,
            playStopBtn, clockLabel
        ])
        transportRow.translatesAutoresizingMaskIntoConstraints = false
        transportRow.orientation = .horizontal
        transportRow.spacing = 8
        clockLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        root.addSubview(transportRow)

        let modeRow = NSStackView(views: [
            NSTextField(labelWithString: "Primary MIDI Mode (7):"), modePopup,
            NSTextField(labelWithString: "Sensitivity:"), sensitivitySlider,
            audioFallbackCheck
        ])
        modeRow.translatesAutoresizingMaskIntoConstraints = false
        modeRow.orientation = .horizontal
        modeRow.spacing = 8
        root.addSubview(modeRow)

        previewStrand.translatesAutoresizingMaskIntoConstraints = false
        previewStrand.settings = settingsStore.settings
        root.addSubview(previewStrand)

        // Left: Channel Mapping Table
        let chBox = NSBox()
        chBox.translatesAutoresizingMaskIntoConstraints = false
        chBox.title = "MIDI Channel & Instrument Zone Mappings"
        root.addSubview(chBox)

        let chScroll = NSScrollView()
        chScroll.translatesAutoresizingMaskIntoConstraints = false
        chScroll.hasVerticalScroller = true
        chScroll.borderType = .bezelBorder
        let c1 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ChMap"))
        c1.title = "Channel → Lighting Mode / Zone"
        c1.width = 365
        channelTable.addTableColumn(c1)
        channelTable.dataSource = self
        channelTable.delegate = self
        chScroll.documentView = channelTable
        chBox.contentView?.addSubview(chScroll)

        // Right: Timed Cue Markers Table
        let cueBox = NSBox()
        cueBox.translatesAutoresizingMaskIntoConstraints = false
        cueBox.title = "Music Cue Markers (Sparkle, Chase, Flash)"
        root.addSubview(cueBox)

        let cueScroll = NSScrollView()
        cueScroll.translatesAutoresizingMaskIntoConstraints = false
        cueScroll.hasVerticalScroller = true
        cueScroll.borderType = .bezelBorder
        let c2 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CueCol"))
        c2.title = "Time • Cue Trigger"
        c2.width = 365
        cueTable.addTableColumn(c2)
        cueTable.dataSource = self
        cueTable.delegate = self
        cueScroll.documentView = cueTable
        cueBox.contentView?.addSubview(cueScroll)

        let addCueBtn = mkBtn("+ Add Cue at Current Clock", #selector(addCueAtCurrentClock))
        let delCueBtn = mkBtn("Remove Cue", #selector(removeSelectedCue))
        let cueBtnRow = NSStackView(views: [addCueBtn, delCueBtn, cueStatusLabel])
        cueBtnRow.translatesAutoresizingMaskIntoConstraints = false
        cueBtnRow.orientation = .horizontal
        cueBtnRow.spacing = 6
        cueStatusLabel.textColor = .secondaryLabelColor
        cueStatusLabel.font = NSFont.systemFont(ofSize: 11)
        cueBox.contentView?.addSubview(cueBtnRow)

        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            topRow.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            topRow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),

            transportRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
            transportRow.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            transportRow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),

            modeRow.topAnchor.constraint(equalTo: transportRow.bottomAnchor, constant: 8),
            modeRow.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            modeRow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            sensitivitySlider.widthAnchor.constraint(equalToConstant: 90),

            previewStrand.topAnchor.constraint(equalTo: modeRow.bottomAnchor, constant: 8),
            previewStrand.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            previewStrand.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            previewStrand.heightAnchor.constraint(equalToConstant: 44),

            chBox.topAnchor.constraint(equalTo: previewStrand.bottomAnchor, constant: 8),
            chBox.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            chBox.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            chBox.widthAnchor.constraint(equalTo: root.widthAnchor, multiplier: 0.48, constant: -14),

            chScroll.topAnchor.constraint(equalTo: chBox.contentView!.topAnchor, constant: 6),
            chScroll.leadingAnchor.constraint(equalTo: chBox.contentView!.leadingAnchor, constant: 6),
            chScroll.trailingAnchor.constraint(equalTo: chBox.contentView!.trailingAnchor, constant: -6),
            chScroll.bottomAnchor.constraint(equalTo: chBox.contentView!.bottomAnchor, constant: -6),

            cueBox.topAnchor.constraint(equalTo: previewStrand.bottomAnchor, constant: 8),
            cueBox.leadingAnchor.constraint(equalTo: chBox.trailingAnchor, constant: 8),
            cueBox.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            cueBox.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),

            cueScroll.topAnchor.constraint(equalTo: cueBox.contentView!.topAnchor, constant: 6),
            cueScroll.leadingAnchor.constraint(equalTo: cueBox.contentView!.leadingAnchor, constant: 6),
            cueScroll.trailingAnchor.constraint(equalTo: cueBox.contentView!.trailingAnchor, constant: -6),
            cueScroll.bottomAnchor.constraint(equalTo: cueBtnRow.topAnchor, constant: -6),

            cueBtnRow.leadingAnchor.constraint(equalTo: cueBox.contentView!.leadingAnchor, constant: 6),
            cueBtnRow.trailingAnchor.constraint(equalTo: cueBox.contentView!.trailingAnchor, constant: -6),
            cueBtnRow.bottomAnchor.constraint(equalTo: cueBox.contentView!.bottomAnchor, constant: -6)
        ])
    }

    private func refreshAllControls() {
        var shows = [composer.activeProject]
        for s in stateStore.state.midiShows where !shows.contains(where: { $0.id == s.id }) {
            shows.append(s)
        }
        showPopup.removeAllItems()
        showPopup.addItems(withTitles: shows.map(\.name))

        trackPopup.removeAllItems()
        trackPopup.addItems(withTitles: audioService.tracks.map(\.title))
        if let idx = audioService.tracks.firstIndex(where: { $0.id == project.musicTrackID }) {
            trackPopup.selectItem(at: idx)
        }

        let mode = settingsStore.settings.modernEffects.midiReactiveMode
        if let mIdx = MIDIReactiveMode.allCases.firstIndex(of: mode) {
            modePopup.selectItem(at: mIdx)
        }
        sensitivitySlider.doubleValue = settingsStore.settings.modernEffects.midiSensitivity
        audioFallbackCheck.state = project.audioReactiveFallbackEnabled ? .on : .off
        composer.setActiveProject(project)
        channelTable.reloadData()
        cueTable.reloadData()
    }

    private func startClockTimer() {
        uiTimer?.invalidate()
        uiTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.stepClockTick()
        }
    }

    private func stepClockTick() {
        let info = audioService.currentPlaybackClockAndEnergy()
        clockLabel.stringValue = String(format: "Clock: %.2fs / %.2fs", info.positionSeconds, info.durationSeconds)
        playStopBtn.title = audioService.isPlaying ? "⏸ Pause Track" : "▶ Play Track + Sync"

        let fired = composer.synchronizeWithAudioClock(positionSeconds: info.positionSeconds)
        if let lastCue = fired.last {
            cueStatusLabel.stringValue = "Cue Fired: \(lastCue.label) @ \(String(format: "%.2fs", lastCue.timeSeconds))"
        }
        composer.applyAudioBufferEnergyIfEnabled(energyLevel: info.energyLevel, isAudioFilePlayback: info.isAudioFilePlayback, to: previewEngine)

        var s = settingsStore.settings
        s.lightingCategory = .modern
        s.modernEffects.midiReactiveEnabled = true
        previewEngine.updateConfigOnly(s.modernEffects)
        previewEngine.stepDeterministic(dt: 1.0 / 30.0)
        previewStrand.settings = s
        previewStrand.currentStates = previewEngine.states
    }

    // MARK: - Table Views

    public func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === channelTable { return project.channelMappings.count }
        return project.cueMarkers.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let text: String
        if tableView === channelTable {
            let m = project.channelMappings[row]
            text = "\(m.label)  [\(m.mode.displayName) → Zone: \(m.targetZoneID)]"
        } else {
            let c = project.cueMarkers[row]
            text = String(format: "%.2fs  •  %@  (%@)", c.timeSeconds, c.label, c.effectTrigger.rawValue)
        }
        let lbl = NSTextField(labelWithString: text)
        lbl.font = NSFont.systemFont(ofSize: 11.5)
        return lbl
    }

    // MARK: - Actions

    @objc private func selectSavedShow() {
        var shows = [composer.activeProject]
        for s in stateStore.state.midiShows where !shows.contains(where: { $0.id == s.id }) {
            shows.append(s)
        }
        let idx = showPopup.indexOfSelectedItem
        if idx >= 0 && idx < shows.count {
            project = shows[idx]
            refreshAllControls()
        }
    }

    @objc private func trackSelectionChanged() {
        let idx = trackPopup.indexOfSelectedItem
        if idx >= 0 && idx < audioService.tracks.count {
            project.musicTrackID = audioService.tracks[idx].id
        }
    }

    @objc private func modeChanged() {
        let idx = max(0, modePopup.indexOfSelectedItem)
        var s = settingsStore.settings
        s.lightingCategory = .modern
        s.modernEffects.midiReactiveEnabled = true
        s.modernEffects.midiReactiveMode = MIDIReactiveMode.allCases[idx]
        settingsStore.settings = s
        onApplyAppSettings?(s)
    }

    @objc private func sensitivityChanged() {
        var s = settingsStore.settings
        s.modernEffects.midiSensitivity = sensitivitySlider.doubleValue
        settingsStore.settings = s
        onApplyAppSettings?(s)
    }

    @objc private func toggleAudioFallback() {
        project.audioReactiveFallbackEnabled = (audioFallbackCheck.state == .on)
        composer.setActiveProject(project)
    }

    @objc private func togglePlayback() {
        if audioService.isPlaying {
            audioService.pause()
        } else {
            let idx = max(0, trackPopup.indexOfSelectedItem)
            audioService.play(trackIndex: idx, settings: settingsStore.settings)
            composer.resetSyncState()
        }
    }

    @objc private func addCueAtCurrentClock() {
        let nowSec = audioService.currentPlaybackClockAndEnergy().positionSeconds
        let cue = MIDICueMarker(
            timeSeconds: nowSec,
            label: "Burst Cue @ \(String(format: "%.1fs", nowSec))",
            effectTrigger: .triggerSparkleBurst
        )
        project.cueMarkers.append(cue)
        project.cueMarkers.sort { $0.timeSeconds < $1.timeSeconds }
        composer.setActiveProject(project)
        cueTable.reloadData()
    }

    @objc private func removeSelectedCue() {
        let r = cueTable.selectedRow
        guard r >= 0 && r < project.cueMarkers.count else { return }
        project.cueMarkers.remove(at: r)
        composer.setActiveProject(project)
        cueTable.reloadData()
    }

    @objc private func saveProject() {
        composer.setActiveProject(project)
        var next = stateStore.state
        if let idx = next.midiShows.firstIndex(where: { $0.id == project.id }) {
            next.midiShows[idx] = project
        } else {
            next.midiShows.append(project)
        }
        next.activeMIDIShowID = project.id
        stateStore.state = next
    }

    @objc private func exportShowFile() {
        guard let data = try? MIDILightShowComposer.exportShow(project) else { return }
        let sp = NSSavePanel()
        sp.nameFieldStringValue = "\(project.name.replacingOccurrences(of: " ", with: "_")).twinklemidi"
        if sp.runModal() == .OK, let url = sp.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    @objc private func importShowFile() {
        let op = NSOpenPanel()
        op.canChooseFiles = true
        op.allowedContentTypes = [.json, UTType(filenameExtension: "twinklemidi")].compactMap { $0 }
        if op.runModal() == .OK, let url = op.url, let data = try? Data(contentsOf: url),
           let imported = try? MIDILightShowComposer.importShow(data: data) {
            project = imported
            saveProject()
            refreshAllControls()
        }
    }

    @objc private func enableDesktopMIDISync() {
        var s = settingsStore.settings
        s.lightsEnabled = true
        s.lightingCategory = .modern
        s.modernEffects.midiReactiveEnabled = true
        settingsStore.settings = s
        saveProject()
        onApplyAppSettings?(s)
    }
}
