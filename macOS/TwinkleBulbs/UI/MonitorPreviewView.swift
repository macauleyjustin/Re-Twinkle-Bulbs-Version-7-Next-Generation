import Cocoa
import CoreGraphics

/// Live classic computer-monitor preview widget matching bmp_189 in Twinkle Bulbs v6.0 Preferences.
final class MonitorPreviewView: NSView {
    override var isFlipped: Bool { true }

    private let engine = BulbEngine()
    private let modernEngine = ModernLightingEngine()
    private var timer: Timer?
    private var settings: AppSettings = .defaultSettings()

    func configure(with settings: AppSettings) {
        self.settings = settings
        var previewSettings = settings
        previewSettings.bulbSize = .normal
        let screenRect = previewScreenRect()
        let virtualW = Int(max(320, screenRect.width * 2))
        let virtualH = Int(max(220, screenRect.height * 2))
        let vBounds = CGRect(x: 0, y: 0, width: virtualW, height: virtualH)
        let t = nowMs()
        engine.configure(bounds: vBounds, settings: previewSettings, nowMs: t)
        modernEngine.configure(bounds: vBounds, settings: previewSettings, nowMs: t)
        needsDisplay = true

        timer?.invalidate()
        let interval = settings.lightingCategory == .modern ? 0.033 : 0.050
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.settings.lightingCategory == .modern {
                self.modernEngine.tick(nowMs: self.nowMs())
                self.needsDisplay = true
            } else if self.engine.tick(nowMs: self.nowMs()) {
                self.needsDisplay = true
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func previewScreenRect() -> CGRect {
        let m = min(bounds.width - 28, (bounds.height - 40) * 1.32)
        let w = max(140, m)
        let h = w * 0.74
        let x = (bounds.width - w) * 0.5
        let y = 14.0
        return CGRect(x: x, y: y, width: w, height: h)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let bezelRect = previewScreenRect().insetBy(dx: -8, dy: -8)
        let scrRect = previewScreenRect()

        // Monitor stand base
        NSColor(white: 0.68, alpha: 1).setFill()
        let standRect = CGRect(x: bezelRect.midX - 28, y: bezelRect.maxY, width: 56, height: 12)
        ctx.fill(standRect)
        let footRect = CGRect(x: bezelRect.midX - 48, y: bezelRect.maxY + 10, width: 96, height: 6)
        NSBezierPath(roundedRect: footRect, xRadius: 3, yRadius: 3).fill()

        // Classic plastic bezel
        NSColor(white: 0.80, alpha: 1).setFill()
        NSBezierPath(roundedRect: bezelRect, xRadius: 7, yRadius: 7).fill()
        NSColor(white: 0.45, alpha: 1).setStroke()
        NSBezierPath(roundedRect: bezelRect, xRadius: 7, yRadius: 7).stroke()

        // Screen surface (active wallpaper preview or classic teal/navy night desktop)
        ctx.saveGState()
        ctx.clip(to: scrRect)
        NSColor(srgbRed: 0.04, green: 0.14, blue: 0.24, alpha: 1).setFill()
        ctx.fill(scrRect)

        // Draw preview bulbs scaled cleanly inside scrRect
        if settings.lightsEnabled {
            let vw = max(320, scrRect.width * 2)
            let vh = max(220, scrRect.height * 2)
            ctx.translateBy(x: scrRect.minX, y: scrRect.minY)
            ctx.scaleBy(x: scrRect.width / vw, y: scrRect.height / vh)
            var ps = settings
            ps.bulbSize = .normal
            if settings.lightingCategory == .modern {
                BulbCanvasView.drawModernStates(modernEngine.states, settings: ps, in: ctx)
            } else {
                BulbCanvasView.drawSlots(engine.slots, settings: ps, in: ctx)
            }
        }
        ctx.restoreGState()
    }

    private func nowMs() -> UInt64 {
        UInt64(ProcessInfo.processInfo.systemUptime * 1000.0)
    }
}
