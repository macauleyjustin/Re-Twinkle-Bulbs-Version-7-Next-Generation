import Cocoa
import CoreGraphics

// MARK: - Extensible Screen Saver Module Protocol (CD Programmer's Toolkit Pattern)

public protocol TwinkleScreenSaverPlugin: AnyObject {
    var moduleID: String { get }
    var displayName: String { get }
    func reset(in rect: CGRect, settings: AppSettings, preview: Bool)
    func step(in rect: CGRect, settings: AppSettings, tick: Int)
    func draw(in ctx: CGContext, rect: CGRect, settings: AppSettings, preview: Bool, tick: Int)
}

public final class ScreenSaverPluginRegistry {
    public static let shared = ScreenSaverPluginRegistry()
    private var externalPlugins: [String: TwinkleScreenSaverPlugin] = [:]

    public func register(_ plugin: TwinkleScreenSaverPlugin) {
        externalPlugins[plugin.moduleID] = plugin
    }

    public func plugin(for moduleID: String) -> TwinkleScreenSaverPlugin? {
        externalPlugins[moduleID]
    }
}

// MARK: - Unified Animated Particle/Scene State for the 20 New Seasonal Modules & Slideshow

public final class SeasonalScreenSaverRenderer {
    public struct ParticleItem {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var size: CGFloat
        var angle: CGFloat
        var vAngle: CGFloat
        var phase: Double
        var speed: Double
        var kind: Int
        var color: NSColor
    }

    private var items: [ParticleItem] = []
    private var burstParticles: [(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat, life: CGFloat, col: NSColor)] = []
    private var slideshowIndex: Int = 0
    private var slideshowTickCounter: Int = 0
    private var slideshowCacheImage: NSImage?
    private var frostProgress: CGFloat = 0.0
    private var lightningAlpha: CGFloat = 0.0

    public init() {}

    /// Optional gentle pointer interaction defers particles smoothly away from moving cursor when opted in.
    public func applyPointerRepulsion(at point: CGPoint, radius: CGFloat = 110.0) {
        let r2 = radius * radius
        for i in items.indices {
            let dx = items[i].x - point.x
            let dy = items[i].y - point.y
            let d2 = dx * dx + dy * dy
            if d2 > 1.0 && d2 < r2 {
                let d = sqrt(d2)
                let push = (1.0 - d / radius) * 2.2
                items[i].x += (dx / d) * push
                items[i].y += (dy / d) * push
            }
        }
    }

