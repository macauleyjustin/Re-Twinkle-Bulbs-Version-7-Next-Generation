import Foundation
import AVFoundation

// MARK: - MIDI Parsing & Errors

public enum MIDIPlayerError: LocalizedError, Equatable {
    case emptyData
    case invalidHeader(String)
    case truncatedTrack(Int)
    case unsupportedDivision
    case soundBankNotFound(String)
    case soundBankLoadFailed(OSStatus, String)
    case audioEngineFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyData: return "MIDI file is empty."
        case .invalidHeader(let msg): return "Invalid MIDI header: \(msg)"
        case .truncatedTrack(let idx): return "MIDI track \(idx) is truncated or corrupt."
        case .unsupportedDivision: return "Unsupported MIDI time division."
        case .soundBankNotFound(let p): return "Sound bank not found: \(p)"
        case .soundBankLoadFailed(let st, let p): return "Failed loading sound bank (\(st)): \(p)"
        case .audioEngineFailed(let msg): return "Audio engine error: \(msg)"
        }
    }
}

public enum MIDIMessageKind: Equatable {
    case noteOff(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case polyAftertouch(channel: UInt8, note: UInt8, pressure: UInt8)
    case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
    case programChange(channel: UInt8, program: UInt8)
    case channelAftertouch(channel: UInt8, pressure: UInt8)
    case pitchBend(channel: UInt8, value: UInt16)
    case setTempo(microsecondsPerQuarter: UInt32)
}

public struct TimedMIDIEvent: Equatable {
    public let tick: UInt64
    public let timeSeconds: Double
    public let trackIndex: Int
    public let orderIndex: Int
    public let kind: MIDIMessageKind
}

public struct ParsedMIDIFile {
    public let format: UInt16
    public let trackCount: UInt16
    public let ticksPerQuarterNote: Double
    public let events: [TimedMIDIEvent]
    public let durationSeconds: Double
    public let initialBPM: Double
    public let channelsUsed: Set<UInt8>
    public let programsUsed: Set<UInt8>
    public let hasPercussion: Bool
    public let trackNames: [String]
}

public struct MIDILightEvent {
    public let channel: UInt8
    public let note: UInt8
    public let velocity: UInt8
    public let isNoteOn: Bool
    public let currentBPM: Double
    public let positionSeconds: Double

    public init(channel: UInt8, note: UInt8, velocity: UInt8, isNoteOn: Bool, currentBPM: Double, positionSeconds: Double) {
        self.channel = channel
        self.note = note
        self.velocity = velocity
        self.isNoteOn = isNoteOn
        self.currentBPM = currentBPM
        self.positionSeconds = positionSeconds
    }
}

public final class StandardMIDIFileParser {
    public static func parse(url: URL) throws -> ParsedMIDIFile {
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }

