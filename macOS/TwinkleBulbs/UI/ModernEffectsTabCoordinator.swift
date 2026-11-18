import Cocoa

final class ModernEffectsTabCoordinator: NSObject {
    private unowned let owner: PreferencesWindowController
    private var panelWindow: NSWindow?

    private let categorySegment = NSSegmentedControl(labels: ["Original / Classic (v6.0)", "Advanced / Modern Effects"], trackingMode: .selectOne, target: nil, action: nil)
    private let effectPopup = NSPopUpButton()
    private let palettePopup = NSPopUpButton()
    private let speedSlider = NSSlider(value: 1.0, minValue: 0.2, maxValue: 3.0, target: nil, action: nil)
    private let brightnessSlider = NSSlider(value: 1.0, minValue: 0.1, maxValue: 1.0, target: nil, action: nil)
    private let smoothnessSlider = NSSlider(value: 0.75, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
    private let widthSlider = NSSlider(value: 6.0, minValue: 2.0, maxValue: 24.0, target: nil, action: nil)
    private let densitySlider = NSSlider(value: 0.5, minValue: 0.1, maxValue: 1.0, target: nil, action: nil)

    private let reverseCheck = NSButton(checkboxWithTitle: "Reverse Flow Direction", target: nil, action: nil)
    private let staggeredCheck = NSButton(checkboxWithTitle: "Staggered Group Wave", target: nil, action: nil)
    private let perMonitorCheck = NSButton(checkboxWithTitle: "Offset Phase Per Monitor", target: nil, action: nil)
    private let randomSeedCheck = NSButton(checkboxWithTitle: "Randomize Seeds Each Run", target: nil, action: nil)

    private let cycleSecField = NSTextField()
    private let cycleRandomCheck = NSButton(checkboxWithTitle: "Random Cycle Order", target: nil, action: nil)
    private let cycleCrossfadeCheck = NSButton(checkboxWithTitle: "Crossfade Transitions", target: nil, action: nil)

    private let midiReactiveCheck = NSButton(checkboxWithTitle: "Sync Lights to MIDI Music Events", target: nil, action: nil)
    private let midiModePopup = NSPopUpButton()
    private let midiSensSlider = NSSlider(value: 1.0, minValue: 0.3, maxValue: 2.0, target: nil, action: nil)
    private let liveStrandPreview = FlashingModePreviewView()

    init(owner: PreferencesWindowController) {
        self.owner = owner
        super.init()
    }

    func openAdvancedPanel() {
        if panelWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 716, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "Advanced / Modern Christmas Effects"
            win.appearance = NSAppearance(named: .aqua)
            win.isReleasedWhenClosed = false
            win.center()
            if let root = win.contentView {
                root.wantsLayer = true
                root.layer?.backgroundColor = NSColor(srgbRed: 0.925, green: 0.914, blue: 0.847, alpha: 1.0).cgColor
                let content = makeModernPanelContent()
                root.addSubview(content)
                let doneBtn = NSButton(title: "Done", target: self, action: #selector(closePanel))
                doneBtn.frame = NSRect(x: 614, y: 12, width: 86, height: 28)
                root.addSubview(doneBtn)
            }
            panelWindow = win
        }
        loadFromSettings(owner.draft)
        panelWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func closePanel() {
        commitFieldsIntoDraft()
        liveStrandPreview.stopPreview()
        panelWindow?.orderOut(nil)
    }

    func makeModernPanelContent() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 44, width: 716, height: 452))

        // Top Category Selector & Live Strand Preview
        let catBox = NSBox(frame: NSRect(x: 16, y: 368, width: 684, height: 76))
        catBox.title = "Engine Separation & Live Modern Strand Preview"
        categorySegment.frame = NSRect(x: 14, y: 20, width: 390, height: 26)
        categorySegment.target = self
        categorySegment.action = #selector(modernChanged)
        liveStrandPreview.frame = NSRect(x: 416, y: 10, width: 254, height: 44)
        catBox.contentView?.addSubview(categorySegment)
        catBox.contentView?.addSubview(liveStrandPreview)
        view.addSubview(catBox)

        // Left Box: Effect, Palette (with swatches), Sliders
        let fxBox = NSBox(frame: NSRect(x: 16, y: 12, width: 360, height: 348))
        fxBox.title = "15 Programmable Modern Patterns"

