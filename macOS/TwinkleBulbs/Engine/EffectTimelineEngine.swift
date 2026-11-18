import Foundation
import CoreGraphics

// MARK: - Part III: Time-Based Animation Timeline Engine (Frame-Rate Independent)

public final class EffectTimelineEngine {
    public private(set) var document: TimelineEffectDocument
    public private(set) var elapsedSeconds: Double = 0.0
    public private(set) var isPlaying: Bool = true

    private var sparkleImpulse: Double = 0.0
    private var lastTriggerTime: Double = -1.0
    private var innerEffectEngine = ModernLightingEngine(seed: 20261225)
    private var innerConfigured = false

    public init(document: TimelineEffectDocument = EffectTimelineEngine.builtInSampleTimelines()[0]) {
        self.document = document
    }

    public func setDocument(_ doc: TimelineEffectDocument) {
        self.document = doc
        self.elapsedSeconds = 0.0
        self.sparkleImpulse = 0.0
        self.lastTriggerTime = -1.0
        self.innerConfigured = false
    }

    public func seek(to timeSeconds: Double) {
        self.elapsedSeconds = normalizedTime(timeSeconds)
        self.sparkleImpulse = 0.0
    }

    public func setPlaying(_ playing: Bool) {
        self.isPlaying = playing
    }

    public func triggerMIDINoteImpulse(_ note: UInt8, velocity: UInt8) {
        let matching = document.tracks.contains { tr in
            !tr.isMuted && tr.keyframes.contains { kf in
                kf.eventKind == .triggerOnMIDI && (kf.midiNoteFilter == nil || kf.midiNoteFilter == note)
            }
        }
        if matching && velocity > 0 {
            sparkleImpulse = max(sparkleImpulse, Double(velocity) / 127.0)
        }
    }

    /// Evaluates keyframe tracks cleanly using exact time in seconds (independent of display refresh rate).
    public func evaluateStates(
        atTimeSeconds tRaw: Double? = nil,
        dt: Double = 0.016,
        bounds: CGRect,
        settings: AppSettings
    ) -> [ModernBulbState] {
        if let explicitT = tRaw {
            elapsedSeconds = normalizedTime(explicitT)
        } else if isPlaying {
            elapsedSeconds = normalizedTime(elapsedSeconds + dt * max(0.1, document.baseSpeed))
        }

        if !innerConfigured {
            innerEffectEngine.configure(bounds: bounds, settings: settings, nowMs: 0)
            innerConfigured = true
        }

        let t = elapsedSeconds
        let colorRGB = sampleColorTrack(at: t)
        let brightness = sampleScalarTrack(kind: .brightness, defaultVal: 1.0, at: t)
        let speed = max(0.1, sampleScalarTrack(kind: .speed, defaultVal: document.baseSpeed, at: t))

        // Evaluate effect & chase/twinkle state events active up to time t
        var effectID = settings.modernEffects.effect
        var reversed = settings.modernEffects.reverseDirection
        var burstAge: Double? = nil
        var pausedAtKey = false

        let fxKeyframes = document.tracks
            .filter { !$0.isMuted && ($0.kind == .effects || $0.kind == .midiTriggers) }
            .flatMap(\.keyframes)
            .sorted { $0.timeSeconds < $1.timeSeconds }

        for kf in fxKeyframes where kf.timeSeconds <= t {
            switch kf.eventKind {
            case .startChase:
                effectID = .rainbowChase; reversed = false
            case .reverseChase:
                reversed = true
            case .beginTwinkle:
                effectID = .twinklefox
            case .triggerSparkleBurst:
                let age = t - kf.timeSeconds
                if age >= 0 && age <= 1.2 { burstAge = age }
            case .changeEffect:
                if let eid = kf.effectID { effectID = eid }
            case .pause:
                if t - kf.timeSeconds < (kf.value ?? 0.5) { pausedAtKey = true }
            default:
                break
            }
        }

        var tempCfg = settings.modernEffects
        tempCfg.effect = effectID
        tempCfg.reverseDirection = reversed
        tempCfg.speed = speed
        tempCfg.brightness = 1.0
        innerEffectEngine.updateConfigOnly(tempCfg)

        if !pausedAtKey {
            innerEffectEngine.stepDeterministic(dt: dt * speed)
        }

        var result = innerEffectEngine.states
        for i in result.indices {
            var st = result[i]
            if let col = colorRGB {
                st.r = st.r * 0.25 + col.r * 0.75
                st.g = st.g * 0.25 + col.g * 0.75
                st.b = st.b * 0.25 + col.b * 0.75
            }
            var finalIntensity = st.intensity * brightness
            if let ba = burstAge {
                let burstEnv = max(0.0, 1.0 - ba / 1.2)
                finalIntensity = min(1.0, finalIntensity + burstEnv * 0.75)
                st.r = min(1.0, st.r + burstEnv * 0.4)
                st.g = min(1.0, st.g + burstEnv * 0.4)
                st.b = min(1.0, st.b + burstEnv * 0.4)
            }
            if sparkleImpulse > 0.02 {
                finalIntensity = min(1.0, finalIntensity + sparkleImpulse * 0.8)
            }
            st.intensity = max(0.0, min(1.0, finalIntensity))
            result[i] = st
        }
        sparkleImpulse *= exp(-dt * 4.5)
        return result
    }

