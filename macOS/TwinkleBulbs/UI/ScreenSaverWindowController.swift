import Cocoa
import CoreGraphics

// MARK: - Screen Saver Animator View

public final class ScreenSaverCanvasView: NSView {
    public override var isFlipped: Bool { true }
    public override var isOpaque: Bool { true }

    public var settings: AppSettings
    public var isPreviewMode: Bool = false

    private let bulbEngine = BulbEngine()
    private var tickCount: Int = 0
    private var scrollX: CGFloat = 0

    // Clock bounce state
    private var clockPos: CGPoint = CGPoint(x: 120, y: 120)
    private var clockVel: CGPoint = CGPoint(x: 2.2, y: 1.7)

    // Fireworks state
    private struct Rocket {
        var x: CGFloat; var y: CGFloat
        var vx: CGFloat; var vy: CGFloat
        var targetY: CGFloat
        var color: NSColor
        var trail: [CGPoint]
    }
    private struct Particle {
        var x: CGFloat; var y: CGFloat
        var vx: CGFloat; var vy: CGFloat
        var life: CGFloat; var maxLife: CGFloat
        var color: NSColor
        var history: [CGPoint]
    }
    private var rockets: [Rocket] = []
    private var particles: [Particle] = []
    private var stars: [(x: CGFloat, y: CGFloat, a: CGFloat)] = []

    // Snowfall state
    private struct Flake {
        var x: CGFloat; var y: CGFloat
        var size: CGFloat
        var speedY: CGFloat
        var swayPhase: CGFloat
        var kind: Int
    }
    private var flakes: [Flake] = []
    private var windOffset: CGFloat = 0
    private var snowDriftHeights: [CGFloat] = []
    private var santaX: CGFloat = -160
    private let seasonalRenderer = SeasonalScreenSaverRenderer()

    public init(frame: NSRect, settings: AppSettings, preview: Bool = false) {
        self.settings = settings
        self.isPreviewMode = preview
        super.init(frame: frame)
        reinitializeScene()
    }

    required init?(coder: NSCoder) { nil }

    public func reinitializeScene() {
        let nowMs = UInt64(ProcessInfo.processInfo.systemUptime * 1000.0)
        var s = settings
        if isPreviewMode { s.bulbSize = .normal }
        var bulbBounds = bounds
        if hasStaticBottomMsg && !settings.ssBottomTextAboveBulbs {
            bulbBounds.size.height = max(32, bounds.height - staticBottomStripHeight)
        }
        bulbEngine.configure(bounds: bulbBounds, settings: s, nowMs: nowMs)

        let w = max(100, bounds.width)
        let h = max(100, bounds.height)
        scrollX = w

        // Stars
        stars = (0..<85).map { _ in
            (CGFloat.random(in: 0..<w), CGFloat.random(in: 0..<(h * 0.78)), CGFloat.random(in: 0.3...1.0))
        }

        // Snowflakes
        let fCount = max(25, isPreviewMode ? 45 : settings.snowfallConfig.flakeCount * (settings.snowfallConfig.blizzardMode ? 2 : 1))
        flakes = (0..<fCount).map { _ in
            Flake(
                x: CGFloat.random(in: 0..<w),
                y: CGFloat.random(in: 0..<h),
                size: CGFloat.random(in: 3.0...8.0),
                speedY: CGFloat.random(in: 1.8...4.6) * (settings.snowfallConfig.blizzardMode ? 1.6 : 1.0),
                swayPhase: CGFloat.random(in: 0...(2 * .pi)),
                kind: Int.random(in: 0..<4)
            )
        }
        let driftBuckets = max(20, Int(w / 8))
        snowDriftHeights = Array(repeating: 4.0, count: driftBuckets)
        rockets.removeAll()
        particles.removeAll()
        santaX = -160
        clockPos = CGPoint(x: w * 0.25, y: h * 0.35)
        if !settings.ssModule.isClassicModule {
            seasonalRenderer.reset(module: settings.ssModule, bounds: contentRect(), settings: settings, preview: isPreviewMode)
            if let plugin = ScreenSaverPluginRegistry.shared.plugin(for: settings.ssModule.rawValue) {
                plugin.reset(in: contentRect(), settings: settings, preview: isPreviewMode)
            }
        }
    }

