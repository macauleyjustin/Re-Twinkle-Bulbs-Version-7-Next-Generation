import Cocoa
import UniformTypeIdentifiers

// MARK: - Interactive 2D Virtual Lighting Canvas

public final class VirtualLayoutCanvasView: NSView {
    public override var isFlipped: Bool { true }

    public var layoutDoc: VirtualLayoutDocument = VirtualLightingLayoutEngine.builtInSampleLayouts()[0] {
        didSet {
            loadBackgroundImageIfNeeded()
            needsDisplay = true
        }
    }
    public var selectedStrandID: String? = nil {
        didSet { needsDisplay = true }
    }
    public var timeSeconds: Double = 0.0 {
        didSet { needsDisplay = true }
    }
    public var baseSettings: AppSettings = .defaultSettings()

    public var onSelectStrand: ((String?) -> Void)?
    public var onUpdateStrandGeometry: ((String, Double, Double, Double, Double) -> Void)?

    private var cachedBgFilename: String? = nil
    private var cachedBgImage: NSImage? = nil

    private enum DragAction {
        case none
        case move(id: String, startNormX: Double, startNormY: Double, mouseStart: CGPoint)
        case resize(id: String, startW: Double, startH: Double, mouseStart: CGPoint)
    }
    private var dragAction: DragAction = .none

    private func loadBackgroundImageIfNeeded() {
        guard layoutDoc.backgroundImageFilename != cachedBgFilename else { return }
        cachedBgFilename = layoutDoc.backgroundImageFilename
        if let fn = cachedBgFilename {
            let url = VirtualLightingLayoutEngine.layoutAssetsDirectory.appendingPathComponent(fn)
            cachedBgImage = NSImage(contentsOf: url)
        } else {
            cachedBgImage = nil
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor(srgbRed: 0.05, green: 0.08, blue: 0.14, alpha: 1).cgColor)
        ctx.fill(bounds)

        if let img = cachedBgImage {
            img.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 0.55, respectFlipped: true, hints: nil)
        } else {
            // Subtle architectural blueprint grid
            ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.06).cgColor)
            ctx.setLineWidth(1.0)
            var x: CGFloat = 24
            while x < bounds.width {
                ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: bounds.height)); x += 24
            }
            var y: CGFloat = 24
            while y < bounds.height {
                ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: bounds.width, y: y)); y += 24
            }
            ctx.strokePath()
        }

        // Draw connecting wire paths for each strand
        for strand in layoutDoc.strands {
            let pts = VirtualLightingLayoutEngine.sampleStrandPoints(item: strand, inCanvasBounds: bounds)
            let isSelected = (strand.id == selectedStrandID)

            if pts.count >= 2 {
                ctx.setStrokeColor(isSelected ? NSColor.systemYellow.withAlphaComponent(0.65).cgColor : NSColor(white: 0.35, alpha: 0.65).cgColor)
                ctx.setLineWidth(isSelected ? 1.8 : 1.1)
                ctx.move(to: pts[0])
                for p in pts.dropFirst() { ctx.addLine(to: p) }
                if strand.shape == .wreath || strand.shape == .window || strand.shape == .yard {
                    ctx.closePath()
                }
                ctx.strokePath()
            }

            if isSelected {
                let box = CGRect(
                    x: CGFloat(strand.originX) * bounds.width,
                    y: CGFloat(strand.originY) * bounds.height,
                    width: CGFloat(strand.width) * bounds.width,
                    height: CGFloat(strand.height) * bounds.height
                )
                ctx.setStrokeColor(NSColor.systemYellow.cgColor)
                ctx.setLineDash(phase: 0, lengths: [5, 3])
                ctx.setLineWidth(1.5)
                ctx.stroke(box)
                ctx.setLineDash(phase: 0, lengths: [])

                // Bottom-right resize grip handle
                let grip = CGRect(x: box.maxX - 7, y: box.maxY - 7, width: 14, height: 14)
                ctx.setFillColor(NSColor.systemYellow.cgColor)
                ctx.fill(grip)
            }
        }

        // Draw animated virtual bulbs per strand artwork
        let nodes = VirtualLightingLayoutEngine.buildBulbNodes(for: layoutDoc, canvasBounds: bounds, timeSeconds: timeSeconds)
        for node in nodes {
            var s = baseSettings
            s.bulbSetName = node.bulbSetID
            BulbCanvasView.drawModernStates([node.state], settings: s, in: ctx)
        }
    }

    public override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)

        // Check selected resize grip first
        if let selID = selectedStrandID, let st = layoutDoc.strands.first(where: { $0.id == selID }) {
            let maxX = CGFloat(st.originX + st.width) * bounds.width
            let maxY = CGFloat(st.originY + st.height) * bounds.height
            let grip = CGRect(x: maxX - 10, y: maxY - 10, width: 20, height: 20)
            if grip.contains(p) {
                dragAction = .resize(id: selID, startW: st.width, startH: st.height, mouseStart: p)
                return
            }
        }

        // Hit-test strands top-down
        for st in layoutDoc.strands.reversed() {
            let box = CGRect(
                x: CGFloat(st.originX) * bounds.width - 8,
                y: CGFloat(st.originY) * bounds.height - 8,
                width: CGFloat(st.width) * bounds.width + 16,
                height: CGFloat(st.height) * bounds.height + 16
            )
            if box.contains(p) {
                onSelectStrand?(st.id)
                dragAction = .move(id: st.id, startNormX: st.originX, startNormY: st.originY, mouseStart: p)
                return
            }
        }
        onSelectStrand?(nil)
    }

    public override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let w = max(1, Double(bounds.width)), h = max(1, Double(bounds.height))
        switch dragAction {
        case .move(let id, let sx, let sy, let mStart):
            guard let st = layoutDoc.strands.first(where: { $0.id == id }) else { return }
            let nx = max(0, min(1 - st.width, sx + Double(p.x - mStart.x) / w))
            let ny = max(0, min(1 - st.height, sy + Double(p.y - mStart.y) / h))
            onUpdateStrandGeometry?(id, nx, ny, st.width, st.height)
        case .resize(let id, let sw, let sh, let mStart):
            guard let st = layoutDoc.strands.first(where: { $0.id == id }) else { return }
            let nw = max(0.06, min(1 - st.originX, sw + Double(p.x - mStart.x) / w))
            let nh = max(0.06, min(1 - st.originY, sh + Double(p.y - mStart.y) / h))
            onUpdateStrandGeometry?(id, st.originX, st.originY, nw, nh)
        case .none:
            break
        }
    }

    public override func mouseUp(with event: NSEvent) {
        dragAction = .none
    }
}