        let fxLbl = NSTextField(labelWithString: "Effect:")
        fxLbl.frame = NSRect(x: 14, y: 296, width: 70, height: 18)
        effectPopup.removeAllItems()
        effectPopup.addItems(withTitles: ModernEffectID.allCases.map(\.displayName))
        effectPopup.frame = NSRect(x: 90, y: 292, width: 252, height: 24)
        effectPopup.target = self; effectPopup.action = #selector(modernChanged)

        let palLbl = NSTextField(labelWithString: "Palette:")
        palLbl.frame = NSRect(x: 14, y: 258, width: 70, height: 18)
        palettePopup.removeAllItems()
        for pal in ModernColorPalette.allCases {
            palettePopup.addItem(withTitle: pal.displayName)
            palettePopup.lastItem?.image = ColorModeSwatchRenderer.swatchImage(for: pal, width: 42, height: 12)
        }
        palettePopup.frame = NSRect(x: 90, y: 254, width: 252, height: 24)
        palettePopup.target = self; palettePopup.action = #selector(modernChanged)

        func addSliderRow(_ label: String, _ slider: NSSlider, y: CGFloat) {
            let lbl = NSTextField(labelWithString: label)
            lbl.font = .systemFont(ofSize: 11.5)
            lbl.frame = NSRect(x: 14, y: y, width: 120, height: 18)
            slider.frame = NSRect(x: 138, y: y - 1, width: 204, height: 20)
            slider.isContinuous = true
            slider.target = self
            slider.action = #selector(modernChanged)
            fxBox.contentView?.addSubview(lbl)
            fxBox.contentView?.addSubview(slider)
        }
        addSliderRow("Animation Speed:", speedSlider, y: 218)
        addSliderRow("Overall Brightness:", brightnessSlider, y: 186)
        addSliderRow("Smoothness:", smoothnessSlider, y: 154)
        addSliderRow("Wave / Tail Width:", widthSlider, y: 122)
        addSliderRow("Sparkle / Burst Rate:", densitySlider, y: 90)

        reverseCheck.frame = NSRect(x: 14, y: 52, width: 170, height: 20)
        staggeredCheck.frame = NSRect(x: 188, y: 52, width: 160, height: 20)
        perMonitorCheck.frame = NSRect(x: 14, y: 22, width: 175, height: 20)
        randomSeedCheck.frame = NSRect(x: 188, y: 22, width: 165, height: 20)