    public static func parse(data rawData: Data) throws -> ParsedMIDIFile {
        guard rawData.count >= 14 else { throw MIDIPlayerError.emptyData }
        let data = unwrapRIFFMIDIIfNeeded(rawData)
        guard data.count >= 14 else { throw MIDIPlayerError.invalidHeader("Too short") }
        guard ascii(data, 0, 4) == "MThd" else {
            throw MIDIPlayerError.invalidHeader("Missing MThd chunk signature")
        }

        let headerLen = Int(readU32BE(data, 4))
        guard headerLen >= 6, 8 + headerLen <= data.count else {
            throw MIDIPlayerError.invalidHeader("Corrupt MThd header length")
        }

        let format = readU16BE(data, 8)
        let trackCount = readU16BE(data, 10)
        let rawDiv = readU16BE(data, 12)
        guard format <= 2 else {
            throw MIDIPlayerError.invalidHeader("Unsupported SMF format \(format)")
        }

        let ppqn: Double
        if (rawDiv & 0x8000) == 0 {
            guard rawDiv > 0 else { throw MIDIPlayerError.unsupportedDivision }
            ppqn = Double(rawDiv)
        } else {
            // SMPTE frames per second x ticks per frame -> synthesize equivalent quarter ticks assuming 120 BPM
            let signedFPS = Int8(bitPattern: UInt8((rawDiv >> 8) & 0xFF))
            let fps = Double(abs(Int(signedFPS)) == 29 ? 29.97 : Double(abs(Int(signedFPS))))
            let tpf = Double(rawDiv & 0xFF)
            guard fps > 0, tpf > 0 else { throw MIDIPlayerError.unsupportedDivision }
            ppqn = (fps * tpf) / 2.0
        }

        var cursor = 8 + headerLen
        var rawEvents: [(tick: UInt64, track: Int, seq: Int, kind: MIDIMessageKind)] = []
        var trackNames: [String] = []
        var channelsUsed: Set<UInt8> = []
        var programsUsed: Set<UInt8> = []
        var seqCounter = 0

        for trackIdx in 0..<Int(trackCount) {
            while cursor + 8 <= data.count && ascii(data, cursor, 4) != "MTrk" {
                let skipLen = Int(readU32BE(data, cursor + 4))
                let next = cursor + 8 + max(0, skipLen)
                if next > data.count || next <= cursor { break }
                cursor = next
            }
            guard cursor + 8 <= data.count, ascii(data, cursor, 4) == "MTrk" else {
                throw MIDIPlayerError.truncatedTrack(trackIdx)
            }
            let chunkLen = Int(readU32BE(data, cursor + 4))
            let trackStart = cursor + 8
            let trackEnd = min(data.count, trackStart + max(0, chunkLen))
            if trackStart + chunkLen > data.count {
                throw MIDIPlayerError.truncatedTrack(trackIdx)
            }

            var p = trackStart
            var tick: UInt64 = 0
            var runningStatus: UInt8 = 0

            while p < trackEnd {
                let delta = readVLQ(data, &p, limit: trackEnd)
                tick &+= delta
                guard p < trackEnd else { break }

                let peek = data[p]
                var status: UInt8
                if peek >= 0x80 {
                    status = peek
                    p += 1
                    if status < 0xF0 {
                        runningStatus = status
                    }
                } else {
                    guard runningStatus >= 0x80 else { break }
                    status = runningStatus
                }

                let hi = status & 0xF0
                let ch = status & 0x0F

                if status == 0xFF {
                    // Meta event
                    runningStatus = 0
                    guard p < trackEnd else { break }
                    let metaType = data[p]
                    p += 1
                    let len = Int(readVLQ(data, &p, limit: trackEnd))
                    let metaEnd = min(trackEnd, p + len)
                    if metaType == 0x2F {
                        p = metaEnd
                        break
                    } else if metaType == 0x51 && (metaEnd - p) >= 3 {
                        let us = (UInt32(data[p]) << 16) | (UInt32(data[p + 1]) << 8) | UInt32(data[p + 2])
                        if us > 0 {
                            rawEvents.append((tick, trackIdx, seqCounter, .setTempo(microsecondsPerQuarter: us)))
                            seqCounter += 1
                        }
                    } else if (metaType == 0x03 || metaType == 0x01), metaEnd > p {
                        if metaType == 0x03, let name = String(data: data[p..<metaEnd], encoding: .utf8), !name.isEmpty {
                            trackNames.append(name)
                        }
                    }
                    p = metaEnd
                } else if status == 0xF0 || status == 0xF7 {
                    runningStatus = 0
                    let len = Int(readVLQ(data, &p, limit: trackEnd))
                    p = min(trackEnd, p + len)
                } else if status >= 0xF1 {
                    runningStatus = 0
                    if status == 0xF2 { p = min(trackEnd, p + 2) }
                    else if status == 0xF1 || status == 0xF3 { p = min(trackEnd, p + 1) }
                } else {
                    switch hi {
                    case 0x80:
                        guard p + 1 < trackEnd else { p = trackEnd; break }
                        let note = data[p] & 0x7F; let vel = data[p + 1] & 0x7F; p += 2
                        channelsUsed.insert(ch)
                        rawEvents.append((tick, trackIdx, seqCounter, .noteOff(channel: ch, note: note, velocity: vel)))
                    case 0x90:
                        guard p + 1 < trackEnd else { p = trackEnd; break }
                        let note = data[p] & 0x7F; let vel = data[p + 1] & 0x7F; p += 2
                        channelsUsed.insert(ch)
                        if vel == 0 {
                            rawEvents.append((tick, trackIdx, seqCounter, .noteOff(channel: ch, note: note, velocity: 0)))
                        } else {
                            rawEvents.append((tick, trackIdx, seqCounter, .noteOn(channel: ch, note: note, velocity: vel)))
                        }
                    case 0xA0:
                        guard p + 1 < trackEnd else { p = trackEnd; break }
                        let note = data[p] & 0x7F; let pres = data[p + 1] & 0x7F; p += 2
                        channelsUsed.insert(ch)
                        rawEvents.append((tick, trackIdx, seqCounter, .polyAftertouch(channel: ch, note: note, pressure: pres)))
                    case 0xB0:
                        guard p + 1 < trackEnd else { p = trackEnd; break }
                        let cc = data[p] & 0x7F; let val = data[p + 1] & 0x7F; p += 2
                        channelsUsed.insert(ch)
                        rawEvents.append((tick, trackIdx, seqCounter, .controlChange(channel: ch, controller: cc, value: val)))
                    case 0xC0:
                        guard p < trackEnd else { p = trackEnd; break }
                        let prog = data[p] & 0x7F; p += 1
                        channelsUsed.insert(ch)
                        programsUsed.insert(prog)
                        rawEvents.append((tick, trackIdx, seqCounter, .programChange(channel: ch, program: prog)))
                    case 0xD0:
                        guard p < trackEnd else { p = trackEnd; break }
                        let pres = data[p] & 0x7F; p += 1
                        channelsUsed.insert(ch)
                        rawEvents.append((tick, trackIdx, seqCounter, .channelAftertouch(channel: ch, pressure: pres)))
                    case 0xE0:
                        guard p + 1 < trackEnd else { p = trackEnd; break }
                        let lsb = UInt16(data[p] & 0x7F)
                        let msb = UInt16(data[p + 1] & 0x7F)
                        p += 2
                        channelsUsed.insert(ch)
                        let val14 = (msb << 7) | lsb
                        rawEvents.append((tick, trackIdx, seqCounter, .pitchBend(channel: ch, value: val14)))
                    default:
                        break
                    }
                    seqCounter += 1
                }
            }
            cursor = trackStart + chunkLen
        }

        // Global sort by (tick, sequence order)
        rawEvents.sort {
            if $0.tick != $1.tick { return $0.tick < $1.tick }
            return $0.seq < $1.seq
        }

        // Map ticks -> exact wall-clock seconds honoring every tempo change
        var usPerQuarter: Double = 500_000.0 // Default 120 BPM per SMF specification
        var initialBPM = 120.0
        var sawInitialTempo = false
        var lastTick: UInt64 = 0
        var accSec: Double = 0.0
        var timed: [TimedMIDIEvent] = []
        timed.reserveCapacity(rawEvents.count)

        for ev in rawEvents {
            let dt = ev.tick >= lastTick ? Double(ev.tick - lastTick) : 0
            accSec += (dt / ppqn) * (usPerQuarter / 1_000_000.0)
            lastTick = ev.tick
            if case .setTempo(let us) = ev.kind {
                usPerQuarter = Double(us)
                if !sawInitialTempo && ev.tick == 0 {
                    initialBPM = 60_000_000.0 / Double(us)
                    sawInitialTempo = true
                }
            }
            timed.append(TimedMIDIEvent(
                tick: ev.tick,
                timeSeconds: accSec,
                trackIndex: ev.track,
                orderIndex: ev.seq,
                kind: ev.kind
            ))
        }

        let duration = (timed.last?.timeSeconds ?? 0.0) + 0.6
        return ParsedMIDIFile(
            format: format,
            trackCount: trackCount,
            ticksPerQuarterNote: ppqn,
            events: timed,
            durationSeconds: duration,
            initialBPM: initialBPM,
            channelsUsed: channelsUsed,
            programsUsed: programsUsed,
            hasPercussion: channelsUsed.contains(9),
            trackNames: trackNames
        )
    }

