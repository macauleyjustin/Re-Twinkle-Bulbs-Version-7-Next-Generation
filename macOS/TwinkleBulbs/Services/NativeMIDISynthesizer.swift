import Foundation
import os

// MARK: - Lightweight Real-Time Unfair Lock Helper

final class AudioUnfairLock {
    private var raw = os_unfair_lock_s()

    @inline(__always)
    func lock() { os_unfair_lock_lock(&raw) }

    @inline(__always)
    func unlock() { os_unfair_lock_unlock(&raw) }
}

// MARK: - Precomputed Band-Limited Wavetables & Noise Table

enum NativeWaveTables {
    static let tableSize = 4096
    static let tableMask = 4095

    static let sine: [Float] = {
        (0..<tableSize).map { i in
            sinf(Float(i) * (2.0 * .pi / Float(tableSize)))
        }
    }()

    /// Warm Acoustic/Electric Piano harmonic table (fundamental + decreasing upper partials)
    static let piano: [Float] = makeAdditiveTable([
        (1, 1.00), (2, 0.56), (3, 0.34), (4, 0.22), (5, 0.12), (6, 0.08), (7, 0.04)
    ])

    /// Classic Pipe / Drawbar Organ harmonic table (8' + 4' + 2 2/3' + 2' + 1 3/5')
    static let organ: [Float] = makeAdditiveTable([
        (1, 1.00), (2, 0.72), (3, 0.35), (4, 0.48), (5, 0.16), (6, 0.22), (8, 0.15)
    ])

    /// Warm Band-Limited Sawtooth (1/k up to 16th harmonic for lush Strings / Ensemble / Leads)
    static let strings: [Float] = makeAdditiveTable((1...16).map { k in
        (k, 1.0 / Double(k))
    })

    /// Symphonic Brass rich harmonic spectrum
    static let brass: [Float] = makeAdditiveTable([
        (1, 0.85), (2, 1.00), (3, 0.82), (4, 0.64), (5, 0.48), (6, 0.35), (7, 0.24), (8, 0.16), (9, 0.10), (10, 0.06)
    ])

    /// Woodwind / Hollow Reed (Clarinet / Oboe / Recorder bias)
    static let reed: [Float] = makeAdditiveTable([
        (1, 1.00), (2, 0.28), (3, 0.62), (4, 0.18), (5, 0.36), (6, 0.10), (7, 0.16)
    ])

    /// Warm Flute / Pan Pipe table
    static let flute: [Float] = makeAdditiveTable([
        (1, 1.00), (2, 0.20), (3, 0.06)
    ])

    /// Guitar / Plucked Harmonic rich table
    static let pluck: [Float] = makeAdditiveTable([
        (1, 1.00), (2, 0.68), (3, 0.44), (4, 0.28), (5, 0.18), (6, 0.10), (7, 0.06), (8, 0.03)
    ])

    /// Precomputed white noise table for glitch-free audio thread percussion & breath
    static let noise: [Float] = {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        return (0..<16384).map { _ in
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let u = UInt32(truncatingIfNeeded: state >> 32)
            return (Float(u) / Float(UInt32.max)) * 2.0 - 1.0
        }
    }()

    private static func makeAdditiveTable(_ harmonics: [(Int, Double)]) -> [Float] {
        var buf = [Double](repeating: 0.0, count: tableSize)
        var maxAbs = 0.0001
        for i in 0..<tableSize {
            let phase = Double(i) * (2.0 * .pi / Double(tableSize))
            var v = 0.0
            for (h, amp) in harmonics {
                v += sin(Double(h) * phase) * amp
            }
            buf[i] = v
            maxAbs = max(maxAbs, abs(v))
        }
        return buf.map { Float($0 / maxAbs) }
    }

    @inline(__always)
    static func sampleLinear(_ table: [Float], phase01: Double) -> Float {
        let wrapped = phase01 - floor(phase01)
        let scaled = wrapped * Double(tableSize)
        let i0 = Int(scaled) & tableMask
        let frac = Float(scaled - Double(Int(scaled)))
        let i1 = (i0 + 1) & tableMask
        let a = table[i0]
        let b = table[i1]
        return a + (b - a) * frac
    }
}

// MARK: - Clean-Room SoundFont 2 (.sf2) Wavetable Parser & Bank

public final class SF2WavetableBank {
    public struct SampleZone {
        public let sampleStart: Int
        public let sampleEnd: Int
        public let loopStart: Int
        public let loopEnd: Int
        public let sampleRate: Double
        public let rootKey: Int
        public let pitchCorrectionCents: Int
        public let hasLoop: Bool
        public let keyRangeLow: Int
        public let keyRangeHigh: Int
        public let pan: Float // -0.5..0.5
        public let releaseSec: Double
    }

    public let sourceURL: URL
    public let bankName: String
    /// PCM 16-bit samples normalized to -1..1
    public let pcmSamples: [Float]
    /// Program (0..127 -> preset zones; key -1 => global fallback zones)
    private let programZones: [Int: [SampleZone]]
    private let drumZones: [SampleZone]

    public init(url: URL) throws {
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw MIDIPlayerError.soundBankNotFound(url.path)
        }
        let data = try Data(contentsOf: url)
        guard data.count >= 12,
              String(bytes: data[0..<4], encoding: .ascii) == "RIFF",
              String(bytes: data[8..<12], encoding: .ascii) == "sfbk" else {
            throw MIDIPlayerError.soundBankLoadFailed(-10851, "Not a valid RIFF SoundFont 2 (.sf2) bank: \(url.lastPathComponent)")
        }

        self.sourceURL = url
        var parsedName = url.deletingPathExtension().lastPathComponent
        var smplOffset = 0
        var smplLength = 0

        struct RawPresetHeader { let name: String; let preset: Int; let bank: Int; let bagIdx: Int }
        struct RawBag { let genIdx: Int; let modIdx: Int }
        struct RawGen { let op: UInt16; let val: UInt16 }
        struct RawInst { let name: String; let bagIdx: Int }
        struct RawSampleHdr {
            let name: String
            let start: Int
            let end: Int
            let loopStart: Int
            let loopEnd: Int
            let sampleRate: Double
            let origPitch: Int
            let pitchCorr: Int
            let sampleType: UInt16
        }

        var phdrs: [RawPresetHeader] = []
        var pbags: [RawBag] = []
        var pgens: [RawGen] = []
        var insts: [RawInst] = []
        var ibags: [RawBag] = []
        var igens: [RawGen] = []
        var shdrs: [RawSampleHdr] = []

        func readU16(_ off: Int) -> UInt16 {
            guard off + 2 <= data.count else { return 0 }
            return UInt16(data[off]) | (UInt16(data[off + 1]) << 8)
        }
        func readI8(_ off: Int) -> Int {
            guard off < data.count else { return 0 }
            return Int(Int8(bitPattern: data[off]))
        }
        func readU32(_ off: Int) -> UInt32 {
            guard off + 4 <= data.count else { return 0 }
            return UInt32(data[off]) | (UInt32(data[off + 1]) << 8) | (UInt32(data[off + 2]) << 16) | (UInt32(data[off + 3]) << 24)
        }
        func ascii(_ off: Int, _ len: Int) -> String {
            guard off >= 0, off + len <= data.count else { return "" }
            let slice = data[off..<(off + len)]
            let end = slice.firstIndex(of: 0) ?? slice.endIndex
            return String(bytes: slice[slice.startIndex..<end], encoding: .ascii) ?? ""
        }

