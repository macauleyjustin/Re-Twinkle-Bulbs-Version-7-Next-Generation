import Foundation
import CoreGraphics
import AppKit

// MARK: - Shared Per-Bulb State for Modern Programmable Effects

public struct ModernBulbState: Equatable {
    public let index: Int
    public let frame: CGRect
    public let edge: BulbEdge
    public let isBareWire: Bool
    public let isMissing: Bool
    public let isBroken: Bool
    public let isBurnedOut: Bool
    public var r: Double
    public var g: Double
    public var b: Double
    public var intensity: Double // 0.0 (unlit base) ... 1.0 (full glow)

    public init(
        index: Int,
        frame: CGRect,
        edge: BulbEdge,
        isBareWire: Bool,
        isMissing: Bool,
        isBroken: Bool,
        isBurnedOut: Bool,
        r: Double,
        g: Double,
        b: Double,
        intensity: Double
    ) {
        self.index = index
        self.frame = frame
        self.edge = edge
        self.isBareWire = isBareWire
        self.isMissing = isMissing
        self.isBroken = isBroken
        self.isBurnedOut = isBurnedOut
        self.r = r
        self.g = g
        self.b = b
        self.intensity = intensity
    }
}

// MARK: - Independent Advanced Lighting Engine (Never alters Classic BulbEngine)

public final class ModernLightingEngine {
    public private(set) var states: [ModernBulbState] = []
    public private(set) var config: ModernEffectsConfig = ModernEffectsConfig()
    public private(set) var activeCycleEffect: ModernEffectID = .twinklefox

    private struct BulbRuntime {
        var phaseA: Double
        var phaseB: Double
        var speedVar: Double
        var colorCur: (Double, Double, Double)
        var colorTarget: (Double, Double, Double)
        var holdTimer: Double
        var valueCur: Double
        var valueTarget: Double
    }

    private struct ActiveBurst {
        var center: Double
        var age: Double
        var radius: Double
        var color: (Double, Double, Double)
    }

    private var runtimes: [BulbRuntime] = []
    private var bursts: [ActiveBurst] = []
    private var rng: RandomSource
    private var elapsed: Double = 0
    private var cycleElapsed: Double = 0
    private var cycleListIndex: Int = 0
    private var lastFrameMs: UInt64 = 0

    // Optional MIDI-reactive modulation buffers (Phase 6)
    private var midiBeatPulse: Double = 0
    private var midiNoteImpulse: [Double] = []
    private var midiChannelTint: [(Double, Double, Double)?] = []
    private var midiLastBPM: Double = 120.0
    private var midiPhaseAdvance: Double = 0

    public init(seed: UInt64 = 20251225) {
        self.rng = SeededRandomSource(seed: seed)
    }

    public func configure(bounds: CGRect, settings: AppSettings, monitorOffset: Int = 0, nowMs: UInt64 = 0) {
        self.config = settings.modernEffects
        let chosenSeed: UInt64
        if config.randomizeSeeds {
            chosenSeed = UInt64.random(in: 1...UInt64.max)
        } else {
            chosenSeed = config.seed &+ UInt64(monitorOffset * 7919)
        }
        self.rng = SeededRandomSource(seed: chosenSeed)

        // Reuse exact v6.0 edge placement geometry without changing classic BulbEngine behavior
        let geometryEngine = BulbEngine(settings: settings, rng: SeededRandomSource(seed: chosenSeed))
        geometryEngine.configure(bounds: bounds, settings: settings, nowMs: nowMs)

        let paletteColors = config.palette.colors
        self.states = geometryEngine.slots.enumerated().map { idx, slot in
            let pal = paletteColors[idx % max(1, paletteColors.count)]
            return ModernBulbState(
                index: slot.index,
                frame: slot.frame,
                edge: slot.edge,
                isBareWire: slot.isBareWire,
                isMissing: slot.isMissing,
                isBroken: slot.isBroken,
                isBurnedOut: slot.isBurnedOut,
                r: pal.r, g: pal.g, b: pal.b,
                intensity: 0.3
            )
        }

        self.runtimes = states.enumerated().map { idx, st in
            let p1 = nextUnitRandom() * .pi * 2.0
            let p2 = 0.6 + nextUnitRandom() * 0.9
            let target = paletteColors[(idx + 1) % max(1, paletteColors.count)]
            return BulbRuntime(
                phaseA: p1,
                phaseB: nextUnitRandom() * 4.0,
                speedVar: p2,
                colorCur: (st.r, st.g, st.b),
                colorTarget: target,
                holdTimer: nextUnitRandom() * 2.0,
                valueCur: 0.4 + 0.5 * nextUnitRandom(),
                valueTarget: 0.5 + 0.5 * nextUnitRandom()
            )
        }

        self.midiNoteImpulse = Array(repeating: 0.0, count: states.count)
        self.midiChannelTint = Array(repeating: nil, count: states.count)
        self.bursts.removeAll()
        self.elapsed = config.perMonitorPhaseOffset ? Double(monitorOffset) * 1.37 : 0.0
        self.cycleElapsed = 0
        self.cycleListIndex = 0
        self.lastFrameMs = nowMs
        self.activeCycleEffect = resolveInitialCycleEffect()

        evaluateFrame(dt: 0)
    }