    private static func unwrapRIFFMIDIIfNeeded(_ data: Data) -> Data {
        guard data.count >= 20, ascii(data, 0, 4) == "RIFF", ascii(data, 8, 4) == "RMID" else {
            return data
        }
        var p = 12
        while p + 8 <= data.count {
            let tag = ascii(data, p, 4)
            let len = Int(UInt32(data[p + 4]) | (UInt32(data[p + 5]) << 8) | (UInt32(data[p + 6]) << 16) | (UInt32(data[p + 7]) << 24))
            let start = p + 8
            if tag == "data", start + len <= data.count {
                return Data(data[start..<(start + len)])
            }
            p = start + max(0, len) + (len & 1)
        }
        return data
    }

    private static func readVLQ(_ data: Data, _ p: inout Int, limit: Int) -> UInt64 {
        var val: UInt64 = 0
        for _ in 0..<4 {
            guard p < limit else { break }
            let b = data[p]; p += 1
            val = (val << 7) | UInt64(b & 0x7F)
            if (b & 0x80) == 0 { break }
        }
        return val
    }

    private static func readU16BE(_ data: Data, _ off: Int) -> UInt16 {
        (UInt16(data[off]) << 8) | UInt16(data[off + 1])
    }

    private static func readU32BE(_ data: Data, _ off: Int) -> UInt32 {
        (UInt32(data[off]) << 24) | (UInt32(data[off + 1]) << 16) | (UInt32(data[off + 2]) << 8) | UInt32(data[off + 3])
    }