    /// 50ms animation tick (20 FPS matching SS_GetTimerInterval() == 0 -> 50ms default in tbulbs.mem @ 0x0046ddd0)
    public func stepFrame() {
        tickCount += 1
        let nowMs = UInt64(ProcessInfo.processInfo.systemUptime * 1000.0)
        bulbEngine.tick(nowMs: nowMs)

        let inset = contentRect()
        let cw = max(80, inset.width)
        let ch = max(80, inset.height)

        switch settings.ssModule {
        case .blank:
            break

        case .clock:
            if settings.clockConfig.bouncePosition {
                clockPos.x += clockVel.x
                clockPos.y += clockVel.y
                let estW: CGFloat = isPreviewMode ? 120 : 320
                let estH: CGFloat = isPreviewMode ? 44 : 110
                if clockPos.x < inset.minX + 16 { clockPos.x = inset.minX + 16; clockVel.x = abs(clockVel.x) }
                if clockPos.x + estW > inset.maxX - 16 { clockPos.x = max(inset.minX + 16, inset.maxX - 16 - estW); clockVel.x = -abs(clockVel.x) }
                if clockPos.y < inset.minY + 16 { clockPos.y = inset.minY + 16; clockVel.y = abs(clockVel.y) }
                if clockPos.y + estH > inset.maxY - 16 { clockPos.y = max(inset.minY + 16, inset.maxY - 16 - estH); clockVel.y = -abs(clockVel.y) }
            }

        case .fireworks:
            stepFireworks(inset: inset)

        case .snowfall:
            stepSnowfall(inset: inset)

        default:
            seasonalRenderer.step(module: settings.ssModule, inset: inset, settings: settings, preview: isPreviewMode, tick: tickCount)
            let interCfg = NextGenStateStore.shared.state.interactive
            if interCfg.enabled && interCfg.particlePointerInteraction, let win = window {
                let winPt = win.convertPoint(fromScreen: NSEvent.mouseLocation)
                let localPt = convert(winPt, from: nil)
                seasonalRenderer.applyPointerRepulsion(at: localPt, radius: CGFloat(interCfg.proximityRadiusPx))
            }
            if let plugin = ScreenSaverPluginRegistry.shared.plugin(for: settings.ssModule.rawValue) {
                plugin.step(in: inset, settings: settings, tick: tickCount)
            }
        }

        if settings.ssEnableMsg && settings.ssScrollMsg {
            scrollX -= (isPreviewMode ? 1.8 : 3.5)
            if scrollX < -cw * 0.9 {
                scrollX = inset.maxX + 40
            }
        }
        _ = cw; _ = ch
        needsDisplay = true
    }

    private func safeRandom(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let lo = min(a, b), hi = max(a, b)
        if lo == hi { return lo }
        return CGFloat.random(in: lo...hi)
    }