    public func reset(module: ScreenSaverModuleID, bounds: CGRect, settings: AppSettings, preview: Bool) {
        items.removeAll()
        burstParticles.removeAll()
        frostProgress = 0.05
        lightningAlpha = 0.0
        slideshowTickCounter = 0

        let w = max(120, bounds.width)
        let h = max(80, bounds.height)
        let cfg = settings.seasonalSSConfig
        let densityScale = CGFloat(max(0.3, min(2.0, cfg.density)))
        let baseCount = Int((preview ? 18.0 : 55.0) * densityScale)

        switch module {
        case .twinklingWreath:
            // 28 warm glowing nostalgic Christmas bulbs wrapped physically around wreath circumference
            for i in 0..<28 {
                let c: NSColor = [NSColor(srgbRed: 1, green: 0.22, blue: 0.22, alpha: 1),
                                  NSColor(srgbRed: 0.25, green: 0.92, blue: 0.30, alpha: 1),
                                  NSColor(srgbRed: 1, green: 0.84, blue: 0.28, alpha: 1),
                                  NSColor(srgbRed: 0.32, green: 0.72, blue: 1.0, alpha: 1)][i % 4]
                items.append(ParticleItem(x: CGFloat(i), y: 0, vx: 0, vy: 0, size: 1, angle: CGFloat(i) * (.pi * 2 / 28.0), vAngle: 0, phase: Double.random(in: 0...6.28), speed: Double.random(in: 0.05...0.16), kind: i, color: c))
            }
        case .christmasTreeGlow:
            // Garland bulb positions in normalized tree triangle coords (-1..1 width, 0..1 height)
            for i in 0..<32 {
                let fy = 0.16 + CGFloat(i) / 36.0
                let halfW = fy * 0.72
                let fx = CGFloat(sin(Double(i) * 1.35)) * halfW
                let c: NSColor = [NSColor.systemRed, .systemYellow, .systemGreen, .systemCyan, .systemOrange][i % 5]
                items.append(ParticleItem(x: fx, y: fy, vx: 0, vy: 0, size: CGFloat.random(in: 0.8...1.3), angle: 0, vAngle: 0, phase: Double.random(in: 0...6.28), speed: Double.random(in: 0.06...0.18), kind: i % 3, color: c))
            }
        case .fallingAutumnLeaves, .autumnForest:
            let leafCols = [
                NSColor(srgbRed: 0.86, green: 0.18, blue: 0.12, alpha: 1), // Red maple
                NSColor(srgbRed: 0.96, green: 0.48, blue: 0.08, alpha: 1), // Orange maple
                NSColor(srgbRed: 0.94, green: 0.76, blue: 0.14, alpha: 1), // Yellow birch/oak
                NSColor(srgbRed: 0.68, green: 0.36, blue: 0.12, alpha: 1)  // Bronze oak
            ]
            for _ in 0..<max(12, baseCount) {
                items.append(ParticleItem(
                    x: CGFloat.random(in: 0...w),
                    y: CGFloat.random(in: 0...h),
                    vx: CGFloat.random(in: -0.6...0.6),
                    vy: CGFloat.random(in: 0.9...2.4),
                    size: (preview ? 0.55 : 1.0) * CGFloat.random(in: 9...18),
                    angle: CGFloat.random(in: 0...6.28),
                    vAngle: CGFloat.random(in: -0.06...0.06),
                    phase: Double.random(in: 0...6.28),
                    speed: Double.random(in: 0.04...0.10),
                    kind: Int.random(in: 0...2), // 0=Maple, 1=Oak, 2=Birch
                    color: leafCols.randomElement()!
                ))
            }
        case .glowingPumpkin, .harvestPumpkinPatch, .hauntedHouse, .fireplaceChristmas:
            // Floating embers / fog wisps / autumn leaves / bats
            for i in 0..<max(10, baseCount / 2) {
                items.append(ParticleItem(
                    x: CGFloat.random(in: 0...w),
                    y: CGFloat.random(in: 0...h),
                    vx: CGFloat.random(in: -1.4...1.4),
                    vy: module == .fireplaceChristmas ? -CGFloat.random(in: 0.8...2.4) : CGFloat.random(in: -0.5...0.7),
                    size: (preview ? 0.6 : 1.0) * CGFloat.random(in: 3...12),
                    angle: CGFloat.random(in: 0...6.28),
                    vAngle: CGFloat.random(in: -0.05...0.05),
                    phase: Double.random(in: 0...6.28),
                    speed: Double.random(in: 0.05...0.15),
                    kind: i % 3,
                    color: module == .fireplaceChristmas ? .systemOrange : NSColor(srgbRed: 0.85, green: 0.88, blue: 0.92, alpha: 0.25)
                ))
            }
        case .springBlossoms, .easterGarden, .valentineHearts:
            let cPalette: [NSColor] = (module == .valentineHearts)
                ? [NSColor(srgbRed: 0.96, green: 0.18, blue: 0.28, alpha: 0.9), NSColor(srgbRed: 1.0, green: 0.45, blue: 0.68, alpha: 0.9), NSColor(srgbRed: 1.0, green: 0.72, blue: 0.84, alpha: 0.85)]
                : [NSColor(srgbRed: 1.0, green: 0.76, blue: 0.85, alpha: 0.9), NSColor(srgbRed: 1.0, green: 0.88, blue: 0.94, alpha: 0.9), NSColor(srgbRed: 0.98, green: 0.64, blue: 0.78, alpha: 0.85)]
            for i in 0..<max(15, baseCount) {
                let rise = (module == .valentineHearts)
                items.append(ParticleItem(
                    x: CGFloat.random(in: 0...w),
                    y: CGFloat.random(in: 0...h),
                    vx: CGFloat.random(in: -0.5...0.5),
                    vy: rise ? -CGFloat.random(in: 0.8...2.0) : CGFloat.random(in: 0.7...1.8),
                    size: (preview ? 0.55 : 1.0) * CGFloat.random(in: 8...18),
                    angle: CGFloat.random(in: -0.4...0.4),
                    vAngle: CGFloat.random(in: -0.03...0.03),
                    phase: Double.random(in: 0...6.28),
                    speed: Double.random(in: 0.04...0.10),
                    kind: i % 4,
                    color: cPalette.randomElement()!
                ))
            }
        case .springRain:
            for i in 0..<max(24, baseCount) {
                items.append(ParticleItem(
                    x: CGFloat.random(in: 0...w),
                    y: CGFloat.random(in: 0...h),
                    vx: 0,
                    vy: CGFloat.random(in: 4.5...9.5) * (preview ? 0.55 : 1.0),
                    size: CGFloat.random(in: 6...16),
                    angle: 0, vAngle: 0,
                    phase: Double.random(in: 0...6.28), speed: 0.08,
                    kind: i % 5,
                    color: NSColor(srgbRed: 0.72, green: 0.88, blue: 1.0, alpha: 0.55)
                ))
            }
        case .summerFireflies, .summerNightSky:
            for i in 0..<max(20, baseCount) {
                let c = (module == .summerFireflies)
                    ? NSColor(srgbRed: 0.76, green: 1.0, blue: 0.25, alpha: 1.0)
                    : [NSColor.white, NSColor(srgbRed: 0.80, green: 0.90, blue: 1.0, alpha: 1.0), NSColor(srgbRed: 1.0, green: 0.92, blue: 0.74, alpha: 1.0)][i % 3]
                items.append(ParticleItem(
                    x: CGFloat.random(in: 0...w),
                    y: CGFloat.random(in: 0...(module == .summerNightSky ? h * 0.78 : h)),
                    vx: module == .summerFireflies ? CGFloat.random(in: -0.9...0.9) : 0,
                    vy: module == .summerFireflies ? CGFloat.random(in: -0.7...0.7) : 0,
                    size: (preview ? 0.65 : 1.0) * CGFloat.random(in: 2...5.5),
                    angle: 0, vAngle: 0,
                    phase: Double.random(in: 0...6.28),
                    speed: Double.random(in: 0.04...0.12),
                    kind: i % 4,
                    color: c
                ))
            }
        case .snowfallVillage, .gingerbreadVillage, .winterFrost:
            for i in 0..<max(25, baseCount) {
                items.append(ParticleItem(
                    x: CGFloat.random(in: 0...w),
                    y: CGFloat.random(in: 0...h),
                    vx: CGFloat.random(in: -0.4...0.4),
                    vy: CGFloat.random(in: 0.7...2.2) * (preview ? 0.6 : 1.0),
                    size: (preview ? 0.65 : 1.0) * CGFloat.random(in: 2...5),
                    angle: 0, vAngle: 0,
                    phase: Double.random(in: 0...6.28), speed: 0.07,
                    kind: i % 4,
                    color: NSColor(white: 0.96, alpha: 0.88)
                ))
            }
        case .beachSunset:
            for i in 0..<24 {
                items.append(ParticleItem(x: CGFloat(i), y: 0, vx: 0, vy: 0, size: 1, angle: 0, vAngle: 0, phase: Double(i) * 0.45, speed: 0.06, kind: i, color: .orange))
            }
        case .newYearsCelebration, .patrioticCelebration:
            for i in 0..<18 {
                let c: NSColor = (module == .patrioticCelebration)
                    ? [NSColor.systemRed, .white, .systemBlue][i % 3]
                    : [NSColor.systemYellow, .systemCyan, .systemPink, .white, .systemOrange][i % 5]
                items.append(ParticleItem(x: CGFloat.random(in: 0...w), y: CGFloat.random(in: 0...h * 0.75), vx: 0, vy: 0, size: 3, angle: 0, vAngle: 0, phase: Double.random(in: 0...6.28), speed: 0.1, kind: i, color: c))
            }
        case .wallpaperSlideshow:
            loadSlideshowImage()
        default:
            break
        }
    }

