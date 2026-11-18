import Foundation

// MARK: - Programmable Jukebox Modes (Version 2 MIDI Restoration)

public enum MusicRepeatMode: Int, CaseIterable, Codable, Identifiable {
    case stopAfterPlaylist = 0
    case repeatAll = 1
    case repeatOne = 2

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .stopAfterPlaylist: return "Stop After Playlist"
        case .repeatAll: return "Repeat All"
        case .repeatOne: return "Repeat One"
        }
    }
}

// MARK: - Lighting Category Separation (Classic vs Advanced/Modern)

public enum LightingEngineCategory: Int, CaseIterable, Codable, Identifiable {
    case classic = 0
    case modern = 1

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .classic: return "Original / Classic"
        case .modern: return "Advanced / Modern Effects"
        }
    }
}

// MARK: - 15 Modern Programmable Lighting Effects

public enum ModernEffectID: Int, CaseIterable, Codable, Identifiable {
    case gentleTwinkle = 0
    case twinklefox = 1
    case slowGlow = 2
    case colorWave = 3
    case rainbowChase = 4
    case meteor = 5
    case candleFlicker = 6
    case fireworks = 7
    case glitter = 8
    case ripple = 9
    case candyCane = 10
    case heartbeat = 11
    case scanner = 12
    case softRandomFade = 13
    case autoCycle = 14

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .gentleTwinkle: return "1. Gentle Twinkle"
        case .twinklefox: return "2. Twinklefox"
        case .slowGlow: return "3. Slow Glow"
        case .colorWave: return "4. Color Wave"
        case .rainbowChase: return "5. Rainbow Chase"
        case .meteor: return "6. Meteor"
        case .candleFlicker: return "7. Candle Flicker"
        case .fireworks: return "8. Fireworks"
        case .glitter: return "9. Glitter"
        case .ripple: return "10. Ripple"
        case .candyCane: return "11. Candy Cane"
        case .heartbeat: return "12. Heartbeat"
        case .scanner: return "13. Scanner"
        case .softRandomFade: return "14. Soft Random Fade"
        case .autoCycle: return "15. Combination / Auto Cycle"
        }
    }
}

public enum ModernColorPalette: Int, CaseIterable, Codable, Identifiable {
    case classicHoliday = 0
    case warmWhite = 1
    case coolIce = 2
    case candyCane = 3
    case forestGold = 4
    case royalPurpleGold = 5
    case rainbowSpectrum = 6
    case blueSilver = 7
    case redWhiteBlue = 8

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .classicHoliday: return "Classic Holiday (R/G/Y/B/P)"
        case .warmWhite: return "Warm Incandescent White"
        case .coolIce: return "Cool Ice & Cyan"
        case .candyCane: return "Candy Cane (Red/White)"
        case .forestGold: return "Forest Green & Gold"
        case .royalPurpleGold: return "Royal Purple & Gold"
        case .rainbowSpectrum: return "Full Rainbow Spectrum"
        case .blueSilver: return "Winter Blue & Silver"
        case .redWhiteBlue: return "Patriotic (Red/White/Blue)"
        }
    }

    public var colors: [(r: Double, g: Double, b: Double)] {
        switch self {
        case .classicHoliday:
            return [(0.92, 0.14, 0.14), (0.16, 0.84, 0.18), (0.96, 0.80, 0.12), (0.18, 0.45, 0.96), (0.82, 0.22, 0.86)]
        case .warmWhite:
            return [(1.0, 0.86, 0.62), (1.0, 0.78, 0.48), (0.98, 0.91, 0.74)]
        case .coolIce:
            return [(0.55, 0.88, 1.0), (0.20, 0.72, 1.0), (0.90, 0.97, 1.0)]
        case .candyCane:
            return [(0.95, 0.12, 0.14), (0.98, 0.98, 1.0)]
        case .forestGold:
            return [(0.12, 0.74, 0.22), (0.98, 0.78, 0.16), (0.18, 0.88, 0.34)]
        case .royalPurpleGold:
            return [(0.68, 0.18, 0.92), (0.98, 0.78, 0.14), (0.86, 0.35, 0.98)]
        case .rainbowSpectrum:
            return [
                (1.0, 0.15, 0.15), (1.0, 0.55, 0.10), (0.96, 0.90, 0.12),
                (0.18, 0.88, 0.25), (0.15, 0.82, 0.92), (0.24, 0.42, 0.98), (0.78, 0.24, 0.96)
            ]
        case .blueSilver:
            return [(0.20, 0.48, 0.98), (0.88, 0.93, 1.0), (0.35, 0.78, 1.0)]
        case .redWhiteBlue:
            return [(0.94, 0.14, 0.18), (0.96, 0.96, 1.0), (0.18, 0.42, 0.96)]
        }
    }
}

public enum MIDIReactiveMode: Int, CaseIterable, Codable, Identifiable {
    case beatPulse = 0
    case notePerBulb = 1
    case channelColors = 2
    case velocityBrightness = 3
    case tempoSyncChase = 4
    case instrumentMapping = 5
    case percussionEffects = 6

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .beatPulse: return "Beat Pulse"
        case .notePerBulb: return "Notes Along Strand"
        case .channelColors: return "Channel Colors"
        case .velocityBrightness: return "Velocity Brightness"
        case .tempoSyncChase: return "Tempo-Synced Chase"
        case .instrumentMapping: return "Instrument Mapping"
        case .percussionEffects: return "Percussion Effects"
        }
    }
}

public struct ModernEffectsConfig: Codable, Equatable {
    public var effect: ModernEffectID = .twinklefox
    public var speed: Double = 1.0              // 0.1 ... 3.0
    public var brightness: Double = 1.0         // 0.1 ... 1.0
    public var smoothness: Double = 0.75        // 0.0 ... 1.0
    public var palette: ModernColorPalette = .classicHoliday
    public var reverseDirection: Bool = false
    public var staggered: Bool = true
    public var wavelengthOrWidth: Double = 6.0  // 2 ... 24 bulbs
    public var intensityOrDensity: Double = 0.5 // 0.1 ... 1.0
    public var randomizeSeeds: Bool = false
    public var seed: UInt64 = 20251225

    // Auto-Cycle / Combination Settings
    public var cycleIntervalSeconds: Double = 15.0
    public var cycleRandomOrder: Bool = false
    public var cycleCrossfade: Bool = true
    public var cycleFavorites: [ModernEffectID] = ModernEffectID.allCases.filter { $0 != .autoCycle }

    // Optional Per-Monitor Override & MIDI-Reactive Modes
    public var perMonitorPhaseOffset: Bool = false
    public var midiReactiveEnabled: Bool = false
    public var midiReactiveMode: MIDIReactiveMode = .velocityBrightness
    public var midiSensitivity: Double = 1.0

    public init() {}
}
