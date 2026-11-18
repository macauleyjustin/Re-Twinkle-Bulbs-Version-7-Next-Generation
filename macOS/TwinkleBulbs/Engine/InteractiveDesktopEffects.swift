import Cocoa
import CoreGraphics

// MARK: - Part V: Interactive Desktop Decorations & Holiday Celebrations (Disabled by Default)

public enum CelebrationEffectPreset: String, CaseIterable, Codable, Identifiable {
    case christmas = "Christmas Sparkle"
    case newYear = "New Year Fireworks"
    case halloween = "Halloween Spooky Flash"
    case birthday = "Birthday Confetti"

    public var id: String { rawValue }
}

public struct DesktopSparkleParticle {
    public var position: CGPoint
    public var velocity: CGVector
    public var life: Double
    public var maxLife: Double
    public var r: Double
    public var g: Double
    public var b: Double
    public var size: Double
}

private struct StrandRippleWave {
    var centerIndex: Double
    var radius: Double
    var amplitude: Double
    var speed: Double
}

public final class InteractiveDesktopEffectsEngine {
    public static let shared = InteractiveDesktopEffectsEngine()

    public private(set) var sparkleParticles: [DesktopSparkleParticle] = []
    private var ripples: [StrandRippleWave] = []
    private var lastPointerScreenPoint: CGPoint?
    private var celebrationBoost: Double = 0.0
    private var celebrationColor: (Double, Double, Double) = (1.0, 0.85, 0.25)

    public init() {}

    /// Pure coordinate transform from global screen space into overlay window top-down local coords.
    public static func pointerInOverlayCanvas(screenPoint: CGPoint, screenFrame: CGRect, canvasBounds: CGRect) -> CGPoint {
        let localX = screenPoint.x - screenFrame.minX
        // Flip Y from Cocoa bottom-left to flipped view top-left
        let localY = (screenFrame.maxY - screenPoint.y)
        return CGPoint(
            x: max(-200, min(canvasBounds.width + 200, localX)),
            y: max(-200, min(canvasBounds.height + 200, localY))
        )
    }

    public func triggerCelebration(_ preset: CelebrationEffectPreset, inCanvasBounds bounds: CGRect) {
        let count = preset == .newYear ? 72 : 48
        let colors: [(Double, Double, Double)]
        switch preset {
        case .christmas:
            colors = [(0.95, 0.16, 0.18), (0.16, 0.88, 0.24), (1.0, 0.86, 0.22), (1.0, 1.0, 1.0)]
            celebrationColor = (1.0, 0.85, 0.22)
        case .newYear:
            colors = [(1.0, 0.88, 0.24), (0.98, 0.98, 1.0), (0.28, 0.72, 1.0), (0.96, 0.35, 0.78)]
            celebrationColor = (1.0, 0.90, 0.35)
        case .halloween:
            colors = [(1.0, 0.45, 0.08), (0.68, 0.18, 0.94), (0.20, 0.92, 0.34)]
            celebrationColor = (1.0, 0.45, 0.08)
        case .birthday:
            colors = [(1.0, 0.25, 0.45), (0.25, 0.78, 1.0), (1.0, 0.84, 0.18), (0.45, 0.92, 0.32)]
            celebrationColor = (0.25, 0.82, 1.0)
        }
        celebrationBoost = 1.0
        let cx = bounds.midX
        let cy = min(bounds.height * 0.25, 160)
        for i in 0..<count {
            let ang = (Double(i) / Double(count)) * .pi * 2.0 + Double.random(in: -0.15...0.15)
            let spd = Double.random(in: 55...210)
            let c = colors[i % colors.count]
            sparkleParticles.append(DesktopSparkleParticle(
                position: CGPoint(x: cx + CGFloat.random(in: -bounds.width * 0.35...bounds.width * 0.35), y: cy),
                velocity: CGVector(dx: cos(ang) * spd, dy: sin(ang) * spd + 25),
                life: 0,
                maxLife: Double.random(in: 0.9...1.8),
                r: c.0, g: c.1, b: c.2,
                size: Double.random(in: 3.0...6.5)
            ))
        }
        if sparkleParticles.count > 160 {
            sparkleParticles.removeFirst(sparkleParticles.count - 160)
        }
    }