        func walkChunks(start: Int, end: Int) {
            var p = start
            while p + 8 <= end {
                let tag = ascii(p, 4)
                let size = Int(readU32(p + 4))
                let bodyStart = p + 8
                let bodyEnd = min(end, bodyStart + max(0, size))
                if tag == "LIST", bodyStart + 4 <= bodyEnd {
                    walkChunks(start: bodyStart + 4, end: bodyEnd)
                } else {
                    switch tag {
                    case "INAM":
                        let nm = ascii(bodyStart, bodyEnd - bodyStart).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !nm.isEmpty { parsedName = nm }
                    case "smpl":
                        smplOffset = bodyStart
                        smplLength = bodyEnd - bodyStart
                    case "phdr":
                        var q = bodyStart
                        while q + 38 <= bodyEnd {
                            phdrs.append(RawPresetHeader(
                                name: ascii(q, 20),
                                preset: Int(readU16(q + 20)),
                                bank: Int(readU16(q + 22)),
                                bagIdx: Int(readU16(q + 24))
                            ))
                            q += 38
                        }
                    case "pbag":
                        var q = bodyStart
                        while q + 4 <= bodyEnd {
                            pbags.append(RawBag(genIdx: Int(readU16(q)), modIdx: Int(readU16(q + 2))))
                            q += 4
                        }
                    case "pgen":
                        var q = bodyStart
                        while q + 4 <= bodyEnd {
                            pgens.append(RawGen(op: readU16(q), val: readU16(q + 2)))
                            q += 4
                        }
                    case "inst":
                        var q = bodyStart
                        while q + 22 <= bodyEnd {
                            insts.append(RawInst(name: ascii(q, 20), bagIdx: Int(readU16(q + 20))))
                            q += 22
                        }
                    case "ibag":
                        var q = bodyStart
                        while q + 4 <= bodyEnd {
                            ibags.append(RawBag(genIdx: Int(readU16(q)), modIdx: Int(readU16(q + 2))))
                            q += 4
                        }
                    case "igen":
                        var q = bodyStart
                        while q + 4 <= bodyEnd {
                            igens.append(RawGen(op: readU16(q), val: readU16(q + 2)))
                            q += 4
                        }
                    case "shdr":
                        var q = bodyStart
                        while q + 46 <= bodyEnd {
                            shdrs.append(RawSampleHdr(
                                name: ascii(q, 20),
                                start: Int(readU32(q + 20)),
                                end: Int(readU32(q + 24)),
                                loopStart: Int(readU32(q + 28)),
                                loopEnd: Int(readU32(q + 32)),
                                sampleRate: max(8000.0, Double(readU32(q + 36))),
                                origPitch: Int(data[q + 40]),
                                pitchCorr: readI8(q + 41),
                                sampleType: readU16(q + 44)
                            ))
                            q += 46
                        }
                    default:
                        break
                    }
                }
                p = bodyStart + max(0, size) + (size & 1)
            }
        }

        walkChunks(start: 12, end: data.count)

        guard smplLength >= 4, !shdrs.isEmpty else {
            throw MIDIPlayerError.soundBankLoadFailed(-10852, "SoundFont contains no audio sample data: \(url.lastPathComponent)")
        }

        let sampleCount = smplLength / 2
        var floats = [Float](repeating: 0, count: sampleCount)
        data.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress?.advanced(by: smplOffset) else { return }
            let i16Ptr = base.assumingMemoryBound(to: Int16.self)
            for i in 0..<sampleCount {
                let le = Int16(littleEndian: i16Ptr[i])
                floats[i] = Float(le) / 32768.0
            }
        }

        self.bankName = parsedName
        self.pcmSamples = floats

        // Build Instrument -> [SampleZone] table
        var progMap: [Int: [SampleZone]] = [:]
        var dZones: [SampleZone] = []

        func zonesForInstrument(_ instIdx: Int, presetLo: Int, presetHi: Int) -> [SampleZone] {
            guard instIdx >= 0, instIdx + 1 < insts.count else { return [] }
            let bagStart = insts[instIdx].bagIdx
            let bagEnd = insts[instIdx + 1].bagIdx
            guard bagStart >= 0, bagEnd <= ibags.count, bagStart < bagEnd else { return [] }

            var out: [SampleZone] = []
            var globalLo = 0, globalHi = 127
            var globalSampleMode = 0
            var globalRootOverride = -1
            var globalRelease = 0.28

            for b in bagStart..<bagEnd {
                let gStart = ibags[b].genIdx
                let gEnd = (b + 1 < ibags.count) ? ibags[b + 1].genIdx : igens.count
                guard gStart >= 0, gEnd <= igens.count, gStart <= gEnd else { continue }

                var lo = globalLo, hi = globalHi
                var mode = globalSampleMode
                var rootOv = globalRootOverride
                var rel = globalRelease
                var sampleID = -1
                var panVal: Float = 0.0

                for g in gStart..<gEnd {
                    let op = igens[g].op
                    let raw = igens[g].val
                    switch op {
                    case 43: // keyRange
                        lo = Int(raw & 0xFF)
                        hi = Int((raw >> 8) & 0xFF)
                    case 54: // sampleModes (1 = loop continuous)
                        mode = Int(raw & 0x03)
                    case 58: // overridingRootKey
                        rootOv = Int(raw)
                    case 38: // releaseVolEnv (timecents)
                        let tc = Double(Int16(bitPattern: raw))
                        rel = max(0.05, min(3.5, pow(2.0, tc / 1200.0)))
                    case 17: // pan (-500..500 tenth-percent)
                        let sVal = Float(Int16(bitPattern: raw)) / 1000.0
                        panVal = max(-0.5, min(0.5, sVal))
                    case 53: // sampleID (always last generator of instrument zone)
                        sampleID = Int(raw)
                    default:
                        break
                    }
                }

                if sampleID == -1 && b == bagStart {
                    globalLo = lo; globalHi = hi; globalSampleMode = mode; globalRootOverride = rootOv; globalRelease = rel
                    continue
                }
                guard sampleID >= 0, sampleID < shdrs.count else { continue }
                let hdr = shdrs[sampleID]
                let effLo = max(presetLo, lo)
                let effHi = min(presetHi, hi)
                guard effLo <= effHi, hdr.end > hdr.start, hdr.end <= sampleCount else { continue }
                let hasLp = (mode == 1) && (hdr.loopEnd > hdr.loopStart + 8) && (hdr.loopEnd <= hdr.end)
                let root = (rootOv >= 0 && rootOv <= 127) ? rootOv : (hdr.origPitch <= 127 ? hdr.origPitch : 60)

                out.append(SampleZone(
                    sampleStart: hdr.start,
                    sampleEnd: hdr.end,
                    loopStart: hdr.loopStart,
                    loopEnd: hdr.loopEnd,
                    sampleRate: hdr.sampleRate,
                    rootKey: root,
                    pitchCorrectionCents: hdr.pitchCorr,
                    hasLoop: hasLp,
                    keyRangeLow: effLo,
                    keyRangeHigh: effHi,
                    pan: panVal,
                    releaseSec: rel
                ))
            }
            return out
        }

        for pIdx in 0..<max(0, phdrs.count - 1) {
            let ph = phdrs[pIdx]
            let bagStart = ph.bagIdx
            let bagEnd = phdrs[pIdx + 1].bagIdx
            guard bagStart >= 0, bagEnd <= pbags.count else { continue }

            var collected: [SampleZone] = []
            for b in bagStart..<bagEnd {
                let gStart = pbags[b].genIdx
                let gEnd = (b + 1 < pbags.count) ? pbags[b + 1].genIdx : pgens.count
                guard gStart >= 0, gEnd <= pgens.count else { continue }
                var lo = 0, hi = 127
                var instIdx = -1
                for g in gStart..<gEnd {
                    if pgens[g].op == 43 {
                        lo = Int(pgens[g].val & 0xFF)
                        hi = Int((pgens[g].val >> 8) & 0xFF)
                    } else if pgens[g].op == 41 {
                        instIdx = Int(pgens[g].val)
                    }
                }
                if instIdx >= 0 {
                    collected.append(contentsOf: zonesForInstrument(instIdx, presetLo: lo, presetHi: hi))
                }
            }

            guard !collected.isEmpty else { continue }
            if ph.bank == 128 {
                if dZones.isEmpty { dZones = collected }
            } else if ph.bank == 0 || progMap[ph.preset] == nil {
                progMap[ph.preset] = collected
            }
        }

        self.programZones = progMap
        self.drumZones = dZones
    }

    func zone(forProgram prog: Int, note: Int, isDrum: Bool) -> SampleZone? {
        let list = isDrum ? drumZones : (programZones[prog] ?? programZones[0])
        guard let candidates = list else { return nil }
        return candidates.first { note >= $0.keyRangeLow && note <= $0.keyRangeHigh } ?? candidates.first
    }
}