    private func stepFireworks(inset: CGRect) {
        guard inset.width > 16, inset.height > 16 else { return }
        let cfg = settings.fireworksConfig
        let fwPalette: [NSColor] = [
            .systemRed, .systemGreen, .systemYellow, .systemCyan,
            NSColor(srgbRed: 1, green: 0.45, blue: 1, alpha: 1),
            NSColor(srgbRed: 1, green: 0.6, blue: 0.15, alpha: 1),
            .white
        ]
        if rockets.count < max(1, cfg.maxRockets) && Int.random(in: 0..<100) < (isPreviewMode ? 9 : 7) {
            let startX = safeRandom(inset.minX + inset.width * 0.12, inset.maxX - inset.width * 0.12)
            rockets.append(Rocket(
                x: startX,
                y: inset.maxY - 8,
                vx: CGFloat.random(in: -1.4...1.4),
                vy: -CGFloat.random(in: 8.5...14.0) * (isPreviewMode ? 0.55 : 1.0),
                targetY: safeRandom(inset.minY + inset.height * 0.14, inset.minY + inset.height * 0.48),
                color: fwPalette.randomElement() ?? .yellow,
                trail: []
            ))
        }

        for i in (0..<rockets.count).reversed() {
            rockets[i].trail.append(CGPoint(x: rockets[i].x, y: rockets[i].y))
            if rockets[i].trail.count > 6 { rockets[i].trail.removeFirst() }
            rockets[i].x += rockets[i].vx
            rockets[i].y += rockets[i].vy
            rockets[i].vy += 0.18
            if rockets[i].y <= rockets[i].targetY || rockets[i].vy >= 0 {
                let r = rockets.remove(at: i)
                let burstCount = isPreviewMode ? 22 : cfg.particlesPerBurst
                for p in 0..<burstCount {
                    let ang = CGFloat(p) * (2.0 * .pi / CGFloat(burstCount)) + CGFloat.random(in: -0.1...0.1)
                    let spd = CGFloat.random(in: 1.5...6.5) * (isPreviewMode ? 0.5 : 1.0)
                    particles.append(Particle(
                        x: r.x, y: r.y,
                        vx: cos(ang) * spd, vy: sin(ang) * spd,
                        life: 1.0, maxLife: CGFloat.random(in: 24...44),
                        color: r.color, history: []
                    ))
                }
                if cfg.soundEnabled && !isPreviewMode {
                    AudioEngineService.shared.playEffect(.pop, enabled: settings.soundFX)
                }
            }
        }

        let maxHist = max(2, cfg.trailLength)
        for i in (0..<particles.count).reversed() {
            particles[i].history.append(CGPoint(x: particles[i].x, y: particles[i].y))
            if particles[i].history.count > maxHist { particles[i].history.removeFirst() }
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].vx *= 0.98
            particles[i].vy += 0.14
            particles[i].life -= 1.0 / particles[i].maxLife
            if particles[i].life <= 0 {
                particles.remove(at: i)
            }
        }
    }

    private func stepSnowfall(inset: CGRect) {
        guard inset.width > 12, inset.height > 12 else { return }
        let cfg = settings.snowfallConfig
        if cfg.windEnabled {
            windOffset = sin(CGFloat(tickCount) * 0.03) * (cfg.blizzardMode ? 4.2 : 1.5)
        } else {
            windOffset = 0
        }
        for i in flakes.indices {
            let sway = sin(CGFloat(tickCount) * 0.08 + flakes[i].swayPhase) * 0.8
            flakes[i].x += windOffset + sway
            flakes[i].y += flakes[i].speedY * (isPreviewMode ? 0.5 : 1.0)

            if flakes[i].x < inset.minX { flakes[i].x = inset.maxX - 2 }
            if flakes[i].x > inset.maxX { flakes[i].x = inset.minX + 2 }
            if flakes[i].y > inset.maxY {
                if cfg.accumulateSnow && !snowDriftHeights.isEmpty {
                    let b = min(snowDriftHeights.count - 1, max(0, Int((flakes[i].x - inset.minX) / 8.0)))
                    snowDriftHeights[b] = min(isPreviewMode ? 18 : 54, snowDriftHeights[b] + 0.4)
                }
                flakes[i].y = inset.minY
                flakes[i].x = safeRandom(inset.minX, inset.maxX)
            }
        }
        if cfg.showSanta {
            santaX += isPreviewMode ? 1.8 : 3.2
            if santaX > inset.maxX + 180 { santaX = inset.minX - 220 }
        }
    }

    private var hasStaticBottomMsg: Bool {
        settings.ssEnableMsg && !settings.ssMsg.isEmpty && !settings.ssScrollMsg
    }

    private var staticBottomStripHeight: CGFloat {
        isPreviewMode ? 16 : 30
    }

    /// Exact Screen Saver viewport inset matching 0x0046de40 in tbulbs.mem!
    public func contentRect() -> CGRect {
        var r = bounds
        if hasStaticBottomMsg {
            r.size.height -= staticBottomStripHeight
        }
        guard settings.ssLights else { return r }
        let sz = CGFloat(isPreviewMode ? 16 : settings.bulbSize.pixels)
        switch settings.location {
        case .top:
            r.origin.y += sz; r.size.height -= sz
        case .topAndBottom:
            r.origin.y += sz; r.size.height -= 2 * sz
        case .aroundScreen:
            r.origin.x += sz; r.origin.y += sz; r.size.width -= 2 * sz; r.size.height -= 2 * sz
        case .sidesOnly:
            r.origin.x += sz; r.size.width -= 2 * sz
        case .topAndSides:
            r.origin.x += sz; r.origin.y += sz; r.size.width -= 2 * sz; r.size.height -= sz
        case .bottomOnly:
            r.size.height -= sz
        }
        return r
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Background
        switch settings.ssModule {
        case .blank, .clock:
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fill(bounds)
        case .fireworks:
            let cols = [NSColor(srgbRed: 0.01, green: 0.02, blue: 0.08, alpha: 1).cgColor,
                        NSColor(srgbRed: 0.03, green: 0.04, blue: 0.14, alpha: 1).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
                ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: bounds.height), options: [])
            }
            for s in stars {
                ctx.setFillColor(NSColor.white.withAlphaComponent(s.a * 0.7).cgColor)
                ctx.fill(CGRect(x: s.x, y: s.y, width: 1.6, height: 1.6))
            }
        case .snowfall:
            let cols = [NSColor(srgbRed: 0.02, green: 0.06, blue: 0.18, alpha: 1).cgColor,
                        NSColor(srgbRed: 0.07, green: 0.15, blue: 0.30, alpha: 1).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
                ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: bounds.height), options: [])
            }
        default:
            seasonalRenderer.drawBackground(module: settings.ssModule, in: ctx, bounds: bounds, settings: settings)
        }

        let inset = contentRect()
        ctx.saveGState()
        ctx.clip(to: inset)

        switch settings.ssModule {
        case .blank:
            break
        case .clock:
            drawClock(in: inset)
        case .fireworks:
            drawFireworks(in: ctx, inset: inset)
        case .snowfall:
            drawSnowfall(in: ctx, inset: inset)
        default:
            if let plugin = ScreenSaverPluginRegistry.shared.plugin(for: settings.ssModule.rawValue) {
                plugin.draw(in: ctx, rect: inset, settings: settings, preview: isPreviewMode, tick: tickCount)
            } else {
                seasonalRenderer.drawForeground(module: settings.ssModule, in: ctx, inset: inset, settings: settings, preview: isPreviewMode, tick: tickCount)
            }
        }

        // Scrolling message inside viewport
        if settings.ssEnableMsg && !settings.ssMsg.isEmpty && settings.ssScrollMsg {
            drawCustomMessage(text: settings.ssMsg, rect: CGRect(x: scrollX, y: inset.midY - 24, width: inset.width, height: 48), centered: false)
        }

        ctx.restoreGState()

        // Bottom static message (cleanly below bottom bulbs, or just above them if ssBottomTextAboveBulbs)
        if hasStaticBottomMsg {
            let msgY = settings.ssBottomTextAboveBulbs ? inset.maxY + 2 : bounds.maxY - staticBottomStripHeight + 4
            drawCustomMessage(text: settings.ssMsg, rect: CGRect(x: 16, y: msgY, width: bounds.width - 32, height: staticBottomStripHeight), centered: true)
        }

        // Logo watermark
        if settings.ssLogo {
            let logoFont = NSFont.boldSystemFont(ofSize: isPreviewMode ? 9 : 14)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: logoFont,
                .foregroundColor: NSColor(white: 0.72, alpha: 0.78)
            ]
            let s = "Re: Twinkle Bulbs" as NSString
            s.draw(at: CGPoint(x: inset.minX + 12, y: inset.minY + 10), withAttributes: attrs)
        }

        // Perimeter Twinkle Bulbs
        if settings.ssLights {
            var s = settings
            if isPreviewMode { s.bulbSize = .normal }
            BulbCanvasView.drawSlots(bulbEngine.slots, settings: s, in: ctx)
        }
    }

    private func drawClock(in inset: CGRect) {
        let cfg = settings.clockConfig
        let fmt = DateFormatter()
        fmt.dateFormat = cfg.use24Hour ? (cfg.showSeconds ? "HH:mm:ss" : "HH:mm") : (cfg.showSeconds ? "h:mm:ss a" : "h:mm a")
        let timeStr = fmt.string(from: Date())

        let scale: CGFloat = isPreviewMode ? 0.34 : 1.0
        let font = NSFont(name: cfg.fontName, size: CGFloat(cfg.fontSize) * scale) ?? NSFont.boldSystemFont(ofSize: CGFloat(cfg.fontSize) * scale)
        let color = NSColor(hex: cfg.textColorHex, fallback: .systemGreen)

        let pos = cfg.bouncePosition ? clockPos : CGPoint(x: inset.midX - 110 * scale, y: inset.midY - 30 * scale)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (timeStr as NSString).draw(at: pos, withAttributes: attrs)

        if cfg.showDate {
            let dfmt = DateFormatter()
            dfmt.dateStyle = .full
            let dStr = dfmt.string(from: Date())
            let dFont = NSFont.systemFont(ofSize: max(10, 20 * scale))
            (dStr as NSString).draw(at: CGPoint(x: pos.x, y: pos.y + font.pointSize + 6), withAttributes: [
                .font: dFont, .foregroundColor: color.withAlphaComponent(0.85)
            ])
        }
    }

    private func drawFireworks(in ctx: CGContext, inset: CGRect) {
        for r in rockets {
            for (idx, pt) in r.trail.enumerated() {
                let a = CGFloat(idx + 1) / CGFloat(max(1, r.trail.count)) * 0.7
                ctx.setFillColor(r.color.withAlphaComponent(a).cgColor)
                ctx.fillEllipse(in: CGRect(x: pt.x - 1.5, y: pt.y - 1.5, width: 3, height: 3))
            }
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: CGRect(x: r.x - 2, y: r.y - 2, width: 4, height: 4))
        }
        for p in particles {
            for (idx, pt) in p.history.enumerated() {
                let a = p.life * (CGFloat(idx + 1) / CGFloat(max(1, p.history.count))) * 0.55
                ctx.setFillColor(p.color.withAlphaComponent(a).cgColor)
                ctx.fillEllipse(in: CGRect(x: pt.x - 1.5, y: pt.y - 1.5, width: 3, height: 3))
            }
            ctx.setFillColor(p.color.withAlphaComponent(p.life).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 2.2, y: p.y - 2.2, width: 4.4, height: 4.4))
        }
        if settings.fireworksConfig.showSkyline && !isPreviewMode {
            ctx.setFillColor(NSColor(srgbRed: 0.02, green: 0.02, blue: 0.05, alpha: 1).cgColor)
            for bx in stride(from: inset.minX, to: inset.maxX, by: 46) {
                let bh = 28 + CGFloat((Int(bx) * 37) % 58)
                ctx.fill(CGRect(x: bx, y: inset.maxY - bh, width: 42, height: bh))
            }
        }
    }

    private func drawSnowfall(in ctx: CGContext, inset: CGRect) {
        let cfg = settings.snowfallConfig
        // Holiday prop: multi-tier decorated pine + cheerful snowman on right side
        if cfg.showTreeAndSnowman {
            let sc: CGFloat = isPreviewMode ? 0.35 : 1.0
            let treeX = inset.maxX - 110 * sc
            let groundY = inset.maxY - 12 * sc
            ctx.setFillColor(NSColor.brown.cgColor)
            ctx.fill(CGRect(x: treeX - 6 * sc, y: groundY - 16 * sc, width: 12 * sc, height: 16 * sc))

            let boughs: [(topY: CGFloat, botY: CGFloat, halfW: CGFloat)] = [
                (groundY - 76 * sc, groundY - 16 * sc, 48 * sc),
                (groundY - 108 * sc, groundY - 52 * sc, 36 * sc),
                (groundY - 134 * sc, groundY - 84 * sc, 24 * sc)
            ]
            for b in boughs {
                let tp = CGMutablePath()
                tp.move(to: CGPoint(x: treeX, y: b.topY))
                tp.addLine(to: CGPoint(x: treeX + b.halfW, y: b.botY))
                tp.addLine(to: CGPoint(x: treeX - b.halfW, y: b.botY))
                tp.closeSubpath()
                ctx.addPath(tp)
                ctx.setFillColor(NSColor(srgbRed: 0.07, green: 0.38, blue: 0.16, alpha: 1).cgColor)
                ctx.fillPath()
            }
            // Gold tree topper & ornaments
            ctx.setFillColor(NSColor.systemYellow.cgColor)
            ctx.fillEllipse(in: CGRect(x: treeX - 5 * sc, y: groundY - 140 * sc, width: 10 * sc, height: 10 * sc))
            let ornaments: [(dx: CGFloat, dy: CGFloat, col: NSColor)] = [
                (-16, -32, .systemRed), (18, -28, .systemYellow), (0, -48, .cyan),
                (-12, -70, .systemPurple), (14, -68, .systemRed), (0, -96, .systemYellow)
            ]
            for o in ornaments {
                ctx.setFillColor(o.col.cgColor)
                ctx.fillEllipse(in: CGRect(x: treeX + o.dx * sc - 3 * sc, y: groundY + o.dy * sc - 3 * sc, width: 6 * sc, height: 6 * sc))
            }

            // Snowman to the left of tree with hat, eyes, carrot nose, scarf
            let smX = treeX - 88 * sc
            ctx.setFillColor(NSColor(white: 0.95, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: smX - 20 * sc, y: groundY - 40 * sc, width: 40 * sc, height: 40 * sc))
            ctx.fillEllipse(in: CGRect(x: smX - 14 * sc, y: groundY - 64 * sc, width: 28 * sc, height: 28 * sc))
            ctx.fillEllipse(in: CGRect(x: smX - 10 * sc, y: groundY - 82 * sc, width: 20 * sc, height: 20 * sc))
            // Scarf
            ctx.setFillColor(NSColor.systemRed.cgColor)
            ctx.fill(CGRect(x: smX - 11 * sc, y: groundY - 65 * sc, width: 22 * sc, height: 4 * sc))
            // Top hat
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fill(CGRect(x: smX - 12 * sc, y: groundY - 84 * sc, width: 24 * sc, height: 3 * sc))
            ctx.fill(CGRect(x: smX - 8 * sc, y: groundY - 96 * sc, width: 16 * sc, height: 12 * sc))
            // Eyes & carrot nose
            ctx.fillEllipse(in: CGRect(x: smX - 4 * sc, y: groundY - 76 * sc, width: 2.5 * sc, height: 2.5 * sc))
            ctx.fillEllipse(in: CGRect(x: smX + 2 * sc, y: groundY - 76 * sc, width: 2.5 * sc, height: 2.5 * sc))
            ctx.setFillColor(NSColor.systemOrange.cgColor)
            ctx.fill(CGRect(x: smX - 1 * sc, y: groundY - 73 * sc, width: 7 * sc, height: 2.5 * sc))
        }

        // Santa curved sleigh & silhouette reindeer across upper sky
        if cfg.showSanta {
            let sy = inset.minY + inset.height * 0.20
            // Runners & sleigh body
            ctx.setStrokeColor(NSColor(white: 0.85, alpha: 0.9).cgColor)
            ctx.setLineWidth(1.8)
            ctx.move(to: CGPoint(x: santaX - 4, y: sy + 18))
            ctx.addLine(to: CGPoint(x: santaX + 44, y: sy + 18))
            ctx.addQuadCurve(to: CGPoint(x: santaX + 49, y: sy + 12), control: CGPoint(x: santaX + 49, y: sy + 18))
            ctx.strokePath()
            ctx.setFillColor(NSColor(srgbRed: 0.85, green: 0.12, blue: 0.16, alpha: 0.92).cgColor)
            ctx.fill(CGRect(x: santaX, y: sy + 5, width: 38, height: 11))
            // Santa silhouette
            ctx.fillEllipse(in: CGRect(x: santaX + 20, y: sy - 2, width: 9, height: 9))
            // Reindeer pair with antlers & harness line
            ctx.setStrokeColor(NSColor(srgbRed: 0.90, green: 0.78, blue: 0.40, alpha: 0.6).cgColor)
            ctx.setLineWidth(1.0)
            ctx.move(to: CGPoint(x: santaX + 38, y: sy + 8))
            ctx.addLine(to: CGPoint(x: santaX + 94, y: sy + 8))
            ctx.strokePath()
            ctx.setFillColor(NSColor(srgbRed: 0.62, green: 0.40, blue: 0.20, alpha: 0.92).cgColor)
            for dx in [54.0, 80.0] {
                ctx.fillEllipse(in: CGRect(x: santaX + dx, y: sy + 5, width: 16, height: 8))
                ctx.fillEllipse(in: CGRect(x: santaX + dx + 13, y: sy, width: 6, height: 6))
                ctx.fill(CGRect(x: santaX + dx + 2, y: sy + 12, width: 2, height: 6))
                ctx.fill(CGRect(x: santaX + dx + 12, y: sy + 12, width: 2, height: 6))
            }
        }

        // Snowflakes
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        for f in flakes {
            ctx.fillEllipse(in: CGRect(x: f.x, y: f.y, width: f.size, height: f.size))
        }

        // Accumulated drift along bottom
        if cfg.accumulateSnow && !snowDriftHeights.isEmpty {
            ctx.setFillColor(NSColor(white: 0.93, alpha: 0.92).cgColor)
            let bucketW = inset.width / CGFloat(snowDriftHeights.count)
            for (idx, h) in snowDriftHeights.enumerated() {
                ctx.fill(CGRect(x: inset.minX + CGFloat(idx) * bucketW, y: inset.maxY - h, width: bucketW + 1, height: h))
            }
        }
    }

    private func drawCustomMessage(text: String, rect: CGRect, centered: Bool) {
        let baseSz = CGFloat(settings.ssMsgSize) * (isPreviewMode ? 0.55 : 1.0)
        var font = NSFont(name: settings.ssMsgFont, size: baseSz) ?? NSFont.systemFont(ofSize: baseSz)
        if settings.ssMsgBold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        let para = NSMutableParagraphStyle()
        para.alignment = centered ? .center : .left
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(hex: settings.ssMsgColorHex, fallback: .red),
            .paragraphStyle: para
        ]
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }
}