    public func step(
        dt: Double,
        config: InteractiveDesktopConfig,
        pointerScreenPoint: CGPoint? = nil,
        screenFrame: CGRect,
        canvasBounds: CGRect,
        bulbStates: inout [ModernBulbState]
    ) {
        let screenPtr = pointerScreenPoint ?? NSEvent.mouseLocation
        let localPtr = Self.pointerInOverlayCanvas(screenPoint: screenPtr, screenFrame: screenFrame, canvasBounds: canvasBounds)

        var pointerDelta = CGVector.zero
        if let prev = lastPointerScreenPoint {
            pointerDelta = CGVector(dx: screenPtr.x - prev.x, dy: screenPtr.y - prev.y)
        }
        lastPointerScreenPoint = screenPtr
        let pointerSpeed = hypot(pointerDelta.dx, pointerDelta.dy)

        if config.enabled {
            // Spawn subtle cursor sparkle trail only when moving swiftly & enabled
            if config.sparkleTrail && pointerSpeed > 14.0 && canvasBounds.contains(localPtr) {
                sparkleParticles.append(DesktopSparkleParticle(
                    position: localPtr,
                    velocity: CGVector(dx: Double.random(in: -18...18), dy: Double.random(in: 8...34)),
                    life: 0,
                    maxLife: 0.55,
                    r: 1.0, g: 0.92, b: 0.65,
                    size: 3.5
                ))
                if sparkleParticles.count > 120 {
                    sparkleParticles.removeFirst(sparkleParticles.count - 120)
                }
            }

            // Spawn strand ripple when cursor sweeps close to a bulb strand
            if config.mouseRipple && pointerSpeed > 22.0, let nearestIdx = nearestBulbIndex(to: localPtr, in: bulbStates, maxDist: config.proximityRadiusPx * 1.2) {
                ripples.append(StrandRippleWave(centerIndex: Double(nearestIdx), radius: 0, amplitude: 0.85, speed: 24.0))
                if ripples.count > 6 { ripples.removeFirst() }
            }

            // Apply proximity glow + ripple wave across bulbs
            let radius = max(24.0, config.proximityRadiusPx)
            for i in bulbStates.indices {
                var st = bulbStates[i]
                if st.isBareWire || st.isMissing || st.isBroken || st.isBurnedOut { continue }

                if config.mouseProximityGlow {
                    let center = CGPoint(x: st.frame.midX, y: st.frame.midY)
                    let d = hypot(center.x - localPtr.x, center.y - localPtr.y)
                    if d < radius {
                        let proximity = 1.0 - (Double(d) / radius)
                        st.intensity = min(1.0, max(st.intensity, 0.35 + proximity * 0.65))
                        st.r = min(1.0, st.r + proximity * 0.25)
                        st.g = min(1.0, st.g + proximity * 0.25)
                        st.b = min(1.0, st.b + proximity * 0.30)
                    }
                }

                for rp in ripples {
                    let waveDist = abs(Double(i) - rp.centerIndex - rp.radius)
                    let revDist = abs(Double(i) - rp.centerIndex + rp.radius)
                    let hit = min(waveDist, revDist)
                    if hit < 2.2 {
                        let env = (1.0 - hit / 2.2) * rp.amplitude
                        st.intensity = min(1.0, st.intensity + env * 0.7)
                    }
                }
                bulbStates[i] = st
            }
        }

        // Apply active holiday celebration pulse even when interactive idle hover is off
        if celebrationBoost > 0.01 {
            for i in bulbStates.indices {
                var st = bulbStates[i]
                if st.isBareWire || st.isMissing || st.isBroken || st.isBurnedOut { continue }
                st.r = min(1.0, st.r * (1.0 - celebrationBoost * 0.4) + celebrationColor.0 * celebrationBoost * 0.6)
                st.g = min(1.0, st.g * (1.0 - celebrationBoost * 0.4) + celebrationColor.1 * celebrationBoost * 0.6)
                st.b = min(1.0, st.b * (1.0 - celebrationBoost * 0.4) + celebrationColor.2 * celebrationBoost * 0.6)
                st.intensity = min(1.0, max(st.intensity, celebrationBoost * 0.85))
                bulbStates[i] = st
            }
            celebrationBoost *= exp(-dt * 1.4)
        }

        // Advance ripples & particles
        for idx in ripples.indices.reversed() {
            ripples[idx].radius += dt * ripples[idx].speed
            ripples[idx].amplitude *= exp(-dt * 2.1)
            if ripples[idx].amplitude < 0.03 { ripples.remove(at: idx) }
        }
        for idx in sparkleParticles.indices.reversed() {
            var p = sparkleParticles[idx]
            p.life += dt
            p.position.x += CGFloat(p.velocity.dx * dt)
            p.position.y += CGFloat(p.velocity.dy * dt)
            p.velocity.dy += 65.0 * dt
            if p.life >= p.maxLife {
                sparkleParticles.remove(at: idx)
            } else {
                sparkleParticles[idx] = p
            }
        }
    }

    public func drawParticles(in ctx: CGContext) {
        guard !sparkleParticles.isEmpty else { return }
        ctx.saveGState()
        for p in sparkleParticles {
            let alpha = max(0.0, 1.0 - p.life / p.maxLife)
            ctx.setFillColor(CGColor(srgbRed: p.r, green: p.g, blue: p.b, alpha: alpha))
            let r = CGRect(x: p.position.x - p.size * 0.5, y: p.position.y - p.size * 0.5, width: p.size, height: p.size)
            ctx.fillEllipse(in: r)
        }
        ctx.restoreGState()
    }

    private func nearestBulbIndex(to pt: CGPoint, in states: [ModernBulbState], maxDist: Double) -> Int? {
        var bestIdx: Int?
        var bestDist = maxDist
        for (i, st) in states.enumerated() {
            let d = hypot(Double(st.frame.midX - pt.x), Double(st.frame.midY - pt.y))
            if d < bestDist {
                bestDist = d
                bestIdx = i
            }
        }
        return bestIdx
    }
}