    public func step(module: ScreenSaverModuleID, inset: CGRect, settings: AppSettings, preview: Bool, tick: Int) {
        let cfg = settings.seasonalSSConfig
        let spd = cfg.reduceMotion ? 0.35 : CGFloat(max(0.2, cfg.speed))
        let w = max(60, inset.width), h = max(60, inset.height)

        for i in items.indices {
            items[i].phase += items[i].speed * Double(spd)
            items[i].angle += items[i].vAngle * spd

            switch module {
            case .fallingAutumnLeaves, .autumnForest:
                let windExtra: CGFloat = cfg.windCondition == .gentle ? 0.3 : (cfg.windCondition == .breezy ? 1.1 : 2.3)
                let flutter = sin(CGFloat(items[i].phase)) * (0.9 + windExtra * 0.7)
                items[i].x += (items[i].vx + windExtra * 0.55 + flutter * 0.45) * spd
                items[i].y += items[i].vy * spd
                if items[i].y > inset.maxY + 12 {
                    items[i].y = inset.minY - 10
                    items[i].x = CGFloat.random(in: inset.minX...inset.maxX)
                }
                if items[i].x > inset.maxX + 12 { items[i].x = inset.minX - 8 }
                if items[i].x < inset.minX - 12 { items[i].x = inset.maxX + 8 }

            case .valentineHearts:
                items[i].x += sin(CGFloat(items[i].phase)) * 0.7 * spd
                items[i].y += items[i].vy * spd
                if items[i].y < inset.minY - 18 {
                    items[i].y = inset.maxY + 12
                    items[i].x = CGFloat.random(in: inset.minX...inset.maxX)
                }

            case .springBlossoms, .easterGarden, .snowfallVillage, .gingerbreadVillage, .winterFrost:
                items[i].x += (items[i].vx + sin(CGFloat(items[i].phase)) * 0.65) * spd
                items[i].y += items[i].vy * spd
                if items[i].y > inset.maxY + 12 {
                    items[i].y = inset.minY - 8
                    items[i].x = CGFloat.random(in: inset.minX...inset.maxX)
                }

            case .springRain:
                items[i].y += items[i].vy * spd
                if items[i].y > inset.maxY + 14 {
                    items[i].y = inset.minY - 10
                    items[i].x = CGFloat.random(in: inset.minX...inset.maxX)
                }

            case .summerFireflies, .hauntedHouse:
                items[i].x += (items[i].vx + cos(CGFloat(items[i].phase) * 0.7) * 0.5) * spd
                items[i].y += (items[i].vy + sin(CGFloat(items[i].phase)) * 0.4) * spd
                if items[i].x < inset.minX || items[i].x > inset.maxX { items[i].vx *= -1 }
                if items[i].y < inset.minY || items[i].y > inset.maxY { items[i].vy *= -1 }

            case .fireplaceChristmas:
                items[i].x += sin(CGFloat(items[i].phase)) * 0.8
                items[i].y += items[i].vy * spd
                if items[i].y < inset.minY + h * 0.35 {
                    items[i].y = inset.maxY - h * 0.15
                    items[i].x = inset.midX + CGFloat.random(in: -w * 0.18...w * 0.18)
                }
            default:
                break
            }
        }

        if module == .winterFrost {
            frostProgress = min(1.0, frostProgress + 0.004 * spd)
        }
        if module == .springRain || module == .hauntedHouse {
            lightningAlpha = max(0, lightningAlpha - 0.06)
            if Int.random(in: 0..<110) == 0 { lightningAlpha = 0.75 }
        }
        if module == .newYearsCelebration || module == .patrioticCelebration {
            for idx in burstParticles.indices.reversed() {
                burstParticles[idx].x += burstParticles[idx].vx * spd
                burstParticles[idx].y += burstParticles[idx].vy * spd
                burstParticles[idx].vy += 0.08 * spd
                burstParticles[idx].life -= 0.025 * spd
                if burstParticles[idx].life <= 0 { burstParticles.remove(at: idx) }
            }
            if burstParticles.count < 40 && Int.random(in: 0..<14) == 0 {
                let cx = CGFloat.random(in: (inset.minX + w * 0.15)...(inset.maxX - w * 0.15))
                let cy = CGFloat.random(in: (inset.minY + h * 0.15)...(inset.minY + h * 0.55))
                let pal: [NSColor] = (module == .patrioticCelebration) ? [.systemRed, .white, .systemBlue] : [.systemYellow, .systemCyan, .systemPink, .systemOrange, .white]
                let col = pal.randomElement()!
                for k in 0..<24 {
                    let a = CGFloat(k) * (.pi * 2 / 24.0)
                    let v = CGFloat.random(in: 1.5...4.2) * (preview ? 0.5 : 1.0)
                    burstParticles.append((cx, cy, cos(a) * v, sin(a) * v, 1.0, col))
                }
            }
        }
        if module == .wallpaperSlideshow {
            slideshowTickCounter += 1
            let switchTicks = max(20, Int(cfg.slideshowIntervalSec * 20.0))
            if slideshowTickCounter >= switchTicks {
                slideshowTickCounter = 0
                slideshowIndex += 1
                loadSlideshowImage()
            }
        }
    }

    private func loadSlideshowImage() {
        let wpList = WallpaperService.shared.items
        guard !wpList.isEmpty else { return }
        let item = wpList[slideshowIndex % wpList.count]
        slideshowCacheImage = WallpaperService.shared.previewImage(for: item)
    }

    // MARK: - Scene Rendering for All 20 New Modules + Wallpaper Slideshow