// MARK: - Full-Screen Screen Saver Controller + Idle & Hot Corner Monitor

private final class ScreenSaverOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class ScreenSaverWindowController {
    private var windows: [NSWindow] = []
    private var views: [ScreenSaverCanvasView] = []
    private var animTimer: Timer?
    private var idleMonitorTimer: Timer?
    private var localKeyMonitor: Any?
    private var localMouseMonitor: Any?
    private var lastHotCornerFire: Date = .distantPast

    private(set) var isActive: Bool = false
    var onActiveStateChanged: ((Bool) -> Void)?

    func configureMonitoring(settings: AppSettings) {
        idleMonitorTimer?.invalidate()
        idleMonitorTimer = nil
        guard settings.ssEnable || settings.useHotCorners else { return }

        idleMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkIdleAndHotCorners()
        }
    }

    func startScreenSaver(settings: AppSettings) {
        guard !isActive else { return }
        isActive = true
        onActiveStateChanged?(true)

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            isActive = false
            onActiveStateChanged?(false)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        for scr in screens {
            let win = ScreenSaverOverlayWindow(
                contentRect: scr.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: scr
            )
            win.level = .screenSaver
            win.isReleasedWhenClosed = false
            win.isOpaque = true
            win.backgroundColor = .black
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let view = ScreenSaverCanvasView(frame: CGRect(origin: .zero, size: scr.frame.size), settings: settings, preview: false)
            win.contentView = view
            win.makeKeyAndOrderFront(nil)
            windows.append(win)
            views.append(view)
        }

        // Exact 50ms animation cadence from Twinkle Bulbs v6.0
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.050, repeats: true) { [weak self] _ in
            self?.views.forEach { $0.stepFrame() }
        }

        installDismissMonitors(settings: settings)
    }

    func stopScreenSaver() {
        guard isActive else { return }
        isActive = false
        animTimer?.invalidate(); animTimer = nil
        if let m = localKeyMonitor { NSEvent.removeMonitor(m); localKeyMonitor = nil }
        if let m = localMouseMonitor { NSEvent.removeMonitor(m); localMouseMonitor = nil }
        let oldWindows = windows
        windows.removeAll()
        views.removeAll()
        for w in oldWindows {
            w.orderOut(nil)
            w.contentView = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            _ = oldWindows.count
        }
        onActiveStateChanged?(false)
    }

    private func installDismissMonitors(settings: AppSettings) {
        let spawnGrace = Date().addingTimeInterval(0.6)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] ev in
            guard let self, self.isActive, Date() > spawnGrace else { return ev }
            if settings.ssKeyboard || ev.keyCode == 53 /* Esc */ {
                DispatchQueue.main.async { self.stopScreenSaver() }
                return nil
            }
            return ev
        }
        var moveAccum = 0.0
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .mouseMoved, .scrollWheel]) { [weak self] ev in
            guard let self, self.isActive, Date() > spawnGrace else { return ev }
            switch ev.type {
            case .leftMouseDown, .rightMouseDown:
                if settings.ssMouseClick { DispatchQueue.main.async { self.stopScreenSaver() } }
            case .scrollWheel:
                if settings.ssMouseWheel { DispatchQueue.main.async { self.stopScreenSaver() } }
            case .mouseMoved:
                if settings.ssMouseMove {
                    moveAccum += hypot(Double(ev.deltaX), Double(ev.deltaY))
                    if moveAccum > 24.0 { DispatchQueue.main.async { self.stopScreenSaver() } }
                }
            default:
                break
            }
            return ev
        }
    }

    private func checkIdleAndHotCorners() {
        let s = SettingsStore.shared.settings
        guard !isActive else { return }

        if s.useHotCorners, let main = NSScreen.main {
            let loc = NSEvent.mouseLocation
            let f = main.frame
            let margin: CGFloat = 6.0
            let hitTL = s.hotCornerTopLeft && loc.x <= f.minX + margin && loc.y >= f.maxY - margin
            let hitTR = s.hotCornerTopRight && loc.x >= f.maxX - margin && loc.y >= f.maxY - margin
            let hitBL = s.hotCornerBottomLeft && loc.x <= f.minX + margin && loc.y <= f.minY + margin
            let hitBR = s.hotCornerBottomRight && loc.x >= f.maxX - margin && loc.y <= f.minY + margin
            if (hitTL || hitTR || hitBL || hitBR) && Date().timeIntervalSince(lastHotCornerFire) > 4.0 {
                lastHotCornerFire = Date()
                startScreenSaver(settings: s)
                return
            }
        }

        if s.ssEnable && s.ssDelayMinutes > 0 {
            let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
            if idle >= TimeInterval(s.ssDelayMinutes * 60) {
                startScreenSaver(settings: s)
            }
        }
    }
}
