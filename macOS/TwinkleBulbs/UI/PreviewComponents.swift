import Cocoa
import CoreGraphics

// MARK: - Miniature Swatch Generator for Color Mode & Modern Palette Dropdowns

public enum ColorModeSwatchRenderer {
    public static func swatchImage(for mode: ColorMode, width: Int = 56, height: Int = 14) -> NSImage {
        var rng: any RandomSource = SeededRandomSource(seed: UInt64(mode.rawValue + 101))
        let indices = BulbEngine.colorSequence(mode: mode, count: 7, rng: &rng)
        let colors = indices.map { idx -> NSColor in
            let rgb = BulbArtworkRegistry.slotColors[max(0, min(6, idx))].onGlow
            return NSColor(srgbRed: CGFloat(rgb.0)/255, green: CGFloat(rgb.1)/255, blue: CGFloat(rgb.2)/255, alpha: 1)
        }
        return renderBeadRow(colors: colors, width: width, height: height)
    }

    public static func swatchImage(for palette: ModernColorPalette, width: Int = 56, height: Int = 14) -> NSImage {
        let raw = palette.colors
        let colors = (0..<7).map { i -> NSColor in
            let c = raw[i % max(1, raw.count)]
            return NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
        }
        return renderBeadRow(colors: colors, width: width, height: height)
    }

    private static func renderBeadRow(colors: [NSColor], width: Int, height: Int) -> NSImage {
        let img = NSImage(size: NSSize(width: width, height: height))
        img.lockFocus()
        let count = max(1, colors.count)
        let step = CGFloat(width - 4) / CGFloat(count)
        for (i, c) in colors.enumerated() {
            let r = CGRect(x: 2 + CGFloat(i) * step, y: 2, width: max(6, step - 1.5), height: CGFloat(height - 4))
            c.setFill()
            NSBezierPath(ovalIn: r).fill()
            NSColor.black.withAlphaComponent(0.6).setStroke()
            let strokePath = NSBezierPath(ovalIn: r)
            strokePath.lineWidth = 0.8
            strokePath.stroke()
        }
        img.unlockFocus()
        return img
    }
}

// MARK: - Live Bulb Set Sample Strand Preview (ON / OFF / Broken / Burned Out / Wire)

public final class BulbSetPreviewView: NSView {
    public override var isFlipped: Bool { true }
    public var settings: AppSettings = .defaultSettings() {
        didSet { needsDisplay = true }
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor(srgbRed: 0.05, green: 0.14, blue: 0.24, alpha: 1).cgColor)
        ctx.fill(bounds)
        ctx.setStrokeColor(NSColor(white: 0.45, alpha: 1).cgColor)
        ctx.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))

        let demoCount = 6
        let tileSz = min(30.0, (bounds.width - 12) / CGFloat(demoCount))
        let startX = (bounds.width - tileSz * CGFloat(demoCount)) * 0.5
        let y: CGFloat = 4

        var rng: any RandomSource = SeededRandomSource(seed: 19)
        let seq = BulbEngine.colorSequence(mode: settings.colorMode, count: demoCount, rng: &rng)
        var s = settings
        s.bulbSize = .normal

        let slots: [BulbSlot] = (0..<demoCount).map { i in
            let isWire = (i == 4)
            let isBroken = (i == 3 && settings.broken)
            let isBurned = (i == 2 && settings.burnedOut)
            let isLit = (i == 0 || i == 1 || i == 5)
            return BulbSlot(
                index: i,
                frame: CGRect(x: startX + CGFloat(i) * tileSz, y: y, width: tileSz, height: tileSz),
                edge: .top,
                colorIndex: seq[i],
                isBareWire: isWire,
                isMissing: false,
                isBroken: isBroken,
                isBurnedOut: isBurned,
                isLit: isLit,
                flashable: true,
                nextToggleMs: 0
            )
        }
        BulbCanvasView.drawSlots(slots, settings: s, in: ctx)

        let cap = "ON • ON • OFF • Sample" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9.5), .foregroundColor: NSColor(white: 0.85, alpha: 0.85)]
        let sz = cap.size(withAttributes: attrs)
        cap.draw(at: CGPoint(x: (bounds.width - sz.width) * 0.5, y: bounds.height - sz.height - 2), withAttributes: attrs)
    }
}

// MARK: - Live Flashing & Modern Effect Strand Preview (Driven by Production Engines)

public final class FlashingModePreviewView: NSView {
    public override var isFlipped: Bool { true }

    private let classicEngine = BulbEngine()
    private let modernEngine = ModernLightingEngine()
    private var timer: Timer?
    private var settings: AppSettings = .defaultSettings()

    public func configure(with newSettings: AppSettings) {
        self.settings = newSettings
        var previewS = newSettings
        previewS.location = .top
        previewS.bulbSize = .normal
        previewS.notSoMany = false
        previewS.broken = false
        previewS.burnedOut = false
        previewS.missing = false
        let virtualBounds = CGRect(x: 0, y: 0, width: 256, height: 32)
        let nowMs = UInt64(ProcessInfo.processInfo.systemUptime * 1000.0)
        classicEngine.configure(bounds: virtualBounds, settings: previewS, nowMs: nowMs)
        modernEngine.configure(bounds: virtualBounds, settings: previewS, nowMs: nowMs)
        needsDisplay = true

        timer?.invalidate()
        timer = nil
        guard !newSettings.reduceMotion else { return }

        let interval = (newSettings.lightingCategory == .modern) ? 0.033 : 0.050
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let t = UInt64(ProcessInfo.processInfo.systemUptime * 1000.0)
            if self.settings.lightingCategory == .modern {
                self.modernEngine.tick(nowMs: t)
                self.needsDisplay = true
            } else if self.classicEngine.tick(nowMs: t) {
                self.needsDisplay = true
            }
        }
    }

    public func stopPreview() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopPreview()
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor(srgbRed: 0.04, green: 0.09, blue: 0.16, alpha: 1).cgColor)
        ctx.fill(bounds)
        ctx.setStrokeColor(NSColor(white: 0.45, alpha: 1).cgColor)
        ctx.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))

        var ps = settings
        ps.bulbSize = .normal
        ctx.saveGState()
        let sy = bounds.height / 32.0
        let sx = bounds.width / 256.0
        ctx.scaleBy(x: sx, y: sy)
        if settings.lightingCategory == .modern {
            BulbCanvasView.drawModernStates(modernEngine.states, settings: ps, in: ctx)
        } else {
            BulbCanvasView.drawSlots(classicEngine.slots, settings: ps, in: ctx)
        }
        ctx.restoreGState()
    }
}