// MARK: - Self-Contained 64-Voice General MIDI + Drum Synthesizer & Stereo Hall Reverb

public final class TwinkleNativeGMSynth {
    private enum SynthTimbre {
        case piano, electricPiano, bellFM, pipeOrgan, reedOrgan, pluck, guitar, bass
        case strings, soloString, brass, reedWind, flute, bagpipe, warmPad
        case sf2Sample
        case drumKick, drumSnare, drumHiHat, drumCymbal, drumTom, drumSleighBell, drumTambourine, drumTriangle, drumPercussive
    }

    private struct MIDIChannelState {
        var program: UInt8 = 0
        var volume: Float = 100.0 / 127.0
        var expression: Float = 1.0
        var pan: Float = 0.5 // 0=L, 0.5=C, 1=R
        var modulation: Float = 0.0
        var sustainPedal: Bool = false
        var pitchBendSemitones: Float = 0.0 // +- 2 semitones default
    }

    private enum EnvStage {
        case attack, decay, sustain, release, finished
    }

    private struct SynthVoice {
        var active: Bool = false
        var channel: UInt8 = 0
        var note: UInt8 = 60
        var velocityGain: Float = 0.0
        var sustainedHold: Bool = false
        var timbre: SynthTimbre = .piano
        var ageSamples: UInt64 = 0

        // Oscillator & FM phases
        var phase0: Double = 0
        var phase1: Double = 0
        var phase2: Double = 0
        var modPhase: Double = 0
        var noiseCursor: Int = 0

        // Base frequencies & filter state
        var baseFreqHz: Double = 440.0
        var fmRatio: Double = 2.0
        var fmIndexStart: Float = 0.0
        var fmDecayRate: Float = 1.0
        var lpStateL: Float = 0
        var lpStateR: Float = 0
        var lpCutoffStart: Float = 0.7
        var lpCutoffEnd: Float = 0.25

        // Envelope
        var envStage: EnvStage = .finished
        var envLevel: Float = 0
        var attackRate: Float = 0.05
        var decayRate: Float = 0.9999
        var sustainLevel: Float = 0.5
        var releaseRate: Float = 0.9995
        var autoReleaseTimeSec: Float = 0.0 // For drums/short bells
        var elapsedSec: Float = 0.0

        // Tremolo / Vibrato
        var vibratoRateHz: Double = 5.2
        var tremoloDepth: Float = 0.0
        var stereoWidth: Float = 0.15

        // Optional SF2 sample playback state
        var sf2Pos: Double = 0.0
        var sf2Step: Double = 1.0
        var sf2End: Int = 0
        var sf2LoopStart: Int = 0
        var sf2LoopEnd: Int = 0
        var sf2HasLoop: Bool = false
        var sf2PanOffset: Float = 0.0
    }

    /// Lightweight Stereo Schroeder Reverb (4 Comb + 2 Allpass per channel)
    private struct StereoHallReverb {
        private var cL0: [Float], cL1: [Float], cL2: [Float], cL3: [Float]
        private var cR0: [Float], cR1: [Float], cR2: [Float], cR3: [Float]
        private var apL0: [Float], apL1: [Float], apR0: [Float], apR1: [Float]
        private var idxCL = [0, 0, 0, 0], idxCR = [0, 0, 0, 0]
        private var idxAPL = [0, 0], idxAPR = [0, 0]
        private var lpL = [Float](repeating: 0, count: 4)
        private var lpR = [Float](repeating: 0, count: 4)

        init(sampleRate: Double) {
            let scale = sampleRate / 44100.0
            func buf(_ base: Int) -> [Float] { [Float](repeating: 0, count: max(64, Int(Double(base) * scale))) }
            cL0 = buf(1116); cL1 = buf(1188); cL2 = buf(1277); cL3 = buf(1356)
            cR0 = buf(1139); cR1 = buf(1211); cR2 = buf(1300); cR3 = buf(1379)
            apL0 = buf(556); apL1 = buf(441)
            apR0 = buf(579); apR1 = buf(464)
        }

        mutating func clear() {
            for i in cL0.indices { cL0[i] = 0 }; for i in cL1.indices { cL1[i] = 0 }
            for i in cL2.indices { cL2[i] = 0 }; for i in cL3.indices { cL3[i] = 0 }
            for i in cR0.indices { cR0[i] = 0 }; for i in cR1.indices { cR1[i] = 0 }
            for i in cR2.indices { cR2[i] = 0 }; for i in cR3.indices { cR3[i] = 0 }
            for i in apL0.indices { apL0[i] = 0 }; for i in apL1.indices { apL1[i] = 0 }
            for i in apR0.indices { apR0[i] = 0 }; for i in apR1.indices { apR1[i] = 0 }
            lpL = [0, 0, 0, 0]; lpR = [0, 0, 0, 0]
        }

        @inline(__always)
        private static func comb(_ input: Float, _ buf: inout [Float], _ idx: inout Int, _ lp: inout Float) -> Float {
            let out = buf[idx]
            lp = out * 0.72 + lp * 0.28 // warm HF damping
            buf[idx] = input + lp * 0.80
            idx += 1
            if idx >= buf.count { idx = 0 }
            return out
        }

        @inline(__always)
        private static func allpass(_ input: Float, _ buf: inout [Float], _ idx: inout Int) -> Float {
            let bufOut = buf[idx]
            let out = -input + bufOut
            buf[idx] = input + bufOut * 0.5
            idx += 1
            if idx >= buf.count { idx = 0 }
            return out
        }

        @inline(__always)
        mutating func process(inL: Float, inR: Float) -> (Float, Float) {
            let mono = (inL + inR) * 0.16
            var oL = Self.comb(mono, &cL0, &idxCL[0], &lpL[0])
            oL += Self.comb(mono, &cL1, &idxCL[1], &lpL[1])
            oL += Self.comb(mono, &cL2, &idxCL[2], &lpL[2])
            oL += Self.comb(mono, &cL3, &idxCL[3], &lpL[3])
            oL = Self.allpass(oL, &apL0, &idxAPL[0])
            oL = Self.allpass(oL, &apL1, &idxAPL[1])

            var oR = Self.comb(mono, &cR0, &idxCR[0], &lpR[0])
            oR += Self.comb(mono, &cR1, &idxCR[1], &lpR[1])
            oR += Self.comb(mono, &cR2, &idxCR[2], &lpR[2])
            oR += Self.comb(mono, &cR3, &idxCR[3], &lpR[3])
            oR = Self.allpass(oR, &apR0, &idxAPR[0])
            oR = Self.allpass(oR, &apR1, &idxAPR[1])
            return (oL * 0.24, oR * 0.24)
        }
    }

    private let maxVoices = 64
    private let stateLock = AudioUnfairLock()
    private var channels: [MIDIChannelState]
    private var voices: [SynthVoice]
    private var sampleRate: Double = 44100.0
    private var reverb = StereoHallReverb(sampleRate: 44100.0)
    private var globalSampleCounter: UInt64 = 0
    private var sf2Bank: SF2WavetableBank?

    // Scheduled sequence state processed sample-accurately on render thread
    private struct ScheduledSampleEvent {
        let sampleOffset: UInt64
        let timeSeconds: Double
        let kind: MIDIMessageKind
    }
    private var scheduledEvents: [ScheduledSampleEvent] = []
    private var seqCursor: Int = 0
    private var seqSamplePos: UInt64 = 0
    private var seqTotalSamples: UInt64 = 0
    private var seqPlaying: Bool = false
    private var seqPaused: Bool = false
    private var activeBPM: Double = 120.0
    private var completionFired: Bool = false