    public func updateConfigOnly(_ newConfig: ModernEffectsConfig) {
        self.config = newConfig
        if newConfig.effect != .autoCycle {
            activeCycleEffect = newConfig.effect
        } else {
            activeCycleEffect = resolveInitialCycleEffect()
        }
    }

    public func tick(nowMs: UInt64) {
        if lastFrameMs == 0 || nowMs < lastFrameMs {
            lastFrameMs = nowMs
            evaluateFrame(dt: 1.0 / 30.0)
            return
        }
        let dtMs = nowMs - lastFrameMs
        lastFrameMs = nowMs
        let dt = min(0.12, max(0.001, Double(dtMs) / 1000.0))
        evaluateFrame(dt: dt)
    }

    public func stepDeterministic(dt: Double) {
        evaluateFrame(dt: max(0.001, dt))
    }

    /// Receives live MIDI Note/Beat events for Phase 6 MIDI-Reactive Lighting.
    public func handleMIDIEvent(_ evt: MIDILightEvent) {
        guard config.midiReactiveEnabled, !states.isEmpty else { return }
        midiLastBPM = max(40.0, min(240.0, evt.currentBPM))
        guard evt.isNoteOn, evt.velocity > 0 else { return }

        let velNorm = min(1.0, (Double(evt.velocity) / 127.0) * config.midiSensitivity)
        let pal = config.palette.colors
        let chColor = pal[Int(evt.channel) % max(1, pal.count)]

        midiBeatPulse = max(midiBeatPulse, velNorm)
        if evt.channel == 9 || evt.velocity >= 90 {
            midiBeatPulse = 1.0
        }

        let targetIdx = Int(evt.note) % states.count
        let spread = min(3, max(1, states.count / 16))
        for offset in -spread...spread {
            let idx = (targetIdx + offset + states.count) % states.count
            let falloff = 1.0 - (Double(abs(offset)) / Double(spread + 1)) * 0.65
            midiNoteImpulse[idx] = min(1.0, max(midiNoteImpulse[idx], velNorm * falloff))
            midiChannelTint[idx] = chColor
        }
    }

    // MARK: - Core Effect Evaluators

