import Cocoa
import UniformTypeIdentifiers

// MARK: - Live Preview Strand Driven by EffectTimelineEngine

public final class TimelineStrandPreviewView: NSView {
    public override var isFlipped: Bool { true }
    public var currentStates: [ModernBulbState] = [] {
        didSet { needsDisplay = true }
    }
    public var settings: AppSettings = .defaultSettings()

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor(srgbRed: 0.04, green: 0.07, blue: 0.14, alpha: 1).cgColor)
        ctx.fill(bounds)
        ctx.setStrokeColor(NSColor(white: 0.35, alpha: 1).cgColor)
        ctx.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))

        ctx.saveGState()
        let sy = max(0.1, bounds.height / 36.0)
        let sx = max(0.1, bounds.width / 512.0)
        ctx.scaleBy(x: sx, y: sy)
        BulbCanvasView.drawModernStates(currentStates, settings: settings, in: ctx)
        ctx.restoreGState()
    }
}

// MARK: - Interactive Multi-Track Timeline Canvas

public final class TimelineEditorCanvasView: NSView {
    public override var isFlipped: Bool { true }

    public var document: TimelineEffectDocument = EffectTimelineEngine.builtInSampleTimelines()[0] {
        didSet { needsDisplay = true }
    }
    public var playheadSeconds: Double = 0.0 {
        didSet { needsDisplay = true }
    }
    public var selectedTrackIndex: Int = 0 {
        didSet { needsDisplay = true }
    }
    public var selectedKeyframeID: String? = nil {
        didSet { needsDisplay = true }
    }

    public var onBeginEditGesture: (() -> Void)?
    public var onSelectKeyframe: ((Int, String?) -> Void)?
    public var onMoveKeyframe: ((Int, String, Double) -> Void)?
    public var onSeekPlayhead: ((Double) -> Void)?
    public var onAddKeyframeAt: ((Int, Double) -> Void)?

    private let leftLabelWidth: CGFloat = 150
    private let rulerHeight: CGFloat = 24
    private let rowHeight: CGFloat = 46

    private enum DragMode {
        case none
        case playhead
        case keyframe(trackIdx: Int, keyID: String)
    }
    private var dragMode: DragMode = .none

    private func xForTime(_ t: Double) -> CGFloat {
        let dur = max(0.5, document.durationSeconds)
        let usable = max(60, bounds.width - leftLabelWidth - 18)
        return leftLabelWidth + 8 + CGFloat(max(0, min(1, t / dur))) * usable
    }

    private func timeForX(_ x: CGFloat) -> Double {
        let dur = max(0.5, document.durationSeconds)
        let usable = max(60, bounds.width - leftLabelWidth - 18)
        let u = Double(max(0, min(1, (x - leftLabelWidth - 8) / usable)))
        return (u * dur * 20.0).rounded() / 20.0 // snap to 0.05s grid cleanly
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor(srgbRed: 0.13, green: 0.15, blue: 0.19, alpha: 1).cgColor)
        ctx.fill(bounds)

        // Top Time Ruler
        let rulerRect = CGRect(x: leftLabelWidth, y: 0, width: bounds.width - leftLabelWidth, height: rulerHeight)
        ctx.setFillColor(NSColor(srgbRed: 0.18, green: 0.21, blue: 0.26, alpha: 1).cgColor)
        ctx.fill(rulerRect)

