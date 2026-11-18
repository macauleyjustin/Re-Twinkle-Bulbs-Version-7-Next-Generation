import Cocoa
import CoreGraphics

// MARK: - Interactive 24-Door Christmas Advent Calendar (Part D Section 10.B)

public final class AdventCalendarWindowController: NSWindowController {
    private var doorButtons: [NSButton] = []
    private let previewAnyDateCheck = NSButton(checkboxWithTitle: "Allow Opening Any Date (Preview Mode)", target: nil, action: nil)
    private let detailImage = NSImageView()
    private let detailTitle = NSTextField(labelWithString: "Select a numbered Advent door (December 1 – 24)")
    private let detailBody = NSTextField(wrappingLabelWithString: "Each door unlocks on its corresponding December date and reveals an original holiday illustration & greeting.")
    private let statsLabel = NSTextField(labelWithString: "")

    private static let adventMessages: [(String, String, Int)] = [
        ("Day 1 — First Light", "Untangle the warm holiday strands and welcome December!", 1),
        ("Day 2 — Winter Pine", "Boughs of evergreen bring cozy fragrance indoors.", 125),
        ("Day 3 — Candle Glow", "A single candle illuminates the crisp winter night.", 40),
        ("Day 4 — Candy Cane Stripe", "Sweet peppermint twists hang from the branches.", 11),
        ("Day 5 — Jingling Sleigh", "Listen closely for sleigh bells across the frost.", 48),
        ("Day 6 — St. Nicholas Boot", "Tiny boots lined neatly beside the warm hearth.", 50),
        ("Day 7 — Paper Snowflake", "No two falling crystals ever share the same pattern.", 21),
        ("Day 8 — Holly & Ivy", "Crimson berries and emerald leaves deck the halls.", 12),
        ("Day 9 — Frosty Snowman", "Built with a top hat, scarf, and carrot smile.", 28),
        ("Day 10 — Peppermint Treat", "Swirls of sugar and cool winter mint.", 51),
        ("Day 11 — Toy Soldier", "Marching briskly beneath the sparkling pine needles.", 41),
        ("Day 12 — Halfway There", "Twelve sparkling nights until Christmas Eve!", 14),
        ("Day 13 — Winter Mitten", "Warm wool mittens for sledding down snowy hills.", 23),
        ("Day 14 — Gingerbread House", "Candied rooftops and frosted icing trim.", 54),
        ("Day 15 — Golden Bell", "Ring out tidings of comfort and festive joy.", 17),
        ("Day 16 — Coziest Cocoa", "Steaming cinnamon cocoa beside crackling logs.", 196),
        ("Day 17 — Snow Globe Magic", "Shake gently and watch a tiny winter world swirl.", 30),
        ("Day 18 — Stockings Hung", "Hung by the chimney with festive care.", 19),
        ("Day 19 — Nutcracker Suite", "Curtain up for dances beneath the Christmas tree.", 42),
        ("Day 20 — Peaceful Dove", "Snow-white wings over silent moonlit rooftops.", 36),
        ("Day 21 — Winter Solstice", "The longest night shines brightest with holiday bulbs.", 212),
        ("Day 22 — Wrapped Presents", "Ribbons tied tight beneath twinkling pine branches.", 20),
        ("Day 23 — Reindeer Watch", "Antlers etched softly against the northern stars.", 49),
        ("Day 24 — Christmas Eve", "The Bethlehem star beams brightly—Merry Christmas Eve!", 31)
    ]

