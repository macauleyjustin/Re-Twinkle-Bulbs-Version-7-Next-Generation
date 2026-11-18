import Cocoa

// MARK: - Main Historical Windows XP-Era Multi-Tab Settings Window (DIALOG/139, 131, 133, 134, 135, 132, 142)

public final class PreferencesWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    var draft: AppSettings = SettingsStore.shared.settings

    public let tabView = NSTabView()
    private let monitorPreview = MonitorPreviewView()
    private let bulbSetStrandPreview = BulbSetPreviewView()
    private let flashingStrandPreview = FlashingModePreviewView()

    // Bulbs Tab Controls (DIALOG/131)
    private let bulbSearchField = NSSearchField()
    private let bulbCollectionPopup = NSPopUpButton()
    private let bulbFavBtn = NSButton(title: "★", target: nil, action: nil)
    private let bulbTableView = NSTableView()
    private let bulbCountLabel = NSTextField(labelWithString: "")
    private var filteredSets: [BulbSetMetadata] = []

    private let sampleImageView = NSImageView()
    private let colorSwatchView = NSImageView()
    private let colorNoticeLabel = NSTextField(labelWithString: "")

    private let engineCategorySeg = NSSegmentedControl(labels: ["Classic (9)", "Modern (15)"], trackingMode: .selectOne, target: nil, action: nil)
    private let modernSetupBtn = NSButton(title: "Modern Setup...", target: nil, action: nil)
    private let flashModePopup = NSPopUpButton()
    private let reverseCheck = NSButton(checkboxWithTitle: "Reverse", target: nil, action: nil)
    private let rateSlider = NSSlider(value: 2, minValue: 0, maxValue: 5, target: nil, action: nil)
    private let rateLabel = NSTextField(labelWithString: "Medium (500 ms)")

    private let colorPopup = NSPopUpButton()
    private let locationPopup = NSPopUpButton()
    private let drawModePopup = NSPopUpButton()
    private let transparencyCheck = NSButton(checkboxWithTitle: "Use Transparency", target: nil, action: nil)
    private let normalSizeRadio = NSButton(radioButtonWithTitle: "Normal (32×32)", target: nil, action: nil)
    private let largeSizeRadio = NSButton(radioButtonWithTitle: "Large (48×48)", target: nil, action: nil)
    private let monitorPopup = NSPopUpButton()
    private let bareWireCheck = NSButton(checkboxWithTitle: "Show bare wire", target: nil, action: nil)
    private let noCornersCheck = NSButton(checkboxWithTitle: "No corner bulbs", target: nil, action: nil)
    private let notSoManyCheck = NSButton(checkboxWithTitle: "Fewer bulbs", target: nil, action: nil)
    private let noFlickerCheck = NSButton(checkboxWithTitle: "Less flicker", target: nil, action: nil)
    private let brokenCheck = NSButton(checkboxWithTitle: "Broken bulbs", target: nil, action: nil)
    private let burnedOutCheck = NSButton(checkboxWithTitle: "Burned out", target: nil, action: nil)
    private let missingCheck = NSButton(checkboxWithTitle: "Missing", target: nil, action: nil)
    private let randomPropsCheck = NSButton(checkboxWithTitle: "Random", target: nil, action: nil)
    private let mixBulbsCheck = NSButton(checkboxWithTitle: "Mix bulb sets", target: nil, action: nil)
    private let inwardCheck = NSButton(checkboxWithTitle: "Draw inward", target: nil, action: nil)
    private let useAllMonitorsCheck = NSButton(checkboxWithTitle: "Draw on All", target: nil, action: nil)
    private let bulbChangerCheck = NSButton(checkboxWithTitle: "Enable", target: nil, action: nil)
    private let bulbChangerOrderPopup = NSPopUpButton()
    private let bulbChangerFreqField = NSTextField()
    private let lightsOnQuickBtn = NSButton(title: "Lights: On", target: nil, action: nil)

    // General Tab Controls (DIALOG/139)
    private let leftClickPopup = NSPopUpButton()
    private let rightClickPopup = NSPopUpButton()
    private let middleClickPopup = NSPopUpButton()
    private let trayIconPopup = NSPopUpButton()
    private let splashCheck = NSButton(checkboxWithTitle: "Display splash screen on startup", target: nil, action: nil)
    private let toolTipsCheck = NSButton(checkboxWithTitle: "Show tooltips", target: nil, action: nil)
    private let warningMsgsCheck = NSButton(checkboxWithTitle: "Show info / warning messages", target: nil, action: nil)
    private let soundFXCheck = NSButton(checkboxWithTitle: "Play UI sound effects", target: nil, action: nil)
    private let flashIconCheck = NSButton(checkboxWithTitle: "Flash menu bar icon", target: nil, action: nil)
    private let quickAccessCheck = NSButton(checkboxWithTitle: "Quick access bar", target: nil, action: nil)
    private let confirmExitCheck = NSButton(checkboxWithTitle: "Confirm program exit", target: nil, action: nil)
    private let runSSOnlyCheck = NSButton(checkboxWithTitle: "Screen saver mode only (no bulbs)", target: nil, action: nil)
    private let startupCalendarCheck = NSButton(checkboxWithTitle: "Show calendar on startup", target: nil, action: nil)
    private let startupOptionsCheck = NSButton(checkboxWithTitle: "Show configuration on startup", target: nil, action: nil)
    private let enhancedMenuCheck = NSButton(checkboxWithTitle: "Enhanced popup menu", target: nil, action: nil)
    private let zoomCheck = NSButton(checkboxWithTitle: "Zoom window transitions", target: nil, action: nil)
    private let reduceMotionCheck = NSButton(checkboxWithTitle: "Reduce motion in previews/savers", target: nil, action: nil)
    private let cpuPrioritySlider = NSSlider(value: 2, minValue: 0, maxValue: 4, target: nil, action: nil)
    private let cpuPriorityLabel = NSTextField(labelWithString: "Normal")
    private let sysHighlightCheck = NSButton(checkboxWithTitle: "Use classic Navy (#000080) highlight for dimming", target: nil, action: nil)
    private let highlightWell = NSColorWell()

    // Secondary & Modern coordinators
    private lazy var secondaryTabs = PreferencesSecondaryTabsCoordinator(owner: self)
    private lazy var modernPanel = ModernEffectsTabCoordinator(owner: self)

    var onApplySettings: ((AppSettings) -> Void)?
    var onStartScreenSaverNow: (() -> Void)?
    var onOpenCalendarViewer: (() -> Void)?
    var onOpenAdventCalendar: (() -> Void)?

    public convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 790, height: 616),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Re: Twinkle Bulbs — Settings"
        win.appearance = NSAppearance(named: .aqua)
        win.center()
        win.isReleasedWhenClosed = false
        self.init(window: win)
        buildWindowUI()
        loadFromSettings(SettingsStore.shared.settings)
        // Open on historical Bulbs tab (index 1 in General..Help) by default for convenience
        tabView.selectTabViewItem(at: 1)
    }

    func showAndReload() {
        loadFromSettings(SettingsStore.shared.settings)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindowUI() {
        guard let root = window?.contentView else { return }
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(srgbRed: 0.925, green: 0.914, blue: 0.847, alpha: 1.0).cgColor // Classic XP Luna #ECE9D8

        // Classic Windows XP Royal Blue Header Strip (no unlicensed copy banner)
        let banner = XPClassicHeaderView(frame: NSRect(x: 0, y: 582, width: 790, height: 34))
        root.addSubview(banner)

        tabView.frame = NSRect(x: 12, y: 52, width: 766, height: 522)
        tabView.tabViewType = .topTabsBezelBorder
        tabView.font = .systemFont(ofSize: 11.5)
        tabView.appearance = NSAppearance(named: .aqua)

        // Exact Historical Tab Order (1..7)
        tabView.addTabViewItem(makeGeneralTab())                   // 1. General
        tabView.addTabViewItem(makeBulbsTab())                     // 2. Bulbs
        tabView.addTabViewItem(secondaryTabs.makeMusicTab())       // 3. Music
        tabView.addTabViewItem(secondaryTabs.makeScreenSaverTab()) // 4. Screen Saver
        tabView.addTabViewItem(secondaryTabs.makeWallpaperTab())   // 5. Wallpaper
        tabView.addTabViewItem(secondaryTabs.makeCalendarTab())    // 6. Calendar
        tabView.addTabViewItem(secondaryTabs.makeHelpAndToolsTab())// 7. Help
        root.addSubview(tabView)

        // Bottom historical OK / Cancel / Apply / Reset Defaults buttons
        let resetBtn = NSButton(title: "Reset Defaults", target: self, action: #selector(resetDefaultsPressed))
        resetBtn.frame = NSRect(x: 14, y: 12, width: 118, height: 28)

        let okBtn = NSButton(title: "OK", target: self, action: #selector(okPressed))
        okBtn.frame = NSRect(x: 500, y: 12, width: 86, height: 28)
        okBtn.keyEquivalent = "\r"

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancelBtn.frame = NSRect(x: 594, y: 12, width: 86, height: 28)
        cancelBtn.keyEquivalent = "\u{1b}"

        let applyBtn = NSButton(title: "Apply", target: self, action: #selector(applyPressed))
        applyBtn.frame = NSRect(x: 688, y: 12, width: 86, height: 28)

        root.addSubview(resetBtn)
        root.addSubview(okBtn)
        root.addSubview(cancelBtn)
        root.addSubview(applyBtn)
    }

    // MARK: - 1. General Tab (DIALOG/139)

    private func makeGeneralTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "general")
        item.label = "General"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 750, height: 480))

        let startupBox = NSBox(frame: NSRect(x: 12, y: 318, width: 235, height: 150))
        startupBox.title = "Startup"
        let startChecks = [splashCheck, startupCalendarCheck, startupOptionsCheck, quickAccessCheck]
        for (idx, chk) in startChecks.enumerated() {
            chk.font = .systemFont(ofSize: 11)
            chk.frame = NSRect(x: 10, y: 104 - CGFloat(idx) * 27, width: 215, height: 22)
            chk.target = self; chk.action = #selector(generalControlChanged)
            startupBox.contentView?.addSubview(chk)
        }
        view.addSubview(startupBox)

        let otherBox = NSBox(frame: NSRect(x: 256, y: 318, width: 245, height: 150))
        otherBox.title = "Other"
        let otherChecks = [runSSOnlyCheck, toolTipsCheck, warningMsgsCheck, confirmExitCheck, enhancedMenuCheck]
        for (idx, chk) in otherChecks.enumerated() {
            chk.font = .systemFont(ofSize: 11)
            chk.frame = NSRect(x: 10, y: 106 - CGFloat(idx) * 23, width: 225, height: 20)
            chk.target = self; chk.action = #selector(generalControlChanged)
            otherBox.contentView?.addSubview(chk)
        }
        view.addSubview(otherBox)

        let trayBox = NSBox(frame: NSRect(x: 12, y: 100, width: 235, height: 210))
        trayBox.title = "Menu Bar Icon Actions"
        let actionNames = TrayClickAction.allCases.map(\.displayName)
        for p in [leftClickPopup, rightClickPopup, middleClickPopup] {
            p.addItems(withTitles: actionNames)
            p.font = .systemFont(ofSize: 11)
            p.target = self; p.action = #selector(generalControlChanged)
        }
        trayIconPopup.addItems(withTitles: ["Yellow Glow", "Red Ornament", "Green Pine", "Ice Blue"])
        trayIconPopup.font = .systemFont(ofSize: 11)
        trayIconPopup.target = self; trayIconPopup.action = #selector(generalControlChanged)
        flashIconCheck.font = .systemFont(ofSize: 11)
        flashIconCheck.target = self; flashIconCheck.action = #selector(generalControlChanged)

        let rows: [(String, NSView, CGFloat)] = [
            ("Select Icon:", trayIconPopup, 152),
            ("Left Button:", leftClickPopup, 100),
            ("Middle Button:", middleClickPopup, 56),
            ("Right Button:", rightClickPopup, 12)
        ]
        for (lblText, ctrl, y) in rows {
            let lbl = NSTextField(labelWithString: lblText)
            lbl.font = .systemFont(ofSize: 11)
            lbl.frame = NSRect(x: 10, y: y + 18, width: 100, height: 16)
            ctrl.frame = NSRect(x: 10, y: y - 4, width: 212, height: 22)
            trayBox.contentView?.addSubview(lbl)
            trayBox.contentView?.addSubview(ctrl)
        }
        flashIconCheck.frame = NSRect(x: 10, y: 132, width: 210, height: 20)
        trayBox.contentView?.addSubview(flashIconCheck)
        view.addSubview(trayBox)

        let cpuBox = NSBox(frame: NSRect(x: 256, y: 224, width: 245, height: 86))
        cpuBox.title = "CPU Priority"
        cpuPrioritySlider.numberOfTickMarks = 5
        cpuPrioritySlider.allowsTickMarkValuesOnly = true
        cpuPrioritySlider.frame = NSRect(x: 12, y: 34, width: 216, height: 22)
        cpuPrioritySlider.target = self; cpuPrioritySlider.action = #selector(generalControlChanged)
        cpuPriorityLabel.font = .systemFont(ofSize: 11)
        cpuPriorityLabel.alignment = .center
        cpuPriorityLabel.frame = NSRect(x: 12, y: 10, width: 216, height: 16)
        cpuBox.contentView?.addSubview(cpuPrioritySlider)
        cpuBox.contentView?.addSubview(cpuPriorityLabel)
        view.addSubview(cpuBox)

        let fxBox = NSBox(frame: NSRect(x: 256, y: 100, width: 245, height: 116))
        fxBox.title = "Effects & Motion"
        soundFXCheck.font = .systemFont(ofSize: 11); soundFXCheck.frame = NSRect(x: 10, y: 68, width: 220, height: 20)
        zoomCheck.font = .systemFont(ofSize: 11); zoomCheck.frame = NSRect(x: 10, y: 42, width: 220, height: 20)
        reduceMotionCheck.font = .systemFont(ofSize: 11); reduceMotionCheck.frame = NSRect(x: 10, y: 16, width: 220, height: 20)
        for c in [soundFXCheck, zoomCheck, reduceMotionCheck] {
            c.target = self; c.action = #selector(generalControlChanged)
            fxBox.contentView?.addSubview(c)
        }
        view.addSubview(fxBox)

        // Monitor Preview & Highlight color panel
        let prevBox = NSBox(frame: NSRect(x: 510, y: 100, width: 232, height: 368))
        prevBox.title = "Live Workspace Preview"
        monitorPreview.frame = NSRect(x: 8, y: 108, width: 214, height: 234)
        sysHighlightCheck.font = .systemFont(ofSize: 10.5)
        sysHighlightCheck.frame = NSRect(x: 10, y: 54, width: 210, height: 34)
        sysHighlightCheck.target = self; sysHighlightCheck.action = #selector(generalControlChanged)
        let hlLbl = NSTextField(labelWithString: "Dim Color:")
        hlLbl.font = .systemFont(ofSize: 11); hlLbl.frame = NSRect(x: 10, y: 16, width: 70, height: 18)
        highlightWell.frame = NSRect(x: 84, y: 12, width: 64, height: 24)
        highlightWell.target = self; highlightWell.action = #selector(generalControlChanged)
        for v: NSView in [monitorPreview, sysHighlightCheck, hlLbl, highlightWell] { prevBox.contentView?.addSubview(v) }
        view.addSubview(prevBox)

        let verLbl = NSTextField(labelWithString: "Re: Twinkle Bulbs v7.0.0 (Version 7: Next Generation + Classic v6.0) — Freeware Tribute to Don Metzler & Barefoot Productions")
        verLbl.font = .systemFont(ofSize: 11)
        verLbl.textColor = .secondaryLabelColor
        verLbl.frame = NSRect(x: 14, y: 36, width: 720, height: 20)
        view.addSubview(verLbl)

        item.view = view
        return item
    }

    // MARK: - 2. Restored Historical Bulbs Tab (DIALOG/131 + Live Previews + 250 Collections)

    private func makeBulbsTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "bulbs")
        item.label = "Bulbs"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 750, height: 480))

        // LEFT UPPER: Bulb Sets Scrollable Thumbnail List (Search + Category Filter + Fav)
        let setBox = NSBox(frame: NSRect(x: 10, y: 138, width: 266, height: 334))
        setBox.title = "Bulb Sets"

        bulbSearchField.frame = NSRect(x: 8, y: 284, width: 136, height: 22)
        bulbSearchField.placeholderString = "Search..."
        bulbSearchField.delegate = self

        bulbCollectionPopup.frame = NSRect(x: 148, y: 283, width: 108, height: 24)
        bulbCollectionPopup.font = .systemFont(ofSize: 10.5)
        bulbCollectionPopup.removeAllItems()
        bulbCollectionPopup.addItem(withTitle: "All Sets (265)")
        bulbCollectionPopup.addItem(withTitle: "Favorites ★")
        bulbCollectionPopup.addItem(withTitle: "Recently Used")
        for c in BulbCollectionCategory.allCases {
            bulbCollectionPopup.addItem(withTitle: c.displayName)
        }
        bulbCollectionPopup.target = self; bulbCollectionPopup.action = #selector(filterBulbSets)

        let colIcon = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("icon"))
        colIcon.width = 28
        let colName = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        colName.width = 198
        bulbTableView.addTableColumn(colIcon)
        bulbTableView.addTableColumn(colName)
        bulbTableView.headerView = nil
        bulbTableView.rowHeight = 28
        bulbTableView.backgroundColor = .white // Crisp historical recessed white list
        bulbTableView.usesAlternatingRowBackgroundColors = false
        bulbTableView.dataSource = self
        bulbTableView.delegate = self

        let scroll = NSScrollView(frame: NSRect(x: 8, y: 66, width: 248, height: 212))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.documentView = bulbTableView

        bulbCountLabel.font = .systemFont(ofSize: 10)
        bulbCountLabel.textColor = .secondaryLabelColor
        bulbCountLabel.frame = NSRect(x: 8, y: 48, width: 184, height: 15)

        bulbFavBtn.frame = NSRect(x: 196, y: 45, width: 60, height: 20)
        bulbFavBtn.font = .systemFont(ofSize: 10.5)
        bulbFavBtn.target = self; bulbFavBtn.action = #selector(toggleFavoriteBulbSet)

        bulbSetStrandPreview.frame = NSRect(x: 8, y: 6, width: 248, height: 40)

        for v: NSView in [bulbSearchField, bulbCollectionPopup, scroll, bulbCountLabel, bulbFavBtn, bulbSetStrandPreview] {
            setBox.contentView?.addSubview(v)
        }
        view.addSubview(setBox)

        // LEFT LOWER: Color Group Box with Real Swatch Dropdown & Live Indicator
        let colorBox = NSBox(frame: NSRect(x: 10, y: 12, width: 266, height: 120))
        colorBox.title = "Color"
        colorSwatchView.frame = NSRect(x: 10, y: 58, width: 56, height: 20)
        colorSwatchView.imageScaling = .scaleProportionallyUpOrDown
        colorPopup.removeAllItems()
        for cm in ColorMode.allCases {
            colorPopup.addItem(withTitle: cm.displayName)
            colorPopup.lastItem?.image = ColorModeSwatchRenderer.swatchImage(for: cm, width: 44, height: 12)
        }
        colorPopup.frame = NSRect(x: 72, y: 56, width: 182, height: 26)
        colorPopup.font = .systemFont(ofSize: 11)
        colorPopup.target = self; colorPopup.action = #selector(bulbsControlChanged)

        colorNoticeLabel.font = .systemFont(ofSize: 10)
        colorNoticeLabel.textColor = .secondaryLabelColor
        colorNoticeLabel.frame = NSRect(x: 10, y: 12, width: 244, height: 34)
        for v: NSView in [colorSwatchView, colorPopup, colorNoticeLabel] { colorBox.contentView?.addSubview(v) }
        view.addSubview(colorBox)

        // RIGHT UPPER: Style Group Box (Burned out / Broken bulbs / Missing / Random / Mix + Actions)
        let styleBox = NSBox(frame: NSRect(x: 284, y: 378, width: 458, height: 94))
        styleBox.title = "Style & Active Set"
        sampleImageView.frame = NSRect(x: 10, y: 36, width: 34, height: 34)
        sampleImageView.imageScaling = .scaleProportionallyUpOrDown

        let styleChecks: [(NSButton, CGFloat, CGFloat)] = [
            (burnedOutCheck, 52, 46), (brokenCheck, 152, 46), (mixBulbsCheck, 256, 46),
            (missingCheck, 52, 22), (randomPropsCheck, 152, 22)
        ]
        for (chk, x, y) in styleChecks {
            chk.font = .systemFont(ofSize: 11)
            chk.frame = NSRect(x: x, y: y, width: 102, height: 20)
            chk.target = self; chk.action = #selector(bulbsControlChanged)
            styleBox.contentView?.addSubview(chk)
        }
        let propsBtn = NSButton(title: "Info...", target: self, action: #selector(showBulbProperties))
        propsBtn.font = .systemFont(ofSize: 11); propsBtn.frame = NSRect(x: 372, y: 46, width: 76, height: 22)
        let impBtn = NSButton(title: "Import...", target: self, action: #selector(importBulbAssets))
        impBtn.font = .systemFont(ofSize: 11); impBtn.frame = NSRect(x: 372, y: 20, width: 76, height: 22)
        lightsOnQuickBtn.font = .systemFont(ofSize: 10.5); lightsOnQuickBtn.frame = NSRect(x: 256, y: 18, width: 108, height: 22)
        lightsOnQuickBtn.target = self; lightsOnQuickBtn.action = #selector(toggleLightsQuick)
        for v: NSView in [sampleImageView, propsBtn, impBtn, lightsOnQuickBtn] { styleBox.contentView?.addSubview(v) }
        view.addSubview(styleBox)

        // RIGHT MIDDLE LEFT: Flashing Box (Classic 9 / Modern 15 Switch + Continuous Preview + Rate Slider)
        let flashBox = NSBox(frame: NSRect(x: 284, y: 174, width: 274, height: 198))
        flashBox.title = "Flashing"

        engineCategorySeg.font = .systemFont(ofSize: 10.5)
        engineCategorySeg.frame = NSRect(x: 8, y: 146, width: 174, height: 22)
        engineCategorySeg.target = self; engineCategorySeg.action = #selector(engineCategoryChanged)
        modernSetupBtn.title = "Setup..."
        modernSetupBtn.font = .systemFont(ofSize: 10.5)
        modernSetupBtn.frame = NSRect(x: 186, y: 145, width: 78, height: 24)
        modernSetupBtn.target = self; modernSetupBtn.action = #selector(openModernSetupPanel)

        let modeLbl = NSTextField(labelWithString: "Mode:")
        modeLbl.font = .systemFont(ofSize: 11); modeLbl.frame = NSRect(x: 10, y: 118, width: 42, height: 18)
        flashModePopup.frame = NSRect(x: 52, y: 115, width: 212, height: 24)
        flashModePopup.font = .systemFont(ofSize: 11)
        flashModePopup.target = self; flashModePopup.action = #selector(modeSelectionChanged)

        reverseCheck.font = .systemFont(ofSize: 11)
        reverseCheck.frame = NSRect(x: 52, y: 92, width: 92, height: 18)
        reverseCheck.target = self; reverseCheck.action = #selector(bulbsControlChanged)

        rateSlider.numberOfTickMarks = 6
        rateSlider.allowsTickMarkValuesOnly = true
        rateSlider.isContinuous = true
        rateSlider.frame = NSRect(x: 10, y: 66, width: 254, height: 22)
        rateSlider.target = self; rateSlider.action = #selector(rateSliderChanged)

        rateLabel.font = .systemFont(ofSize: 10.5)
        rateLabel.alignment = .center
        rateLabel.frame = NSRect(x: 10, y: 48, width: 254, height: 16)

        flashingStrandPreview.frame = NSRect(x: 10, y: 8, width: 254, height: 36)

        for v: NSView in [engineCategorySeg, modernSetupBtn, modeLbl, flashModePopup, reverseCheck, rateSlider, rateLabel, flashingStrandPreview] {
            flashBox.contentView?.addSubview(v)
        }
        view.addSubview(flashBox)

        // RIGHT MIDDLE RIGHT: Options Group Box
        let optBox = NSBox(frame: NSRect(x: 566, y: 174, width: 176, height: 198))
        optBox.title = "Options"
        let opts = [noFlickerCheck, notSoManyCheck, bareWireCheck, noCornersCheck, inwardCheck]
        for (idx, chk) in opts.enumerated() {
            chk.font = .systemFont(ofSize: 11)
            chk.frame = NSRect(x: 10, y: 146 - CGFloat(idx) * 30, width: 156, height: 22)
            chk.target = self; chk.action = #selector(bulbsControlChanged)
            optBox.contentView?.addSubview(chk)
        }
        view.addSubview(optBox)

        // RIGHT LOWER: Drawing / Location + Bulb Changer + Bulb Size + Monitor(s)
        let drawBox = NSBox(frame: NSRect(x: 284, y: 78, width: 274, height: 92))
        drawBox.title = "Drawing / Location"
        drawModePopup.addItems(withTitles: DrawMode.allCases.map(\.displayName))
        drawModePopup.font = .systemFont(ofSize: 11)
        drawModePopup.frame = NSRect(x: 58, y: 44, width: 206, height: 22)
        drawModePopup.target = self; drawModePopup.action = #selector(bulbsControlChanged)
        locationPopup.addItems(withTitles: BulbLocation.allCases.map(\.displayName))
        locationPopup.font = .systemFont(ofSize: 11)
        locationPopup.frame = NSRect(x: 56, y: 18, width: 122, height: 22)
        locationPopup.target = self; locationPopup.action = #selector(bulbsControlChanged)
        transparencyCheck.title = "Transparent"
        transparencyCheck.font = .systemFont(ofSize: 10)
        transparencyCheck.frame = NSRect(x: 182, y: 18, width: 88, height: 20)
        transparencyCheck.target = self; transparencyCheck.action = #selector(bulbsControlChanged)

        let dmLbl = NSTextField(labelWithString: "Layer:"); dmLbl.font = .systemFont(ofSize: 10.5); dmLbl.frame = NSRect(x: 8, y: 47, width: 48, height: 16)
        let lcLbl = NSTextField(labelWithString: "Edge:"); lcLbl.font = .systemFont(ofSize: 10.5); lcLbl.frame = NSRect(x: 8, y: 21, width: 48, height: 16)
        for v: NSView in [dmLbl, drawModePopup, lcLbl, locationPopup, transparencyCheck] { drawBox.contentView?.addSubview(v) }
        view.addSubview(drawBox)

        let chgBox = NSBox(frame: NSRect(x: 284, y: 12, width: 274, height: 62))
        chgBox.title = "Bulb Changer"
        bulbChangerCheck.font = .systemFont(ofSize: 11); bulbChangerCheck.frame = NSRect(x: 8, y: 14, width: 64, height: 20)
        bulbChangerCheck.target = self; bulbChangerCheck.action = #selector(bulbsControlChanged)
        bulbChangerOrderPopup.addItems(withTitles: ["Sequential", "Random"])
        bulbChangerOrderPopup.font = .systemFont(ofSize: 10.5); bulbChangerOrderPopup.frame = NSRect(x: 72, y: 13, width: 92, height: 22)
        bulbChangerOrderPopup.target = self; bulbChangerOrderPopup.action = #selector(bulbsControlChanged)
        let minLbl = NSTextField(labelWithString: "min:"); minLbl.font = .systemFont(ofSize: 10.5); minLbl.frame = NSRect(x: 170, y: 16, width: 28, height: 16)
        bulbChangerFreqField.frame = NSRect(x: 200, y: 13, width: 58, height: 20)
        for v: NSView in [bulbChangerCheck, bulbChangerOrderPopup, minLbl, bulbChangerFreqField] { chgBox.contentView?.addSubview(v) }
        view.addSubview(chgBox)

        let sizeBox = NSBox(frame: NSRect(x: 566, y: 98, width: 176, height: 72))
        sizeBox.title = "Bulb Size (pixels)"
        normalSizeRadio.font = .systemFont(ofSize: 11); normalSizeRadio.frame = NSRect(x: 10, y: 28, width: 150, height: 20)
        largeSizeRadio.font = .systemFont(ofSize: 11); largeSizeRadio.frame = NSRect(x: 10, y: 6, width: 150, height: 20)
        normalSizeRadio.target = self; normalSizeRadio.action = #selector(sizeRadioChanged(_:))
        largeSizeRadio.target = self; largeSizeRadio.action = #selector(sizeRadioChanged(_:))
        sizeBox.contentView?.addSubview(normalSizeRadio); sizeBox.contentView?.addSubview(largeSizeRadio)
        view.addSubview(sizeBox)

        let monBox = NSBox(frame: NSRect(x: 566, y: 12, width: 176, height: 82))
        monBox.title = "Select Monitor(s)"
        monitorPopup.frame = NSRect(x: 8, y: 34, width: 158, height: 22)
        monitorPopup.font = .systemFont(ofSize: 10.5)
        monitorPopup.target = self; monitorPopup.action = #selector(bulbsControlChanged)
        useAllMonitorsCheck.font = .systemFont(ofSize: 10.5); useAllMonitorsCheck.frame = NSRect(x: 8, y: 8, width: 100, height: 20)
        useAllMonitorsCheck.target = self; useAllMonitorsCheck.action = #selector(bulbsControlChanged)
        let idBtn = NSButton(title: "ID", target: self, action: #selector(flashMonitorID))
        idBtn.font = .systemFont(ofSize: 10.5); idBtn.frame = NSRect(x: 118, y: 7, width: 46, height: 22)
        for v: NSView in [monitorPopup, useAllMonitorsCheck, idBtn] { monBox.contentView?.addSubview(v) }
        view.addSubview(monBox)

        item.view = view
        return item
    }

    // MARK: - Data Binding & Synchronization

    func loadFromSettings(_ s: AppSettings) {
        draft = s
        refreshFilteredBulbSets(selecting: s.bulbSetName)
        refreshModePopup()
        rateSlider.integerValue = s.rate.rawValue
        rateLabel.stringValue = "\(s.rate.displayName)"
        colorPopup.selectItem(at: max(0, min(ColorMode.allCases.count - 1, s.colorMode.rawValue)))
        locationPopup.selectItem(at: s.location.rawValue)
        drawModePopup.selectItem(at: s.drawMode.rawValue)
        transparencyCheck.state = s.transparency ? .on : .off
        normalSizeRadio.state = (s.bulbSize == .normal) ? .on : .off
        largeSizeRadio.state = (s.bulbSize == .large) ? .on : .off
        refreshMonitorDropdown()

        bareWireCheck.state = s.bareWire ? .on : .off
        noCornersCheck.state = s.noCorners ? .on : .off
        notSoManyCheck.state = s.notSoMany ? .on : .off
        noFlickerCheck.state = s.noFlicker ? .on : .off
        brokenCheck.state = s.broken ? .on : .off
        burnedOutCheck.state = s.burnedOut ? .on : .off
        missingCheck.state = s.missing ? .on : .off
        randomPropsCheck.state = s.randomProperties ? .on : .off
        mixBulbsCheck.state = s.mixBulbs ? .on : .off
        reverseCheck.state = (s.lightingCategory == .modern ? s.modernEffects.reverseDirection : s.reverse) ? .on : .off
        inwardCheck.state = s.inward ? .on : .off
        useAllMonitorsCheck.state = s.useAllMonitors ? .on : .off
        bulbChangerCheck.state = s.bulbChanger ? .on : .off
        bulbChangerOrderPopup.selectItem(at: max(0, min(1, s.bulbChangeOrder)))
        bulbChangerFreqField.integerValue = s.bulbChangeFreqMinutes
        lightsOnQuickBtn.title = s.lightsEnabled ? "Lights: On" : "Lights: Off"

        trayIconPopup.selectItem(at: max(0, min(3, s.trayIconIndex)))
        leftClickPopup.selectItem(at: s.trayLeftClick.rawValue)
        rightClickPopup.selectItem(at: s.trayRightClick.rawValue)
        middleClickPopup.selectItem(at: s.trayMiddleClick.rawValue)
        splashCheck.state = s.splashScreen ? .on : .off
        toolTipsCheck.state = s.toolTips ? .on : .off
        warningMsgsCheck.state = s.warningMsgs ? .on : .off
        soundFXCheck.state = s.soundFX ? .on : .off
        flashIconCheck.state = s.flashIcon ? .on : .off
        quickAccessCheck.state = s.quickAccess ? .on : .off
        confirmExitCheck.state = s.confirmExit ? .on : .off
        runSSOnlyCheck.state = s.runSSOnly ? .on : .off
        startupCalendarCheck.state = s.startupCalendar ? .on : .off
        startupOptionsCheck.state = s.startupOptions ? .on : .off
        enhancedMenuCheck.state = s.enhancedMenu ? .on : .off
        zoomCheck.state = s.zoom ? .on : .off
        reduceMotionCheck.state = s.reduceMotion ? .on : .off
        cpuPrioritySlider.integerValue = max(0, min(4, s.cpuPriority))
        cpuPriorityLabel.stringValue = ["Idle", "Low", "Normal", "High", "Realtime"][max(0, min(4, s.cpuPriority))]
        sysHighlightCheck.state = s.sysColorHighlight ? .on : .off
        highlightWell.color = NSColor(hex: s.highlightColorHex, fallback: NSColor(srgbRed: 0, green: 0, blue: 0.5, alpha: 1))
        highlightWell.isEnabled = !s.sysColorHighlight

        secondaryTabs.loadFromSettings(s)
        modernPanel.loadFromSettings(s)
        updatePreviews()
    }

    func refreshModeControlsFromModernPanel() {
        engineCategorySeg.selectedSegment = draft.lightingCategory.rawValue
        refreshModePopup()
        reverseCheck.state = (draft.lightingCategory == .modern ? draft.modernEffects.reverseDirection : draft.reverse) ? .on : .off
        updatePreviews()
    }

    private func refreshModePopup() {
        engineCategorySeg.selectedSegment = draft.lightingCategory.rawValue
        modernSetupBtn.isEnabled = true
        flashModePopup.removeAllItems()
        if draft.lightingCategory == .modern {
            flashModePopup.addItems(withTitles: ModernEffectID.allCases.map(\.displayName))
            flashModePopup.selectItem(at: draft.modernEffects.effect.rawValue)
            rateSlider.isEnabled = true
        } else {
            flashModePopup.addItems(withTitles: FlashMode.allCases.map(\.displayName))
            flashModePopup.selectItem(at: draft.flashMode.rawValue)
            rateSlider.isEnabled = true
        }
    }

    // MARK: - Bulb Table DataSource / Delegate

    func refreshFilteredBulbSets(selecting setID: String? = nil) {
        let all = BulbArtworkRegistry.shared.availableSets
        let q = bulbSearchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filterIdx = bulbCollectionPopup.indexOfSelectedItem

        filteredSets = all.filter { meta in
            if filterIdx == 1 {
                if !draft.favoriteBulbSetIDs.contains(meta.id) { return false }
            } else if filterIdx == 2 {
                if !draft.recentBulbSetIDs.contains(meta.id) { return false }
            } else if filterIdx >= 3 {
                let colIdx = filterIdx - 3
                if meta.collection.rawValue != colIdx { return false }
            }
            if !q.isEmpty {
                return meta.title.lowercased().contains(q) || meta.collection.displayName.lowercased().contains(q)
            }
            return true
        }

        bulbTableView.reloadData()
        let target = BulbArtworkRegistry.shared.resolveSetID(setID ?? draft.bulbSetName)
        if let row = filteredSets.firstIndex(where: { $0.id == target }) {
            bulbTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            bulbTableView.scrollRowToVisible(row)
        }
        bulbCountLabel.stringValue = "\(filteredSets.count) of \(all.count) bulb sets"
        bulbFavBtn.title = draft.favoriteBulbSetIDs.contains(target) ? "★ Fav" : "☆ Fav"
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        filteredSets.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < filteredSets.count else { return nil }
        let meta = filteredSets[row]
        if tableColumn?.identifier.rawValue == "icon" {
            let iv = NSImageView(frame: NSRect(x: 2, y: 2, width: 24, height: 24))
            iv.imageScaling = .scaleProportionallyUpOrDown
            if let cg = BulbArtworkRegistry.shared.sampleImage(for: meta.id) {
                iv.image = NSImage(cgImage: cg, size: NSSize(width: 24, height: 24))
            }
            return iv
        } else {
            let prefix = draft.favoriteBulbSetIDs.contains(meta.id) ? "★ " : ""
            let lbl = NSTextField(labelWithString: "\(prefix)\(meta.title)")
            lbl.font = .systemFont(ofSize: 11.5)
            lbl.textColor = .black
            lbl.lineBreakMode = .byTruncatingTail
            return lbl
        }
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        let row = bulbTableView.selectedRow
        guard row >= 0, row < filteredSets.count else { return }
        let picked = filteredSets[row].id
        if draft.bulbSetName != picked {
            draft.bulbSetName = picked
            var recent = draft.recentBulbSetIDs.filter { $0 != picked }
            recent.insert(picked, at: 0)
            draft.recentBulbSetIDs = recent
            AudioEngineService.shared.playEffect(.softTick, enabled: draft.soundFX)
            bulbFavBtn.title = draft.favoriteBulbSetIDs.contains(picked) ? "★ Fav" : "☆ Fav"
            updatePreviews()
        }
    }

    public func controlTextDidChange(_ obj: Notification) {
        if let sf = obj.object as? NSSearchField, sf === bulbSearchField {
            refreshFilteredBulbSets(selecting: draft.bulbSetName)
        }
    }

    @objc private func filterBulbSets() {
        refreshFilteredBulbSets(selecting: draft.bulbSetName)
    }

    @objc private func toggleFavoriteBulbSet() {
        let cur = BulbArtworkRegistry.shared.resolveSetID(draft.bulbSetName)
        var favs = draft.favoriteBulbSetIDs
        if let idx = favs.firstIndex(of: cur) {
            favs.remove(at: idx)
        } else {
            favs.append(cur)
        }
        draft.favoriteBulbSetIDs = favs
        refreshFilteredBulbSets(selecting: cur)
    }

    private func refreshMonitorDropdown() {
        let screens = NSScreen.screens
        monitorPopup.removeAllItems()
        for (i, scr) in screens.enumerated() {
            let sz = scr.frame.size
            monitorPopup.addItem(withTitle: "Display \(i + 1) (\(Int(sz.width))×\(Int(sz.height)))")
        }
        if !screens.isEmpty {
            monitorPopup.selectItem(at: min(max(0, draft.drawMonitorIndex), screens.count - 1))
        }
        monitorPopup.isEnabled = !draft.useAllMonitors
    }

    // MARK: - Actions

    @objc private func engineCategoryChanged() {
        draft.lightingCategory = LightingEngineCategory(rawValue: max(0, engineCategorySeg.selectedSegment)) ?? .classic
        refreshModePopup()
        reverseCheck.state = (draft.lightingCategory == .modern ? draft.modernEffects.reverseDirection : draft.reverse) ? .on : .off
        AudioEngineService.shared.playEffect(.softTick, enabled: draft.soundFX)
        updatePreviews()
    }

    @objc private func openModernSetupPanel() {
        modernPanel.openAdvancedPanel()
    }

    @objc private func modeSelectionChanged() {
        if draft.lightingCategory == .modern {
            var m = draft.modernEffects
            m.effect = ModernEffectID(rawValue: max(0, flashModePopup.indexOfSelectedItem)) ?? .twinklefox
            draft.modernEffects = m
        } else {
            draft.flashMode = FlashMode(rawValue: max(0, flashModePopup.indexOfSelectedItem)) ?? .chase
        }
        AudioEngineService.shared.playEffect(.softTick, enabled: draft.soundFX)
        updatePreviews()
    }

    @objc private func rateSliderChanged() {
        let step = max(0, min(5, rateSlider.integerValue))
        draft.rate = FlashRate(rawValue: step) ?? .medium
        rateLabel.stringValue = draft.rate.displayName
        if draft.lightingCategory == .modern {
            let speedMap = [0.4, 0.7, 1.0, 1.4, 2.0, 2.7]
            var m = draft.modernEffects
            m.speed = speedMap[step]
            draft.modernEffects = m
        }
        updatePreviews()
    }

    @objc private func sizeRadioChanged(_ sender: NSButton) {
        normalSizeRadio.state = (sender === normalSizeRadio) ? .on : .off
        largeSizeRadio.state = (sender === largeSizeRadio) ? .on : .off
        bulbsControlChanged()
    }

    @objc private func flashMonitorID() {
        let screens = NSScreen.screens
        let idx = min(max(0, draft.drawMonitorIndex), max(0, screens.count - 1))
        guard idx < screens.count else { return }
        let scr = screens[idx]
        let badge = NSWindow(contentRect: NSRect(x: scr.frame.midX - 90, y: scr.frame.midY - 50, width: 180, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
        badge.level = .floating; badge.isOpaque = false; badge.backgroundColor = NSColor.black.withAlphaComponent(0.75)
        badge.isReleasedWhenClosed = false
        let lbl = NSTextField(labelWithString: "\(idx + 1)")
        lbl.font = .boldSystemFont(ofSize: 56); lbl.textColor = .white; lbl.alignment = .center
        lbl.frame = NSRect(x: 0, y: 15, width: 180, height: 70)
        badge.contentView?.addSubview(lbl)
        badge.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { badge.orderOut(nil) }
    }

    @objc private func bulbsControlChanged() {
        draft.colorMode = ColorMode(rawValue: max(0, colorPopup.indexOfSelectedItem)) ?? .redGreen
        draft.location = BulbLocation(rawValue: max(0, locationPopup.indexOfSelectedItem)) ?? .top
        draft.drawMode = DrawMode(rawValue: max(0, drawModePopup.indexOfSelectedItem)) ?? .desktop
        draft.transparency = transparencyCheck.state == .on
        draft.bulbSize = (largeSizeRadio.state == .on) ? .large : .normal
        draft.bareWire = bareWireCheck.state == .on
        draft.noCorners = noCornersCheck.state == .on
        draft.notSoMany = notSoManyCheck.state == .on
        draft.noFlicker = noFlickerCheck.state == .on
        draft.broken = brokenCheck.state == .on
        draft.burnedOut = burnedOutCheck.state == .on
        draft.missing = missingCheck.state == .on
        draft.randomProperties = randomPropsCheck.state == .on
        draft.mixBulbs = mixBulbsCheck.state == .on
        if draft.lightingCategory == .modern {
            var m = draft.modernEffects; m.reverseDirection = (reverseCheck.state == .on); draft.modernEffects = m
        } else {
            draft.reverse = reverseCheck.state == .on
        }
        draft.inward = inwardCheck.state == .on
        draft.useAllMonitors = useAllMonitorsCheck.state == .on
        draft.drawMonitorIndex = max(0, monitorPopup.indexOfSelectedItem)
        draft.bulbChanger = bulbChangerCheck.state == .on
        draft.bulbChangeOrder = max(0, bulbChangerOrderPopup.indexOfSelectedItem)
        draft.bulbChangeFreqMinutes = max(1, bulbChangerFreqField.integerValue)
        monitorPopup.isEnabled = !draft.useAllMonitors
        AudioEngineService.shared.playEffect(.softTick, enabled: draft.soundFX)
        updatePreviews()
    }

    @objc private func generalControlChanged() {
        draft.trayIconIndex = max(0, trayIconPopup.indexOfSelectedItem)
        draft.trayLeftClick = TrayClickAction(rawValue: leftClickPopup.indexOfSelectedItem) ?? .configuration
        draft.trayRightClick = TrayClickAction(rawValue: rightClickPopup.indexOfSelectedItem) ?? .popupMenu
        draft.trayMiddleClick = TrayClickAction(rawValue: middleClickPopup.indexOfSelectedItem) ?? .popupMenu
        draft.splashScreen = splashCheck.state == .on
        draft.toolTips = toolTipsCheck.state == .on
        draft.warningMsgs = warningMsgsCheck.state == .on
        draft.soundFX = soundFXCheck.state == .on
        draft.flashIcon = flashIconCheck.state == .on
        draft.quickAccess = quickAccessCheck.state == .on
        draft.confirmExit = confirmExitCheck.state == .on
        draft.runSSOnly = runSSOnlyCheck.state == .on
        draft.startupCalendar = startupCalendarCheck.state == .on
        draft.startupOptions = startupOptionsCheck.state == .on
        draft.enhancedMenu = enhancedMenuCheck.state == .on
        draft.zoom = zoomCheck.state == .on
        draft.reduceMotion = reduceMotionCheck.state == .on
        let cpuVal = max(0, min(4, cpuPrioritySlider.integerValue))
        draft.cpuPriority = cpuVal
        cpuPriorityLabel.stringValue = ["Idle", "Low", "Normal", "High", "Realtime"][cpuVal]
        draft.sysColorHighlight = sysHighlightCheck.state == .on
        draft.highlightColorHex = highlightWell.color.hexString
        highlightWell.isEnabled = !draft.sysColorHighlight
        AudioEngineService.shared.playEffect(.softTick, enabled: draft.soundFX)
        updatePreviews()
    }

    func updatePreviews() {
        monitorPreview.configure(with: draft)
        bulbSetStrandPreview.settings = draft
        flashingStrandPreview.configure(with: draft)
        colorSwatchView.image = ColorModeSwatchRenderer.swatchImage(for: draft.colorMode, width: 56, height: 18)

        let meta = BulbArtworkRegistry.shared.metadata(for: draft.bulbSetName)
        colorNoticeLabel.stringValue = (meta?.supportsColorModes == false)
            ? "Note: This fixed-art seasonal set preserves its hand-painted colors."
            : "Selected: \(draft.colorMode.displayName)"

        if let cg = BulbArtworkRegistry.shared.sampleImage(for: draft.bulbSetName) {
            sampleImageView.image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
    }

    @objc private func toggleLightsQuick() {
        draft.lightsEnabled.toggle()
        lightsOnQuickBtn.title = draft.lightsEnabled ? "Lights: On" : "Lights: Off"
        AudioEngineService.shared.playEffect(.click, enabled: draft.soundFX)
        updatePreviews()
        applyPressed()
    }

    @objc private func showBulbProperties() {
        guard let meta = BulbArtworkRegistry.shared.metadata(for: draft.bulbSetName) else { return }
        let alert = NSAlert()
        alert.messageText = meta.title
        alert.informativeText =
            "Collection: \(meta.collection.displayName)\nAuthor: \(meta.author)\nVersion: \(meta.version)\n" +
            "Monochrome: \(meta.isMonochrome ? "Yes" : "No") | On-Only Dim: \(meta.isOnOnly ? "Yes" : "No")\n\n\(meta.comment)"
        alert.runModal()
    }

    @objc private func importBulbAssets() {
        let panel = NSOpenPanel()
        panel.title = "Import .blb / .icl / .ico / .blz Bulb Sets"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            let destDir = BulbArtworkRegistry.importedBulbsDirectory
            var importedCount = 0
            for url in panel.urls {
                let dest = destDir.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: dest)
                if (try? FileManager.default.copyItem(at: url, to: dest)) != nil {
                    importedCount += 1
                }
            }
            if importedCount > 0 {
                BulbArtworkRegistry.shared.reloadAllSets(size: draft.bulbSize.pixels, highlightHex: draft.sysColorHighlight ? "#000080" : draft.highlightColorHex)
                refreshFilteredBulbSets(selecting: draft.bulbSetName)
                updatePreviews()
            }
        }
    }

    @objc func applyPressed() {
        secondaryTabs.commitFieldsIntoDraft()
        modernPanel.commitFieldsIntoDraft()
        SettingsStore.shared.settings = draft
        onApplySettings?(draft)
        AudioEngineService.shared.playEffect(.click, enabled: draft.soundFX)
    }

    @objc private func okPressed() {
        applyPressed()
        flashingStrandPreview.stopPreview()
        window?.orderOut(nil)
    }

    @objc private func cancelPressed() {
        flashingStrandPreview.stopPreview()
        window?.orderOut(nil)
    }

    @objc private func resetDefaultsPressed() {
        let def = AppSettings.defaultSettings()
        loadFromSettings(def)
        SettingsStore.shared.settings = def
        onApplySettings?(def)
    }
}

// MARK: - Classic Windows XP Header Strip

private final class XPClassicHeaderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cols = [
            NSColor(srgbRed: 0.02, green: 0.34, blue: 0.89, alpha: 1.0).cgColor,
            NSColor(srgbRed: 0.24, green: 0.58, blue: 1.0, alpha: 1.0).cgColor
        ] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: bounds.width, y: 0), options: [])
        }
        ctx.setFillColor(NSColor(srgbRed: 0.0, green: 0.20, blue: 0.65, alpha: 1.0).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: bounds.width, height: 1.5))

        if let sample = BulbArtworkRegistry.shared.sampleImage(for: "Outdoor") {
            ctx.draw(sample, in: CGRect(x: 10, y: 5, width: 24, height: 24))
        }
        let title = "Re: Twinkle Bulbs — Version 7: Next Generation (v7.0.0)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor.white
        ]
        title.draw(at: CGPoint(x: 42, y: 9), withAttributes: attrs)
    }
}