        let dur = max(0.5, document.durationSeconds)
        let stepSec: Double = dur <= 8 ? 0.5 : (dur <= 20 ? 1.0 : 2.0)
        let rulerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .medium),
            .foregroundColor: NSColor(white: 0.85, alpha: 1)
        ]
        var sec = 0.0
        while sec <= dur + 0.001 {
            let x = xForTime(sec)
            ctx.setStrokeColor(NSColor(white: 0.45, alpha: 0.8).cgColor)
            ctx.move(to: CGPoint(x: x, y: rulerHeight - 8))
            ctx.addLine(to: CGPoint(x: x, y: bounds.height))
            ctx.strokePath()
            let lbl = String(format: "%.1fs", sec) as NSString
            lbl.draw(at: CGPoint(x: x + 2, y: 4), withAttributes: rulerAttrs)
            sec += stepSec
        }

        // Track Rows & Keyframes
        for (idx, tr) in document.tracks.enumerated() {
            let y = rulerHeight + CGFloat(idx) * rowHeight
            let isSelTrack = (idx == selectedTrackIndex)

            ctx.setFillColor((isSelTrack ? NSColor(srgbRed: 0.17, green: 0.21, blue: 0.29, alpha: 1) : (idx % 2 == 0 ? NSColor(white: 0.14, alpha: 1) : NSColor(white: 0.16, alpha: 1))).cgColor)
            ctx.fill(CGRect(x: 0, y: y, width: bounds.width, height: rowHeight))

            ctx.setFillColor(NSColor(srgbRed: 0.19, green: 0.22, blue: 0.27, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 0, y: y, width: leftLabelWidth, height: rowHeight - 1))

            let trAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: isSelTrack ? .semibold : .regular),
                .foregroundColor: tr.isMuted ? NSColor.secondaryLabelColor : NSColor.white
            ]
            (tr.name as NSString).draw(at: CGPoint(x: 8, y: y + 8), withAttributes: trAttrs)
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9.5),
                .foregroundColor: NSColor(white: 0.68, alpha: 1)
            ]
            ("\(tr.kind.rawValue) • \(tr.keyframes.count) keys" as NSString).draw(at: CGPoint(x: 8, y: y + 25), withAttributes: subAttrs)

            // Draw scalar / color transition line across sorted keyframes
            let sorted = tr.keyframes.sorted { $0.timeSeconds < $1.timeSeconds }
            if sorted.count >= 2 && (tr.kind == .brightness || tr.kind == .speed) {
                ctx.setStrokeColor(NSColor(srgbRed: 0.35, green: 0.78, blue: 0.96, alpha: 0.75).cgColor)
                ctx.setLineWidth(1.6)
                for i in 0..<(sorted.count - 1) {
                    let a = sorted[i], b = sorted[i + 1]
                    let va = max(0, min(2.0, a.value ?? 1.0))
                    let vb = max(0, min(2.0, b.value ?? 1.0))
                    let xa = xForTime(a.timeSeconds), xb = xForTime(b.timeSeconds)
                    let steps = 16
                    for s in 0...steps {
                        let frac = Double(s) / Double(steps)
                        let u = EffectTimelineEngine.evaluateCurve(b.curve, t: frac)
                        let val = va + (vb - va) * u
                        let px = xa + (xb - xa) * CGFloat(frac)
                        let py = y + rowHeight - 6 - CGFloat(min(1.0, val / 1.5)) * (rowHeight - 14)
                        if s == 0 { ctx.move(to: CGPoint(x: px, y: py)) }
                        else { ctx.addLine(to: CGPoint(x: px, y: py)) }
                    }
                    ctx.strokePath()
                }
            }

            // Keyframe Diamond Nodes
            for kf in sorted {
                let kx = xForTime(kf.timeSeconds)
                let valNorm: CGFloat = (tr.kind == .brightness || tr.kind == .speed) ? CGFloat(min(1.0, (kf.value ?? 1.0) / 1.5)) : 0.5
                let ky = (tr.kind == .brightness || tr.kind == .speed)
                    ? (y + rowHeight - 6 - valNorm * (rowHeight - 14))
                    : (y + rowHeight * 0.5)

                let isSelected = (kf.id == selectedKeyframeID && idx == selectedTrackIndex)
                let radius: CGFloat = isSelected ? 7.0 : 5.5

                let fillCol: NSColor
                if let c = kf.color {
                    fillCol = NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
                } else if kf.eventKind == .triggerSparkleBurst {
                    fillCol = .systemYellow
                } else if kf.eventKind == .triggerOnMIDI {
                    fillCol = .systemPink
                } else {
                    fillCol = isSelected ? .systemOrange : .systemTeal
                }

                let path = CGMutablePath()
                path.move(to: CGPoint(x: kx, y: ky - radius))
                path.addLine(to: CGPoint(x: kx + radius, y: ky))
                path.addLine(to: CGPoint(x: kx, y: ky + radius))
                path.addLine(to: CGPoint(x: kx - radius, y: ky))
                path.closeSubpath()

                ctx.setFillColor(fillCol.cgColor)
                ctx.addPath(path)
                ctx.fillPath()

                ctx.setStrokeColor((isSelected ? NSColor.white : NSColor.black).cgColor)
                ctx.setLineWidth(isSelected ? 1.8 : 1.0)
                ctx.addPath(path)
                ctx.strokePath()
            }

            ctx.setStrokeColor(NSColor(white: 0.25, alpha: 1).cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: 0, y: y + rowHeight))
            ctx.addLine(to: CGPoint(x: bounds.width, y: y + rowHeight))
            ctx.strokePath()
        }

        // Playhead Line
        let px = xForTime(playheadSeconds)
        ctx.setStrokeColor(NSColor.systemRed.cgColor)
        ctx.setLineWidth(2.0)
        ctx.move(to: CGPoint(x: px, y: 0))
        ctx.addLine(to: CGPoint(x: px, y: bounds.height))
        ctx.strokePath()

        let headPath = CGMutablePath()
        headPath.move(to: CGPoint(x: px - 6, y: 0))
        headPath.addLine(to: CGPoint(x: px + 6, y: 0))
        headPath.addLine(to: CGPoint(x: px, y: 11))
        headPath.closeSubpath()
        ctx.setFillColor(NSColor.systemRed.cgColor)
        ctx.addPath(headPath)
        ctx.fillPath()
    }

    public override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if p.y <= rulerHeight || p.x < leftLabelWidth {
            if p.y > rulerHeight {
                let tIdx = Int((p.y - rulerHeight) / rowHeight)
                if tIdx >= 0 && tIdx < document.tracks.count {
                    onSelectKeyframe?(tIdx, nil)
                }
            }
            if p.x >= leftLabelWidth {
                dragMode = .playhead
                onSeekPlayhead?(timeForX(p.x))
            }
            return
        }

        let tIdx = Int((p.y - rulerHeight) / rowHeight)
        guard tIdx >= 0 && tIdx < document.tracks.count else { return }

        // Hit-test keyframes in row
        let track = document.tracks[tIdx]
        for kf in track.keyframes {
            let kx = xForTime(kf.timeSeconds)
            if abs(p.x - kx) <= 9 {
                onBeginEditGesture?()
                onSelectKeyframe?(tIdx, kf.id)
                dragMode = .keyframe(trackIdx: tIdx, keyID: kf.id)
                return
            }
        }

        if event.clickCount == 2 {
            onBeginEditGesture?()
            onAddKeyframeAt?(tIdx, timeForX(p.x))
        } else {
            onSelectKeyframe?(tIdx, nil)
            dragMode = .playhead
            onSeekPlayhead?(timeForX(p.x))
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let t = timeForX(p.x)
        switch dragMode {
        case .playhead:
            onSeekPlayhead?(t)
        case .keyframe(let tIdx, let kID):
            onMoveKeyframe?(tIdx, kID, t)
        case .none:
            break
        }
    }

    public override func mouseUp(with event: NSEvent) {
        dragMode = .none
    }
}