    private static func ascii(_ data: Data, _ off: Int, _ len: Int) -> String {
        guard off + len <= data.count else { return "" }
        return String(bytes: data[off..<(off + len)], encoding: .ascii) ?? ""
    }
}

// MARK: - Native Self-Contained General MIDI Synthesizer & Sample-Accurate Player

public final class MIDISynthPlayer {
    public let synthCore = TwinkleNativeGMSynth(sampleRate: 44100.0)

    public private(set) var activeSoundBankURL: URL?
    public private(set) var activeSoundBankDescription: String = "TwinkleSynth Built-in GM (64-Voice DSP)"
    public private(set) var parsedMIDI: ParsedMIDIFile?
    public private(set) var isPlaying: Bool = false
    public private(set) var isPaused: Bool = false
    public var currentPositionSeconds: Double { synthCore.currentPositionSeconds }
    public var peakOutputRMS: Float { max(synthCore.peakOutputRMS, tapPeakRMS) }

    public var volume: Double = 0.85 {
        didSet {
            let v = Float(max(0.0, min(1.0, volume)))
            synthCore.masterVolume = v
            engine.mainMixerNode.outputVolume = 1.0
        }
    }

    public var onMIDIEvent: ((MIDILightEvent) -> Void)? {
        didSet { synthCore.onMIDIEvent = onMIDIEvent }
    }
    public var onCompletion: (() -> Void)?

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var tapPeakRMS: Float = 0.0
    private var tapInstalled: Bool = false

    public init() {
        let outFmt = engine.mainMixerNode.outputFormat(forBus: 0)
        let hwRate = (outFmt.sampleRate >= 8000 && outFmt.sampleRate <= 192000) ? outFmt.sampleRate : 44100.0
        synthCore.updateSampleRate(hwRate)
        synthCore.masterVolume = Float(volume)

        let renderFmt = AVAudioFormat(standardFormatWithSampleRate: hwRate, channels: 2)!
        let core = synthCore
        let node = AVAudioSourceNode(format: renderFmt) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let count = Int(frameCount)
            if abl.count >= 2,
               let leftPtr = abl[0].mData?.assumingMemoryBound(to: Float.self),
               let rightPtr = abl[1].mData?.assumingMemoryBound(to: Float.self) {
                core.renderFrames(left: leftPtr, right: rightPtr, frameCount: count)
            } else {
                for buf in abl {
                    if let p = buf.mData {
                        memset(p, 0, Int(buf.mDataByteSize))
                    }
                }
            }
            return noErr
        }
        self.sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: renderFmt)
        engine.mainMixerNode.outputVolume = 1.0