    private func evaluateFrame(dt: Double) {
        guard !states.isEmpty else { return }
        let speed = max(0.1, config.speed)
        elapsed += dt * speed

        var currentEffect = config.effect
        var crossfadeBlend = 1.0
        var prevCycleEffect: ModernEffectID = activeCycleEffect

        if config.effect == .autoCycle {
            let interval = max(2.0, config.cycleIntervalSeconds)
            cycleElapsed += dt
            if cycleElapsed >= interval {
                cycleElapsed = 0
                prevCycleEffect = activeCycleEffect
                let favs = validFavorites()
                if config.cycleRandomOrder {
                    let pool = favs.filter { $0 != activeCycleEffect }
                    activeCycleEffect = (pool.isEmpty ? favs : pool).randomElement() ?? .twinklefox
                } else {
                    cycleListIndex = (cycleListIndex + 1) % max(1, favs.count)
                    activeCycleEffect = favs[cycleListIndex]
                }
            }
            currentEffect = activeCycleEffect
            if config.cycleCrossfade && cycleElapsed < 1.0 && prevCycleEffect != currentEffect {
                crossfadeBlend = cycleElapsed
            }
        } else {
            activeCycleEffect = currentEffect
        }

        // Advance bursts/MIDI decay once per frame
        advanceAuxiliaryState(dt: dt * speed, effect: currentEffect)

        if crossfadeBlend < 0.999 {
            let snapshotA = evaluateEffect(prevCycleEffect, dt: dt * speed)
            let snapshotB = evaluateEffect(currentEffect, dt: dt * speed)
            for i in states.indices {
                var st = states[i]
                if !isControllableBulb(st) {
                    st.intensity = 0
                    states[i] = st
                    continue
                }
                let a = snapshotA[i], b = snapshotB[i]
                st.r = lerp(a.r, b.r, crossfadeBlend)
                st.g = lerp(a.g, b.g, crossfadeBlend)
                st.b = lerp(a.b, b.b, crossfadeBlend)
                st.intensity = lerp(a.intensity, b.intensity, crossfadeBlend)
                states[i] = applyMIDIModulation(state: st, index: i, dt: dt)
            }
        } else {
            let rendered = evaluateEffect(currentEffect, dt: dt * speed)
            for i in states.indices {
                var st = states[i]
                if !isControllableBulb(st) {
                    st.intensity = 0
                    states[i] = st
                    continue
                }
                st.r = rendered[i].r
                st.g = rendered[i].g
                st.b = rendered[i].b
                st.intensity = rendered[i].intensity
                states[i] = applyMIDIModulation(state: st, index: i, dt: dt)
            }
        }

        // Decay MIDI modulation
        let decay = exp(-dt * 5.2)
        midiBeatPulse *= decay
        for i in midiNoteImpulse.indices {
            midiNoteImpulse[i] *= decay
        }
        if config.midiReactiveEnabled && config.midiReactiveMode == .tempoSyncChase {
            midiPhaseAdvance += dt * (midiLastBPM / 60.0) * 1.5
        }
    }

    private func advanceAuxiliaryState(dt: Double, effect: ModernEffectID) {
        if effect == .fireworks || effect == .ripple {
            for idx in bursts.indices.reversed() {
                bursts[idx].age += dt * (effect == .ripple ? 1.8 : 1.4)
                if bursts[idx].age > 2.2 {
                    bursts.remove(at: idx)
                }
            }
            let maxBursts = effect == .fireworks ? 3 : 2
            let spawnProb = dt * (0.6 + config.intensityOrDensity * 1.6)
            if (bursts.isEmpty || (bursts.count < maxBursts && nextUnitRandom() < spawnProb)) && !states.isEmpty {
                let pal = config.palette.colors
                let c = pal[rng.nextInt(upperBound: max(1, pal.count))]
                let center = Double(rng.nextInt(upperBound: max(1, states.count)))
                let rad = max(3.0, config.wavelengthOrWidth)
                bursts.append(ActiveBurst(center: center, age: 0, radius: rad, color: (c.r, c.g, c.b)))
            }
        } else if !bursts.isEmpty {
            bursts.removeAll()
        }
    }