// MARK: - Lighting Effect Studio Window Controller

public final class LightingEffectStudioWindowController: NSWindowController, NSWindowDelegate {
    private let previewStrand = TimelineStrandPreviewView()
    private let canvasView = TimelineEditorCanvasView()

    private let docPopup = NSPopUpButton()
    private let playPauseBtn = NSButton()
    private let loopCheck = NSButton(checkboxWithTitle: "Loop", target: nil, action: nil)
    private let timeReadout = NSTextField(labelWithString: "0.00s / 12.00s")
    private let durationField = NSTextField(string: "12.0")

    private let undoBtn = NSButton()
    private let redoBtn = NSButton()
    private let addKeyBtn = NSButton()
    private let deleteKeyBtn = NSButton()

    private let eventPopup = NSPopUpButton()
    private let curvePopup = NSPopUpButton()
    private let kfTimeField = NSTextField(string: "0.00")
    private let kfValueSlider = NSSlider(value: 1.0, minValue: 0.0, maxValue: 2.0, target: nil, action: nil)
    private let kfColorWell = NSColorWell()
    private let kfEffectPopup = NSPopUpButton()
    private let kfMidiNoteField = NSTextField(string: "")

    private let timelineEngine = EffectTimelineEngine()
    private var currentDocument: TimelineEffectDocument
    private var undoStack: [TimelineEffectDocument] = []
    private var redoStack: [TimelineEffectDocument] = []
    private var selectedTrackIndex: Int = 0
    private var selectedKeyframeID: String?

    private var previewTimer: Timer?
    private let stateStore: NextGenStateStore
    private let settingsStore: SettingsStore