        synthCore.onCompletion = { [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.isPaused = false
            self.onCompletion?()
        }
    }

    deinit {
        stop()
        removeMixerTap()
        engine.stop()
    }

    /// Uses TwinkleSynth's built-in 64-voice General MIDI DSP engine by default (no Apple MIDISynth or gs_instruments.dls).
    /// When a custom `.sf2` SoundFont path is given, parses its RIFF wavetable samples in-house into TwinkleSynth.
    public func configureSoundBank(customPath: String?) throws {
        let trimmed = customPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            activeSoundBankURL = nil
            activeSoundBankDescription = "TwinkleSynth Built-in GM (64-Voice DSP)"
            synthCore.setSoundFontBank(nil)
            return
        }

        let customURL = URL(fileURLWithPath: trimmed)
        guard FileManager.default.isReadableFile(atPath: customURL.path) else {
            throw MIDIPlayerError.soundBankNotFound(trimmed)
        }
        if activeSoundBankURL == customURL { return }

        let ext = customURL.pathExtension.lowercased()
        guard ext == "sf2" else {
            throw MIDIPlayerError.soundBankLoadFailed(
                -10851,
                "TwinkleSynth native bank loader supports .sf2 SoundFont 2 files (leave blank for built-in TwinkleSynth GM engine)."
            )
        }
        let bank = try SF2WavetableBank(url: customURL)
        synthCore.setSoundFontBank(bank)
        activeSoundBankURL = customURL
        activeSoundBankDescription = "TwinkleSynth + \(bank.bankName)"
    }

    public func installLevelTapIfNeeded() {
        guard !tapInstalled else { return }
        let fmt = engine.mainMixerNode.outputFormat(forBus: 0)
        guard fmt.channelCount > 0 else { return }
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            guard let self, let chData = buf.floatChannelData else { return }
            let frames = Int(buf.frameLength)
            let channels = Int(buf.format.channelCount)
            var sumSq: Float = 0
            for ch in 0..<channels {
                let ptr = chData[ch]
                for i in 0..<frames {
                    let s = ptr[i]
                    sumSq += s * s
                }
            }
            let rms = frames > 0 ? sqrt(sumSq / Float(frames * max(1, channels))) : 0
            if rms > self.tapPeakRMS {
                self.tapPeakRMS = rms
            }
        }
        tapInstalled = true
    }

    public func removeMixerTap() {
        guard tapInstalled else { return }
        engine.mainMixerNode.removeTap(onBus: 0)
        tapInstalled = false
    }

    public func load(url: URL, customSoundBankPath: String?) throws -> ParsedMIDIFile {
        let parsed = try StandardMIDIFileParser.parse(url: url)
        try load(parsed: parsed, customSoundBankPath: customSoundBankPath)
        return parsed
    }

    public func load(data: Data, customSoundBankPath: String?) throws -> ParsedMIDIFile {
        let parsed = try StandardMIDIFileParser.parse(data: data)
        try load(parsed: parsed, customSoundBankPath: customSoundBankPath)
        return parsed
    }

    public func load(parsed: ParsedMIDIFile, customSoundBankPath: String?) throws {
        stop()
        try configureSoundBank(customPath: customSoundBankPath)
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                throw MIDIPlayerError.audioEngineFailed(error.localizedDescription)
            }
        }
        self.parsedMIDI = parsed
        self.tapPeakRMS = 0.0
        synthCore.onMIDIEvent = onMIDIEvent
        synthCore.loadSequence(parsed)
    }

    public func play() {
        guard parsedMIDI != nil else { return }
        if !engine.isRunning { try? engine.start() }
        if isPaused {
            resume()
            return
        }
        isPlaying = true
        isPaused = false
        synthCore.startPlayback()
    }

    public func pause() {
        guard isPlaying, !isPaused else { return }
        isPaused = true
        isPlaying = false
        synthCore.pausePlayback()
    }

    public func resume() {
        guard isPaused, parsedMIDI != nil else { return }
        if !engine.isRunning { try? engine.start() }
        isPaused = false
        isPlaying = true
        synthCore.resumePlayback()
    }

    public func stop() {
        synthCore.stopPlayback()
        isPlaying = false
        isPaused = false
    }

    public func resetMIDIControllers() {
        synthCore.resetControllers()
    }

    /// Deterministic offline stereo PCM render for DSP inspection and headless verification.
    public func renderOfflineStereoFrames(frameCount: Int, sampleRate: Double = 44100.0) -> (left: [Float], right: [Float], rms: Float) {
        synthCore.updateSampleRate(sampleRate)
        return synthCore.renderOfflineStereo(frameCount: frameCount)
    }
}