    private func evaluateEffect(_ effect: ModernEffectID, dt: Double) -> [(r: Double, g: Double, b: Double, intensity: Double)] {
        let count = states.count
        let pal = config.palette.colors
        let globalBright = max(0.05, min(1.0, config.brightness))
        let width = max(2.0, config.wavelengthOrWidth)
        let dirSign = config.reverseDirection ? -1.0 : 1.0
        var out = [(r: Double, g: Double, b: Double, intensity: Double)](repeating: (1, 1, 1, 0), count: count)

        for i in 0..<count {
            var rt = runtimes[i]
            let palColor = pal[i % max(1, pal.count)]
            var rgb: (Double, Double, Double) = (palColor.r, palColor.g, palColor.b)
            var intensity = 1.0
            let pos = Double(i)

            switch effect {
            case .gentleTwinkle:
                let wave = 0.5 + 0.5 * sin(elapsed * 1.8 * rt.speedVar + rt.phaseA)
                let shaped = pow(wave, 1.0 + config.smoothness * 1.4)
                intensity = 0.14 + 0.86 * shaped

            case .twinklefox:
                // Organic smooth illuminate -> brief hold -> smooth decay curve
                let cycleLen = max(1.6, 4.2 - config.intensityOrDensity * 1.8)
                let tNorm = ((elapsed * 0.75 * rt.speedVar + rt.phaseB).truncatingRemainder(dividingBy: cycleLen)) / cycleLen
                if tNorm < 0.25 {
                    let u = tNorm / 0.25
                    intensity = 0.08 + 0.92 * (0.5 - 0.5 * cos(u * .pi))
                } else if tNorm < 0.45 {
                    intensity = 1.0
                } else {
                    let u = (tNorm - 0.45) / 0.55
                    intensity = 0.08 + 0.92 * (0.5 + 0.5 * cos(u * .pi))
                }

            case .slowGlow:
                let phase = config.staggered ? (elapsed * 1.6 + pos * (0.35 / max(1.0, width / 6.0))) : (elapsed * 1.5)
                let wave = 0.5 + 0.5 * sin(phase)
                intensity = 0.10 + 0.90 * pow(wave, 1.2)

            case .colorWave:
                let u = (pos / width - elapsed * 0.55 * dirSign + 1000.0).truncatingRemainder(dividingBy: 1.0)
                let scaled = u * Double(pal.count)
                let idxA = Int(floor(scaled)) % pal.count
                let idxB = (idxA + 1) % pal.count
                let frac = scaled - floor(scaled)
                let smoothFrac = lerp(frac, 0.5 - 0.5 * cos(frac * .pi), config.smoothness)
                let cA = pal[idxA], cB = pal[idxB]
                rgb = (lerp(cA.r, cB.r, smoothFrac), lerp(cA.g, cB.g, smoothFrac), lerp(cA.b, cB.b, smoothFrac))
                intensity = 0.75 + 0.25 * sin(u * .pi * 2.0)

            case .rainbowChase:
                let hue = ((pos / (width * 1.8)) - elapsed * 0.28 * dirSign + 1000.0).truncatingRemainder(dividingBy: 1.0)
                rgb = hsvToRGB(h: hue, s: 0.95, v: 1.0)
                intensity = 0.95

            case .meteor:
                let totalSpan = Double(count) + width * 1.5
                let headPosRaw = (elapsed * 16.0).truncatingRemainder(dividingBy: totalSpan)
                let head = config.reverseDirection ? (Double(count - 1) - headPosRaw) : headPosRaw
                let dist = config.reverseDirection ? (pos - head) : (head - pos)
                if dist >= 0 && dist <= width {
                    let falloff = exp(-dist * (3.2 / max(2.0, width)))
                    let shimmer = 0.85 + 0.15 * sin(rt.phaseA + elapsed * 14.0)
                    intensity = falloff * shimmer
                    let meteorBase = config.palette == .classicHoliday ? (0.85, 0.92, 1.0) : pal[0]
                    rgb = (lerp(meteorBase.0, 1.0, falloff * 0.6), lerp(meteorBase.1, 1.0, falloff * 0.6), lerp(meteorBase.2, 1.0, falloff * 0.6))
                } else {
                    intensity = 0.04
                }

            case .candleFlicker:
                rt.holdTimer -= dt
                if rt.holdTimer <= 0 {
                    rt.holdTimer = 0.07 + nextUnitRandom() * 0.16
                    rt.valueTarget = 0.42 + 0.58 * nextUnitRandom()
                }
                let blend = min(1.0, dt * (7.5 - config.smoothness * 3.0))
                rt.valueCur = lerp(rt.valueCur, rt.valueTarget, blend)
                let warmth = 0.78 + 0.22 * rt.valueCur
                rgb = (min(1.0, 1.0 * warmth), 0.56 * rt.valueCur + 0.18, 0.08 * rt.valueCur)
                intensity = rt.valueCur

            case .fireworks:
                var bestI = 0.06
                var bestColor = rgb
                for burst in bursts {
                    let radiusNow = burst.age * burst.radius
                    let d = abs(pos - burst.center)
                    if d <= radiusNow + 1.5 {
                        let ring = max(0.0, 1.0 - abs(d - radiusNow * 0.65) / max(1.5, burst.radius * 0.45))
                        let fade = max(0.0, 1.0 - burst.age / 2.2)
                        let spark = 0.65 + 0.35 * sin(rt.phaseA + elapsed * 20.0)
                        let val = ring * fade * spark
                        if val > bestI {
                            bestI = val
                            bestColor = burst.color
                        }
                    }
                }
                rgb = bestColor
                intensity = bestI

            case .glitter:
                let baseBright = max(0.20, min(0.75, config.intensityOrDensity))
                rt.holdTimer -= dt
                if rt.holdTimer <= 0 {
                    rt.holdTimer = 0.06 + nextUnitRandom() * 0.22
                    rt.valueTarget = nextUnitRandom() < (0.06 + config.intensityOrDensity * 0.12) ? 1.0 : baseBright
                }
                rt.valueCur = lerp(rt.valueCur, rt.valueTarget, min(1.0, dt * 16.0))
                let sparkleMix = max(0.0, (rt.valueCur - baseBright) / max(0.01, 1.0 - baseBright))
                rgb = (lerp(palColor.r, 1.0, sparkleMix), lerp(palColor.g, 1.0, sparkleMix), lerp(palColor.b, 1.0, sparkleMix))
                intensity = rt.valueCur

            case .ripple:
                var accum = 0.05
                var accumColor = rgb
                for burst in bursts {
                    let front = burst.age * (burst.radius * 1.35)
                    let d = abs(pos - burst.center)
                    let diff = abs(d - front)
                    if diff < 2.8 {
                        let envelope = (1.0 - diff / 2.8) * exp(-burst.age * 0.85) * exp(-d * 0.08)
                        if envelope > accum {
                            accum = envelope
                            accumColor = burst.color
                        }
                    }
                }
                rgb = accumColor
                intensity = accum

            case .candyCane:
                let stripeW = max(2.0, round(width * 0.5))
                let shifted = pos - elapsed * 6.0 * dirSign + 10000.0
                let bandPos = (shifted / stripeW).truncatingRemainder(dividingBy: 2.0)
                let isRed = bandPos < 1.0
                rgb = isRed ? (0.95, 0.08, 0.12) : (0.98, 0.97, 0.99)
                intensity = 0.95

            case .heartbeat:
                let speedVal = max(0.1, config.speed)
                let period = max(0.65, 1.35 / speedVal)
                let phase = ((elapsed / speedVal).truncatingRemainder(dividingBy: period)) / period
                let beat1 = exp(-pow((phase - 0.16) / 0.055, 2.0))
                let beat2 = 0.78 * exp(-pow((phase - 0.34) / 0.065, 2.0))
                let pulse = min(1.0, beat1 + beat2)
                rgb = config.palette == .classicHoliday ? (0.95, 0.10, 0.18) : pal[0]
                intensity = 0.10 + 0.90 * pulse

            case .scanner:
                let span = max(1.0, Double(count - 1))
                let triangle = abs(((elapsed * 8.0) / span + 1000.0).truncatingRemainder(dividingBy: 2.0) - 1.0)
                let center = triangle * span
                let clusterHalf = max(1.0, width * 0.35)
                let dist = abs(pos - center)
                if dist <= clusterHalf {
                    intensity = 1.0
                } else {
                    intensity = max(0.05, exp(-(dist - clusterHalf) * 0.7))
                }
                rgb = pal[0]

            case .softRandomFade:
                let stepSpeed = max(0.25, 0.8 - config.smoothness * 0.45)
                let blend = min(1.0, dt * stepSpeed)
                rt.colorCur = (
                    lerp(rt.colorCur.0, rt.colorTarget.0, blend),
                    lerp(rt.colorCur.1, rt.colorTarget.1, blend),
                    lerp(rt.colorCur.2, rt.colorTarget.2, blend)
                )
                let dist = abs(rt.colorCur.0 - rt.colorTarget.0) + abs(rt.colorCur.1 - rt.colorTarget.1) + abs(rt.colorCur.2 - rt.colorTarget.2)
                if dist < 0.04 {
                    let nextC = pal[rng.nextInt(upperBound: max(1, pal.count))]
                    rt.colorTarget = (nextC.r, nextC.g, nextC.b)
                }
                rgb = rt.colorCur
                intensity = 0.92

            case .autoCycle:
                break
            }

            runtimes[i] = rt
            out[i] = (rgb.0, rgb.1, rgb.2, max(0.0, min(1.0, intensity * globalBright)))
        }

        return out
    }

