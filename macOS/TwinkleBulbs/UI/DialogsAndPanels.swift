import Cocoa

// MARK: - Quick Access Floating Bar (DIALOG QuickAccess)

public final class QuickAccessPanelController: NSWindowController {
    private let lightsBtn = NSButton()
    private let musicBtn = NSButton()
    private let flashPopup = NSPopUpButton()
    private let colorPopup = NSPopUpButton()

    var onOpenSettings: (() -> Void)?
    var onStartSaver: (() -> Void)?
    var onSettingsChanged: ((AppSettings) -> Void)?

    public convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 120, y: 120, width: 490, height: 42),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Re: Twinkle Bulbs Quick Access"
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        self.init(window: panel)
        buildUI()
        refresh()
    }

    private func buildUI() {
        guard let root = window?.contentView else { return }
        let stack = NSStackView(frame: root.bounds.insetBy(dx: 8, dy: 6))
        stack.autoresizingMask = [.width, .height]
        stack.orientation = .horizontal
        stack.spacing = 6

        lightsBtn.bezelStyle = .rounded
        lightsBtn.target = self
        lightsBtn.action = #selector(toggleLights)

        flashPopup.addItems(withTitles: FlashMode.allCases.map(\.displayName))
        flashPopup.target = self
        flashPopup.action = #selector(changeFlash)

        colorPopup.addItems(withTitles: ColorMode.allCases.map(\.displayName))
        colorPopup.target = self
        colorPopup.action = #selector(changeColor)

        musicBtn.bezelStyle = .rounded
        musicBtn.target = self
        musicBtn.action = #selector(toggleMusic)

        let ssBtn = NSButton(title: "Saver", target: self, action: #selector(runSaver))
        ssBtn.bezelStyle = .rounded

        let gearBtn = NSButton(title: "Settings", target: self, action: #selector(openSettings))
        gearBtn.bezelStyle = .rounded

        for v: NSView in [lightsBtn, flashPopup, colorPopup, musicBtn, ssBtn, gearBtn] {
            stack.addArrangedSubview(v)
        }
        root.addSubview(stack)
    }

    func refresh() {
        let s = SettingsStore.shared.settings
        lightsBtn.title = s.lightsEnabled ? "Lights On" : "Lights Off"
        flashPopup.selectItem(at: s.flashMode.rawValue)
        colorPopup.selectItem(at: s.colorMode.rawValue)
        musicBtn.title = AudioEngineService.shared.isPlaying ? "Stop Music" : "Music"
    }

    @objc private func toggleLights() {
        var s = SettingsStore.shared.settings
        s.lightsEnabled.toggle()
        SettingsStore.shared.settings = s
        onSettingsChanged?(s)
        AudioEngineService.shared.playEffect(.click, enabled: s.soundFX)
        refresh()
    }

    @objc private func changeFlash() {
        var s = SettingsStore.shared.settings
        if let fm = FlashMode(rawValue: flashPopup.indexOfSelectedItem) {
            s.flashMode = fm
            SettingsStore.shared.settings = s
            onSettingsChanged?(s)
            AudioEngineService.shared.playEffect(.softTick, enabled: s.soundFX)
        }
    }

    @objc private func changeColor() {
        var s = SettingsStore.shared.settings
        if let cm = ColorMode(rawValue: colorPopup.indexOfSelectedItem) {
            s.colorMode = cm
            SettingsStore.shared.settings = s
            onSettingsChanged?(s)
            AudioEngineService.shared.playEffect(.softTick, enabled: s.soundFX)
        }
    }

    @objc private func toggleMusic() {
        let s = SettingsStore.shared.settings
        AudioEngineService.shared.togglePlayStop(settings: s)
        refresh()
    }

    @objc private func runSaver() { onStartSaver?() }
    @objc private func openSettings() { onOpenSettings?() }
}

// MARK: - Splash Screen Window (bmp_138 style)

final class SplashWindowController: NSWindowController {
    private final class SplashCanvas: NSView {
        override func draw(_ dirtyRect: NSRect) {
            let ctx = NSGraphicsContext.current!.cgContext
            let cols = [NSColor(srgbRed: 0.05, green: 0.14, blue: 0.24, alpha: 1).cgColor,
                        NSColor(srgbRed: 0.02, green: 0.05, blue: 0.11, alpha: 1).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
                ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: bounds.height), options: [])
            }
            NSColor(srgbRed: 0.85, green: 0.72, blue: 0.25, alpha: 0.85).setStroke()
            let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 10, yRadius: 10)
            border.lineWidth = 2
            border.stroke()

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 26),
                .foregroundColor: NSColor(srgbRed: 1.0, green: 0.90, blue: 0.35, alpha: 1.0)
            ]
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor(white: 0.90, alpha: 0.9)
            ]
            ("Re: Twinkle Bulbs" as NSString).draw(at: NSPoint(x: 72, y: 184), withAttributes: titleAttrs)
            ("Version 7: Next Generation • v7.0.0" as NSString).draw(at: NSPoint(x: 56, y: 152), withAttributes: subAttrs)
            ("Tribute to Don Metzler & Barefoot Productions" as NSString).draw(at: NSPoint(x: 34, y: 122), withAttributes: subAttrs)
        }
    }

    private static var retainedSplashWindow: NSWindow?

    static func showBriefly() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 364, height: 280),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .floating
        win.center()
        let v = SplashCanvas(frame: win.contentView!.bounds)
        win.contentView = v

        let engine = BulbEngine(settings: .defaultSettings())
        let strip = BulbCanvasView(frame: NSRect(x: 0, y: 12, width: 364, height: 32))
        strip.engine = engine
        var s = AppSettings.defaultSettings(); s.flashMode = .none; s.colorMode = .multiColor
        engine.configure(bounds: CGRect(x: 0, y: 0, width: 364, height: 32), settings: s)
        strip.currentSettings = s
        v.addSubview(strip)

        retainedSplashWindow = win
        win.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            win.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if retainedSplashWindow === win {
                    retainedSplashWindow = nil
                }
            }
        }
    }
}