    public var onApplyTimelineToDesktop: ((TimelineEffectDocument?) -> Void)?

    public init(stateStore: NextGenStateStore = .shared, settingsStore: SettingsStore = .shared) {
        self.stateStore = stateStore
        self.settingsStore = settingsStore

        let initial = stateStore.state.timelines.first ?? EffectTimelineEngine.builtInSampleTimelines()[0]
        self.currentDocument = initial

        let win = NSWindow(
            contentRect: NSRect(x: 140, y: 110, width: 900, height: 610),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Re: Twinkle Bulbs — Lighting Effect Studio (.twinklefx)"
        win.minSize = NSSize(width: 780, height: 540)
        win.appearance = NSAppearance(named: .aqua)
        win.isReleasedWhenClosed = false
        super.init(window: win)
        win.delegate = self

        timelineEngine.setDocument(initial)
        buildUI()
        refreshDocumentList()
        syncViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showAndStartPreview() {
        refreshDocumentList()
        startPreviewTimer()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        previewTimer?.invalidate()
        previewTimer = nil
    }

    private func buildUI() {
        guard let root = window?.contentView else { return }

        // Top Bar: Document Management + Transport
        func mkBtn(_ title: String, _ act: Selector) -> NSButton {
            let b = NSButton(title: title, target: self, action: act)
            b.bezelStyle = .rounded
            return b
        }

        docPopup.target = self
        docPopup.action = #selector(selectDocument)

        let newDocBtn = mkBtn("New", #selector(createNewTimeline))
        let saveDocBtn = mkBtn("Save", #selector(saveCurrentTimeline))
        let expBtn = mkBtn("Export .twinklefx...", #selector(exportTimelineFile))
        let impBtn = mkBtn("Import .twinklefx...", #selector(importTimelineFile))
        let applyDesktopBtn = mkBtn("Apply to Desktop", #selector(applyToDesktop))
        let clearDesktopBtn = mkBtn("Stop Desktop Timeline", #selector(clearDesktopTimeline))

        let topBar = NSStackView(views: [docPopup, newDocBtn, saveDocBtn, expBtn, impBtn, applyDesktopBtn, clearDesktopBtn])
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.orientation = .horizontal
        topBar.spacing = 6
        root.addSubview(topBar)

        previewStrand.translatesAutoresizingMaskIntoConstraints = false
        previewStrand.settings = settingsStore.settings
        root.addSubview(previewStrand)

        // Transport + Undo/Redo Row
        playPauseBtn.title = "⏸ Pause"
        playPauseBtn.bezelStyle = .rounded
        playPauseBtn.target = self
        playPauseBtn.action = #selector(togglePlayPause)

        let rewindBtn = mkBtn("⏮ Rewind", #selector(rewindTimeline))
        loopCheck.target = self
        loopCheck.action = #selector(toggleLoop)

        durationField.target = self
        durationField.action = #selector(updateDuration)

        undoBtn.title = "↩ Undo"
        undoBtn.bezelStyle = .rounded
        undoBtn.target = self
        undoBtn.action = #selector(performUndo)

        redoBtn.title = "↪ Redo"
        redoBtn.bezelStyle = .rounded
        redoBtn.target = self
        redoBtn.action = #selector(performRedo)

        addKeyBtn.title = "+ Add Keyframe"
        addKeyBtn.bezelStyle = .rounded
        addKeyBtn.target = self
        addKeyBtn.action = #selector(addKeyframeAtPlayhead)

        deleteKeyBtn.title = "Delete Keyframe"
        deleteKeyBtn.bezelStyle = .rounded
        deleteKeyBtn.target = self
        deleteKeyBtn.action = #selector(deleteSelectedKeyframe)

        timeReadout.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)

        let transport = NSStackView(views: [
            playPauseBtn, rewindBtn, loopCheck,
            NSTextField(labelWithString: "Duration (s):"), durationField,
            timeReadout, undoBtn, redoBtn, addKeyBtn, deleteKeyBtn
        ])
        transport.translatesAutoresizingMaskIntoConstraints = false
        transport.orientation = .horizontal
        transport.spacing = 6
        root.addSubview(transport)

        // Timeline Canvas
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.onBeginEditGesture = { [weak self] in self?.pushUndoSnapshot() }
        canvasView.onSelectKeyframe = { [weak self] tIdx, kID in
            self?.selectedTrackIndex = tIdx
            self?.selectedKeyframeID = kID
            self?.syncViews()
        }
        canvasView.onMoveKeyframe = { [weak self] tIdx, kID, newT in
            self?.moveKeyframe(trackIdx: tIdx, keyID: kID, to: newT)
        }
        canvasView.onSeekPlayhead = { [weak self] t in
            self?.timelineEngine.seek(to: t)
            self?.canvasView.playheadSeconds = t
            self?.evaluatePreviewOnce(at: t)
        }
        canvasView.onAddKeyframeAt = { [weak self] tIdx, t in
            self?.selectedTrackIndex = tIdx
            self?.insertKeyframe(trackIdx: tIdx, timeSeconds: t)
        }
        root.addSubview(canvasView)

        // Bottom Keyframe Inspector Box
        let inspBox = NSBox()
        inspBox.translatesAutoresizingMaskIntoConstraints = false
        inspBox.title = "Selected Keyframe Inspector (Double-click timeline lane or click + Add Keyframe)"
        root.addSubview(inspBox)

        eventPopup.addItems(withTitles: TimelineEventKind.allCases.map(\.rawValue))
        eventPopup.target = self
        eventPopup.action = #selector(editKeyframeFields)

        let curves = ["Linear", "Ease In", "Ease Out", "Ease In-Out", "Step", "Custom Bezier"]
        curvePopup.addItems(withTitles: curves)
        curvePopup.target = self
        curvePopup.action = #selector(editKeyframeFields)

        kfTimeField.target = self
        kfTimeField.action = #selector(editKeyframeFields)
        kfValueSlider.target = self
        kfValueSlider.action = #selector(editKeyframeFields)
        kfColorWell.target = self
        kfColorWell.action = #selector(editKeyframeFields)
        kfEffectPopup.addItems(withTitles: ModernEffectID.allCases.map(\.displayName))
        kfEffectPopup.target = self
        kfEffectPopup.action = #selector(editKeyframeFields)
        kfMidiNoteField.placeholderString = "MIDI Note (0-127)"
        kfMidiNoteField.target = self
        kfMidiNoteField.action = #selector(editKeyframeFields)

        let inspRow = NSStackView(views: [
            NSTextField(labelWithString: "Event:"), eventPopup,
            NSTextField(labelWithString: "Curve:"), curvePopup,
            NSTextField(labelWithString: "Time:"), kfTimeField,
            NSTextField(labelWithString: "Value:"), kfValueSlider,
            NSTextField(labelWithString: "Color:"), kfColorWell,
            NSTextField(labelWithString: "Effect:"), kfEffectPopup,
            NSTextField(labelWithString: "MIDI Note:"), kfMidiNoteField
        ])
        inspRow.translatesAutoresizingMaskIntoConstraints = false
        inspRow.orientation = .horizontal
        inspRow.spacing = 6
        inspBox.contentView?.addSubview(inspRow)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            topBar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            topBar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),

            previewStrand.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 8),
            previewStrand.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            previewStrand.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            previewStrand.heightAnchor.constraint(equalToConstant: 44),

            transport.topAnchor.constraint(equalTo: previewStrand.bottomAnchor, constant: 8),
            transport.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            transport.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            durationField.widthAnchor.constraint(equalToConstant: 48),

            canvasView.topAnchor.constraint(equalTo: transport.bottomAnchor, constant: 8),
            canvasView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            canvasView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            canvasView.bottomAnchor.constraint(equalTo: inspBox.topAnchor, constant: -8),

            inspBox.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            inspBox.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            inspBox.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10),
            inspBox.heightAnchor.constraint(equalToConstant: 66),

            inspRow.leadingAnchor.constraint(equalTo: inspBox.contentView!.leadingAnchor, constant: 8),
            inspRow.trailingAnchor.constraint(equalTo: inspBox.contentView!.trailingAnchor, constant: -8),
            inspRow.centerYAnchor.constraint(equalTo: inspBox.contentView!.centerYAnchor),
            kfTimeField.widthAnchor.constraint(equalToConstant: 48),
            kfValueSlider.widthAnchor.constraint(equalToConstant: 78),
            kfColorWell.widthAnchor.constraint(equalToConstant: 36),
            kfMidiNoteField.widthAnchor.constraint(equalToConstant: 64)
        ])
    }

    private func startPreviewTimer() {
        previewTimer?.invalidate()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let virtualBounds = CGRect(x: 0, y: 0, width: 512, height: 36)
            let states = self.timelineEngine.evaluateStates(dt: 1.0 / 30.0, bounds: virtualBounds, settings: self.settingsStore.settings)
            self.previewStrand.currentStates = states
            self.canvasView.playheadSeconds = self.timelineEngine.elapsedSeconds
            self.timeReadout.stringValue = String(format: "%.2fs / %.2fs", self.timelineEngine.elapsedSeconds, self.currentDocument.durationSeconds)
        }
    }

    private func evaluatePreviewOnce(at t: Double) {
        let virtualBounds = CGRect(x: 0, y: 0, width: 512, height: 36)
        previewStrand.currentStates = timelineEngine.evaluateStates(atTimeSeconds: t, dt: 0.016, bounds: virtualBounds, settings: settingsStore.settings)
        timeReadout.stringValue = String(format: "%.2fs / %.2fs", t, currentDocument.durationSeconds)
    }

    private func pushUndoSnapshot() {
        undoStack.append(currentDocument)
        if undoStack.count > 40 { undoStack.removeFirst() }
        redoStack.removeAll()
        syncUndoButtons()
    }

    private func syncUndoButtons() {
        undoBtn.isEnabled = !undoStack.isEmpty
        redoBtn.isEnabled = !redoStack.isEmpty
    }

    private func refreshDocumentList() {
        var docs = EffectTimelineEngine.builtInSampleTimelines()
        for u in stateStore.state.timelines where !docs.contains(where: { $0.id == u.id }) {
            docs.append(u)
        }
        docPopup.removeAllItems()
        docPopup.addItems(withTitles: docs.map(\.name))
        if let idx = docs.firstIndex(where: { $0.id == currentDocument.id }) {
            docPopup.selectItem(at: idx)
        }
    }

    private func allAvailableDocuments() -> [TimelineEffectDocument] {
        var docs = EffectTimelineEngine.builtInSampleTimelines()
        for u in stateStore.state.timelines where !docs.contains(where: { $0.id == u.id }) {
            docs.append(u)
        }
        return docs
    }

    private func syncViews() {
        timelineEngine.setDocument(currentDocument)
        canvasView.document = currentDocument
        canvasView.selectedTrackIndex = selectedTrackIndex
        canvasView.selectedKeyframeID = selectedKeyframeID
        loopCheck.state = currentDocument.loop ? .on : .off
        durationField.stringValue = String(format: "%.1f", currentDocument.durationSeconds)
        syncUndoButtons()

        let kf = currentSelectedKeyframe()
        let enabled = (kf != nil)
        for v in [eventPopup, curvePopup, kfTimeField, kfValueSlider, kfColorWell, kfEffectPopup, kfMidiNoteField] as [NSControl] {
            v.isEnabled = enabled
        }
        deleteKeyBtn.isEnabled = enabled
        if let kf {
            if let evIdx = TimelineEventKind.allCases.firstIndex(of: kf.eventKind) {
                eventPopup.selectItem(at: evIdx)
            }
            switch kf.curve {
            case .linear: curvePopup.selectItem(at: 0)
            case .easeIn: curvePopup.selectItem(at: 1)
            case .easeOut: curvePopup.selectItem(at: 2)
            case .easeInOut: curvePopup.selectItem(at: 3)
            case .step: curvePopup.selectItem(at: 4)
            case .cubicBezier: curvePopup.selectItem(at: 5)
            }
            kfTimeField.stringValue = String(format: "%.2f", kf.timeSeconds)
            kfValueSlider.doubleValue = kf.value ?? 1.0
            if let c = kf.color {
                kfColorWell.color = NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
            }
            if let eid = kf.effectID, let idx = ModernEffectID.allCases.firstIndex(of: eid) {
                kfEffectPopup.selectItem(at: idx)
            }
            kfMidiNoteField.stringValue = kf.midiNoteFilter.map(String.init) ?? ""
        }
        evaluatePreviewOnce(at: timelineEngine.elapsedSeconds)
    }

    private func currentSelectedKeyframe() -> TimelineKeyframe? {
        guard selectedTrackIndex >= 0 && selectedTrackIndex < currentDocument.tracks.count, let kID = selectedKeyframeID else { return nil }
        return currentDocument.tracks[selectedTrackIndex].keyframes.first(where: { $0.id == kID })
    }

    private func moveKeyframe(trackIdx: Int, keyID: String, to newT: Double) {
        guard trackIdx >= 0 && trackIdx < currentDocument.tracks.count,
              let kIdx = currentDocument.tracks[trackIdx].keyframes.firstIndex(where: { $0.id == keyID }) else { return }
        currentDocument.tracks[trackIdx].keyframes[kIdx].timeSeconds = max(0, min(currentDocument.durationSeconds, newT))
        syncViews()
    }

    private func insertKeyframe(trackIdx: Int, timeSeconds: Double) {
        guard trackIdx >= 0 && trackIdx < currentDocument.tracks.count else { return }
        let kind: TimelineEventKind
        var val: Double? = nil
        var col: TimelineColorRGB? = nil
        switch currentDocument.tracks[trackIdx].kind {
        case .color:
            kind = .setColor; col = TimelineColorRGB(r: 1, g: 0.35, b: 0.25)
        case .brightness:
            kind = .setBrightness; val = 1.0
        case .speed:
            kind = .changeSpeed; val = 1.0
        case .effects:
            kind = .triggerSparkleBurst
        case .midiTriggers:
            kind = .triggerOnMIDI
        }
        let kf = TimelineKeyframe(timeSeconds: max(0, min(currentDocument.durationSeconds, timeSeconds)), eventKind: kind, curve: .easeInOut, color: col, value: val)
        currentDocument.tracks[trackIdx].keyframes.append(kf)
        selectedKeyframeID = kf.id
        syncViews()
    }

    // MARK: - Actions

    @objc private func selectDocument() {
        let docs = allAvailableDocuments()
        let idx = docPopup.indexOfSelectedItem
        if idx >= 0 && idx < docs.count {
            undoStack.removeAll(); redoStack.removeAll()
            currentDocument = docs[idx]
            selectedTrackIndex = 0
            selectedKeyframeID = currentDocument.tracks.first?.keyframes.first?.id
            syncViews()
        }
    }

    @objc private func createNewTimeline() {
        let alert = NSAlert()
        alert.messageText = "New Lighting Effect Timeline"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = "Custom Holiday Show"
        alert.accessoryView = field
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let doc = TimelineEffectDocument(
            name: field.stringValue.isEmpty ? "Custom Timeline" : field.stringValue,
            bulbSetID: settingsStore.settings.bulbSetName,
            durationSeconds: 12.0,
            loop: true,
            tracks: [
                TimelineTrack(name: "Color Palette Flow", kind: .color),
                TimelineTrack(name: "Brightness Envelope", kind: .brightness, keyframes: [
                    TimelineKeyframe(timeSeconds: 0, eventKind: .setBrightness, curve: .linear, value: 1.0),
                    TimelineKeyframe(timeSeconds: 12, eventKind: .setBrightness, curve: .linear, value: 1.0)
                ]),
                TimelineTrack(name: "Speed Curve", kind: .speed),
                TimelineTrack(name: "Effects & Bursts", kind: .effects),
                TimelineTrack(name: "MIDI Triggers", kind: .midiTriggers)
            ]
        )
        var next = stateStore.state
        next.timelines.append(doc)
        stateStore.state = next
        currentDocument = doc
        refreshDocumentList()
        syncViews()
    }

    @objc private func saveCurrentTimeline() {
        var next = stateStore.state
        if let idx = next.timelines.firstIndex(where: { $0.id == currentDocument.id }) {
            next.timelines[idx] = currentDocument
        } else {
            currentDocument.id = "fx_user:\(UUID().uuidString.prefix(8))"
            next.timelines.append(currentDocument)
        }
        stateStore.state = next
        refreshDocumentList()
    }

    @objc private func exportTimelineFile() {
        guard let data = try? EffectTimelineEngine.exportTimeline(currentDocument) else { return }
        let sp = NSSavePanel()
        sp.nameFieldStringValue = "\(currentDocument.name.replacingOccurrences(of: " ", with: "_")).twinklefx"
        if sp.runModal() == .OK, let url = sp.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    @objc private func importTimelineFile() {
        let op = NSOpenPanel()
        op.canChooseFiles = true
        op.allowedContentTypes = [.json, UTType(filenameExtension: "twinklefx")].compactMap { $0 }
        if op.runModal() == .OK, let url = op.url, let data = try? Data(contentsOf: url),
           var imported = try? EffectTimelineEngine.importTimeline(data: data) {
            imported.id = "fx_user:\(UUID().uuidString.prefix(8))"
            var next = stateStore.state
            next.timelines.append(imported)
            stateStore.state = next
            currentDocument = imported
            refreshDocumentList()
            syncViews()
        }
    }

    @objc private func applyToDesktop() {
        saveCurrentTimeline()
        var next = stateStore.state
        next.activeTimelineID = currentDocument.id
        stateStore.state = next
        onApplyTimelineToDesktop?(currentDocument)
    }

    @objc private func clearDesktopTimeline() {
        var next = stateStore.state
        next.activeTimelineID = nil
        stateStore.state = next
        onApplyTimelineToDesktop?(nil)
    }

    @objc private func togglePlayPause() {
        let next = !timelineEngine.isPlaying
        timelineEngine.setPlaying(next)
        playPauseBtn.title = next ? "⏸ Pause" : "▶ Play"
    }

    @objc private func rewindTimeline() {
        timelineEngine.seek(to: 0)
        canvasView.playheadSeconds = 0
        evaluatePreviewOnce(at: 0)
    }

    @objc private func toggleLoop() {
        pushUndoSnapshot()
        currentDocument.loop = (loopCheck.state == .on)
        syncViews()
    }

    @objc private func updateDuration() {
        if let val = Double(durationField.stringValue), val >= 1.0, val <= 300.0 {
            pushUndoSnapshot()
            currentDocument.durationSeconds = val
            syncViews()
        }
    }

    @objc private func performUndo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(currentDocument)
        currentDocument = prev
        syncViews()
    }

    @objc private func performRedo() {
        guard let nextDoc = redoStack.popLast() else { return }
        undoStack.append(currentDocument)
        currentDocument = nextDoc
        syncViews()
    }

    @objc private func addKeyframeAtPlayhead() {
        pushUndoSnapshot()
        insertKeyframe(trackIdx: selectedTrackIndex, timeSeconds: timelineEngine.elapsedSeconds)
    }

    @objc private func deleteSelectedKeyframe() {
        guard selectedTrackIndex >= 0 && selectedTrackIndex < currentDocument.tracks.count,
              let kID = selectedKeyframeID else { return }
        pushUndoSnapshot()
        currentDocument.tracks[selectedTrackIndex].keyframes.removeAll { $0.id == kID }
        selectedKeyframeID = nil
        syncViews()
    }

    @objc private func editKeyframeFields() {
        guard selectedTrackIndex >= 0 && selectedTrackIndex < currentDocument.tracks.count,
              let kID = selectedKeyframeID,
              let kIdx = currentDocument.tracks[selectedTrackIndex].keyframes.firstIndex(where: { $0.id == kID }) else { return }
        pushUndoSnapshot()
        var kf = currentDocument.tracks[selectedTrackIndex].keyframes[kIdx]
        let evIdx = max(0, eventPopup.indexOfSelectedItem)
        kf.eventKind = TimelineEventKind.allCases[evIdx]
        switch curvePopup.indexOfSelectedItem {
        case 0: kf.curve = .linear
        case 1: kf.curve = .easeIn
        case 2: kf.curve = .easeOut
        case 3: kf.curve = .easeInOut
        case 4: kf.curve = .step
        default: kf.curve = .cubicBezier(c1x: 0.25, c1y: 0.1, c2x: 0.25, c2y: 1.0)
        }
        if let t = Double(kfTimeField.stringValue) {
            kf.timeSeconds = max(0, min(currentDocument.durationSeconds, t))
        }
        kf.value = kfValueSlider.doubleValue
        if let srgb = kfColorWell.color.usingColorSpace(.sRGB) {
            kf.color = TimelineColorRGB(r: srgb.redComponent, g: srgb.greenComponent, b: srgb.blueComponent)
        }
        let fxIdx = max(0, kfEffectPopup.indexOfSelectedItem)
        if fxIdx < ModernEffectID.allCases.count {
            kf.effectID = ModernEffectID.allCases[fxIdx]
        }
        let noteTrim = kfMidiNoteField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        kf.midiNoteFilter = UInt8(noteTrim)
        currentDocument.tracks[selectedTrackIndex].keyframes[kIdx] = kf
        syncViews()
    }
}