    private func applyMIDIModulation(state: ModernBulbState, index: Int, dt: Double) -> ModernBulbState {
        guard config.midiReactiveEnabled else { return state }
        var st = state
        switch config.midiReactiveMode {
        case .beatPulse:
            st.intensity = min(1.0, st.intensity * (0.45 + 0.55 * midiBeatPulse) + midiBeatPulse * 0.35)
        case .notePerBulb:
            let imp = midiNoteImpulse[index]
            st.intensity = min(1.0, max(st.intensity * 0.35, imp))
            if imp > 0.15, let tint = midiChannelTint[index] {
                st.r = lerp(st.r, tint.0, min(1.0, imp))
                st.g = lerp(st.g, tint.1, min(1.0, imp))
                st.b = lerp(st.b, tint.2, min(1.0, imp))
            }
        case .channelColors:
            if let tint = midiChannelTint[index], midiNoteImpulse[index] > 0.05 {
                let mixAmt = min(1.0, midiNoteImpulse[index])
                st.r = lerp(st.r, tint.0, mixAmt)
                st.g = lerp(st.g, tint.1, mixAmt)
                st.b = lerp(st.b, tint.2, mixAmt)
            }
        case .velocityBrightness:
            let boost = max(midiBeatPulse * 0.5, midiNoteImpulse[index])
            st.intensity = min(1.0, st.intensity * 0.4 + boost * 0.85)
        case .tempoSyncChase:
            let window = ((Double(index) * 0.25) - midiPhaseAdvance + 1000.0).truncatingRemainder(dividingBy: 1.0)
            let beatGlow = max(0.15, 1.0 - window * 1.4)
            st.intensity = min(1.0, max(st.intensity * 0.4, beatGlow * (0.6 + 0.4 * midiBeatPulse)))
        case .instrumentMapping:
            // Maps instrument family/channel into warm/cool/gemstone spectral hues with note envelope
            let chIdx = (index / max(1, states.count / 4)) % 16
            let hue = Double((chIdx * 47) % 360) / 360.0
            let rgb = hsvToRGB(h: hue, s: 0.85, v: 1.0)
            let imp = max(midiNoteImpulse[index], midiBeatPulse * 0.45)
            st.r = lerp(st.r, rgb.0, min(1.0, imp))
            st.g = lerp(st.g, rgb.1, min(1.0, imp))
            st.b = lerp(st.b, rgb.2, min(1.0, imp))
            st.intensity = min(1.0, max(st.intensity * 0.3, imp))
        case .percussionEffects:
            // High-contrast crisp white/gold percussion flash & alternate color flip
            let imp = midiNoteImpulse[index]
            if midiBeatPulse > 0.65 {
                let flash = min(1.0, midiBeatPulse)
                st.r = lerp(st.r, 1.0, flash * 0.75)
                st.g = lerp(st.g, 0.94, flash * 0.75)
                st.b = lerp(st.b, 0.78, flash * 0.75)
                st.intensity = min(1.0, max(st.intensity, flash))
            } else {
                st.intensity = min(1.0, max(st.intensity * 0.35, imp))
            }
        }
        return st
    }

    private func isControllableBulb(_ st: ModernBulbState) -> Bool {
        !st.isBareWire && !st.isMissing && !st.isBroken && !st.isBurnedOut
    }

    private func validFavorites() -> [ModernEffectID] {
        let favs = config.cycleFavorites.filter { $0 != .autoCycle }
        return favs.isEmpty ? ModernEffectID.allCases.filter { $0 != .autoCycle } : favs
    }

    private func resolveInitialCycleEffect() -> ModernEffectID {
        validFavorites().first ?? .twinklefox
    }

    private func nextUnitRandom() -> Double {
        Double(rng.nextInt(upperBound: 100_000)) / 100_000.0
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * max(0.0, min(1.0, t))
    }

    private func hsvToRGB(h: Double, s: Double, v: Double) -> (Double, Double, Double) {
        let hue = (h < 0 ? h + 1.0 : h).truncatingRemainder(dividingBy: 1.0)
        let i = Int(floor(hue * 6.0))
        let f = hue * 6.0 - Double(i)
        let p = v * (1.0 - s)
        let q = v * (1.0 - f * s)
        let t = v * (1.0 - (1.0 - f) * s)
        switch i % 6 {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }
}