// MARK: - Clean-Room Multi-Channel Standard MIDI Arrangement Builder

public enum BuiltInCarolMIDIBuilder {
    public struct CarolSpec {
        public let id: String
        public let title: String
        public let bpm: Double
        public let melodyProgram: UInt8
        public let harmonyProgram: UInt8
        public let bassProgram: UInt8
        public let includePercussion: Bool
        public let notes: [(midi: UInt8, beats: Double)]
    }

    /// Generates genuine multi-track Format-1 SMF binary data (Melody + Harmony + Chords + Bass + Channel 10 Percussion).
    public static func buildFormat1MIDI(spec: CarolSpec) -> Data {
        let ppqn: UInt16 = 480
        let usPerQuarter = UInt32(round(60_000_000.0 / max(40.0, spec.bpm)))

        // Track 0: Tempo & Name
        var track0 = [UInt8]()
        appendMetaText(&track0, delta: 0, type: 0x03, text: spec.title)
        appendTempo(&track0, delta: 0, usPerQuarter: usPerQuarter)
        appendEndOfTrack(&track0, delta: 0)

        // Track 1: Channel 0 Lead Melody
        var track1 = [UInt8]()
        track1.append(contentsOf: [0x00, 0xC0, spec.melodyProgram])
        track1.append(contentsOf: [0x00, 0xB0, 10, 64]) // Pan Center
        track1.append(contentsOf: [0x00, 0xB0, 7, 118]) // Lead Vol
        for (i, n) in spec.notes.enumerated() {
            let ticks = max(120, UInt64(round(n.beats * Double(ppqn))))
            let vel: UInt8 = (i % 4 == 0) ? 98 : 84
            let playTicks = UInt64(Double(ticks) * 0.90)
            let restTicks = ticks - playTicks
            appendVLQ(&track1, 0)
            track1.append(contentsOf: [0x90, n.midi, vel])
            appendVLQ(&track1, playTicks)
            track1.append(contentsOf: [0x80, n.midi, 0])
            appendVLQ(&track1, restTicks)
        }
        appendEndOfTrack(&track1, delta: 0)

        // Track 2: Channel 1 Harmony / Thirds & Strings + Sustain
        var track2 = [UInt8]()
        track2.append(contentsOf: [0x00, 0xC1, spec.harmonyProgram])
        track2.append(contentsOf: [0x00, 0xB1, 10, 42]) // Slight Left
        track2.append(contentsOf: [0x00, 0xB1, 7, 74])
        for n in spec.notes {
            let ticks = max(120, UInt64(round(n.beats * Double(ppqn))))
            let harm = max(48, n.midi - 4)
            appendVLQ(&track2, 0)
            track2.append(contentsOf: [0x91, harm, 58])
            appendVLQ(&track2, ticks)
            track2.append(contentsOf: [0x81, harm, 0])
        }
        appendEndOfTrack(&track2, delta: 0)

        // Track 3: Channel 2 Acoustic Bass (root progression every 2 beats)
        var track3 = [UInt8]()
        track3.append(contentsOf: [0x00, 0xC2, spec.bassProgram])
        track3.append(contentsOf: [0x00, 0xB2, 10, 82]) // Slight Right
        track3.append(contentsOf: [0x00, 0xB2, 7, 86])
        var beatAcc = 0.0
        let totalBeats = spec.notes.reduce(0.0) { $0 + $1.beats }
        var stepIdx = 0
        while beatAcc < totalBeats {
            let span = min(2.0, totalBeats - beatAcc)
            let bassNotes: [UInt8] = [36, 36, 41, 43] // C2-F2-G2 Holiday cadence
            let note = bassNotes[stepIdx % bassNotes.count]
            let ticks = UInt64(round(span * Double(ppqn)))
            appendVLQ(&track3, 0)
            track3.append(contentsOf: [0x92, note, 84])
            appendVLQ(&track3, ticks)
            track3.append(contentsOf: [0x82, note, 0])
            beatAcc += span
            stepIdx += 1
        }
        appendEndOfTrack(&track3, delta: 0)

        // Track 4: Channel 9 (MIDI Channel 10) Sleigh Bells / Percussion
        var track4 = [UInt8]()
        if spec.includePercussion {
            track4.append(contentsOf: [0x00, 0xB9, 7, 92])
            var b = 0.0
            var beatNum = 0
            while b < totalBeats {
                let dur = min(0.5, totalBeats - b)
                let ticks = UInt64(round(dur * Double(ppqn)))
                let inst: UInt8 = (beatNum % 4 == 0) ? 83 : ((beatNum % 2 == 0) ? 54 : 42) // Sleigh Bell, Tambourine, HiHat
                let vel: UInt8 = (beatNum % 4 == 0) ? 88 : 54
                appendVLQ(&track4, 0)
                track4.append(contentsOf: [0x99, inst, vel])
                appendVLQ(&track4, ticks)
                track4.append(contentsOf: [0x89, inst, 0])
                b += dur
                beatNum += 1
            }
        }
        appendEndOfTrack(&track4, delta: 0)

        let tracks = [track0, track1, track2, track3, track4]
        var out = Data()
        out.append(contentsOf: Array("MThd".utf8))
        appendU32BE(&out, 6)
        appendU16BE(&out, 1) // Format 1 multi-track
        appendU16BE(&out, UInt16(tracks.count))
        appendU16BE(&out, ppqn)
        for trk in tracks {
            out.append(contentsOf: Array("MTrk".utf8))
            appendU32BE(&out, UInt32(trk.count))
            out.append(contentsOf: trk)
        }
        return out
    }

