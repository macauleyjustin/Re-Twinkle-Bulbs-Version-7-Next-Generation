import Foundation
import AVFoundation

public struct MusicTrack: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let url: URL? // nil => clean-room multi-track GM built-in MIDI arrangement
    public let builtInMIDI: Data?
    public let tempoBPM: Double

    public static func == (lhs: MusicTrack, rhs: MusicTrack) -> Bool { lhs.id == rhs.id }
}

/// Clean-room audio service handling UI sound effects (wave_165..388 equivalents)
/// and the restored Twinkle Bulbs programmable MIDI / MP3 / WAV jukebox.
public final class AudioEngineService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = AudioEngineService()

    public enum UIEffect: Int {
        case click = 0      // wave_165 (34ms)
        case softTick = 1   // wave_253 (13ms)
        case altTick = 2    // wave_254 (19ms)
        case menuChime = 9  // wave_166 (31ms)
        case pop = 11       // wave_257 (10ms)
        case celebrate = 12 // wave_388 (307ms)
    }

    public static let supportedExtensions: Set<String> = ["mid", "midi", "rmi", "wav", "mp3", "m4a", "aiff", "aac", "caf"]
    public static let midiExtensions: Set<String> = ["mid", "midi", "rmi"]

    @Published public private(set) var tracks: [MusicTrack] = []
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var currentTrackTitle: String = "Stopped"
    @Published public private(set) var currentTrackFormatInfo: String = ""
    @Published public private(set) var currentTrackIndex: Int = 0
    @Published public private(set) var lastErrorMessage: String? = nil

    public let midiSynth = MIDISynthPlayer()
    public var onMIDINoteEvent: ((MIDILightEvent) -> Void)? {
        didSet {
            midiSynth.onMIDIEvent = onMIDINoteEvent
        }
    }

    private var sfxPlayers: [Int: AVAudioPlayer] = [:]
    private var musicAudioPlayer: AVAudioPlayer?
    private var pauseTimer: Timer?
    private var interTrackDelayWorkItem: DispatchWorkItem?
    private var playHistory: [Int] = []
    private var shufflePlayedIDs: Set<String> = []
    private var activeCustomDirectory: String = ""
    private var consecutiveFailures: Int = 0

    public static var importedMusicDirectory: URL {
        let appSup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSup.appendingPathComponent("TwinkleBulbs/ImportedMusic", isDirectory: true)
    }

    override init() {
        super.init()
        try? FileManager.default.createDirectory(at: Self.importedMusicDirectory, withIntermediateDirectories: true)
        midiSynth.onCompletion = { [weak self] in
            guard let self else { return }
            self.handleTrackCompleted(settings: SettingsStore.shared.settings)
        }
        rebuildTrackList(musicDirectoryPath: SettingsStore.shared.settings.musicDirectoryPath)
        prepareSFXCache()
    }

    public func rebuildTrackList(musicDirectoryPath: String? = nil) {
        let dirPath = musicDirectoryPath ?? SettingsStore.shared.settings.musicDirectoryPath
        activeCustomDirectory = dirPath
        var list: [MusicTrack] = []
        var seenPaths = Set<String>()

        func scanDirectory(_ dirURL: URL, sourceTag: String, recursive: Bool) {
            let fm = FileManager.default
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dirURL.path, isDirectory: &isDir), isDir.boolValue else { return }

            let candidates: [URL]
            if recursive, let enumerator = fm.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) {
                candidates = enumerator.compactMap { $0 as? URL }
            } else {
                candidates = (try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)) ?? []
            }

            for f in candidates.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
                let ext = f.pathExtension.lowercased()
                guard Self.supportedExtensions.contains(ext) else { continue }
                let canonical = f.resolvingSymlinksInPath().standardizedFileURL.path
                guard !seenPaths.contains(canonical) else { continue }
                seenPaths.insert(canonical)
                list.append(MusicTrack(
                    id: "\(sourceTag):\(canonical)",
                    title: f.deletingPathExtension().lastPathComponent,
                    url: f,
                    builtInMIDI: nil,
                    tempoBPM: 120
                ))
            }
        }

        // User-selected music folder (prioritized when configured) + ImportedMusic folder
        let trimmedFolder = dirPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFolder.isEmpty {
            scanDirectory(URL(fileURLWithPath: trimmedFolder), sourceTag: "folder", recursive: true)
        }
        scanDirectory(Self.importedMusicDirectory, sourceTag: "imported", recursive: false)

        // Built-in multi-track, multi-channel GM carol arrangements
        list.append(contentsOf: Self.builtInCarols())
        tracks = list
        if currentTrackIndex >= tracks.count {
            currentTrackIndex = 0
        }
    }

    // MARK: - UI Sound Effects (synthesized WAVs cleanly matching v6.0 SFX durations/characters)

    public func playEffect(_ effect: UIEffect, enabled: Bool) {
        guard enabled else { return }
        if let player = sfxPlayers[effect.rawValue] {
            player.currentTime = 0
            player.play()
        }
    }

    private func prepareSFXCache() {
        let specs: [(Int, Double, Double, Double)] = [
            (UIEffect.click.rawValue, 880, 520, 0.034),
            (UIEffect.softTick.rawValue, 1320, 990, 0.014),
            (UIEffect.altTick.rawValue, 1175, 880, 0.020),
            (UIEffect.menuChime.rawValue, 1046.5, 1318.5, 0.032),
            (UIEffect.pop.rawValue, 660, 440, 0.012),
            (UIEffect.celebrate.rawValue, 1046.5, 1568.0, 0.300)
        ]
        for (tag, f0, f1, dur) in specs {
            let wavData = Self.makeToneWAV(startFreq: f0, endFreq: f1, durationSec: dur, volume: tag == UIEffect.celebrate.rawValue ? 0.35 : 0.22)
            if let p = try? AVAudioPlayer(data: wavData) {
                p.prepareToPlay()
                sfxPlayers[tag] = p
            }
        }
    }

    private static func makeToneWAV(startFreq: Double, endFreq: Double, durationSec: Double, volume: Double) -> Data {
        let rate = 22050
        let count = max(120, Int(Double(rate) * durationSec))
        var pcm = Data(capacity: count * 2)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / Double(count)
            let freq = startFreq + (endFreq - startFreq) * t
            let env = (1.0 - t) * min(1.0, Double(i) / 12.0)
            phase += 2.0 * .pi * freq / Double(rate)
            let sample = (sin(phase) + 0.25 * sin(phase * 2.0)) * env * volume
            let int16 = Int16(max(-32767, min(32767, sample * 32767.0)))
            var le = int16.littleEndian
            pcm.append(Data(bytes: &le, count: 2))
        }
        return wrapPCMAsWAV(pcm: pcm, sampleRate: rate, channels: 1, bitsPerSample: 16)
    }

    public static func wrapPCMAsWAV(pcm: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) -> Data {
        var out = Data()
        let byteRate = UInt32(sampleRate * channels * bitsPerSample / 8)
        let blockAlign = UInt16(channels * bitsPerSample / 8)
        let subchunk2Size = UInt32(pcm.count)
        let chunkSize = UInt32(36 + pcm.count)

        out.append("RIFF".data(using: .ascii)!)
        out.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian, Array.init))
        out.append("WAVEfmt ".data(using: .ascii)!)
        out.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian, Array.init))
        out.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian, Array.init))
        out.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian, Array.init))
        out.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian, Array.init))
        out.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian, Array.init))
        out.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian, Array.init))
        out.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian, Array.init))
        out.append("data".data(using: .ascii)!)
        out.append(contentsOf: withUnsafeBytes(of: subchunk2Size.littleEndian, Array.init))
        out.append(pcm)
        return out
    }

    // MARK: - Holiday Music Jukebox Control

    public func syncWithSettings(_ settings: AppSettings, isScreenSaverActive: Bool) {
        if settings.musicDirectoryPath != activeCustomDirectory {
            rebuildTrackList(musicDirectoryPath: settings.musicDirectoryPath)
        }
        setVolume(settings.musicVolume)

        let shouldPlay = settings.musicEnabled && (!settings.ssMusic || isScreenSaverActive)
        if shouldPlay && !isPlaying && !isPaused {
            if settings.resetMusic {
                playHistory.removeAll()
                shufflePlayedIDs.removeAll()
            }
            play(settings: settings)
        } else if !shouldPlay && (isPlaying || isPaused) {
            stop()
        }
    }

    public func setVolume(_ volume: Double) {
        let clamped = max(0.0, min(1.0, volume))
        midiSynth.volume = clamped
        musicAudioPlayer?.volume = Float(clamped)
    }

    public func play(trackIndex: Int? = nil, settings: AppSettings, recordHistory: Bool = true) {
        cancelInterTrackDelay()
        stopPlaybackOnly()

        let pool = activeTrackIndices(settings: settings)
        guard !pool.isEmpty else {
            lastErrorMessage = "No music tracks available."
            isPlaying = false
            isPaused = false
            return
        }

        let chosenIndex: Int
        if let explicit = trackIndex, explicit >= 0, explicit < tracks.count {
            chosenIndex = explicit
        } else if settings.musicPlayMode == 1 {
            let unplayed = pool.filter { !shufflePlayedIDs.contains(tracks[$0].id) }
            let source = unplayed.isEmpty ? pool : unplayed
            chosenIndex = source.randomElement() ?? pool[0]
        } else if pool.contains(currentTrackIndex) {
            chosenIndex = currentTrackIndex
        } else {
            chosenIndex = pool[0]
        }

        if recordHistory && (!playHistory.isEmpty || isPlaying) && playHistory.last != chosenIndex {
            playHistory.append(chosenIndex)
            if playHistory.count > 100 { playHistory.removeFirst() }
        } else if playHistory.isEmpty {
            playHistory.append(chosenIndex)
        }

        currentTrackIndex = chosenIndex
        let track = tracks[currentTrackIndex]
        shufflePlayedIDs.insert(track.id)
        lastErrorMessage = nil
        midiSynth.volume = settings.musicVolume

        do {
            if let url = track.url {
                let ext = url.pathExtension.lowercased()
                guard FileManager.default.isReadableFile(atPath: url.path) else {
                    throw NSError(domain: "TwinkleBulbsAudio", code: 404, userInfo: [NSLocalizedDescriptionKey: "Missing or unreadable file: \(url.lastPathComponent)"])
                }
                if Self.midiExtensions.contains(ext) {
                    let parsed = try midiSynth.load(url: url, customSoundBankPath: settings.customSoundBankPath)
                    midiSynth.onMIDIEvent = onMIDINoteEvent
                    midiSynth.play()
                    currentTrackTitle = track.title
                    let chCount = parsed.channelsUsed.count
                    currentTrackFormatInfo = "TwinkleSynth GM • SMF Type \(parsed.format) • \(parsed.trackCount) tracks • \(chCount) ch\(parsed.hasPercussion ? " + Drums" : "")"
                } else {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.delegate = self
                    player.isMeteringEnabled = true
                    player.volume = Float(max(0.0, min(1.0, settings.musicVolume)))
                    guard player.play() else {
                        throw NSError(domain: "TwinkleBulbsAudio", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to start audio playback for \(url.lastPathComponent)"])
                    }
                    musicAudioPlayer = player
                    currentTrackTitle = track.title
                    currentTrackFormatInfo = "\(ext.uppercased()) • \(Int(round(player.duration)))s"
                }
            } else if let midiData = track.builtInMIDI {
                let parsed = try midiSynth.load(data: midiData, customSoundBankPath: settings.customSoundBankPath)
                midiSynth.onMIDIEvent = onMIDINoteEvent
                midiSynth.play()
                currentTrackTitle = track.title
                currentTrackFormatInfo = "TwinkleSynth GM • \(parsed.channelsUsed.count) ch + Sleigh Bells"
            } else {
                throw NSError(domain: "TwinkleBulbsAudio", code: 400, userInfo: [NSLocalizedDescriptionKey: "Track has neither URL nor MIDI data."])
            }

            isPlaying = true
            isPaused = false
            consecutiveFailures = 0
            schedulePauseTimerIfNeeded(settings: settings)
        } catch {
            lastErrorMessage = "\(track.title): \(error.localizedDescription)"
            isPlaying = false
            isPaused = false
            currentTrackTitle = "Error: \(track.title)"
            currentTrackFormatInfo = error.localizedDescription
            consecutiveFailures += 1
            if consecutiveFailures < min(3, pool.count) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.playNext(settings: settings)
                }
            }
        }
    }

    public func pause() {
        guard isPlaying, !isPaused else { return }
        if midiSynth.isPlaying {
            midiSynth.pause()
        }
        if let ap = musicAudioPlayer, ap.isPlaying {
            ap.pause()
        }
        isPlaying = false
        isPaused = true
        currentTrackFormatInfo = "Paused"
    }

    public func resume(settings: AppSettings) {
        guard isPaused else {
            if !isPlaying { play(settings: settings) }
            return
        }
        setVolume(settings.musicVolume)
        if midiSynth.isPaused {
            midiSynth.resume()
        } else if let ap = musicAudioPlayer {
            ap.play()
        }
        isPlaying = true
        isPaused = false
        currentTrackFormatInfo = "Resumed"
        schedulePauseTimerIfNeeded(settings: settings)
    }

    public func togglePause(settings: AppSettings) {
        if isPlaying {
            pause()
        } else if isPaused {
            resume(settings: settings)
        } else {
            play(settings: settings)
        }
    }

    public func restartTrack(settings: AppSettings) {
        play(trackIndex: currentTrackIndex, settings: settings, recordHistory: false)
    }

    public func playNext(settings: AppSettings) {
        let pool = activeTrackIndices(settings: settings)
        guard !pool.isEmpty else { return }
        if settings.musicPlayMode == 1 {
            var remaining = pool.filter { !shufflePlayedIDs.contains(tracks[$0].id) }
            if remaining.isEmpty {
                shufflePlayedIDs.removeAll()
                remaining = pool.filter { $0 != currentTrackIndex }
                if remaining.isEmpty { remaining = pool }
            }
            let nextIdx = remaining.randomElement() ?? pool[0]
            play(trackIndex: nextIdx, settings: settings)
        } else if let pos = pool.firstIndex(of: currentTrackIndex) {
            let nextIdx = pool[(pos + 1) % pool.count]
            play(trackIndex: nextIdx, settings: settings)
        } else {
            play(trackIndex: pool[0], settings: settings)
        }
    }

    public func playPrevious(settings: AppSettings) {
        if playHistory.count > 1 {
            _ = playHistory.popLast()
            if let prev = playHistory.last {
                play(trackIndex: prev, settings: settings, recordHistory: false)
                return
            }
        }
        let pool = activeTrackIndices(settings: settings)
        guard !pool.isEmpty else { return }
        if let pos = pool.firstIndex(of: currentTrackIndex) {
            let prevIdx = pool[(pos - 1 + pool.count) % pool.count]
            play(trackIndex: prevIdx, settings: settings, recordHistory: false)
        } else {
            play(trackIndex: pool[0], settings: settings, recordHistory: false)
        }
    }

    public func togglePlayStop(settings: AppSettings) {
        if isPlaying || isPaused {
            stop()
        } else {
            play(settings: settings)
        }
    }

    public func stop() {
        cancelInterTrackDelay()
        stopPlaybackOnly()
        pauseTimer?.invalidate()
        pauseTimer = nil
        isPlaying = false
        isPaused = false
        currentTrackTitle = "Stopped"
        currentTrackFormatInfo = ""
    }

    private func stopPlaybackOnly() {
        midiSynth.stop()
        musicAudioPlayer?.stop()
        musicAudioPlayer = nil
    }

    private func cancelInterTrackDelay() {
        interTrackDelayWorkItem?.cancel()
        interTrackDelayWorkItem = nil
    }

    private func schedulePauseTimerIfNeeded(settings: AppSettings) {
        pauseTimer?.invalidate()
        guard settings.enablePause, settings.pauseMinutes > 0 else { return }
        pauseTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.pauseMinutes * 60), repeats: false) { [weak self] _ in
            self?.stop()
        }
    }

    public func handleTrackCompleted(settings: AppSettings) {
        guard isPlaying else { return }
        let pool = activeTrackIndices(settings: settings)
        guard !pool.isEmpty else {
            stop()
            return
        }

        switch settings.musicRepeatMode {
        case .repeatOne:
            scheduleAfterTrackDelay(settings.musicTrackDelaySeconds) { [weak self] in
                self?.play(trackIndex: self?.currentTrackIndex, settings: settings, recordHistory: false)
            }
        case .stopAfterPlaylist:
            if settings.musicPlayMode == 1 {
                let remaining = pool.filter { !shufflePlayedIDs.contains(tracks[$0].id) }
                if remaining.isEmpty {
                    stop()
                    return
                }
            } else if let pos = pool.firstIndex(of: currentTrackIndex), pos == pool.count - 1 {
                stop()
                return
            }
            scheduleAfterTrackDelay(settings.musicTrackDelaySeconds) { [weak self] in
                self?.playNext(settings: settings)
            }
        case .repeatAll:
            scheduleAfterTrackDelay(settings.musicTrackDelaySeconds) { [weak self] in
                self?.playNext(settings: settings)
            }
        }
    }

    private func scheduleAfterTrackDelay(_ seconds: Double, action: @escaping () -> Void) {
        cancelInterTrackDelay()
        let delay = max(0.0, seconds)
        if delay <= 0.02 {
            action()
            return
        }
        let item = DispatchWorkItem(block: action)
        interTrackDelayWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        handleTrackCompleted(settings: SettingsStore.shared.settings)
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        lastErrorMessage = error?.localizedDescription ?? "Audio decode error"
        handleTrackCompleted(settings: SettingsStore.shared.settings)
    }

    private func activeTrackIndices(settings: AppSettings) -> [Int] {
        guard !tracks.isEmpty else { return [] }
        if settings.enabledTrackIDs.isEmpty {
            return Array(tracks.indices)
        }
        let matching = tracks.indices.filter { settings.enabledTrackIDs.contains(tracks[$0].id) }
        return matching.isEmpty ? Array(tracks.indices) : matching
    }

    /// Authoritative single playback clock & internal output energy (no microphone capture!).
    public func currentPlaybackClockAndEnergy() -> (positionSeconds: Double, durationSeconds: Double, energyLevel: Double, isAudioFilePlayback: Bool) {
        if midiSynth.isPlaying || midiSynth.isPaused || midiSynth.parsedMIDI != nil {
            let dur = midiSynth.parsedMIDI?.durationSeconds ?? 0.0
            let rms = Double(max(0, min(1, midiSynth.synthCore.peakOutputRMS * 2.2)))
            return (midiSynth.currentPositionSeconds, dur, rms, false)
        }
        if let ap = musicAudioPlayer {
            ap.updateMeters()
            let ch0 = Double(ap.averagePower(forChannel: 0))
            // Map -55dB..0dB cleanly onto 0...1
            let lin = max(0.0, min(1.0, (ch0 + 55.0) / 55.0))
            return (ap.currentTime, ap.duration, lin, true)
        }
        return (0.0, 0.0, 0.0, false)
    }

    // MARK: - Clean-Room Multi-Track General MIDI Carol Library

    public static func builtInCarols() -> [MusicTrack] {
        let jingleBells: [(UInt8, Double)] = [
            (64,1),(64,1),(64,2), (64,1),(64,1),(64,2), (64,1),(67,1),(60,1.5),(62,0.5),(64,4),
            (65,1),(65,1),(65,1.5),(65,0.5), (65,1),(64,1),(64,1),(64,0.5),(64,0.5),
            (64,1),(62,1),(62,1),(64,1),(62,2),(67,2),
            (64,1),(64,1),(64,2), (64,1),(64,1),(64,2), (64,1),(67,1),(60,1.5),(62,0.5),(64,4),
            (65,1),(65,1),(65,1.5),(65,0.5), (65,1),(64,1),(64,1),(64,0.5),(64,0.5),
            (67,1),(67,1),(65,1),(62,1),(60,4)
        ]
        let deckTheHalls: [(UInt8, Double)] = [
            (67,1.5),(65,0.5),(64,1),(62,1),(60,1),(62,1),(64,1),(60,1),
            (62,0.5),(64,0.5),(65,0.5),(62,0.5),(64,1.5),(62,0.5),(60,1),(59,1),(60,2),
            (67,1.5),(65,0.5),(64,1),(62,1),(60,1),(62,1),(64,1),(60,1),
            (62,0.5),(64,0.5),(65,0.5),(62,0.5),(64,1.5),(62,0.5),(60,1),(59,1),(60,2)
        ]
        let silentNight: [(UInt8, Double)] = [
            (67,1.5),(69,0.5),(67,1),(64,3), (67,1.5),(69,0.5),(67,1),(64,3),
            (74,2),(74,1),(71,3), (72,2),(72,1),(67,3),
            (69,2),(69,1),(72,1.5),(71,0.5),(69,1), (67,1.5),(69,0.5),(67,1),(64,3),
            (74,2),(74,1),(77,1.5),(74,0.5),(71,1),(72,3),(76,3),
            (72,1.5),(67,0.5),(64,1),(67,1.5),(65,0.5),(62,1),(60,4)
        ]
        let firstNoel: [(UInt8, Double)] = [
            (64,0.5),(62,0.5),(60,1.5),(62,0.5),(64,0.5),(65,0.5),(67,2),
            (69,0.5),(71,0.5),(72,1),(71,1),(69,1),(67,2),
            (69,0.5),(71,0.5),(72,1),(71,1),(69,1),(67,1),(69,1),(71,1),(72,1),(67,1),(65,1),(64,2)
        ]
        let greensleeves: [(UInt8, Double)] = [
            (69,1),(72,2),(74,1),(76,1.5),(77,0.5),(76,1),(74,2),(71,1),(67,1.5),(69,0.5),(71,1),
            (72,2),(69,1),(69,1.5),(68,0.5),(69,1),(71,2),(68,1),(64,3),
            (69,1),(72,2),(74,1),(76,1.5),(77,0.5),(76,1),(74,2),(71,1),(67,1.5),(69,0.5),(71,1),
            (72,1.5),(71,0.5),(69,1),(68,1.5),(66,0.5),(68,1),(69,3)
        ]
        let weWishYou: [(UInt8, Double)] = [
            (62,1),(67,1),(67,0.5),(69,0.5),(67,0.5),(66,0.5),(64,1),(64,1),(64,1),
            (69,1),(69,0.5),(71,0.5),(69,0.5),(67,0.5),(66,1),(62,1),(62,1),
            (71,1),(71,0.5),(72,0.5),(71,0.5),(69,0.5),(67,1),(64,1),(62,0.5),(62,0.5),
            (64,1),(69,1),(66,1),(67,2)
        ]
        let joyToTheWorld: [(UInt8, Double)] = [
            (72,2),(71,1.5),(69,0.5),(67,3),(65,1),(64,2),(62,2),(60,3),(67,1),
            (69,3),(69,1),(71,3),(71,1),(72,3),(72,1),(72,1),(71,1),(69,1),(67,1),
            (67,1.5),(65,0.5),(64,1),(72,1),(72,1),(71,1),(69,1),(67,1),(67,1.5),(65,0.5),(64,1),
            (64,1),(64,1),(64,1),(64,0.5),(65,0.5),(67,3),(65,0.5),(64,0.5),
            (62,1),(62,1),(62,1),(62,0.5),(64,0.5),(65,3),(64,0.5),(62,0.5),
            (60,1),(72,2),(69,1),(67,1.5),(65,0.5),(64,1),(65,1),(64,2),(62,2),(60,3)
        ]
        let littleTown: [(UInt8, Double)] = [
            (64,1),(64,1),(64,1),(63,1),(64,1),(67,1),(65,1),(62,2),(60,1),(62,1),(64,1),(60,1),(64,1),(67,3),
            (64,1),(64,1),(69,1),(67,1),(65,1),(65,1),(64,2),(62,1),(60,1),(62,1),(64,1),(62,1),(64,1),(60,3)
        ]

        let specs: [BuiltInCarolMIDIBuilder.CarolSpec] = [
            .init(id: "builtin:jingle_bells", title: "Jingle Bells (GM)", bpm: 140, melodyProgram: 8, harmonyProgram: 48, bassProgram: 32, includePercussion: true, notes: jingleBells),
            .init(id: "builtin:deck_halls", title: "Deck the Halls (GM)", bpm: 132, melodyProgram: 14, harmonyProgram: 48, bassProgram: 32, includePercussion: true, notes: deckTheHalls),
            .init(id: "builtin:silent_night", title: "Silent Night (GM)", bpm: 92, melodyProgram: 10, harmonyProgram: 89, bassProgram: 43, includePercussion: false, notes: silentNight),
            .init(id: "builtin:first_noel", title: "The First Noel (GM)", bpm: 108, melodyProgram: 68, harmonyProgram: 48, bassProgram: 32, includePercussion: false, notes: firstNoel),
            .init(id: "builtin:greensleeves", title: "Greensleeves (GM)", bpm: 112, melodyProgram: 73, harmonyProgram: 46, bassProgram: 32, includePercussion: false, notes: greensleeves),
            .init(id: "builtin:little_town", title: "O Little Town of Bethlehem (GM)", bpm: 104, melodyProgram: 11, harmonyProgram: 49, bassProgram: 32, includePercussion: false, notes: littleTown),
            .init(id: "builtin:joy_world", title: "Joy to the World (GM)", bpm: 126, melodyProgram: 56, harmonyProgram: 48, bassProgram: 32, includePercussion: true, notes: joyToTheWorld),
            .init(id: "builtin:we_wish", title: "We Wish You a Merry Christmas (GM)", bpm: 136, melodyProgram: 0, harmonyProgram: 48, bassProgram: 32, includePercussion: true, notes: weWishYou)
        ]

        let primary = specs.map { spec in
            MusicTrack(
                id: spec.id,
                title: spec.title,
                url: nil,
                builtInMIDI: BuiltInCarolMIDIBuilder.buildFormat1MIDI(spec: spec),
                tempoBPM: spec.bpm
            )
        }
        return primary + HolidayMusicPack105.expansionTracks()
    }
}