    public var masterVolume: Float = 0.85
    public private(set) var peakOutputRMS: Float = 0.0
    public var onMIDIEvent: ((MIDILightEvent) -> Void)?
    public var onCompletion: (() -> Void)?

    public var currentPositionSeconds: Double {
        stateLock.lock()
        let pos = Double(seqSamplePos) / max(1.0, sampleRate)
        stateLock.unlock()
        return pos
    }

    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
        self.channels = [MIDIChannelState](repeating: MIDIChannelState(), count: 16)
        self.voices = [SynthVoice](repeating: SynthVoice(), count: 64)
        self.reverb = StereoHallReverb(sampleRate: sampleRate)
    }

    public func setSoundFontBank(_ bank: SF2WavetableBank?) {
        stateLock.lock()
        silenceAllLocked(resetControllers: true)
        self.sf2Bank = bank
        stateLock.unlock()
    }

    public func updateSampleRate(_ sr: Double) {
        guard sr >= 8000, abs(sr - sampleRate) > 1.0 else { return }
        stateLock.lock()
        let oldSR = sampleRate
        sampleRate = sr
        reverb = StereoHallReverb(sampleRate: sr)
        // Rescale scheduled events smoothly if sample rate changed
        if oldSR > 0 && !scheduledEvents.isEmpty {
            let ratio = sr / oldSR
            scheduledEvents = scheduledEvents.map {
                ScheduledSampleEvent(sampleOffset: UInt64(Double($0.sampleOffset) * ratio), timeSeconds: $0.timeSeconds, kind: $0.kind)
            }
            seqSamplePos = UInt64(Double(seqSamplePos) * ratio)
            seqTotalSamples = UInt64(Double(seqTotalSamples) * ratio)
        }
        stateLock.unlock()
    }

    public func loadSequence(_ parsed: ParsedMIDIFile) {
        stateLock.lock()
        silenceAllLocked(resetControllers: true)
        reverb.clear()
        let sr = sampleRate
        scheduledEvents = parsed.events.map {
            ScheduledSampleEvent(
                sampleOffset: UInt64(max(0.0, $0.timeSeconds) * sr),
                timeSeconds: $0.timeSeconds,
                kind: $0.kind
            )
        }
        seqCursor = 0
        seqSamplePos = 0
        seqTotalSamples = UInt64(max(0.1, parsed.durationSeconds) * sr)
        seqPlaying = false
        seqPaused = false
        activeBPM = parsed.initialBPM
        completionFired = false
        peakOutputRMS = 0.0
        stateLock.unlock()
    }

    public func startPlayback() {
        stateLock.lock()
        if seqPaused {
            seqPaused = false
            seqPlaying = true
        } else {
            silenceAllLocked(resetControllers: true)
            seqCursor = 0
            seqSamplePos = 0
            seqPlaying = true
            seqPaused = false
            completionFired = false
        }
        stateLock.unlock()
    }

    public func pausePlayback() {
        stateLock.lock()
        seqPaused = true
        seqPlaying = false
        silenceAllLocked(resetControllers: false)
        stateLock.unlock()
    }

    public func resumePlayback() {
        stateLock.lock()
        guard seqPaused else {
            stateLock.unlock()
            return
        }
        seqPaused = false
        seqPlaying = true
        stateLock.unlock()
    }

    public func stopPlayback() {
        stateLock.lock()
        seqPlaying = false
        seqPaused = false
        seqCursor = 0
        seqSamplePos = 0
        completionFired = false
        silenceAllLocked(resetControllers: true)
        stateLock.unlock()
    }

    public func resetRMSPeak() {
        stateLock.lock()
        peakOutputRMS = 0.0
        stateLock.unlock()
    }

    // Direct event injection (for testing / controller resets)
    public func handleMIDI(_ kind: MIDIMessageKind) {
        var ignored: [MIDILightEvent]? = nil
        stateLock.lock()
        applyMIDILocked(kind, posSeconds: Double(seqSamplePos) / max(1.0, sampleRate), lightQueue: &ignored)
        stateLock.unlock()
    }

    public func resetControllers() {
        stateLock.lock()
        silenceAllLocked(resetControllers: true)
        stateLock.unlock()
    }

    // MARK: - Sample-Accurate Stereo Render Loop (Real-Time Audio Safe & Offline Testable)

    public func renderOfflineStereo(frameCount: Int) -> (left: [Float], right: [Float], rms: Float) {
        guard frameCount > 0 else { return ([], [], 0) }
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        left.withUnsafeMutableBufferPointer { lBuf in
            right.withUnsafeMutableBufferPointer { rBuf in
                if let lBase = lBuf.baseAddress, let rBase = rBuf.baseAddress {
                    renderFrames(left: lBase, right: rBase, frameCount: frameCount)
                }
            }
        }
        var sumSq: Float = 0
        for i in 0..<frameCount {
            sumSq += left[i] * left[i] + right[i] * right[i]
        }
        return (left, right, sqrtf(sumSq / Float(frameCount * 2)))
    }

    public func renderFrames(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard frameCount > 0 else { return }
        var lightEventsToEmit: [MIDILightEvent]? = []
        var didComplete = false

        stateLock.lock()
        let sr = sampleRate
        let invSR = 1.0 / sr
        let vol = masterVolume
        let activeBank = sf2Bank
        var outIdx = 0
        var sumSq: Float = 0.0

        while outIdx < frameCount {
            // Sub-chunk up to 64 samples or next MIDI event sample offset for <1.5ms/sample precision
            var chunkEnd = min(frameCount, outIdx + 64)
            if seqPlaying && !seqPaused {
                while seqCursor < scheduledEvents.count && scheduledEvents[seqCursor].sampleOffset <= seqSamplePos {
                    let ev = scheduledEvents[seqCursor]
                    seqCursor += 1
                    applyMIDILocked(ev.kind, posSeconds: ev.timeSeconds, lightQueue: &lightEventsToEmit)
                }
                if seqCursor < scheduledEvents.count {
                    let dist = scheduledEvents[seqCursor].sampleOffset > seqSamplePos ? Int(min(UInt64(chunkEnd - outIdx), scheduledEvents[seqCursor].sampleOffset - seqSamplePos)) : 0
                    if dist > 0 { chunkEnd = outIdx + dist }
                }
            }

            let nSamples = chunkEnd - outIdx
            for _ in 0..<nSamples {
                var mixL: Float = 0.0
                var mixR: Float = 0.0
                renderOneSampleLocked(activeBank: activeBank, invSR: Float(invSR), invSRD: invSR, outL: &mixL, outR: &mixR)

                let (revL, revR) = reverb.process(inL: mixL, inR: mixR)
                let wetL = (mixL + revL) * vol
                let wetR = (mixR + revR) * vol

                // Soft-limiting prevents hard digital clipping even across full holiday chords
                let satL = tanhf(wetL * 0.92)
                let satR = tanhf(wetR * 0.92)
                left[outIdx] = satL
                right[outIdx] = satR
                sumSq += satL * satL + satR * satR
                outIdx += 1
                globalSampleCounter &+= 1
                if seqPlaying && !seqPaused {
                    seqSamplePos &+= 1
                }
            }
        }

        let rms = sqrtf(sumSq / Float(max(1, frameCount * 2)))
        if rms > peakOutputRMS {
            peakOutputRMS = rms
        }

        if seqPlaying && !seqPaused && !completionFired && seqCursor >= scheduledEvents.count && seqSamplePos >= seqTotalSamples {
            completionFired = true
            seqPlaying = false
            silenceAllLocked(resetControllers: false)
            didComplete = true
        }
        stateLock.unlock()

        // Emit UI / Light callbacks outside the lock asynchronously
        if let emitList = lightEventsToEmit, !emitList.isEmpty, let cb = onMIDIEvent {
            DispatchQueue.main.async {
                for e in emitList { cb(e) }
            }
        }
        if didComplete, let comp = onCompletion {
            DispatchQueue.main.async { comp() }
        }
    }

    // MARK: - Internal Voice & Channel State Management

    private func silenceAllLocked(resetControllers: Bool) {
        for i in 0..<maxVoices where voices[i].active {
            voices[i].sustainedHold = false
            voices[i].envStage = .release
            voices[i].releaseRate = 0.985 // Quick 6ms de-click tail
        }
        for c in 0..<16 {
            channels[c].sustainPedal = false
            if resetControllers {
                channels[c] = MIDIChannelState()
            }
        }
    }

    private func applyMIDILocked(_ kind: MIDIMessageKind, posSeconds: Double, lightQueue: inout [MIDILightEvent]?) {
        switch kind {
        case .noteOff(let ch, let note, _):
            let c = Int(ch & 0x0F)
            if c != 9 {
                let hold = channels[c].sustainPedal
                for i in 0..<maxVoices where voices[i].active && voices[i].channel == ch && voices[i].note == note {
                    if hold {
                        voices[i].sustainedHold = true
                    } else if voices[i].envStage != .release {
                        voices[i].envStage = .release
                    }
                }
            }
            lightQueue?.append(MIDILightEvent(channel: ch, note: note, velocity: 0, isNoteOn: false, currentBPM: activeBPM, positionSeconds: posSeconds))

        case .noteOn(let ch, let note, let vel):
            if vel == 0 {
                applyMIDILocked(.noteOff(channel: ch, note: note, velocity: 0), posSeconds: posSeconds, lightQueue: &lightQueue)
                return
            }
            triggerNoteLocked(channel: ch, note: note, velocity: vel)
            lightQueue?.append(MIDILightEvent(channel: ch, note: note, velocity: vel, isNoteOn: true, currentBPM: activeBPM, positionSeconds: posSeconds))

        case .controlChange(let ch, let cc, let val):
            let c = Int(ch & 0x0F)
            switch cc {
            case 1: channels[c].modulation = Float(val) / 127.0
            case 7: channels[c].volume = Float(val) / 127.0
            case 10: channels[c].pan = Float(val) / 127.0
            case 11: channels[c].expression = Float(val) / 127.0
            case 64:
                let down = val >= 64
                channels[c].sustainPedal = down
                if !down {
                    for i in 0..<maxVoices where voices[i].active && voices[i].channel == ch && voices[i].sustainedHold {
                        voices[i].sustainedHold = false
                        voices[i].envStage = .release
                    }
                }
            case 120, 123: // All Sound Off / All Notes Off
                for i in 0..<maxVoices where voices[i].active && voices[i].channel == ch {
                    voices[i].sustainedHold = false
                    voices[i].envStage = .release
                    if cc == 120 { voices[i].releaseRate = 0.985 }
                }
            case 121: // Reset All Controllers
                channels[c].modulation = 0
                channels[c].expression = 1.0
                channels[c].sustainPedal = false
                channels[c].pitchBendSemitones = 0
            default:
                break
            }

        case .programChange(let ch, let prog):
            channels[Int(ch & 0x0F)].program = prog & 0x7F

        case .pitchBend(let ch, let val):
            let norm = (Float(val) - 8192.0) / 8192.0
            channels[Int(ch & 0x0F)].pitchBendSemitones = norm * 2.0

        case .setTempo(let us):
            if us > 0 { activeBPM = 60_000_000.0 / Double(us) }

        case .polyAftertouch, .channelAftertouch:
            break
        }
    }

    private func triggerNoteLocked(channel ch: UInt8, note: UInt8, velocity: UInt8) {
        let chIdx = Int(ch & 0x0F)
        // Find free slot, re-trigger same channel+note if already sounding, or steal oldest/quietest
        var slot = -1
        for i in 0..<maxVoices {
            if !voices[i].active { slot = i; break }
        }
        if slot == -1 {
            var bestScore: Float = Float.greatestFiniteMagnitude
            for i in 0..<maxVoices {
                let stagePenalty: Float = (voices[i].envStage == .release) ? 0.0 : 10.0
                let score = stagePenalty + voices[i].envLevel - Float(globalSampleCounter &- voices[i].ageSamples) * 1e-6
                if score < bestScore {
                    bestScore = score
                    slot = i
                }
            }
        }
        guard slot >= 0 else { return }

        let velCurve = powf(Float(velocity) / 127.0, 1.35)
        let isDrum = (chIdx == 9)
        let sr = sampleRate

        // Open/Closed Hi-Hat choke group (closed/pedal chokes open hi-hat cleanly)
        if isDrum && (note == 42 || note == 44) {
            for i in 0..<maxVoices where voices[i].active && voices[i].channel == 9 && voices[i].note == 46 {
                voices[i].envStage = .release
                voices[i].releaseRate = 0.992
            }
        }

        var v = SynthVoice()
        v.active = true
        v.channel = ch
        v.note = note
        v.velocityGain = velCurve * (isDrum ? 0.28 : 0.22)
        v.ageSamples = globalSampleCounter
        v.noiseCursor = (Int(note) &* 7919) & 16383
        v.baseFreqHz = 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
        v.phase0 = 0; v.phase1 = 0.07; v.phase2 = 0.13; v.modPhase = 0
        v.envStage = .attack
        v.envLevel = 0.0

        // Check if custom SF2 bank is loaded & has matching zone
        if let bank = sf2Bank, let z = bank.zone(forProgram: Int(channels[chIdx].program), note: Int(note), isDrum: isDrum) {
            v.timbre = .sf2Sample
            let semiDiff = Double(Int(note) - z.rootKey) - Double(z.pitchCorrectionCents) / 100.0
            v.sf2Step = (z.sampleRate / sr) * pow(2.0, semiDiff / 12.0)
            v.sf2Pos = Double(z.sampleStart)
            v.sf2End = z.sampleEnd
            v.sf2LoopStart = z.loopStart
            v.sf2LoopEnd = z.loopEnd
            v.sf2HasLoop = z.hasLoop
            v.sf2PanOffset = z.pan
            v.attackRate = Float(1.0 / max(1.0, 0.004 * sr))
            v.decayRate = 0.99992
            v.sustainLevel = 0.85
            v.releaseRate = Float(exp(-6.9 / max(100.0, z.releaseSec * sr)))
            voices[slot] = v
            return
        }

        if isDrum {
            configureDrumVoice(&v, drumNote: note, sr: sr)
        } else {
            configureMelodicVoice(&v, program: channels[chIdx].program, note: note, sr: sr)
        }
        voices[slot] = v
    }

    private func configureMelodicVoice(_ v: inout SynthVoice, program: UInt8, note: UInt8, sr: Double) {
        let pitchScale = Double(max(24, min(96, note))) / 60.0
        func rateForSec(_ sec: Double, target: Double = 0.001) -> Float {
            Float(exp(log(target) / max(32.0, sec * sr)))
        }

        switch program {
        case 0...3: // Acoustic Pianos
            v.timbre = .piano
            v.attackRate = Float(1.0 / max(1.0, 0.003 * sr))
            v.decayRate = rateForSec(max(0.55, 3.6 / pitchScale), target: 0.01)
            v.sustainLevel = 0.04
            v.releaseRate = rateForSec(0.22)
            v.lpCutoffStart = 0.82; v.lpCutoffEnd = 0.16; v.fmDecayRate = rateForSec(0.18)
            v.stereoWidth = 0.08
        case 4...7: // Electric Piano / Harpsichord / Clav
            v.timbre = .electricPiano
            v.attackRate = Float(1.0 / max(1.0, 0.003 * sr))
            v.decayRate = rateForSec(program == 6 ? 1.4 / pitchScale : 2.8 / pitchScale, target: 0.01)
            v.sustainLevel = program == 6 ? 0.06 : 0.18
            v.releaseRate = rateForSec(0.20)
            v.fmRatio = program == 6 ? 3.0 : 14.0 // Classic bell tine for EP / bright pluck for Harpsichord
            v.fmIndexStart = program == 6 ? 1.8 : 0.9
            v.fmDecayRate = rateForSec(0.12)
        case 8...15: // Celesta (8), Glockenspiel (9), Music Box (10), Vibraphone (11), Marimba, Tubular Bells (14)
            v.timbre = .bellFM
            v.attackRate = Float(1.0 / max(1.0, 0.002 * sr))
            let dur = (program == 14) ? 3.2 : ((program == 12 || program == 13) ? 0.65 : 2.1 / max(0.7, pitchScale * 0.7))
            v.decayRate = rateForSec(dur, target: 0.004)
            v.sustainLevel = 0.0
            v.releaseRate = rateForSec(0.45)
            v.fmRatio = (program == 12) ? 3.98 : ((program == 14) ? 2.756 : 3.5) // Bar / Chime metallic partials
            v.fmIndexStart = (program == 10 || program == 8) ? 2.4 : 3.1
            v.fmDecayRate = rateForSec(0.32)
            v.tremoloDepth = (program == 11) ? 0.25 : 0.0
            v.autoReleaseTimeSec = Float(dur)
        case 16...23: // Organs & Accordions (Pipe Organ 19!)
            v.timbre = (program == 19 || program == 20) ? .pipeOrgan : .reedOrgan
            v.attackRate = Float(1.0 / max(1.0, 0.016 * sr))
            v.decayRate = 1.0
            v.sustainLevel = 0.95
            v.releaseRate = rateForSec(0.14)
            v.stereoWidth = 0.24
        case 24...31, 45...46, 104...108: // Guitars, Pizzicato, Orchestral Harp (46)
            v.timbre = (program == 46) ? .pluck : .guitar
            v.attackRate = Float(1.0 / max(1.0, 0.003 * sr))
            v.decayRate = rateForSec(max(0.6, 2.5 / pitchScale), target: 0.01)
            v.sustainLevel = 0.05
            v.releaseRate = rateForSec(0.24)
            v.lpCutoffStart = 0.88; v.lpCutoffEnd = 0.14; v.fmDecayRate = rateForSec(0.25)
            v.stereoWidth = 0.14
        case 32...39: // Acoustic / Finger / Pick / Synth Bass
            v.timbre = .bass
            v.attackRate = Float(1.0 / max(1.0, 0.004 * sr))
            v.decayRate = rateForSec(1.8, target: 0.08)
            v.sustainLevel = 0.35
            v.releaseRate = rateForSec(0.16)
            v.lpCutoffStart = 0.65; v.lpCutoffEnd = 0.15; v.fmDecayRate = rateForSec(0.10)
            v.stereoWidth = 0.0
        case 40...44, 47...55: // Solo Violin/Cello, Strings Ensemble (48/49), Choir (52/53)
            v.timbre = (program <= 44) ? .soloString : .strings
            let att = (program == 49 || program == 51 || program == 52) ? 0.14 : 0.065
            v.attackRate = Float(1.0 / max(1.0, att * sr))
            v.decayRate = rateForSec(2.0, target: 0.78)
            v.sustainLevel = 0.78
            v.releaseRate = rateForSec(0.38)
            v.lpCutoffStart = 0.58; v.lpCutoffEnd = 0.42
            v.stereoWidth = 0.36
        case 56...63: // Trumpet, Trombone, French Horn, Brass Section
            v.timbre = .brass
            v.attackRate = Float(1.0 / max(1.0, 0.028 * sr))
            v.decayRate = rateForSec(1.2, target: 0.82)
            v.sustainLevel = 0.82
            v.releaseRate = rateForSec(0.16)
            v.lpCutoffStart = 0.76; v.lpCutoffEnd = 0.48
            v.stereoWidth = 0.20
        case 64...71: // Sax, Oboe (68), English Horn (69), Clarinet (71)
            v.timbre = .reedWind
            v.attackRate = Float(1.0 / max(1.0, 0.022 * sr))
            v.decayRate = 0.99995
            v.sustainLevel = 0.88
            v.releaseRate = rateForSec(0.14)
            v.lpCutoffStart = 0.66; v.lpCutoffEnd = 0.50
            v.stereoWidth = 0.12
        case 72...79: // Flute (73), Recorder (74), Pan Flute (75)
            v.timbre = .flute
            v.attackRate = Float(1.0 / max(1.0, 0.032 * sr))
            v.decayRate = 0.99996
            v.sustainLevel = 0.90
            v.releaseRate = rateForSec(0.16)
            v.stereoWidth = 0.12
        case 109...111: // Bagpipe (109), Fiddle, Shanai
            v.timbre = .bagpipe
            v.attackRate = Float(1.0 / max(1.0, 0.015 * sr))
            v.decayRate = 1.0
            v.sustainLevel = 0.92
            v.releaseRate = rateForSec(0.10)
            v.stereoWidth = 0.25
        default: // Synth Leads, Warm Pads (89), Effects
            v.timbre = .warmPad
            let isPad = (program >= 88 && program <= 103)
            v.attackRate = Float(1.0 / max(1.0, (isPad ? 0.18 : 0.018) * sr))
            v.decayRate = rateForSec(1.8, target: 0.72)
            v.sustainLevel = 0.75
            v.releaseRate = rateForSec(isPad ? 0.55 : 0.22)
            v.lpCutoffStart = 0.62; v.lpCutoffEnd = 0.34
            v.stereoWidth = 0.38
        }
    }

    private func configureDrumVoice(_ v: inout SynthVoice, drumNote: UInt8, sr: Double) {
        func rateForSec(_ sec: Double, target: Double = 0.002) -> Float {
            Float(exp(log(target) / max(32.0, sec * sr)))
        }
        v.attackRate = Float(1.0 / max(1.0, 0.0015 * sr))
        v.sustainLevel = 0.0
        v.releaseRate = rateForSec(0.08)

        switch drumNote {
        case 35, 36: // Acoustic Bass Drum / Kick
            v.timbre = .drumKick
            v.baseFreqHz = 155.0
            v.decayRate = rateForSec(0.24)
            v.autoReleaseTimeSec = 0.26
        case 37, 38, 39, 40: // Rimshot, Snare, Clap
            v.timbre = .drumSnare
            v.baseFreqHz = (drumNote == 37) ? 410.0 : 185.0
            v.decayRate = rateForSec(drumNote == 37 ? 0.07 : 0.20)
            v.autoReleaseTimeSec = 0.24
        case 42, 44: // Closed / Pedal Hi-Hat
            v.timbre = .drumHiHat
            v.decayRate = rateForSec(0.065)
            v.autoReleaseTimeSec = 0.08
        case 46: // Open Hi-Hat
            v.timbre = .drumHiHat
            v.decayRate = rateForSec(0.38)
            v.autoReleaseTimeSec = 0.42
        case 41, 43, 45, 47, 48, 50: // Toms
            v.timbre = .drumTom
            v.baseFreqHz = 72.0 + Double(Int(drumNote) - 41) * 16.0
            v.decayRate = rateForSec(0.26)
            v.autoReleaseTimeSec = 0.28
        case 49, 51, 52, 53, 55, 57, 59: // Crash / Ride / Splash Cymbals
            v.timbre = .drumCymbal
            v.decayRate = rateForSec((drumNote == 51 || drumNote == 53) ? 0.70 : 1.15)
            v.autoReleaseTimeSec = 1.2
        case 54: // Tambourine
            v.timbre = .drumTambourine
            v.decayRate = rateForSec(0.18)
            v.autoReleaseTimeSec = 0.20
        case 80, 81: // Triangle
            v.timbre = .drumTriangle
            v.baseFreqHz = (drumNote == 81) ? 2680.0 : 2100.0
            v.decayRate = rateForSec(drumNote == 80 ? 0.09 : 0.55)
            v.autoReleaseTimeSec = 0.6
        case 83, 84: // Sleigh Bells / Bell Tree (festive Christmas highlight!)
            v.timbre = .drumSleighBell
            v.baseFreqHz = 3420.0
            v.decayRate = rateForSec(0.26)
            v.autoReleaseTimeSec = 0.30
        default: // Woodblock / Cowbell / Perc
            v.timbre = .drumPercussive
            v.baseFreqHz = (drumNote == 56) ? 540.0 : (360.0 + Double(drumNote % 12) * 55.0)
            v.decayRate = rateForSec(0.14)
            v.autoReleaseTimeSec = 0.16
        }
    }

    // MARK: - Per-Sample DSP Evaluation

    @inline(__always)
    private func renderOneSampleLocked(activeBank: SF2WavetableBank?, invSR: Float, invSRD: Double, outL: inout Float, outR: inout Float) {
        let noiseTable = NativeWaveTables.noise
        let sinTable = NativeWaveTables.sine

        for i in 0..<maxVoices {
            guard voices[i].active else { continue }
            var v = voices[i]
            let ch = channels[Int(v.channel & 0x0F)]

            // Advance envelope
            switch v.envStage {
            case .attack:
                v.envLevel += v.attackRate
                if v.envLevel >= 1.0 {
                    v.envLevel = 1.0
                    v.envStage = .decay
                }
            case .decay:
                v.envLevel = v.sustainLevel + (v.envLevel - v.sustainLevel) * v.decayRate
                if v.envLevel <= max(0.0004, v.sustainLevel + 0.0005) {
                    v.envLevel = v.sustainLevel
                    v.envStage = v.sustainLevel <= 0.001 ? .release : .sustain
                }
            case .sustain:
                v.envLevel = v.sustainLevel
            case .release:
                v.envLevel *= v.releaseRate
                if v.envLevel < 0.00035 {
                    v.active = false
                    v.envStage = .finished
                    voices[i] = v
                    continue
                }
            case .finished:
                v.active = false
                voices[i] = v
                continue
            }

            v.elapsedSec += invSR
            if v.autoReleaseTimeSec > 0 && v.elapsedSec >= v.autoReleaseTimeSec && v.envStage != .release {
                v.envStage = .release
            }

            let bendRatio = pow(2.0, Double(ch.pitchBendSemitones) / 12.0)
            let vibMod = ch.modulation > 0.02
                ? sin(Double(v.elapsedSec) * v.vibratoRateHz * 6.283185) * Double(ch.modulation) * 0.014
                : 0.0
            let freq = v.baseFreqHz * bendRatio * (1.0 + vibMod)
            let inc0 = freq * invSRD

            v.noiseCursor = (v.noiseCursor &+ 1) & 16383
            let nz = noiseTable[v.noiseCursor]

            var sL: Float = 0.0
            var sR: Float = 0.0

            switch v.timbre {
            case .sf2Sample:
                if let bank = activeBank {
                    let pcm = bank.pcmSamples
                    let idx0 = Int(v.sf2Pos)
                    let frac = Float(v.sf2Pos - Double(idx0))
                    if idx0 >= 0 && idx0 + 1 < v.sf2End && idx0 + 1 < pcm.count {
                        let s = pcm[idx0] + (pcm[idx0 + 1] - pcm[idx0]) * frac
                        sL = s; sR = s
                    } else {
                        v.envStage = .release
                    }
                    v.sf2Pos += v.sf2Step * bendRatio
                    if v.sf2HasLoop && v.sf2Pos >= Double(v.sf2LoopEnd) {
                        v.sf2Pos -= Double(max(1, v.sf2LoopEnd - v.sf2LoopStart))
                    } else if !v.sf2HasLoop && Int(v.sf2Pos) >= v.sf2End {
                        v.envStage = .release
                    }
                }

            case .piano:
                v.phase0 += inc0; v.phase1 += inc0 * 1.0012
                let a = NativeWaveTables.sampleLinear(NativeWaveTables.piano, phase01: v.phase0)
                let b = NativeWaveTables.sampleLinear(NativeWaveTables.piano, phase01: v.phase1)
                let hammer = v.elapsedSec < 0.012 ? nz * (1.0 - v.elapsedSec / 0.012) * 0.16 : 0.0
                let raw = (a * 0.65 + b * 0.35 + hammer)
                let cutoff = v.lpCutoffEnd + (v.lpCutoffStart - v.lpCutoffEnd) * max(0.0, 1.0 - v.elapsedSec * 2.2)
                v.lpStateL += cutoff * (raw - v.lpStateL)
                sL = v.lpStateL * 1.02
                sR = v.lpStateL * 0.98

            case .electricPiano:
                v.phase0 += inc0
                v.modPhase += inc0 * Double(v.fmRatio)
                let modEnv = powf(v.fmDecayRate, Float(globalSampleCounter &- v.ageSamples))
                let modSig = NativeWaveTables.sampleLinear(sinTable, phase01: v.modPhase) * v.fmIndexStart * modEnv * 0.15
                let s = NativeWaveTables.sampleLinear(sinTable, phase01: v.phase0 + Double(modSig))
                sL = s; sR = s

            case .bellFM:
                v.phase0 += inc0
                v.modPhase += inc0 * Double(v.fmRatio)
                let modEnv = expf(-v.elapsedSec * 4.2)
                let modSig = NativeWaveTables.sampleLinear(sinTable, phase01: v.modPhase) * v.fmIndexStart * modEnv * 0.16
                let carrier = NativeWaveTables.sampleLinear(sinTable, phase01: v.phase0 + Double(modSig))
                let trem = v.tremoloDepth > 0 ? (1.0 - v.tremoloDepth * (0.5 + 0.5 * sinf(v.elapsedSec * 34.5))) : 1.0
                let bell = carrier * trem
                sL = bell; sR = bell

            case .pipeOrgan, .reedOrgan:
                v.phase0 += inc0; v.phase1 += inc0 * 2.0018
                let w1 = NativeWaveTables.sampleLinear(NativeWaveTables.organ, phase01: v.phase0)
                let w2 = NativeWaveTables.sampleLinear(v.timbre == .pipeOrgan ? NativeWaveTables.organ : NativeWaveTables.reed, phase01: v.phase1) * 0.28
                sL = w1 * 0.85 + w2; sR = w1 * 0.85 - w2 * 0.8

            case .pluck, .guitar:
                v.phase0 += inc0; v.phase1 += inc0 * 0.9985
                let raw = NativeWaveTables.sampleLinear(NativeWaveTables.pluck, phase01: v.phase0) * 0.7
                        + NativeWaveTables.sampleLinear(NativeWaveTables.pluck, phase01: v.phase1) * 0.3
                let c = v.lpCutoffEnd + (v.lpCutoffStart - v.lpCutoffEnd) * expf(-v.elapsedSec * 3.8)
                v.lpStateL += c * (raw - v.lpStateL)
                sL = v.lpStateL; sR = v.lpStateL

            case .bass:
                v.phase0 += inc0
                let raw = NativeWaveTables.sampleLinear(NativeWaveTables.pluck, phase01: v.phase0) * 0.55
                        + NativeWaveTables.sampleLinear(sinTable, phase01: v.phase0) * 0.55
                let c = v.lpCutoffEnd + (v.lpCutoffStart - v.lpCutoffEnd) * expf(-v.elapsedSec * 8.0)
                v.lpStateL += c * (raw - v.lpStateL)
                sL = v.lpStateL * 1.15; sR = v.lpStateL * 1.15

            case .strings, .soloString:
                let autoVib = v.elapsedSec > 0.16 ? sin(Double(v.elapsedSec) * 32.0) * 0.0028 : 0.0
                let df = inc0 * (1.0 + autoVib)
                v.phase0 += df
                v.phase1 += df * 0.9962
                v.phase2 += df * 1.0038
                let a = NativeWaveTables.sampleLinear(NativeWaveTables.strings, phase01: v.phase0)
                let b = NativeWaveTables.sampleLinear(NativeWaveTables.strings, phase01: v.phase1)
                let c = NativeWaveTables.sampleLinear(NativeWaveTables.strings, phase01: v.phase2)
                let rawL = a * 0.45 + b * 0.40 + c * 0.15
                let rawR = a * 0.45 + b * 0.15 + c * 0.40
                let cutoff: Float = (v.timbre == .soloString) ? 0.42 : 0.28
                v.lpStateL += cutoff * (rawL - v.lpStateL)
                v.lpStateR += cutoff * (rawR - v.lpStateR)
                sL = v.lpStateL; sR = v.lpStateR

            case .brass:
                v.phase0 += inc0; v.phase1 += inc0 * 1.0018
                let raw = NativeWaveTables.sampleLinear(NativeWaveTables.brass, phase01: v.phase0) * 0.65
                        + NativeWaveTables.sampleLinear(NativeWaveTables.brass, phase01: v.phase1) * 0.35
                let swell = min(1.0, v.elapsedSec / 0.045)
                let cutoff = 0.22 + 0.45 * swell
                v.lpStateL += cutoff * (raw - v.lpStateL)
                sL = v.lpStateL; sR = v.lpStateL

            case .reedWind:
                v.phase0 += inc0
                let raw = NativeWaveTables.sampleLinear(NativeWaveTables.reed, phase01: v.phase0)
                v.lpStateL += 0.36 * (raw - v.lpStateL)
                sL = v.lpStateL; sR = v.lpStateL

            case .flute:
                v.phase0 += inc0
                let tone = NativeWaveTables.sampleLinear(NativeWaveTables.flute, phase01: v.phase0)
                let breath = (nz - v.lpStateR) * (v.elapsedSec < 0.06 ? 0.14 : 0.03)
                v.lpStateR = nz
                sL = tone + breath; sR = tone + breath

            case .bagpipe:
                v.phase0 += inc0; v.phase1 += inc0 * 0.5 // Octave drone + chanter
                let raw = NativeWaveTables.sampleLinear(NativeWaveTables.reed, phase01: v.phase0) * 0.72
                        + NativeWaveTables.sampleLinear(NativeWaveTables.brass, phase01: v.phase1) * 0.28
                sL = raw; sR = raw

            case .warmPad:
                v.phase0 += inc0; v.phase1 += inc0 * 0.994; v.phase2 += inc0 * 1.006
                let a = NativeWaveTables.sampleLinear(NativeWaveTables.strings, phase01: v.phase0)
                let b = NativeWaveTables.sampleLinear(NativeWaveTables.strings, phase01: v.phase1)
                let c = NativeWaveTables.sampleLinear(NativeWaveTables.strings, phase01: v.phase2)
                v.lpStateL += 0.18 * ((a + b) * 0.5 - v.lpStateL)
                v.lpStateR += 0.18 * ((a + c) * 0.5 - v.lpStateR)
                sL = v.lpStateL; sR = v.lpStateR

            // --- General MIDI Channel 10 Drum & Sleigh Bell Algorithms ---
            case .drumKick:
                let kFreq = 46.0 + 115.0 * exp(-Double(v.elapsedSec) * 42.0)
                v.phase0 += kFreq * invSRD
                let thump = NativeWaveTables.sampleLinear(sinTable, phase01: v.phase0) * 1.35
                let click = v.elapsedSec < 0.008 ? nz * 0.25 : 0.0
                sL = thump + click; sR = sL

            case .drumSnare:
                v.phase0 += 185.0 * invSRD; v.phase1 += 330.0 * invSRD
                let body = (NativeWaveTables.sampleLinear(sinTable, phase01: v.phase0) + NativeWaveTables.sampleLinear(sinTable, phase01: v.phase1)) * 0.42 * expf(-v.elapsedSec * 18.0)
                let hp = nz - v.lpStateL; v.lpStateL += 0.25 * (nz - v.lpStateL)
                let snappy = body + hp * 0.85
                sL = snappy; sR = snappy

            case .drumHiHat, .drumCymbal:
                // 6-frequency metallic FM shimmer + high-pass sheen
                v.phase0 += 3180.0 * invSRD; v.phase1 += 4520.0 * invSRD; v.phase2 += 6310.0 * invSRD
                let m = (NativeWaveTables.sampleLinear(sinTable, phase01: v.phase0)
                       + NativeWaveTables.sampleLinear(sinTable, phase01: v.phase1)
                       + NativeWaveTables.sampleLinear(sinTable, phase01: v.phase2)) * 0.35
                let hp = (nz - v.lpStateL) * 0.72 + m * 0.45
                v.lpStateL += 0.45 * (nz - v.lpStateL)
                sL = hp; sR = hp * 0.94

            case .drumTom:
                let tf = v.baseFreqHz * (0.72 + 0.55 * exp(-Double(v.elapsedSec) * 24.0))
                v.phase0 += tf * invSRD
                let tSig = NativeWaveTables.sampleLinear(sinTable, phase01: v.phase0) * 1.15
                sL = tSig; sR = tSig

            case .drumSleighBell:
                // Multi-jingle shimmering festive sleigh bell cluster!
                v.phase0 += 3420.0 * invSRD
                v.phase1 += 4890.0 * invSRD
                v.phase2 += 6740.0 * invSRD
                let jingleBurst = (0.55 + 0.45 * sinf(v.elapsedSec * 95.0))
                let bells = (NativeWaveTables.sampleLinear(sinTable, phase01: v.phase0) * 0.45
                           + NativeWaveTables.sampleLinear(sinTable, phase01: v.phase1) * 0.35
                           + NativeWaveTables.sampleLinear(sinTable, phase01: v.phase2) * 0.25)
                let shimmer = ((nz - v.lpStateL) * 0.28 + bells * 0.92) * jingleBurst
                v.lpStateL += 0.65 * (nz - v.lpStateL)
                sL = shimmer * 1.1; sR = shimmer * 0.9

            case .drumTambourine:
                v.phase0 += 5120.0 * invSRD; v.phase1 += 7640.0 * invSRD
                let jingles = (NativeWaveTables.sampleLinear(sinTable, phase01: v.phase0)
                             + NativeWaveTables.sampleLinear(sinTable, phase01: v.phase1)) * 0.5
                let tamb = bellsOrAir(nz: nz, lp: &v.lpStateL, tone: jingles)
                sL = tamb; sR = tamb

            case .drumTriangle:
                v.phase0 += v.baseFreqHz * invSRD; v.phase1 += v.baseFreqHz * 2.71 * invSRD
                let tri = NativeWaveTables.sampleLinear(sinTable, phase01: v.phase0) * 0.72
                        + NativeWaveTables.sampleLinear(sinTable, phase01: v.phase1) * 0.28
                sL = tri; sR = tri

            case .drumPercussive:
                v.phase0 += v.baseFreqHz * invSRD; v.phase1 += v.baseFreqHz * 1.48 * invSRD
                let perc = NativeWaveTables.sampleLinear(sinTable, phase01: v.phase0) * 0.65
                         + NativeWaveTables.sampleLinear(sinTable, phase01: v.phase1) * 0.35
                sL = perc; sR = perc
            }

            // Constant-power stereo pan + channel Volume * Expression * Envelope
            let panRaw = max(0.0, min(1.0, ch.pan + v.sf2PanOffset))
            let panAngle = panRaw * (.pi * 0.5)
            let gain = v.envLevel * v.velocityGain * ch.volume * ch.expression
            outL += sL * cosf(panAngle) * gain
            outR += sR * sinf(panAngle) * gain

            voices[i] = v
        }
    }

    @inline(__always)
    private func bellsOrAir(nz: Float, lp: inout Float, tone: Float) -> Float {
        let hp = nz - lp
        lp += 0.55 * (nz - lp)
        return hp * 0.45 + tone * 0.55
    }
}