    public func drawBackground(module: ScreenSaverModuleID, in ctx: CGContext, bounds: CGRect, settings: AppSettings) {
        let b = CGFloat(max(0.25, min(1.0, settings.seasonalSSConfig.brightness)))
        let colors: [CGColor]
        switch module {
        case .twinklingWreath, .christmasTreeGlow, .snowfallVillage, .gingerbreadVillage, .winterFrost:
            colors = [NSColor(srgbRed: 0.02 * b, green: 0.05 * b, blue: 0.14 * b, alpha: 1).cgColor,
                      NSColor(srgbRed: 0.06 * b, green: 0.14 * b, blue: 0.28 * b, alpha: 1).cgColor]
        case .fireplaceChristmas:
            colors = [NSColor(srgbRed: 0.12 * b, green: 0.04 * b, blue: 0.02 * b, alpha: 1).cgColor,
                      NSColor(srgbRed: 0.24 * b, green: 0.09 * b, blue: 0.04 * b, alpha: 1).cgColor]
        case .fallingAutumnLeaves:
            switch settings.seasonalSSConfig.leavesBackground {
            case .blackNight:
                colors = [NSColor.black.cgColor, NSColor(srgbRed: 0.06, green: 0.04, blue: 0.03, alpha: 1).cgColor]
            case .twilightSunset:
                colors = [NSColor(srgbRed: 0.20 * b, green: 0.08 * b, blue: 0.03 * b, alpha: 1).cgColor,
                          NSColor(srgbRed: 0.42 * b, green: 0.19 * b, blue: 0.05 * b, alpha: 1).cgColor]
            case .autumnLandscape:
                colors = [NSColor(srgbRed: 0.32 * b, green: 0.22 * b, blue: 0.10 * b, alpha: 1).cgColor,
                          NSColor(srgbRed: 0.62 * b, green: 0.34 * b, blue: 0.12 * b, alpha: 1).cgColor]
            }
        case .autumnForest, .harvestPumpkinPatch:
            colors = [NSColor(srgbRed: 0.12 * b, green: 0.06 * b, blue: 0.14 * b, alpha: 1).cgColor,
                      NSColor(srgbRed: 0.34 * b, green: 0.16 * b, blue: 0.06 * b, alpha: 1).cgColor]
        case .glowingPumpkin, .hauntedHouse:
            colors = [NSColor(srgbRed: 0.04 * b, green: 0.03 * b, blue: 0.10 * b, alpha: 1).cgColor,
                      NSColor(srgbRed: 0.12 * b, green: 0.07 * b, blue: 0.20 * b, alpha: 1).cgColor]
        case .springBlossoms, .easterGarden:
            colors = [NSColor(srgbRed: 0.42 * b, green: 0.72 * b, blue: 0.96 * b, alpha: 1).cgColor,
                      NSColor(srgbRed: 0.72 * b, green: 0.90 * b, blue: 0.98 * b, alpha: 1).cgColor]
        case .springRain:
            colors = [NSColor(srgbRed: 0.12 * b, green: 0.18 * b, blue: 0.26 * b, alpha: 1).cgColor,
                      NSColor(srgbRed: 0.22 * b, green: 0.30 * b, blue: 0.40 * b, alpha: 1).cgColor]
        case .summerFireflies, .summerNightSky, .newYearsCelebration, .patrioticCelebration:
            colors = [NSColor(srgbRed: 0.01 * b, green: 0.03 * b, blue: 0.10 * b, alpha: 1).cgColor,
                      NSColor(srgbRed: 0.04 * b, green: 0.08 * b, blue: 0.22 * b, alpha: 1).cgColor]
        case .beachSunset:
            colors = [NSColor(srgbRed: 0.35 * b, green: 0.14 * b, blue: 0.44 * b, alpha: 1).cgColor,
                      NSColor(srgbRed: 0.96 * b, green: 0.48 * b, blue: 0.18 * b, alpha: 1).cgColor]
        case .valentineHearts:
            colors = [NSColor(srgbRed: 0.20 * b, green: 0.02 * b, blue: 0.08 * b, alpha: 1).cgColor,
                      NSColor(srgbRed: 0.38 * b, green: 0.06 * b, blue: 0.18 * b, alpha: 1).cgColor]
        default:
            colors = [NSColor.black.cgColor, NSColor.black.cgColor]
        }
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: bounds.height), options: [])
        }
    }

    public func drawForeground(module: ScreenSaverModuleID, in ctx: CGContext, inset: CGRect, settings: AppSettings, preview: Bool, tick: Int) {
        let cfg = settings.seasonalSSConfig
        let bright = CGFloat(max(0.25, min(1.0, cfg.brightness)))

        switch module {
        case .wallpaperSlideshow:
            if let img = slideshowCacheImage {
                img.draw(in: inset, from: .zero, operation: .sourceOver, fraction: bright)
            }

        case .twinklingWreath:
            let R = min(inset.width, inset.height) * 0.33 * CGFloat(cfg.wreathSizeScale)
            let center = CGPoint(x: inset.midX, y: inset.midY)
            // Evergreen pine needle ring
            ctx.setStrokeColor(NSColor(srgbRed: 0.08, green: 0.44, blue: 0.14, alpha: 1).cgColor)
            ctx.setLineWidth(R * 0.42)
            ctx.strokeEllipse(in: CGRect(x: center.x - R, y: center.y - R, width: R * 2, height: R * 2))
            ctx.setStrokeColor(NSColor(srgbRed: 0.14, green: 0.60, blue: 0.20, alpha: 0.75).cgColor)
            ctx.setLineWidth(R * 0.24)
            ctx.strokeEllipse(in: CGRect(x: center.x - R, y: center.y - R, width: R * 2, height: R * 2))
            // Pine cones
            for a in [0.6, 2.5, 4.2] {
                let px = center.x + cos(CGFloat(a)) * R, py = center.y + sin(CGFloat(a)) * R
                ctx.setFillColor(NSColor(srgbRed: 0.48, green: 0.28, blue: 0.12, alpha: 1).cgColor)
                ctx.fillEllipse(in: CGRect(x: px - R * 0.10, y: py - R * 0.14, width: R * 0.20, height: R * 0.28))
            }
            // Nostalgic warm red bow at top
            let bowY = center.y - R
            ctx.setFillColor(NSColor(srgbRed: 0.88, green: 0.10, blue: 0.14, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: center.x - R * 0.42, y: bowY - R * 0.18, width: R * 0.40, height: R * 0.30))
            ctx.fillEllipse(in: CGRect(x: center.x + R * 0.02, y: bowY - R * 0.18, width: R * 0.40, height: R * 0.30))
            ctx.fillEllipse(in: CGRect(x: center.x - R * 0.11, y: bowY - R * 0.11, width: R * 0.22, height: R * 0.22))
            // Wrapped strand wire + independently twinkling bulbs
            ctx.setStrokeColor(NSColor(srgbRed: 0.04, green: 0.28, blue: 0.08, alpha: 0.8).cgColor)
            ctx.setLineWidth(preview ? 1.2 : 2.5)
            ctx.strokeEllipse(in: CGRect(x: center.x - R, y: center.y - R, width: R * 2, height: R * 2))
            for item in items {
                let glow = CGFloat(0.25 + 0.75 * (0.5 + 0.5 * sin(item.phase))) * bright
                let rad = R + CGFloat(sin(Double(item.kind) * 2.1)) * (R * 0.15)
                let bx = center.x + cos(item.angle) * rad
                let by = center.y + sin(item.angle) * rad
                let bSz = max(4.0, R * 0.13)
                ctx.setFillColor(item.color.withAlphaComponent(glow * 0.35).cgColor)
                ctx.fillEllipse(in: CGRect(x: bx - bSz * 1.1, y: by - bSz * 1.1, width: bSz * 2.2, height: bSz * 2.2))
                ctx.setFillColor(item.color.withAlphaComponent(glow).cgColor)
                ctx.fillEllipse(in: CGRect(x: bx - bSz * 0.5, y: by - bSz * 0.5, width: bSz, height: bSz))
            }

        case .christmasTreeGlow:
            let cx = inset.midX, topY = inset.minY + inset.height * 0.14, botY = inset.maxY - inset.height * 0.12
            let treeH = botY - topY, treeW = min(inset.width * 0.45, treeH * 0.75)
            ctx.setFillColor(NSColor(srgbRed: 0.44, green: 0.24, blue: 0.10, alpha: 1).cgColor)
            ctx.fill(CGRect(x: cx - treeW * 0.08, y: botY - treeH * 0.05, width: treeW * 0.16, height: treeH * 0.12))
            ctx.setFillColor(NSColor(srgbRed: 0.06, green: 0.42, blue: 0.14, alpha: 1).cgColor)
            for layer in 0..<3 {
                let lyTop = topY + CGFloat(layer) * treeH * 0.24
                let lyBot = topY + CGFloat(layer + 1) * treeH * 0.32 + treeH * 0.06
                let hw = treeW * (0.28 + CGFloat(layer) * 0.15)
                let tri = CGMutablePath(); tri.move(to: CGPoint(x: cx, y: lyTop)); tri.addLine(to: CGPoint(x: cx - hw, y: lyBot)); tri.addLine(to: CGPoint(x: cx + hw, y: lyBot)); tri.closeSubpath()
                ctx.addPath(tri); ctx.fillPath()
            }
            // Gold star atop
            let stPath = Holiday250Catalog.starPath(center: CGPoint(x: cx, y: topY), outerR: max(7, treeW * 0.09), innerR: max(3, treeW * 0.04), points: 5)
            ctx.addPath(stPath); ctx.setFillColor(NSColor.systemYellow.withAlphaComponent(bright).cgColor); ctx.fillPath()
            for item in items {
                let bx = cx + item.x * (treeW * 0.55)
                let by = topY + item.y * treeH * 0.90
                let tw = CGFloat(0.2 + 0.8 * (0.5 + 0.5 * sin(item.phase))) * bright
                let r = max(3.5, treeW * 0.025)
                ctx.setFillColor(item.color.withAlphaComponent(tw * 0.35).cgColor)
                ctx.fillEllipse(in: CGRect(x: bx - r * 1.8, y: by - r * 1.8, width: r * 3.6, height: r * 3.6))
                ctx.setFillColor(item.color.withAlphaComponent(tw).cgColor)
                ctx.fillEllipse(in: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2))
            }

        case .snowfallVillage, .gingerbreadVillage:
            let groundY = inset.maxY - inset.height * 0.16
            ctx.setFillColor((module == .gingerbreadVillage ? NSColor(srgbRed: 0.96, green: 0.88, blue: 0.92, alpha: 1) : NSColor(white: 0.92, alpha: 1)).cgColor)
            ctx.fill(CGRect(x: inset.minX, y: groundY, width: inset.width, height: inset.height * 0.18))
            let houseCount = 4
            for hIdx in 0..<houseCount {
                let hx = inset.minX + inset.width * (0.14 + CGFloat(hIdx) * 0.21)
                let hw = inset.width * 0.13, hh = inset.height * 0.20
                let hy = groundY - hh
                let wallCol = module == .gingerbreadVillage ? NSColor(srgbRed: 0.68, green: 0.40, blue: 0.18, alpha: 1) : [NSColor.systemRed, .systemTeal, .systemBrown, .systemIndigo][hIdx]
                ctx.setFillColor(wallCol.cgColor); ctx.fill(CGRect(x: hx, y: hy, width: hw, height: hh))
                let roof = CGMutablePath(); roof.move(to: CGPoint(x: hx - 6, y: hy)); roof.addLine(to: CGPoint(x: hx + hw * 0.5, y: hy - hh * 0.55)); roof.addLine(to: CGPoint(x: hx + hw + 6, y: hy)); roof.closeSubpath()
                ctx.addPath(roof); ctx.setFillColor(NSColor(white: 0.94, alpha: 1).cgColor); ctx.fillPath()
                let winCol = NSColor(srgbRed: 1.0, green: 0.86, blue: 0.35, alpha: bright)
                ctx.setFillColor(winCol.cgColor)
                ctx.fill(CGRect(x: hx + hw * 0.20, y: hy + hh * 0.28, width: hw * 0.22, height: hh * 0.28))
                ctx.fill(CGRect(x: hx + hw * 0.58, y: hy + hh * 0.28, width: hw * 0.22, height: hh * 0.28))
            }
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            for item in items { ctx.fillEllipse(in: CGRect(x: item.x, y: item.y, width: item.size, height: item.size)) }

        case .fireplaceChristmas:
            let fpW = inset.width * 0.44, fpH = inset.height * 0.48
            let fpX = inset.midX - fpW * 0.5, fpY = inset.maxY - fpH
            // Brick surround + hearth
            ctx.setFillColor(NSColor(srgbRed: 0.48, green: 0.16, blue: 0.12, alpha: 1).cgColor)
            ctx.fill(CGRect(x: fpX, y: fpY, width: fpW, height: fpH))
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fill(CGRect(x: fpX + fpW * 0.16, y: fpY + fpH * 0.24, width: fpW * 0.68, height: fpH * 0.72))
            // Mantle + evergreen garland & stockings
            ctx.setFillColor(NSColor(srgbRed: 0.36, green: 0.20, blue: 0.08, alpha: 1).cgColor)
            ctx.fill(CGRect(x: fpX - 10, y: fpY - 10, width: fpW + 20, height: 14))
            for idx in 0..<3 {
                let sx = fpX + fpW * (0.20 + CGFloat(idx) * 0.26)
                ctx.setFillColor([NSColor.systemRed, .systemGreen, .systemRed][idx].cgColor)
                ctx.fill(CGRect(x: sx, y: fpY + 4, width: fpW * 0.08, height: fpH * 0.22))
            }
            // Dancing flame cones
            for fIdx in 0..<5 {
                let flicker = CGFloat(0.75 + 0.35 * sin(Double(tick) * 0.24 + Double(fIdx) * 1.4))
                let fx = inset.midX + CGFloat(fIdx - 2) * (fpW * 0.10)
                let fh = fpH * 0.44 * flicker
                ctx.setFillColor((fIdx % 2 == 0 ? NSColor.systemOrange : NSColor.systemYellow).withAlphaComponent(0.85 * bright).cgColor)
                ctx.fillEllipse(in: CGRect(x: fx - fpW * 0.07, y: inset.maxY - fh, width: fpW * 0.14, height: fh))
            }
            for item in items {
                ctx.setFillColor(NSColor.systemYellow.withAlphaComponent(0.75 * bright).cgColor)
                ctx.fillEllipse(in: CGRect(x: item.x, y: item.y, width: 3, height: 3))
            }

        case .winterFrost:
            let edgeSize = min(inset.width, inset.height) * 0.22 * frostProgress
            ctx.setStrokeColor(NSColor(srgbRed: 0.72, green: 0.90, blue: 1.0, alpha: 0.65 * bright).cgColor)
            ctx.setLineWidth(preview ? 1.0 : 2.0)
            for c in [CGPoint(x: inset.minX, y: inset.minY), CGPoint(x: inset.maxX, y: inset.minY), CGPoint(x: inset.minX, y: inset.maxY), CGPoint(x: inset.maxX, y: inset.maxY)] {
                for rIdx in 0..<5 {
                    let a = CGFloat(rIdx) * 0.35 + (c.x > inset.midX ? .pi : 0)
                    let dirY: CGFloat = (c.y > inset.midY ? -1 : 1)
                    ctx.move(to: c); ctx.addLine(to: CGPoint(x: c.x + cos(a) * edgeSize, y: c.y + dirY * abs(sin(a)) * edgeSize))
                }
            }
            ctx.strokePath()
            ctx.setFillColor(NSColor(white: 0.95, alpha: 0.85).cgColor)
            for item in items { ctx.fillEllipse(in: CGRect(x: item.x, y: item.y, width: item.size, height: item.size)) }

        case .fallingAutumnLeaves:
            drawFallingLeaves(in: ctx, items: items, bright: bright)

        case .autumnForest:
            let groundY = inset.maxY - inset.height * 0.14
            ctx.setFillColor(NSColor(srgbRed: 0.38, green: 0.22, blue: 0.08, alpha: 1).cgColor)
            ctx.fill(CGRect(x: inset.minX, y: groundY, width: inset.width, height: inset.height * 0.16))
            for i in 0..<5 {
                let tx = inset.minX + inset.width * (0.12 + CGFloat(i) * 0.19)
                let th = inset.height * (0.36 + CGFloat(i % 2) * 0.12)
                ctx.setFillColor(NSColor.brown.cgColor); ctx.fill(CGRect(x: tx - 6, y: groundY - th * 0.6, width: 12, height: th * 0.6))
                let canopy = [NSColor.systemOrange, .systemRed, .systemYellow, .systemOrange, .systemBrown][i]
                ctx.setFillColor(canopy.withAlphaComponent(0.9 * bright).cgColor)
                ctx.fillEllipse(in: CGRect(x: tx - th * 0.35, y: groundY - th, width: th * 0.70, height: th * 0.58))
            }
            drawFallingLeaves(in: ctx, items: items, bright: bright)

        case .glowingPumpkin:
            let r = min(inset.width, inset.height) * 0.34
            drawGlowingJackOLantern(in: ctx, center: CGPoint(x: inset.midX, y: inset.midY), radius: r, style: cfg.pumpkinFaceStyle, tick: tick, bright: bright)
            for item in items {
                ctx.setFillColor(item.color.cgColor)
                ctx.fillEllipse(in: CGRect(x: item.x, y: item.y, width: item.size * 3, height: item.size))
            }

        case .harvestPumpkinPatch:
            let groundY = inset.maxY - inset.height * 0.16
            ctx.setFillColor(NSColor(srgbRed: 0.12, green: 0.08, blue: 0.04, alpha: 1).cgColor)
            ctx.fill(CGRect(x: inset.minX, y: groundY, width: inset.width, height: inset.height * 0.18))
            for i in 0..<4 {
                let px = inset.minX + inset.width * (0.18 + CGFloat(i) * 0.21)
                let pr = min(inset.width, inset.height) * (i % 2 == 0 ? 0.10 : 0.08)
                drawGlowingJackOLantern(in: ctx, center: CGPoint(x: px, y: groundY - pr * 0.65), radius: pr, style: (i + cfg.pumpkinFaceStyle) % 4, tick: tick + i * 7, bright: bright)
            }

        case .hauntedHouse:
            if lightningAlpha > 0.05 {
                ctx.setFillColor(NSColor.white.withAlphaComponent(lightningAlpha * 0.35).cgColor)
                ctx.fill(inset)
            }
            // Full moon + Victorian manor silhouette + glowing windows + flying bats
            let mSz = min(inset.width, inset.height) * 0.22
            ctx.setFillColor(NSColor(srgbRed: 0.98, green: 0.92, blue: 0.68, alpha: 0.92).cgColor)
            ctx.fillEllipse(in: CGRect(x: inset.maxX - mSz * 1.8, y: inset.minY + mSz * 0.4, width: mSz, height: mSz))
            let hw = inset.width * 0.34, hh = inset.height * 0.38
            let hx = inset.midX - hw * 0.5, hy = inset.maxY - hh
            ctx.setFillColor(NSColor(white: 0.08, alpha: 1).cgColor); ctx.fill(CGRect(x: hx, y: hy, width: hw, height: hh))
            let roof = CGMutablePath(); roof.move(to: CGPoint(x: hx - 12, y: hy)); roof.addLine(to: CGPoint(x: inset.midX, y: hy - hh * 0.6)); roof.addLine(to: CGPoint(x: hx + hw + 12, y: hy)); roof.closeSubpath()
            ctx.addPath(roof); ctx.fillPath()
            ctx.setFillColor(NSColor.systemYellow.withAlphaComponent(bright * 0.9).cgColor)
            ctx.fill(CGRect(x: hx + hw * 0.22, y: hy + hh * 0.25, width: hw * 0.16, height: hh * 0.24))
            ctx.fill(CGRect(x: hx + hw * 0.62, y: hy + hh * 0.25, width: hw * 0.16, height: hh * 0.24))
            for item in items {
                ctx.setStrokeColor(NSColor.black.cgColor); ctx.setLineWidth(preview ? 1.2 : 2.2)
                ctx.move(to: CGPoint(x: item.x - item.size, y: item.y)); ctx.addQuadCurve(to: CGPoint(x: item.x, y: item.y + 3), control: CGPoint(x: item.x - item.size * 0.5, y: item.y - 5))
                ctx.addQuadCurve(to: CGPoint(x: item.x + item.size, y: item.y), control: CGPoint(x: item.x + item.size * 0.5, y: item.y - 5)); ctx.strokePath()
            }

        case .springBlossoms, .easterGarden:
            let groundY = inset.maxY - inset.height * 0.14
            ctx.setFillColor(NSColor(srgbRed: 0.24, green: 0.64, blue: 0.26, alpha: 1).cgColor)
            ctx.fill(CGRect(x: inset.minX, y: groundY, width: inset.width, height: inset.height * 0.16))
            if module == .easterGarden {
                for e in 0..<5 {
                    let ex = inset.minX + inset.width * (0.14 + CGFloat(e) * 0.18)
                    let ew = max(10, inset.width * 0.045)
                    ctx.setFillColor([NSColor.systemPink, .systemYellow, .systemCyan, .systemPurple, .systemMint][e].cgColor)
                    ctx.fillEllipse(in: CGRect(x: ex, y: groundY - ew * 0.85, width: ew, height: ew * 1.35))
                }
            }
            for item in items {
                ctx.saveGState(); ctx.translateBy(x: item.x, y: item.y); ctx.rotate(by: item.angle)
                ctx.setFillColor(item.color.cgColor)
                ctx.fillEllipse(in: CGRect(x: -item.size * 0.5, y: -item.size * 0.3, width: item.size, height: item.size * 0.6))
                ctx.restoreGState()
            }

        case .springRain:
            if lightningAlpha > 0.05 {
                ctx.setFillColor(NSColor.white.withAlphaComponent(lightningAlpha * 0.30).cgColor)
                ctx.fill(inset)
            }
            ctx.setStrokeColor(NSColor(srgbRed: 0.72, green: 0.88, blue: 1.0, alpha: 0.60 * bright).cgColor)
            ctx.setLineWidth(preview ? 1.0 : 1.8)
            for item in items {
                ctx.move(to: CGPoint(x: item.x, y: item.y)); ctx.addLine(to: CGPoint(x: item.x - 2, y: item.y + item.size))
            }
            ctx.strokePath()

        case .summerFireflies, .summerNightSky:
            if module == .summerNightSky {
                let groundY = inset.maxY - inset.height * 0.12
                ctx.setFillColor(NSColor(white: 0.04, alpha: 1).cgColor); ctx.fill(CGRect(x: inset.minX, y: groundY, width: inset.width, height: inset.height * 0.14))
            }
            for item in items {
                let glow = CGFloat(0.15 + 0.85 * (0.5 + 0.5 * sin(item.phase))) * bright
                ctx.setFillColor(item.color.withAlphaComponent(glow * 0.32).cgColor)
                ctx.fillEllipse(in: CGRect(x: item.x - item.size * 1.8, y: item.y - item.size * 1.8, width: item.size * 3.6, height: item.size * 3.6))
                ctx.setFillColor(item.color.withAlphaComponent(glow).cgColor)
                ctx.fillEllipse(in: CGRect(x: item.x - item.size * 0.6, y: item.y - item.size * 0.6, width: item.size * 1.2, height: item.size * 1.2))
            }

        case .beachSunset:
            let horizonY = inset.minY + inset.height * 0.56
            let sunR = min(inset.width, inset.height) * 0.18
            ctx.setFillColor(NSColor(srgbRed: 1.0, green: 0.72, blue: 0.20, alpha: 0.92 * bright).cgColor)
            ctx.fillEllipse(in: CGRect(x: inset.midX - sunR, y: horizonY - sunR * 0.7, width: sunR * 2, height: sunR * 1.4))
            ctx.setFillColor(NSColor(srgbRed: 0.06, green: 0.22, blue: 0.44, alpha: 1).cgColor)
            ctx.fill(CGRect(x: inset.minX, y: horizonY, width: inset.width, height: inset.maxY - horizonY))
            for item in items {
                let wy = horizonY + CGFloat(item.kind) * ((inset.maxY - horizonY) / 24.0)
                let shimmer = CGFloat(0.35 + 0.65 * abs(sin(item.phase))) * bright
                let sw = sunR * (1.5 - CGFloat(item.kind) * 0.03)
                ctx.setFillColor(NSColor(srgbRed: 1.0, green: 0.65, blue: 0.25, alpha: shimmer).cgColor)
                ctx.fill(CGRect(x: inset.midX - sw * 0.5 + sin(CGFloat(item.phase)) * 8, y: wy, width: sw, height: preview ? 1.5 : 3))
            }

        case .valentineHearts:
            for item in items {
                let pulse = CGFloat(0.65 + 0.35 * sin(item.phase)) * bright
                let hp = Holiday250Catalog.heartPath(cx: item.x, topY: item.y, w: item.size, h: item.size)
                ctx.addPath(hp); ctx.setFillColor(item.color.withAlphaComponent(pulse).cgColor); ctx.fillPath()
            }

        case .newYearsCelebration, .patrioticCelebration:
            for p in burstParticles {
                ctx.setFillColor(p.col.withAlphaComponent(max(0, p.life) * bright).cgColor)
                let r: CGFloat = preview ? 2.2 : 4.2
                ctx.fillEllipse(in: CGRect(x: p.x - r * 0.5, y: p.y - r * 0.5, width: r, height: r))
            }
            if module == .newYearsCelebration && cfg.showMidnightCountdown {
                let cal = Calendar.current
                let y = cal.component(.year, from: Date())
                let ny = cal.date(from: DateComponents(year: y + 1, month: 1, day: 1)) ?? Date()
                let diff = max(0, Int(ny.timeIntervalSinceNow))
                let d = diff / 86400; let h = (diff % 86400) / 3600; let m = (diff % 3600) / 60; let s = diff % 60
                let str = String(format: "New Year: %dd %02dh %02dm %02ds", d, h, m, s)
                let font = NSFont.boldSystemFont(ofSize: preview ? 11 : 28)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.systemYellow.withAlphaComponent(bright)]
                let sz = (str as NSString).size(withAttributes: attrs)
                (str as NSString).draw(at: CGPoint(x: inset.midX - sz.width * 0.5, y: inset.maxY - sz.height - (preview ? 14 : 42)), withAttributes: attrs)
            }
        default:
            break
        }
    }

    private func drawFallingLeaves(in ctx: CGContext, items: [ParticleItem], bright: CGFloat) {
        for item in items {
            ctx.saveGState()
            ctx.translateBy(x: item.x, y: item.y)
            ctx.rotate(by: item.angle)
            let s = item.size / 14.0
            ctx.setFillColor(item.color.withAlphaComponent(0.92 * bright).cgColor)
            if item.kind == 0 {
                // 3-lobed Maple leaf + stem
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 0, y: -8 * s)); p.addLine(to: CGPoint(x: 2.8 * s, y: -3 * s)); p.addLine(to: CGPoint(x: 7.5 * s, y: -2.2 * s))
                p.addLine(to: CGPoint(x: 4 * s, y: 2.5 * s)); p.addLine(to: CGPoint(x: 5 * s, y: 6.5 * s)); p.addLine(to: CGPoint(x: 0, y: 4.5 * s))
                p.addLine(to: CGPoint(x: -5 * s, y: 6.5 * s)); p.addLine(to: CGPoint(x: -4 * s, y: 2.5 * s)); p.addLine(to: CGPoint(x: -7.5 * s, y: -2.2 * s))
                p.addLine(to: CGPoint(x: -2.8 * s, y: -3 * s)); p.closeSubpath()
                ctx.addPath(p); ctx.fillPath()
            } else if item.kind == 1 {
                // Scalloped Oak leaf
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 0, y: -8 * s))
                p.addQuadCurve(to: CGPoint(x: 5 * s, y: -2 * s), control: CGPoint(x: 6 * s, y: -6 * s))
                p.addQuadCurve(to: CGPoint(x: 5 * s, y: 4 * s), control: CGPoint(x: 3 * s, y: 1 * s))
                p.addQuadCurve(to: CGPoint(x: 0, y: 8 * s), control: CGPoint(x: 5 * s, y: 7 * s))
                p.addQuadCurve(to: CGPoint(x: -5 * s, y: 4 * s), control: CGPoint(x: -5 * s, y: 7 * s))
                p.addQuadCurve(to: CGPoint(x: -5 * s, y: -2 * s), control: CGPoint(x: -3 * s, y: 1 * s))
                p.addQuadCurve(to: CGPoint(x: 0, y: -8 * s), control: CGPoint(x: -6 * s, y: -6 * s))
                ctx.addPath(p); ctx.fillPath()
            } else {
                // Serrated pointed Birch leaf
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 0, y: -8 * s))
                p.addQuadCurve(to: CGPoint(x: 5 * s, y: 1 * s), control: CGPoint(x: 6 * s, y: -2 * s))
                p.addQuadCurve(to: CGPoint(x: 0, y: 7 * s), control: CGPoint(x: 4 * s, y: 5 * s))
                p.addQuadCurve(to: CGPoint(x: -5 * s, y: 1 * s), control: CGPoint(x: -4 * s, y: 5 * s))
                p.addQuadCurve(to: CGPoint(x: 0, y: -8 * s), control: CGPoint(x: -6 * s, y: -2 * s))
                ctx.addPath(p); ctx.fillPath()
            }
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.32).cgColor)
            ctx.setLineWidth(max(0.7, 0.9 * s))
            ctx.move(to: CGPoint(x: 0, y: -5.5 * s)); ctx.addLine(to: CGPoint(x: 0, y: 9.5 * s)); ctx.strokePath()
            ctx.restoreGState()
        }
    }

    private func drawGlowingJackOLantern(in ctx: CGContext, center: CGPoint, radius: CGFloat, style: Int, tick: Int, bright: CGFloat) {
        let flicker = CGFloat(0.78 + 0.22 * sin(Double(tick) * 0.31) * cos(Double(tick) * 0.17)) * bright
        // Stem
        ctx.setFillColor(NSColor(srgbRed: 0.18, green: 0.45, blue: 0.12, alpha: 1).cgColor)
        ctx.fill(CGRect(x: center.x - radius * 0.12, y: center.y - radius * 1.05, width: radius * 0.24, height: radius * 0.30))
        // Glowing Aura
        ctx.setFillColor(NSColor(srgbRed: 1.0, green: 0.48, blue: 0.05, alpha: 0.25 * flicker).cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - radius * 1.45, y: center.y - radius * 1.1, width: radius * 2.9, height: radius * 2.2))
        // Pumpkin ribs
        let shell = CGRect(x: center.x - radius * 1.15, y: center.y - radius * 0.85, width: radius * 2.30, height: radius * 1.70)
        ctx.setFillColor(NSColor(srgbRed: 0.92, green: 0.42, blue: 0.06, alpha: 1).cgColor)
        ctx.fillEllipse(in: shell)
        ctx.setStrokeColor(NSColor(srgbRed: 0.58, green: 0.22, blue: 0.02, alpha: 0.65).cgColor)
        ctx.setLineWidth(max(1.0, radius * 0.04))
        ctx.strokeEllipse(in: CGRect(x: center.x - radius * 0.65, y: shell.minY, width: radius * 1.30, height: shell.height))
        // Carved glowing candle features
        let innerGlow = NSColor(srgbRed: 1.0, green: 0.88 * flicker, blue: 0.25, alpha: flicker)
        ctx.setFillColor(innerGlow.cgColor)
        let eyY = center.y - radius * 0.24, eyeSz = radius * 0.28
        for side: CGFloat in [-1, 1] {
            let tri = CGMutablePath()
            let ex = center.x + side * radius * 0.42
            tri.move(to: CGPoint(x: ex, y: eyY - eyeSz * 0.6))
            tri.addLine(to: CGPoint(x: ex - eyeSz * 0.5, y: eyY + eyeSz * 0.5))
            tri.addLine(to: CGPoint(x: ex + eyeSz * 0.5, y: eyY + eyeSz * 0.5)); tri.closeSubpath()
            ctx.addPath(tri); ctx.fillPath()
        }
        // Nose triangle
        let nose = CGMutablePath()
        nose.move(to: CGPoint(x: center.x, y: center.y - radius * 0.04))
        nose.addLine(to: CGPoint(x: center.x - radius * 0.12, y: center.y + radius * 0.10))
        nose.addLine(to: CGPoint(x: center.x + radius * 0.12, y: center.y + radius * 0.10)); nose.closeSubpath()
        ctx.addPath(nose); ctx.fillPath()
        // Curved jack-o'-lantern grin with carved teeth cutouts
        let smile = CGMutablePath()
        let mw = radius * 0.60, my = center.y + radius * 0.18, mh = radius * (style % 2 == 0 ? 0.24 : 0.30)
        smile.move(to: CGPoint(x: center.x - mw, y: my))
        smile.addQuadCurve(to: CGPoint(x: center.x + mw, y: my), control: CGPoint(x: center.x, y: my + mh * 0.45))
        smile.addQuadCurve(to: CGPoint(x: center.x - mw, y: my), control: CGPoint(x: center.x, y: my + mh * 1.35))
        ctx.addPath(smile); ctx.fillPath()
        ctx.setFillColor(NSColor(srgbRed: 0.92, green: 0.42, blue: 0.06, alpha: 1).cgColor)
        ctx.fill(CGRect(x: center.x - mw * 0.45, y: my + mh * 0.12, width: radius * 0.14, height: mh * 0.40))
        ctx.fill(CGRect(x: center.x + mw * 0.28, y: my + mh * 0.45, width: radius * 0.14, height: mh * 0.42))
    }
}
