import Cocoa
import UniformTypeIdentifiers

// MARK: - Part I: Holiday Scene Browser & Manager Window

public final class SceneBrowserWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSWindowDelegate {
    private let seasonPopup = NSPopUpButton()
    private let favoritesOnlyCheck = NSButton(checkboxWithTitle: "Favorites Only", target: nil, action: nil)
    private let searchField = NSSearchField()
    private let tableView = NSTableView()

    private let titleLabel = NSTextField(labelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")
    private let detailsLabel = NSTextField(wrappingLabelWithString: "")
    private let bulbPreview = BulbSetPreviewView()
    private let flashPreview = FlashingModePreviewView()

    private let previewBtn = NSButton()
    private let activateBtn = NSButton()
    private let favoriteBtn = NSButton()
    private let saveCurrentBtn = NSButton()
    private let duplicateBtn = NSButton()
    private let renameBtn = NSButton()
    private let deleteBtn = NSButton()
    private let exportBtn = NSButton()
    private let importBtn = NSButton()
    private let restorePrevBtn = NSButton()
    private let returnClassicBtn = NSButton()

    private let sceneManager: HolidaySceneManager
    private let stateStore: NextGenStateStore
    private let settingsStore: SettingsStore

    private var filteredScenes: [HolidayScene] = []
    private var selectedScene: HolidayScene?
    private var previewBaselineSettings: AppSettings?

    public var onApplyAppSettings: ((AppSettings) -> Void)?

    public init(
        sceneManager: HolidaySceneManager = .shared,
        stateStore: NextGenStateStore = .shared,
        settingsStore: SettingsStore = .shared
    ) {
        self.sceneManager = sceneManager
        self.stateStore = stateStore
        self.settingsStore = settingsStore

        let win = NSWindow(
            contentRect: NSRect(x: 160, y: 120, width: 820, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Re: Twinkle Bulbs — Holiday Scenes Browser"
        win.minSize = NSSize(width: 720, height: 480)
        win.appearance = NSAppearance(named: .aqua)
        win.isReleasedWhenClosed = false
        super.init(window: win)
        win.delegate = self
        buildUI()
        reloadScenes(selectID: stateStore.state.activeSceneID ?? sceneManager.allScenes.first?.id)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showAndReload() {
        reloadScenes(selectID: stateStore.state.activeSceneID ?? selectedScene?.id ?? sceneManager.allScenes.first?.id)
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let root = window?.contentView else { return }

        let topBar = NSView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(topBar)

        let filterLbl = NSTextField(labelWithString: "Season:")
        filterLbl.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        seasonPopup.addItems(withTitles: SceneSeasonCategory.allCases.map(\.rawValue))
        seasonPopup.target = self
        seasonPopup.action = #selector(filterChanged)

        favoritesOnlyCheck.target = self
        favoritesOnlyCheck.action = #selector(filterChanged)

        searchField.placeholderString = "Search scenes, bulbs, music..."
        searchField.delegate = self
        searchField.setAccessibilityLabel("Search holiday scenes")

        let filterStack = NSStackView(views: [filterLbl, seasonPopup, favoritesOnlyCheck, searchField])
        filterStack.translatesAutoresizingMaskIntoConstraints = false
        filterStack.orientation = .horizontal
        filterStack.spacing = 10
        topBar.addSubview(filterStack)

        let splitScroll = NSScrollView()
        splitScroll.translatesAutoresizingMaskIntoConstraints = false
        splitScroll.hasVerticalScroller = true
        splitScroll.borderType = .bezelBorder

        let colName = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SceneCol"))
        colName.title = "Holiday Scenes (Built-In & Custom)"
        colName.width = 285
        tableView.addTableColumn(colName)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 36
        tableView.doubleAction = #selector(activateSelected)
        tableView.target = self
        tableView.setAccessibilityLabel("Holiday Scenes List")
        splitScroll.documentView = tableView
        root.addSubview(splitScroll)

        let inspector = NSBox()
        inspector.translatesAutoresizingMaskIntoConstraints = false
        inspector.boxType = .primary
        inspector.title = "Scene Inspector & Live Preview"
        root.addSubview(inspector)

        let inspContent = NSView()
        inspContent.translatesAutoresizingMaskIntoConstraints = false
        inspector.contentView?.addSubview(inspContent)

        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        metaLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        metaLabel.textColor = .secondaryLabelColor
        detailsLabel.font = NSFont.systemFont(ofSize: 11.5)
        detailsLabel.maximumNumberOfLines = 6

        bulbPreview.translatesAutoresizingMaskIntoConstraints = false
        flashPreview.translatesAutoresizingMaskIntoConstraints = false

        func cfg(_ btn: NSButton, _ title: String, _ act: Selector, key: String = "") {
            btn.title = title
            btn.bezelStyle = .rounded
            btn.target = self
            btn.action = act
            btn.keyEquivalent = key
        }
        cfg(activateBtn, "Activate Scene", #selector(activateSelected), key: "\r")
        cfg(previewBtn, "Preview on Desktop", #selector(toggleLiveDesktopPreview))
        cfg(favoriteBtn, "★ Favorite", #selector(toggleFavoriteSelected))
        cfg(saveCurrentBtn, "Save Current...", #selector(saveCurrentAsScene))
        cfg(duplicateBtn, "Duplicate", #selector(duplicateSelected))
        cfg(renameBtn, "Rename...", #selector(renameSelected))
        cfg(deleteBtn, "Delete", #selector(deleteSelected))
        cfg(exportBtn, "Export...", #selector(exportSelected))
        cfg(importBtn, "Import...", #selector(importSceneFromFile))
        cfg(restorePrevBtn, "Restore Previous Scene", #selector(restorePreviousScene))
        cfg(returnClassicBtn, "Return to Classic Twinkle Bulbs", #selector(returnToClassic))

        let row1 = NSStackView(views: [activateBtn, previewBtn, favoriteBtn])
        row1.orientation = .horizontal
        row1.spacing = 8

        let row2 = NSStackView(views: [saveCurrentBtn, duplicateBtn, renameBtn, deleteBtn])
        row2.orientation = .horizontal
        row2.spacing = 6

        let row3 = NSStackView(views: [exportBtn, importBtn, restorePrevBtn])
        row3.orientation = .horizontal
        row3.spacing = 6

        let row4 = NSStackView(views: [returnClassicBtn])
        row4.orientation = .horizontal

        let vStack = NSStackView(views: [
            titleLabel, metaLabel, detailsLabel,
            bulbPreview, flashPreview,
            row1, row2, row3, row4
        ])
        vStack.translatesAutoresizingMaskIntoConstraints = false
        vStack.orientation = .vertical
        vStack.alignment = .leading
        vStack.spacing = 10
        inspContent.addSubview(vStack)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            topBar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            topBar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            topBar.heightAnchor.constraint(equalToConstant: 28),

            filterStack.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            filterStack.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            filterStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),

            splitScroll.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 10),
            splitScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            splitScroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),
            splitScroll.widthAnchor.constraint(equalToConstant: 300),

            inspector.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 10),
            inspector.leadingAnchor.constraint(equalTo: splitScroll.trailingAnchor, constant: 12),
            inspector.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            inspector.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),

            inspContent.topAnchor.constraint(equalTo: inspector.contentView!.topAnchor, constant: 10),
            inspContent.leadingAnchor.constraint(equalTo: inspector.contentView!.leadingAnchor, constant: 12),
            inspContent.trailingAnchor.constraint(equalTo: inspector.contentView!.trailingAnchor, constant: -12),
            inspContent.bottomAnchor.constraint(equalTo: inspector.contentView!.bottomAnchor, constant: -10),

            vStack.topAnchor.constraint(equalTo: inspContent.topAnchor),
            vStack.leadingAnchor.constraint(equalTo: inspContent.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: inspContent.trailingAnchor),

            bulbPreview.widthAnchor.constraint(equalTo: vStack.widthAnchor),
            bulbPreview.heightAnchor.constraint(equalToConstant: 50),
            flashPreview.widthAnchor.constraint(equalTo: vStack.widthAnchor),
            flashPreview.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    public func reloadScenes(selectID: String? = nil) {
        let seasonIdx = max(0, seasonPopup.indexOfSelectedItem)
        let selectedSeason = SceneSeasonCategory.allCases[seasonIdx]
        let favOnly = favoritesOnlyCheck.state == .on
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        filteredScenes = sceneManager.allScenes.filter { sc in
            if selectedSeason != .all && sc.season != selectedSeason { return false }
            if favOnly && !sc.isFavorite { return false }
            if !query.isEmpty {
                let hay = "\(sc.name) \(sc.subtitle) \(sc.season.rawValue) \(sc.bulbSetName)".lowercased()
                if !hay.contains(query) { return false }
            }
            return true
        }
        tableView.reloadData()

        if let targetID = selectID, let idx = filteredScenes.firstIndex(where: { $0.id == targetID }) {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            tableView.scrollRowToVisible(idx)
            updateInspector(for: filteredScenes[idx])
        } else if let first = filteredScenes.first {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            updateInspector(for: first)
        } else {
            selectedScene = nil
            updateInspector(for: nil)
        }
    }

    private func updateInspector(for sc: HolidayScene?) {
        selectedScene = sc
        restorePrevBtn.isEnabled = (stateStore.state.previousSnapshot != nil)

        guard let sc else {
            titleLabel.stringValue = "No Scene Selected"
            metaLabel.stringValue = ""
            detailsLabel.stringValue = "Choose a Holiday Scene from the list or clear filters."
            flashPreview.stopPreview()
            for btn in [activateBtn, previewBtn, favoriteBtn, duplicateBtn, renameBtn, deleteBtn, exportBtn] {
                btn.isEnabled = false
            }
            return
        }

        let activeBadge = (stateStore.state.activeSceneID == sc.id) ? " [ACTIVE]" : ""
        titleLabel.stringValue = "\(sc.isFavorite ? "★ " : "")\(sc.name)\(activeBadge)"
        metaLabel.stringValue = "Season: \(sc.season.rawValue)  •  \(sc.isBuiltIn ? "Built-In Preset" : "User Custom Scene")  •  Engine: \(sc.lightingCategory == .classic ? "Classic v6.0" : "Modern 60fps")"

        let musicText = sc.preferredTrackIDs.isEmpty ? "Current Playlist" : "\(sc.preferredTrackIDs.count) Curated Carol(s)"
        let effectDesc = sc.lightingCategory == .classic ? sc.flashMode.displayName : sc.modernEffects.effect.displayName
        detailsLabel.stringValue = """
        \(sc.subtitle)

        • Bulbs: \(sc.bulbSetName) (\(sc.bulbSize.displayName))
        • Animation: \(effectDesc) • Brightness: \(Int(sc.modernEffects.brightness * sc.brightnessMultiplier * 100))% • Speed: \(String(format: "%.2gx", sc.modernEffects.speed))
        • Screensaver: \(sc.ssModule.displayName) • Wallpaper: \(sc.activeWallpaperID)
        • Music: \(musicText)\(sc.musicEnabled ? " (Auto-Play)" : " (Muted/Optional)")
        """

        let previewAppSettings = sceneManager.applySceneConfiguration(sc, to: settingsStore.settings)
        bulbPreview.settings = previewAppSettings
        flashPreview.configure(with: previewAppSettings)

        activateBtn.isEnabled = true
        previewBtn.isEnabled = true
        favoriteBtn.isEnabled = true
        favoriteBtn.title = sc.isFavorite ? "★ Unfavorite" : "☆ Favorite"
        duplicateBtn.isEnabled = true
        renameBtn.isEnabled = !sc.isBuiltIn
        deleteBtn.isEnabled = !sc.isBuiltIn
        exportBtn.isEnabled = true
    }

    // MARK: - NSTableViewDataSource & Delegate

    public func numberOfRows(in tableView: NSTableView) -> Int {
        filteredScenes.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < filteredScenes.count else { return nil }
        let sc = filteredScenes[row]
        let cell = NSTableCellView()
        let activeMark = (stateStore.state.activeSceneID == sc.id) ? " ●" : ""
        let star = sc.isFavorite ? "★ " : ""
        let lbl = NSTextField(labelWithString: "\(star)\(sc.name)\(activeMark)\n\(sc.season.rawValue) • \(sc.isBuiltIn ? "Built-In" : "Custom")")
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.maximumNumberOfLines = 2
        lbl.font = NSFont.systemFont(ofSize: 11.5)
        cell.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            lbl.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            lbl.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        let r = tableView.selectedRow
        if r >= 0 && r < filteredScenes.count {
            updateInspector(for: filteredScenes[r])
        }
    }

    public func controlTextDidChange(_ obj: Notification) {
        reloadScenes(selectID: selectedScene?.id)
    }

    public func windowWillClose(_ notification: Notification) {
        revertDesktopPreviewIfActive()
        flashPreview.stopPreview()
    }

    // MARK: - Actions

    @objc private func filterChanged() {
        reloadScenes(selectID: selectedScene?.id)
    }

    @objc private func toggleLiveDesktopPreview() {
        if let baseline = previewBaselineSettings {
            previewBaselineSettings = nil
            previewBtn.title = "Preview on Desktop"
            onApplyAppSettings?(baseline)
            return
        }
        guard let sc = selectedScene else { return }
        previewBaselineSettings = settingsStore.settings
        previewBtn.title = "Stop Preview"
        let temp = sceneManager.applySceneConfiguration(sc, to: settingsStore.settings)
        onApplyAppSettings?(temp)
    }

    private func revertDesktopPreviewIfActive() {
        if let baseline = previewBaselineSettings {
            previewBaselineSettings = nil
            previewBtn.title = "Preview on Desktop"
            onApplyAppSettings?(baseline)
        }
    }

    @objc private func activateSelected() {
        guard let sc = selectedScene else { return }
        previewBaselineSettings = nil
        previewBtn.title = "Preview on Desktop"
        _ = sceneManager.activateScene(id: sc.id, settingsStore: settingsStore, applyWallpaper: true)
        onApplyAppSettings?(settingsStore.settings)
        reloadScenes(selectID: sc.id)
    }

    @objc private func toggleFavoriteSelected() {
        guard let sc = selectedScene else { return }
        sceneManager.toggleFavorite(id: sc.id)
        reloadScenes(selectID: sc.id)
    }

    @objc private func saveCurrentAsScene() {
        let alert = NSAlert()
        alert.messageText = "Save Current Configuration as Holiday Scene"
        alert.informativeText = "Stores bulbs, colors, animation speed, brightness, screensaver, wallpaper, and music preferences."
        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        nameField.placeholderString = "My Holiday Scene"
        nameField.stringValue = "Custom Holiday Mix"
        alert.accessoryView = nameField
        alert.addButton(withTitle: "Save Scene")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let snap = sceneManager.snapshotCurrentSettings(name: name, season: .custom, from: settingsStore.settings)
        let saved = sceneManager.saveUserScene(snap)
        reloadScenes(selectID: saved.id)
    }

    @objc private func duplicateSelected() {
        guard let sc = selectedScene, let dup = sceneManager.duplicateScene(id: sc.id) else { return }
        reloadScenes(selectID: dup.id)
    }

    @objc private func renameSelected() {
        guard let sc = selectedScene, !sc.isBuiltIn else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Custom Scene"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = sc.name
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            _ = sceneManager.renameUserScene(id: sc.id, newName: field.stringValue)
            reloadScenes(selectID: sc.id)
        }
    }

    @objc private func deleteSelected() {
        guard let sc = selectedScene, !sc.isBuiltIn else { return }
        let alert = NSAlert()
        alert.messageText = "Delete \"\(sc.name)\"?"
        alert.informativeText = "Built-in scenes cannot be deleted, but this custom scene will be removed permanently."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            _ = sceneManager.deleteScene(id: sc.id)
            reloadScenes(selectID: nil)
        }
    }

    @objc private func exportSelected() {
        guard let sc = selectedScene, let data = try? sceneManager.exportScene(id: sc.id) else { return }
        let sp = NSSavePanel()
        sp.nameFieldStringValue = "\(sc.name.replacingOccurrences(of: " ", with: "_")).twinklescene"
        if sp.runModal() == .OK, let url = sp.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    @objc private func importSceneFromFile() {
        let op = NSOpenPanel()
        op.canChooseFiles = true
        op.canChooseDirectories = false
        op.allowedContentTypes = [.json, UTType(filenameExtension: "twinklescene")].compactMap { $0 }
        if op.runModal() == .OK, let url = op.url, let data = try? Data(contentsOf: url),
           let imported = try? sceneManager.importScene(data: data) {
            reloadScenes(selectID: imported.id)
        }
    }

    @objc private func restorePreviousScene() {
        previewBaselineSettings = nil
        if sceneManager.restorePreviousScene(settingsStore: settingsStore) {
            onApplyAppSettings?(settingsStore.settings)
            reloadScenes(selectID: stateStore.state.activeSceneID)
        }
    }

    @objc private func returnToClassic() {
        previewBaselineSettings = nil
        sceneManager.returnToClassicTwinkleBulbs(settingsStore: settingsStore)
        onApplyAppSettings?(settingsStore.settings)
        reloadScenes(selectID: nil)
    }
}