        for v: NSView in [fxLbl, effectPopup, palLbl, palettePopup, reverseCheck, staggeredCheck, perMonitorCheck, randomSeedCheck] {
            if let btn = v as? NSButton { btn.target = self; btn.action = #selector(modernChanged) }
            fxBox.contentView?.addSubview(v)
        }
        view.addSubview(fxBox)

        // Top Right Box: Automatic Effect Cycle
        let cycBox = NSBox(frame: NSRect(x: 390, y: 186, width: 310, height: 174))
        cycBox.title = "Combination / Automatic Cycle"
        let cycLbl = NSTextField(labelWithString: "Seconds Per Effect:")
        cycLbl.frame = NSRect(x: 14, y: 114, width: 140, height: 18)
        cycleSecField.frame = NSRect(x: 160, y: 112, width: 64, height: 22)
        cycleRandomCheck.frame = NSRect(x: 14, y: 80, width: 260, height: 20)
        cycleCrossfadeCheck.frame = NSRect(x: 14, y: 50, width: 260, height: 20)
        let cycHint = NSTextField(labelWithString: "Classic v6 modes remain preserved on return.")
        cycHint.font = .systemFont(ofSize: 10.5)
        cycHint.textColor = .secondaryLabelColor
        cycHint.frame = NSRect(x: 14, y: 18, width: 276, height: 18)
        for v: NSView in [cycLbl, cycleSecField, cycleRandomCheck, cycleCrossfadeCheck, cycHint] {
            if let btn = v as? NSButton { btn.target = self; btn.action = #selector(modernChanged) }
            cycBox.contentView?.addSubview(v)
        }
        view.addSubview(cycBox)

        // Bottom Right Box: Optional MIDI-Reactive Lighting
        let midiBox = NSBox(frame: NSRect(x: 390, y: 12, width: 310, height: 164))
        midiBox.title = "Optional MIDI-Reactive Lighting"
        midiReactiveCheck.frame = NSRect(x: 14, y: 108, width: 270, height: 22)
        midiReactiveCheck.target = self; midiReactiveCheck.action = #selector(modernChanged)

        let mmLbl = NSTextField(labelWithString: "Sync Mode:")
        mmLbl.frame = NSRect(x: 14, y: 74, width: 85, height: 18)
        midiModePopup.removeAllItems()
        midiModePopup.addItems(withTitles: MIDIReactiveMode.allCases.map(\.displayName))
        midiModePopup.frame = NSRect(x: 100, y: 70, width: 194, height: 24)
        midiModePopup.target = self; midiModePopup.action = #selector(modernChanged)

        let msLbl = NSTextField(labelWithString: "Sensitivity:")
        msLbl.frame = NSRect(x: 14, y: 38, width: 85, height: 18)
        midiSensSlider.frame = NSRect(x: 100, y: 36, width: 194, height: 20)
        midiSensSlider.isContinuous = true
        midiSensSlider.target = self; midiSensSlider.action = #selector(modernChanged)

        for v: NSView in [midiReactiveCheck, mmLbl, midiModePopup, msLbl, midiSensSlider] {
            midiBox.contentView?.addSubview(v)
        }
        view.addSubview(midiBox)
        return view
    }

    func loadFromSettings(_ s: AppSettings) {
        categorySegment.selectedSegment = s.lightingCategory.rawValue
        let m = s.modernEffects
        effectPopup.selectItem(at: m.effect.rawValue)
        palettePopup.selectItem(at: m.palette.rawValue)
        speedSlider.doubleValue = m.speed
        brightnessSlider.doubleValue = m.brightness
        smoothnessSlider.doubleValue = m.smoothness
        widthSlider.doubleValue = m.wavelengthOrWidth
        densitySlider.doubleValue = m.intensityOrDensity
        reverseCheck.state = m.reverseDirection ? .on : .off
        staggeredCheck.state = m.staggered ? .on : .off
        perMonitorCheck.state = m.perMonitorPhaseOffset ? .on : .off
        randomSeedCheck.state = m.randomizeSeeds ? .on : .off
        cycleSecField.doubleValue = m.cycleIntervalSeconds
        cycleRandomCheck.state = m.cycleRandomOrder ? .on : .off
        cycleCrossfadeCheck.state = m.cycleCrossfade ? .on : .off
        midiReactiveCheck.state = m.midiReactiveEnabled ? .on : .off
        midiModePopup.selectItem(at: m.midiReactiveMode.rawValue)
        midiSensSlider.doubleValue = m.midiSensitivity
        liveStrandPreview.configure(with: s)
    }

    func commitFieldsIntoDraft() {
        owner.draft.lightingCategory = LightingEngineCategory(rawValue: max(0, categorySegment.selectedSegment)) ?? .classic
        var m = owner.draft.modernEffects
        m.effect = ModernEffectID(rawValue: max(0, effectPopup.indexOfSelectedItem)) ?? .twinklefox
        m.palette = ModernColorPalette(rawValue: max(0, palettePopup.indexOfSelectedItem)) ?? .classicHoliday
        m.speed = speedSlider.doubleValue
        m.brightness = brightnessSlider.doubleValue
        m.smoothness = smoothnessSlider.doubleValue
        m.wavelengthOrWidth = widthSlider.doubleValue
        m.intensityOrDensity = densitySlider.doubleValue
        m.reverseDirection = reverseCheck.state == .on
        m.staggered = staggeredCheck.state == .on
        m.perMonitorPhaseOffset = perMonitorCheck.state == .on
        m.randomizeSeeds = randomSeedCheck.state == .on
        let cyc = cycleSecField.doubleValue
        m.cycleIntervalSeconds = cyc >= 2.0 ? cyc : 15.0
        m.cycleRandomOrder = cycleRandomCheck.state == .on
        m.cycleCrossfade = cycleCrossfadeCheck.state == .on
        m.midiReactiveEnabled = midiReactiveCheck.state == .on
        m.midiReactiveMode = MIDIReactiveMode(rawValue: max(0, midiModePopup.indexOfSelectedItem)) ?? .velocityBrightness
        m.midiSensitivity = midiSensSlider.doubleValue
        owner.draft.modernEffects = m
    }

    @objc private func modernChanged() {
        commitFieldsIntoDraft()
        AudioEngineService.shared.playEffect(.softTick, enabled: owner.draft.soundFX)
        liveStrandPreview.configure(with: owner.draft)
        owner.refreshModeControlsFromModernPanel()
    }
}