// MARK: - Virtual Lighting Layout Designer Window Controller

public final class VirtualLayoutDesignerWindowController: NSWindowController, NSWindowDelegate {
    private let layoutPopup = NSPopUpButton()
    private let canvasView = VirtualLayoutCanvasView()

    private let strandNameField = NSTextField(string: "")
    private let zoneField = NSTextField(string: "")
    private let shapePopup = NSPopUpButton()
    private let bulbSetPopup = NSPopUpButton()
    private let effectPopup = NSPopUpButton()
    private let palettePopup = NSPopUpButton()
    private let countSlider = NSSlider(value: 24, minValue: 4, maxValue: 120, target: nil, action: nil)
    private let rotSlider = NSSlider(value: 0, minValue: -180, maxValue: 180, target: nil, action: nil)
    private let spacingSlider = NSSlider(value: 1.0, minValue: 0.6, maxValue: 2.0, target: nil, action: nil)

    private var currentLayout: VirtualLayoutDocument
    private var selectedStrandID: String?
    private var animTimer: Timer?
    private var elapsed: Double = 0.0

    private let stateStore: NextGenStateStore
    private let settingsStore: SettingsStore

    public init(stateStore: NextGenStateStore = .shared, settingsStore: SettingsStore = .shared) {
        self.stateStore = stateStore
        self.settingsStore = settingsStore
        self.currentLayout = stateStore.state.layouts.first ?? VirtualLightingLayoutEngine.builtInSampleLayouts()[0]
        self.selectedStrandID = self.currentLayout.strands.first?.id

        let win = NSWindow(
            contentRect: NSRect(x: 130, y: 90, width: 920, height: 610),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Re: Twinkle Bulbs — Virtual Lighting Layout Designer (.twinklelayout)"
        win.minSize = NSSize(width: 800, height: 530)
        win.appearance = NSAppearance(named: .aqua)
        win.isReleasedWhenClosed = false
        super.init(window: win)
        win.delegate = self

        buildUI()
        refreshLayoutPopup()
        syncInspector()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showAndPreview() {
        refreshLayoutPopup()
        syncInspector()
        startPreviewTimer()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        animTimer?.invalidate()
        animTimer = nil
    }

    private func buildUI() {
        guard let root = window?.contentView else { return }

        func mkBtn(_ t: String, _ a: Selector) -> NSButton {
            let b = NSButton(title: t, target: self, action: a)
            b.bezelStyle = .rounded
            return b
        }

        layoutPopup.target = self; layoutPopup.action = #selector(selectLayout)
        let newBtn = mkBtn("New Layout", #selector(createNewLayout))
        let saveBtn = mkBtn("Save Layout", #selector(saveCurrentLayout))
        let bgBtn = mkBtn("Background Photo...", #selector(chooseBackgroundPhoto))
        let clrBgBtn = mkBtn("Clear BG", #selector(clearBackgroundPhoto))
        let expBtn = mkBtn("Export...", #selector(exportLayoutFile))
        let impBtn = mkBtn("Import...", #selector(importLayoutFile))
        let addStrandBtn = mkBtn("+ Add Strand", #selector(addStrand))
        let delStrandBtn = mkBtn("Remove Strand", #selector(removeSelectedStrand))

        let topBar = NSStackView(views: [
            layoutPopup, newBtn, saveBtn, bgBtn, clrBgBtn, expBtn, impBtn, addStrandBtn, delStrandBtn
        ])
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.orientation = .horizontal
        topBar.spacing = 6
        root.addSubview(topBar)

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.baseSettings = settingsStore.settings
        canvasView.onSelectStrand = { [weak self] id in
            self?.selectedStrandID = id
            self?.syncInspector()
        }
        canvasView.onUpdateStrandGeometry = { [weak self] id, ox, oy, w, h in
            self?.updateGeometry(id: id, ox: ox, oy: oy, w: w, h: h)
        }
        root.addSubview(canvasView)

        let insp = NSBox()
        insp.translatesAutoresizingMaskIntoConstraints = false
        insp.title = "Selected Strand & Zone Configuration"
        root.addSubview(insp)

        strandNameField.target = self; strandNameField.action = #selector(inspectorEdited)
        zoneField.target = self; zoneField.action = #selector(inspectorEdited)
        shapePopup.addItems(withTitles: VirtualStrandShape.allCases.map(\.rawValue))
        shapePopup.target = self; shapePopup.action = #selector(inspectorEdited)

        let bulbNames = BulbArtworkRegistry.shared.availableSets.map(\.id)
        bulbSetPopup.addItems(withTitles: bulbNames)
        bulbSetPopup.target = self; bulbSetPopup.action = #selector(inspectorEdited)

        effectPopup.addItems(withTitles: ModernEffectID.allCases.filter { $0 != .autoCycle }.map(\.displayName))
        effectPopup.target = self; effectPopup.action = #selector(inspectorEdited)

        palettePopup.addItems(withTitles: ModernColorPalette.allCases.map(\.displayName))
        palettePopup.target = self; palettePopup.action = #selector(inspectorEdited)

        countSlider.target = self; countSlider.action = #selector(inspectorEdited)
        rotSlider.target = self; rotSlider.action = #selector(inspectorEdited)
        spacingSlider.target = self; spacingSlider.action = #selector(inspectorEdited)

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Name:"), strandNameField],
            [NSTextField(labelWithString: "Zone ID:"), zoneField],
            [NSTextField(labelWithString: "Shape:"), shapePopup],
            [NSTextField(labelWithString: "Bulb Set:"), bulbSetPopup],
            [NSTextField(labelWithString: "Effect:"), effectPopup],
            [NSTextField(labelWithString: "Palette:"), palettePopup],
            [NSTextField(labelWithString: "Bulb Count:"), countSlider],
            [NSTextField(labelWithString: "Rotation:"), rotSlider],
            [NSTextField(labelWithString: "Spacing:"), spacingSlider]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        insp.contentView?.addSubview(grid)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            topBar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            topBar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),

            canvasView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 10),
            canvasView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            canvasView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            canvasView.trailingAnchor.constraint(equalTo: insp.leadingAnchor, constant: -12),

            insp.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 10),
            insp.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            insp.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            insp.widthAnchor.constraint(equalToConstant: 280),

            grid.topAnchor.constraint(equalTo: insp.contentView!.topAnchor, constant: 12),
            grid.leadingAnchor.constraint(equalTo: insp.contentView!.leadingAnchor, constant: 10),
            grid.trailingAnchor.constraint(equalTo: insp.contentView!.trailingAnchor, constant: -10)
        ])
    }

    private func startPreviewTimer() {
        animTimer?.invalidate()
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsed += 1.0 / 30.0
            self.canvasView.timeSeconds = self.elapsed
        }
    }

    private func allLayouts() -> [VirtualLayoutDocument] {
        var list = VirtualLightingLayoutEngine.builtInSampleLayouts()
        for l in stateStore.state.layouts where !list.contains(where: { $0.id == l.id }) {
            list.append(l)
        }
        return list
    }

    private func refreshLayoutPopup() {
        let docs = allLayouts()
        layoutPopup.removeAllItems()
        layoutPopup.addItems(withTitles: docs.map(\.name))
        if let idx = docs.firstIndex(where: { $0.id == currentLayout.id }) {
            layoutPopup.selectItem(at: idx)
        }
    }

    private func syncInspector() {
        canvasView.layoutDoc = currentLayout
        canvasView.selectedStrandID = selectedStrandID

        let strand = currentLayout.strands.first(where: { $0.id == selectedStrandID })
        let hasSel = (strand != nil)
        for ctrl in [strandNameField, zoneField, shapePopup, bulbSetPopup, effectPopup, palettePopup, countSlider, rotSlider, spacingSlider] as [NSControl] {
            ctrl.isEnabled = hasSel
        }
        guard let st = strand else { return }
        strandNameField.stringValue = st.name
        zoneField.stringValue = st.zoneID
        if let sIdx = VirtualStrandShape.allCases.firstIndex(of: st.shape) { shapePopup.selectItem(at: sIdx) }
        bulbSetPopup.selectItem(withTitle: st.bulbSetID)
        let fxList = ModernEffectID.allCases.filter { $0 != .autoCycle }
        if let fxIdx = fxList.firstIndex(of: st.assignedEffect) { effectPopup.selectItem(at: fxIdx) }
        if let pIdx = ModernColorPalette.allCases.firstIndex(of: st.palette) { palettePopup.selectItem(at: pIdx) }
        countSlider.doubleValue = Double(st.bulbCount)
        rotSlider.doubleValue = st.rotationDegrees
        spacingSlider.doubleValue = st.spacingScale
    }

    private func updateGeometry(id: String, ox: Double, oy: Double, w: Double, h: Double) {
        guard let idx = currentLayout.strands.firstIndex(where: { $0.id == id }) else { return }
        currentLayout.strands[idx].originX = ox
        currentLayout.strands[idx].originY = oy
        currentLayout.strands[idx].width = w
        currentLayout.strands[idx].height = h
        canvasView.layoutDoc = currentLayout
    }

    // MARK: - Actions

    @objc private func selectLayout() {
        let docs = allLayouts()
        let idx = layoutPopup.indexOfSelectedItem
        if idx >= 0 && idx < docs.count {
            currentLayout = docs[idx]
            selectedStrandID = currentLayout.strands.first?.id
            syncInspector()
        }
    }

    @objc private func createNewLayout() {
        let doc = VirtualLayoutDocument(
            id: "layout_user:\(UUID().uuidString.prefix(8))",
            name: "Custom Home Layout \(allLayouts().count + 1)",
            strands: [VirtualStrandItem(name: "Main Strand", shape: .roofline, zoneID: "main", originX: 0.1, originY: 0.2, width: 0.8, height: 0.3, bulbCount: 30)]
        )
        currentLayout = doc
        selectedStrandID = doc.strands.first?.id
        saveCurrentLayout()
    }

    @objc private func saveCurrentLayout() {
        var next = stateStore.state
        if let idx = next.layouts.firstIndex(where: { $0.id == currentLayout.id }) {
            next.layouts[idx] = currentLayout
        } else {
            if currentLayout.id.hasPrefix("layout:") {
                currentLayout.id = "layout_user:\(UUID().uuidString.prefix(8))"
            }
            next.layouts.append(currentLayout)
        }
        next.activeLayoutID = currentLayout.id
        stateStore.state = next
        refreshLayoutPopup()
        syncInspector()
    }

    @objc private func chooseBackgroundPhoto() {
        let op = NSOpenPanel()
        op.canChooseFiles = true
        op.allowedContentTypes = [.image]
        if op.runModal() == .OK, let url = op.url, let fn = VirtualLightingLayoutEngine.saveBackgroundImageLocalCopy(from: url) {
            currentLayout.backgroundImageFilename = fn
            syncInspector()
        }
    }

    @objc private func clearBackgroundPhoto() {
        currentLayout.backgroundImageFilename = nil
        syncInspector()
    }

    @objc private func exportLayoutFile() {
        guard let data = try? VirtualLightingLayoutEngine.exportLayout(currentLayout) else { return }
        let sp = NSSavePanel()
        sp.nameFieldStringValue = "\(currentLayout.name.replacingOccurrences(of: " ", with: "_")).twinklelayout"
        if sp.runModal() == .OK, let url = sp.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    @objc private func importLayoutFile() {
        let op = NSOpenPanel()
        op.canChooseFiles = true
        op.allowedContentTypes = [.json, UTType(filenameExtension: "twinklelayout")].compactMap { $0 }
        if op.runModal() == .OK, let url = op.url, let data = try? Data(contentsOf: url),
           var imp = try? VirtualLightingLayoutEngine.importLayout(data: data) {
            imp.id = "layout_user:\(UUID().uuidString.prefix(8))"
            currentLayout = imp
            selectedStrandID = imp.strands.first?.id
            saveCurrentLayout()
        }
    }

    @objc private func addStrand() {
        let st = VirtualStrandItem(
            name: "Strand \(currentLayout.strands.count + 1)",
            shape: .wreath,
            zoneID: "zone_\(currentLayout.strands.count + 1)",
            originX: 0.3, originY: 0.35, width: 0.25, height: 0.3, bulbCount: 24
        )
        currentLayout.strands.append(st)
        selectedStrandID = st.id
        syncInspector()
    }

    @objc private func removeSelectedStrand() {
        guard let selID = selectedStrandID else { return }
        currentLayout.strands.removeAll { $0.id == selID }
        selectedStrandID = currentLayout.strands.first?.id
        syncInspector()
    }

    @objc private func inspectorEdited() {
        guard let selID = selectedStrandID,
              let idx = currentLayout.strands.firstIndex(where: { $0.id == selID }) else { return }
        var st = currentLayout.strands[idx]
        if !strandNameField.stringValue.isEmpty { st.name = strandNameField.stringValue }
        if !zoneField.stringValue.isEmpty { st.zoneID = zoneField.stringValue }
        st.shape = VirtualStrandShape.allCases[max(0, shapePopup.indexOfSelectedItem)]
        if let bulbTitle = bulbSetPopup.selectedItem?.title { st.bulbSetID = bulbTitle }
        let fxList = ModernEffectID.allCases.filter { $0 != .autoCycle }
        let fIdx = max(0, effectPopup.indexOfSelectedItem)
        if fIdx < fxList.count { st.assignedEffect = fxList[fIdx] }
        st.palette = ModernColorPalette.allCases[max(0, palettePopup.indexOfSelectedItem)]
        st.bulbCount = Int(countSlider.doubleValue.rounded())
        st.rotationDegrees = rotSlider.doubleValue
        st.spacingScale = spacingSlider.doubleValue
        currentLayout.strands[idx] = st
        syncInspector()
    }
}