    public convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 470),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Re: Twinkle Bulbs — Interactive Christmas Advent Calendar"
        win.appearance = NSAppearance(named: .aqua)
        win.center()
        win.isReleasedWhenClosed = false
        self.init(window: win)
        buildUI()
        refresh()
    }

    private func buildUI() {
        guard let root = window?.contentView else { return }
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(srgbRed: 0.92, green: 0.91, blue: 0.85, alpha: 1.0).cgColor

        let header = NSTextField(labelWithString: "24-Day Christmas Advent Calendar")
        header.font = .boldSystemFont(ofSize: 16)
        header.frame = NSRect(x: 18, y: 428, width: 340, height: 24)
        root.addSubview(header)

        previewAnyDateCheck.frame = NSRect(x: 372, y: 430, width: 292, height: 22)
        previewAnyDateCheck.target = self
        previewAnyDateCheck.action = #selector(togglePreviewMode)
        root.addSubview(previewAnyDateCheck)

        // Left 6x4 numbered Advent doors grid
        let gridBox = NSBox(frame: NSRect(x: 16, y: 62, width: 396, height: 356))
        gridBox.title = "December 1 – 24 Doors"
        let cols = 6
        let btnW: CGFloat = 56, btnH: CGFloat = 68, gap: CGFloat = 6
        for i in 0..<24 {
            let day = i + 1
            let col = i % cols
            let row = i / cols
            let x = 14 + CGFloat(col) * (btnW + gap)
            let y = 248 - CGFloat(row) * (btnH + gap)
            let btn = NSButton(frame: NSRect(x: x, y: y, width: btnW, height: btnH))
            btn.bezelStyle = .rounded
            btn.tag = day
            btn.title = "\(day)"
            btn.target = self
            btn.action = #selector(doorPressed(_:))
            gridBox.contentView?.addSubview(btn)
            doorButtons.append(btn)
        }
        root.addSubview(gridBox)

        // Right reveal panel
        let revealBox = NSBox(frame: NSRect(x: 424, y: 62, width: 240, height: 356))
        revealBox.title = "Daily Surprise"
        detailImage.frame = NSRect(x: 54, y: 196, width: 128, height: 128)
        detailImage.imageScaling = .scaleProportionallyUpOrDown
        detailTitle.font = .boldSystemFont(ofSize: 13.5)
        detailTitle.frame = NSRect(x: 12, y: 156, width: 214, height: 32)
        detailBody.frame = NSRect(x: 12, y: 36, width: 214, height: 112)
        for v: NSView in [detailImage, detailTitle, detailBody] {
            revealBox.contentView?.addSubview(v)
        }
        root.addSubview(revealBox)

        statsLabel.frame = NSRect(x: 18, y: 20, width: 340, height: 20)
        statsLabel.textColor = .secondaryLabelColor
        root.addSubview(statsLabel)

        let closeBtn = NSButton(title: "Close", target: window, action: #selector(NSWindow.orderOut(_:)))
        closeBtn.frame = NSRect(x: 576, y: 16, width: 88, height: 28)
        root.addSubview(closeBtn)
    }

    public func refresh() {
        let s = SettingsStore.shared.settings
        previewAnyDateCheck.state = s.adventAllowAnyDatePreview ? .on : .off
        let opened = s.openedAdventDoors
        for btn in doorButtons {
            let day = btn.tag
            if opened.contains(day) {
                btn.title = "★ \(day)"
            } else {
                btn.title = "\(day)"
            }
        }
        statsLabel.stringValue = "Opened \(opened.count) of 24 doors (persisted across launches)"
    }

    public func canOpenDoor(day: Int, on date: Date = Date(), settings: AppSettings) -> Bool {
        guard day >= 1 && day <= 24 else { return false }
        if settings.adventAllowAnyDatePreview { return true }
        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let dom = cal.component(.day, from: date)
        if month == 12 { return dom >= day }
        return false
    }

    @objc private func togglePreviewMode() {
        var s = SettingsStore.shared.settings
        s.adventAllowAnyDatePreview = previewAnyDateCheck.state == .on
        SettingsStore.shared.settings = s
        refresh()
    }

    @objc private func doorPressed(_ sender: NSButton) {
        let day = sender.tag
        var s = SettingsStore.shared.settings
        if !canOpenDoor(day: day, settings: s) {
            detailTitle.stringValue = "December \(day) — Locked"
            detailBody.stringValue = "This door unlocks on December \(day). Check 'Allow Opening Any Date' above if you would like to preview it early."
            detailImage.image = nil
            AudioEngineService.shared.playEffect(.softTick, enabled: s.soundFX)
            return
        }

        var opened = s.openedAdventDoors
        opened.insert(day)
        s.openedAdventDoors = opened
        SettingsStore.shared.settings = s
        AudioEngineService.shared.playEffect(.celebrate, enabled: s.soundFX)

        let info = Self.adventMessages[min(day - 1, Self.adventMessages.count - 1)]
        detailTitle.stringValue = info.0
        detailBody.stringValue = info.1
        let setID = String(format: "holiday250:%03d", info.2)
        if let cg = BulbArtworkRegistry.shared.sampleImage(for: setID) {
            detailImage.image = NSImage(cgImage: cg, size: NSSize(width: 96, height: 96))
        }
        refresh()
    }
}