// MARK: - Tip of the Day Window (DIALOG/280)

final class TipOfTheDayWindowController: NSWindowController {
    private let tipTextView = NSTextField(wrappingLabelWithString: "")
    private let indexLabel = NSTextField(labelWithString: "")
    private let showStartupCheck = NSButton(checkboxWithTitle: "Show Tips at Startup", target: nil, action: nil)

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Tip of the Day"
        win.isReleasedWhenClosed = false
        win.center()
        self.init(window: win)
        buildUI()
        showCurrentTip()
    }

    private func buildUI() {
        guard let root = window?.contentView else { return }

        let header = NSTextField(labelWithString: "Did you know...")
        header.font = .boldSystemFont(ofSize: 16)
        header.frame = NSRect(x: 20, y: 196, width: 300, height: 24)
        root.addSubview(header)

        indexLabel.alignment = .right
        indexLabel.textColor = .secondaryLabelColor
        indexLabel.frame = NSRect(x: 340, y: 198, width: 100, height: 20)
        root.addSubview(indexLabel)

        let box = NSBox(frame: NSRect(x: 20, y: 66, width: 420, height: 120))
        box.titlePosition = .noTitle
        tipTextView.font = .systemFont(ofSize: 13)
        tipTextView.frame = NSRect(x: 12, y: 12, width: 392, height: 92)
        box.contentView?.addSubview(tipTextView)
        root.addSubview(box)

        showStartupCheck.frame = NSRect(x: 20, y: 22, width: 175, height: 22)
        showStartupCheck.state = SettingsStore.shared.settings.showTipsOnStartup ? .on : .off
        showStartupCheck.target = self
        showStartupCheck.action = #selector(toggleStartup)
        root.addSubview(showStartupCheck)

        let prevBtn = NSButton(title: "Previous", target: self, action: #selector(prevTip))
        prevBtn.frame = NSRect(x: 205, y: 18, width: 76, height: 28)
        let nextBtn = NSButton(title: "Next Tip", target: self, action: #selector(nextTip))
        nextBtn.frame = NSRect(x: 286, y: 18, width: 76, height: 28)
        let closeBtn = NSButton(title: "Close", target: self, action: #selector(closeWin))
        closeBtn.frame = NSRect(x: 367, y: 18, width: 73, height: 28)
        closeBtn.keyEquivalent = "\r"
        root.addSubview(prevBtn); root.addSubview(nextBtn); root.addSubview(closeBtn)
    }

    private func showCurrentTip() {
        let tips = CalendarService.tipsOfTheDay
        let idx = abs(SettingsStore.shared.settings.lastTipIndex) % tips.count
        tipTextView.stringValue = tips[idx]
        indexLabel.stringValue = "Tip \(idx + 1) of \(tips.count)"
    }

    @objc private func nextTip() {
        var s = SettingsStore.shared.settings
        s.lastTipIndex = (s.lastTipIndex + 1) % CalendarService.tipsOfTheDay.count
        SettingsStore.shared.settings = s
        showCurrentTip()
    }

    @objc private func prevTip() {
        var s = SettingsStore.shared.settings
        let total = CalendarService.tipsOfTheDay.count
        s.lastTipIndex = (s.lastTipIndex - 1 + total) % total
        SettingsStore.shared.settings = s
        showCurrentTip()
    }

    @objc private func toggleStartup() {
        var s = SettingsStore.shared.settings
        s.showTipsOnStartup = (showStartupCheck.state == .on)
        SettingsStore.shared.settings = s
    }

    @objc private func closeWin() {
        window?.orderOut(nil)
    }
}

// MARK: - About Window (DIALOG/100)

public final class AboutWindowController: NSWindowController {
    public var onOpenHistoryAndManual: (() -> Void)?

    public convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "About Re: Twinkle Bulbs — Version 7: Next Generation"
        win.appearance = NSAppearance(named: .aqua)
        win.isReleasedWhenClosed = false
        win.center()
        self.init(window: win)

        guard let root = win.contentView else { return }
        let title = NSTextField(labelWithString: "Re: Twinkle Bulbs — Version 7: Next Generation (v7.0.0)")
        title.font = .boldSystemFont(ofSize: 16.5)
        title.frame = NSRect(x: 24, y: 294, width: 472, height: 26)
        root.addSubview(title)

        let body = NSTextField(wrappingLabelWithString:
            "A restored recreation bringing Twinkle Bulbs back from the dead for a new era.\n\n" +
            "Revival Timeline: Started in 2025 with Google Antigravity -> April 2026 intermediate builds -> " +
            "November 2026 complete faithful recreation matching the authentic original behavior, plus " +
            "Complete Holiday Edition (265 bulb sets, 25 screensavers, 130 wallpapers, 105 GM carols on TwinkleSynth DSP) " +
            "and Next-Generation platform (16 Holiday Scenes, Automation, Effect & MIDI Studios, Virtual Layouts, Web/API Remote).\n\n" +
            "Distributed out of love for the original program, to keep its memory alive. " +
            "All credit goes to the original authors: Don Metzler and Barefoot Productions.\n" +
            "License: Freeware — may be freely shared and modified as desired."
        )
        body.font = .systemFont(ofSize: 12)
        body.frame = NSRect(x: 24, y: 66, width: 472, height: 222)
        root.addSubview(body)

        let docsBtn = NSButton(title: "Full History & Manual...", target: self, action: #selector(openFullDocs))
        docsBtn.bezelStyle = .rounded
        docsBtn.frame = NSRect(x: 24, y: 20, width: 185, height: 28)
        root.addSubview(docsBtn)

        let ok = NSButton(title: "OK", target: win, action: #selector(NSWindow.orderOut(_:)))
        ok.frame = NSRect(x: 416, y: 20, width: 80, height: 28)
        ok.keyEquivalent = "\r"
        root.addSubview(ok)
    }

    @objc private func openFullDocs() {
        onOpenHistoryAndManual?()
    }
}

// MARK: - Complete History, Architecture Manual & Freeware Tribute Window

public final class DocumentationWindowController: NSWindowController {
    private let tabView = NSTabView()

    public init() {
        let win = NSWindow(
            contentRect: NSRect(x: 150, y: 110, width: 780, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Re: Twinkle Bulbs Version 7 — Full History, System Documentation & Credits"
        win.minSize = NSSize(width: 640, height: 420)
        win.appearance = NSAppearance(named: .aqua)
        win.isReleasedWhenClosed = false
        super.init(window: win)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showDocumentation(tabIndex: Int = 0) {
        if tabIndex >= 0 && tabIndex < tabView.numberOfTabViewItems {
            tabView.selectTabViewItem(at: tabIndex)
        }
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

        tabView.addTabViewItem(makeTextTab(id: "history", label: "Restoration History", text: ProgramDocumentation.restorationHistoryText))
        tabView.addTabViewItem(makeTextTab(id: "manual", label: "How Everything Works (Manual)", text: ProgramDocumentation.technicalArchitectureAndManual))
        tabView.addTabViewItem(makeTextTab(id: "credits", label: "Credits & Freeware License", text: ProgramDocumentation.tributeAndFreewareBanner))
    }

    private func makeTextTab(id: String, label: String, text: String) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: id)
        item.label = label
        let container = NSView()
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.font = NSFont.systemFont(ofSize: 12.5)
        tv.textContainerInset = NSSize(width: 10, height: 10)
        tv.string = text
        scroll.documentView = tv
        container.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6)
        ])
        item.view = container
        return item
    }
}

// MARK: - Holiday & Events Calendar Viewer (DIALOG/259)

final class CalendarViewerController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let countdownLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Re: Twinkle Bulbs Event Calendar"
        win.isReleasedWhenClosed = false
        win.center()
        self.init(window: win)
        buildUI()
        refresh()
    }

    private func buildUI() {
        guard let root = window?.contentView else { return }
        countdownLabel.font = .boldSystemFont(ofSize: 14)
        countdownLabel.frame = NSRect(x: 20, y: 298, width: 480, height: 22)
        root.addSubview(countdownLabel)

        let scroll = NSScrollView(frame: NSRect(x: 20, y: 60, width: 480, height: 226))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let cDate = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        cDate.title = "Date"
        cDate.width = 76
        let cTitle = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        cTitle.title = "Event"
        cTitle.width = 140
        let cMsg = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("msg"))
        cMsg.title = "Startup Greeting Message"
        cMsg.width = 240

        tableView.addTableColumn(cDate)
        tableView.addTableColumn(cTitle)
        tableView.addTableColumn(cMsg)
        tableView.dataSource = self
        tableView.delegate = self
        scroll.documentView = tableView
        root.addSubview(scroll)

        let addBtn = NSButton(title: "Add Event...", target: self, action: #selector(addEvent))
        addBtn.frame = NSRect(x: 20, y: 18, width: 110, height: 28)
        let delBtn = NSButton(title: "Remove Selected", target: self, action: #selector(removeEvent))
        delBtn.frame = NSRect(x: 138, y: 18, width: 130, height: 28)
        let okBtn = NSButton(title: "Close", target: window, action: #selector(NSWindow.orderOut(_:)))
        okBtn.frame = NSRect(x: 420, y: 18, width: 80, height: 28)
        okBtn.keyEquivalent = "\r"
        root.addSubview(addBtn); root.addSubview(delBtn); root.addSubview(okBtn)
    }

    func refresh() {
        let s = SettingsStore.shared.settings
        countdownLabel.stringValue = CalendarService.shared.countdownSummary(settings: s)?.headline ?? "No holiday countdown selected"
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        SettingsStore.shared.settings.calendarEvents.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let ev = SettingsStore.shared.settings.calendarEvents[row]
        let txt: String
        switch tableColumn?.identifier.rawValue {
        case "date": txt = String(format: "%02d/%02d", ev.month, ev.day)
        case "title": txt = ev.title
        default: txt = ev.message
        }
        let tf = NSTextField(labelWithString: txt)
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }

    @objc private func addEvent() {
        let alert = NSAlert()
        alert.messageText = "Add Calendar Event"
        alert.informativeText = "Enter event title, month/day, and greeting message."
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 280, height: 84))
        stack.orientation = .vertical
        let titleF = NSTextField(string: "Special Celebration")
        let dateF = NSTextField(string: "12/25")
        let msgF = NSTextField(string: "Happy Holidays!")
        stack.addArrangedSubview(titleF); stack.addArrangedSubview(dateF); stack.addArrangedSubview(msgF)
        alert.accessoryView = stack
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let parts = dateF.stringValue.split(separator: "/")
            let m = parts.count == 2 ? (Int(parts[0]) ?? 12) : 12
            let d = parts.count == 2 ? (Int(parts[1]) ?? 25) : 25
            var s = SettingsStore.shared.settings
            s.calendarEvents.append(CalendarEventItem(title: titleF.stringValue, month: max(1, min(12, m)), day: max(1, min(31, d)), message: msgF.stringValue))
            SettingsStore.shared.settings = s
            refresh()
        }
    }

    @objc private func removeEvent() {
        let row = tableView.selectedRow
        guard row >= 0, row < SettingsStore.shared.settings.calendarEvents.count else { return }
        var s = SettingsStore.shared.settings
        s.calendarEvents.remove(at: row)
        SettingsStore.shared.settings = s
        refresh()
    }
}