    // MARK: - Curve Interpolation Math

    public static func evaluateCurve(_ curve: TimelineCurve, t rawT: Double) -> Double {
        let t = max(0.0, min(1.0, rawT))
        switch curve {
        case .linear:
            return t
        case .easeIn:
            return t * t
        case .easeOut:
            return 1.0 - (1.0 - t) * (1.0 - t)
        case .easeInOut:
            return t < 0.5 ? (2.0 * t * t) : (1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0)
        case .step:
            return t >= 1.0 ? 1.0 : 0.0
        case .cubicBezier(let x1, let y1, let x2, let y2):
            return solveCubicBezierY(x1: x1, y1: y1, x2: x2, y2: y2, xTarget: t)
        }
    }

    private static func solveCubicBezierY(x1: Double, y1: Double, x2: Double, y2: Double, xTarget: Double) -> Double {
        func sample(_ a: Double, _ b: Double, _ u: Double) -> Double {
            let c = 3.0 * a
            let bCoef = 3.0 * (b - a) - c
            let aCoef = 1.0 - c - bCoef
            return ((aCoef * u + bCoef) * u + c) * u
        }
        var u = xTarget
        for _ in 0..<8 {
            let err = sample(x1, x2, u) - xTarget
            if abs(err) < 1e-4 { break }
            let dx = 3.0 * (1 - u) * (1 - u) * x1 + 6.0 * (1 - u) * u * (x2 - x1) + 3.0 * u * u * (1 - x2)
            if abs(dx) < 1e-5 { break }
            u = max(0.0, min(1.0, u - err / dx))
        }
        return max(0.0, min(1.0, sample(y1, y2, u)))
    }

    private func normalizedTime(_ t: Double) -> Double {
        let dur = max(0.25, document.durationSeconds)
        if document.loop {
            let m = t.truncatingRemainder(dividingBy: dur)
            return m < 0 ? m + dur : m
        }
        return max(0.0, min(dur, t))
    }

    private func sampleColorTrack(at t: Double) -> TimelineColorRGB? {
        let keys = document.tracks
            .filter { !$0.isMuted && $0.kind == .color }
            .flatMap(\.keyframes)
            .filter { $0.color != nil }
            .sorted { $0.timeSeconds < $1.timeSeconds }
        guard let first = keys.first else { return nil }
        if t <= first.timeSeconds { return first.color }
        for i in 0..<(keys.count - 1) {
            let a = keys[i], b = keys[i + 1]
            if t >= a.timeSeconds && t <= b.timeSeconds {
                guard let ca = a.color, let cb = b.color else { continue }
                let span = max(0.0001, b.timeSeconds - a.timeSeconds)
                let u = Self.evaluateCurve(b.curve, t: (t - a.timeSeconds) / span)
                return TimelineColorRGB(
                    r: ca.r + (cb.r - ca.r) * u,
                    g: ca.g + (cb.g - ca.g) * u,
                    b: ca.b + (cb.b - ca.b) * u
                )
            }
        }
        return keys.last?.color
    }