    private static func appendMetaText(_ buf: inout [UInt8], delta: UInt64, type: UInt8, text: String) {
        let bytes = Array(text.utf8)
        appendVLQ(&buf, delta)
        buf.append(contentsOf: [0xFF, type])
        appendVLQ(&buf, UInt64(bytes.count))
        buf.append(contentsOf: bytes)
    }

    private static func appendTempo(_ buf: inout [UInt8], delta: UInt64, usPerQuarter: UInt32) {
        appendVLQ(&buf, delta)
        buf.append(contentsOf: [
            0xFF, 0x51, 0x03,
            UInt8((usPerQuarter >> 16) & 0xFF),
            UInt8((usPerQuarter >> 8) & 0xFF),
            UInt8(usPerQuarter & 0xFF)
        ])
    }

    private static func appendEndOfTrack(_ buf: inout [UInt8], delta: UInt64) {
        appendVLQ(&buf, delta)
        buf.append(contentsOf: [0xFF, 0x2F, 0x00])
    }

    private static func appendVLQ(_ buf: inout [UInt8], _ val: UInt64) {
        var bytes: [UInt8] = [UInt8(val & 0x7F)]
        var v = val >> 7
        while v > 0 {
            bytes.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        buf.append(contentsOf: bytes.reversed())
    }

    private static func appendU16BE(_ data: inout Data, _ v: UInt16) {
        data.append(UInt8((v >> 8) & 0xFF))
        data.append(UInt8(v & 0xFF))
    }

    private static func appendU32BE(_ data: inout Data, _ v: UInt32) {
        data.append(UInt8((v >> 24) & 0xFF))
        data.append(UInt8((v >> 16) & 0xFF))
        data.append(UInt8((v >> 8) & 0xFF))
        data.append(UInt8(v & 0xFF))
    }
}
