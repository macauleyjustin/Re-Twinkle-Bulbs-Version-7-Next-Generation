import Foundation
import CoreGraphics

// MARK: - Part IV: MIDI Light Show Composer Engine (Single-Clock Authoritative Sync)

public final class MIDILightShowComposer {
    public static let shared = MIDILightShowComposer()

    public private(set) var activeProject: MIDIShowProject
    private var lastObservedClockSeconds: Double = -1.0
    private var firedCueIDs: Set<String> = []
    private var channelPrograms: [UInt8: UInt8] = [:]

    public var onCueTriggered: ((MIDICueMarker) -> Void)?

    public init(project: MIDIShowProject? = nil) {
        self.activeProject = project ?? Self.defaultProject(forTrackID: "builtin:jingle_bells", name: "Jingle Bells Light Show")
    }

    public func setActiveProject(_ project: MIDIShowProject) {
        self.activeProject = project
        resetSyncState()
    }

    public func resetSyncState() {
        lastObservedClockSeconds = -1.0
        firedCueIDs.removeAll()
    }

    public func recordProgramChange(channel: UInt8, program: UInt8) {
        channelPrograms[channel] = program
    }

    /// Evaluates cue markers strictly from the audio engine's single authoritative clock.
    public func synchronizeWithAudioClock(positionSeconds: Double) -> [MIDICueMarker] {
        // Detect rewind/loop cleanly so markers re-arm accurately
        if positionSeconds + 0.05 < lastObservedClockSeconds {
            firedCueIDs.removeAll()
            lastObservedClockSeconds = -1.0
        }
        var newlyFired: [MIDICueMarker] = []
        for cue in activeProject.cueMarkers.sorted(by: { $0.timeSeconds < $1.timeSeconds }) {
            if !firedCueIDs.contains(cue.id) &&
               positionSeconds >= cue.timeSeconds &&
               (lastObservedClockSeconds < cue.timeSeconds || lastObservedClockSeconds < 0) {
                firedCueIDs.insert(cue.id)
                newlyFired.append(cue)
                onCueTriggered?(cue)
            }
        }
        lastObservedClockSeconds = positionSeconds
        return newlyFired
    }

    /// Routes live MIDI note/percussion events through project channel mappings cleanly.
    public func dispatchMIDIEvent(_ evt: MIDILightEvent, to engine: ModernLightingEngine) {
        let project = activeProject
        var mappedEvent = evt

        if let map = project.channelMappings.first(where: { $0.trackOrChannelIndex == Int(evt.channel) }) {
            // Apply percussion accent boost if Ch 9 (percussion) or explicit percussion mapping
            if (evt.channel == 9 || map.mode == .percussionEffects) && evt.isNoteOn && evt.velocity > 0 {
                mappedEvent = MIDILightEvent(
                    channel: 9,
                    note: evt.note,
                    velocity: min(127, UInt8(min(127, Int(evt.velocity) + 25))),
                    isNoteOn: true,
                    currentBPM: evt.currentBPM,
                    positionSeconds: evt.positionSeconds
                )
            }
        }
        engine.handleMIDIEvent(mappedEvent)
    }

    /// Opt-in internal PCM buffer energy analyzer for non-MIDI MP3/WAV playback (no mic capture!).
    public func applyAudioBufferEnergyIfEnabled(energyLevel: Double, isAudioFilePlayback: Bool, to engine: ModernLightingEngine) {
        guard activeProject.audioReactiveFallbackEnabled, isAudioFilePlayback, energyLevel > 0.05 else { return }
        let synthVel = UInt8(max(1, min(127, Int(energyLevel * 127.0))))
        let pseudoNote = UInt8(48 + (Int(energyLevel * 36.0) % 36))
        let evt = MIDILightEvent(
            channel: energyLevel > 0.72 ? 9 : 0,
            note: pseudoNote,
            velocity: synthVel,
            isNoteOn: true,
            currentBPM: 120.0,
            positionSeconds: lastObservedClockSeconds
        )
        engine.handleMIDIEvent(evt)
    }

    // MARK: - GM Instrument Color Mapping

    public static func gmInstrumentFamily(forProgram program: UInt8) -> String {
        switch program {
        case 0...7: return "Piano"
        case 8...15: return "Chromatic Bells & Mallet"
        case 16...23: return "Organ"
        case 24...31: return "Guitar"
        case 32...39: return "Bass"
        case 40...47: return "Strings"
        case 48...55: return "Ensemble / Choir"
        case 56...63: return "Brass"
        case 64...71: return "Reed"
        case 72...79: return "Flute & Pipe"
        case 80...95: return "Synth Lead / Pad"
        default: return "Special / FX"
        }
    }

    // MARK: - Presets & Serialization (.twinklemidi)

    public static func defaultProject(forTrackID trackID: String, name: String) -> MIDIShowProject {
        var proj = MIDIShowProject(name: name, musicTrackID: trackID)
        proj.channelMappings = [
            MIDITrackLightMapping(trackOrChannelIndex: 0, label: "Ch 1 — Main Melody (Bells/Piano)", targetZoneID: "main", mode: .notePerBulb, overrideColor: TimelineColorRGB(r: 1.0, g: 0.85, b: 0.25)),
            MIDITrackLightMapping(trackOrChannelIndex: 1, label: "Ch 2 — Strings & Harmony", targetZoneID: "roofline", mode: .channelColors, overrideColor: TimelineColorRGB(r: 0.20, g: 0.88, b: 0.35)),
            MIDITrackLightMapping(trackOrChannelIndex: 2, label: "Ch 3 — Warm Bass Pulse", targetZoneID: "yard", mode: .beatPulse, overrideColor: TimelineColorRGB(r: 0.92, g: 0.16, b: 0.20)),
            MIDITrackLightMapping(trackOrChannelIndex: 9, label: "Ch 10 — Sleigh Bells & Percussion", targetZoneID: "tree", mode: .percussionEffects, overrideColor: TimelineColorRGB(r: 1.0, g: 0.98, b: 0.92))
        ]
        proj.cueMarkers = [
            MIDICueMarker(timeSeconds: 2.0, label: "Intro Sparkle Burst", effectTrigger: .triggerSparkleBurst),
            MIDICueMarker(timeSeconds: 6.0, label: "Chorus Chase Accent", effectTrigger: .startChase),
            MIDICueMarker(timeSeconds: 10.0, label: "Reverse Cascade", effectTrigger: .reverseChase)
        ]
        return proj
    }

    public static func exportShow(_ project: MIDIShowProject) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(project)
    }

    public static func importShow(data: Data) throws -> MIDIShowProject {
        try JSONDecoder().decode(MIDIShowProject.self, from: data)
    }
}