    private func sampleScalarTrack(kind: TimelineTrackKind, defaultVal: Double, at t: Double) -> Double {
        let keys = document.tracks
            .filter { !$0.isMuted && $0.kind == kind }
            .flatMap(\.keyframes)
            .filter { $0.value != nil || $0.eventKind == .fadeIn || $0.eventKind == .fadeOut }
            .sorted { $0.timeSeconds < $1.timeSeconds }
        guard let first = keys.first else { return defaultVal }
        func valFor(_ k: TimelineKeyframe) -> Double {
            if let v = k.value { return v }
            return k.eventKind == .fadeIn ? 1.0 : (k.eventKind == .fadeOut ? 0.0 : defaultVal)
        }
        if t <= first.timeSeconds { return valFor(first) }
        for i in 0..<(keys.count - 1) {
            let a = keys[i], b = keys[i + 1]
            if t >= a.timeSeconds && t <= b.timeSeconds {
                let va = valFor(a), vb = valFor(b)
                let span = max(0.0001, b.timeSeconds - a.timeSeconds)
                let u = Self.evaluateCurve(b.curve, t: (t - a.timeSeconds) / span)
                return va + (vb - va) * u
            }
        }
        return keys.last.map(valFor) ?? defaultVal
    }

    // MARK: - Portable Versioned Serialization (.twinklefx)

    public static func exportTimeline(_ doc: TimelineEffectDocument) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(doc)
    }

    public static func importTimeline(data: Data) throws -> TimelineEffectDocument {
        // Supports migrating v0 dictionaries lacking formatVersion cleanly
        var doc = try JSONDecoder().decode(TimelineEffectDocument.self, from: data)
        if doc.formatVersion < TimelineEffectDocument.currentFormatVersion {
            doc.formatVersion = TimelineEffectDocument.currentFormatVersion
        }
        return doc
    }

    public static func builtInSampleTimelines() -> [TimelineEffectDocument] {
        let colorTrack = TimelineTrack(name: "Color Palette Flow", kind: .color, keyframes: [
            TimelineKeyframe(timeSeconds: 0.0, eventKind: .setColor, curve: .linear, color: TimelineColorRGB(r: 0.96, g: 0.14, b: 0.16)),
            TimelineKeyframe(timeSeconds: 4.0, eventKind: .setColor, curve: .easeInOut, color: TimelineColorRGB(r: 0.16, g: 0.88, b: 0.24)),
            TimelineKeyframe(timeSeconds: 8.0, eventKind: .setColor, curve: .easeInOut, color: TimelineColorRGB(r: 1.00, g: 0.84, b: 0.20)),
            TimelineKeyframe(timeSeconds: 12.0, eventKind: .setColor, curve: .easeInOut, color: TimelineColorRGB(r: 0.96, g: 0.14, b: 0.16))
        ])
        let brightTrack = TimelineTrack(name: "Brightness Envelope", kind: .brightness, keyframes: [
            TimelineKeyframe(timeSeconds: 0.0, eventKind: .fadeIn, curve: .easeIn, value: 0.25),
            TimelineKeyframe(timeSeconds: 1.5, eventKind: .setBrightness, curve: .easeOut, value: 1.0),
            TimelineKeyframe(timeSeconds: 10.5, eventKind: .setBrightness, curve: .linear, value: 1.0),
            TimelineKeyframe(timeSeconds: 12.0, eventKind: .fadeOut, curve: .easeOut, value: 0.30)
        ])
        let fxTrack = TimelineTrack(name: "Effects & Bursts", kind: .effects, keyframes: [
            TimelineKeyframe(timeSeconds: 0.0, eventKind: .beginTwinkle, curve: .step),
            TimelineKeyframe(timeSeconds: 3.5, eventKind: .startChase, curve: .step),
            TimelineKeyframe(timeSeconds: 6.0, eventKind: .triggerSparkleBurst, curve: .step),
            TimelineKeyframe(timeSeconds: 8.5, eventKind: .reverseChase, curve: .step)
        ])
        return [
            TimelineEffectDocument(id: "fx:holiday_spectacular", name: "Holiday Curtain Call", bulbSetID: "Outdoor", durationSeconds: 12.0, loop: true, tracks: [colorTrack, brightTrack, fxTrack])
        ]
    }
}
