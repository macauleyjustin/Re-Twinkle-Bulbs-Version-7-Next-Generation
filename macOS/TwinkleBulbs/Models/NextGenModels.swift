import Foundation

// MARK: - Part I: Holiday Scenes System Models

public enum SceneSeasonCategory: String, CaseIterable, Codable, Identifiable {
    case all = "All Seasons"
    case christmas = "Christmas"
    case winter = "Winter"
    case newYear = "New Year"
    case valentines = "Valentine's"
    case stPatricks = "St. Patrick's"
    case easter = "Easter"
    case spring = "Spring"
    case summer = "Summer"
    case patriotic = "Patriotic"
    case autumn = "Autumn"
    case halloween = "Halloween"
    case thanksgiving = "Thanksgiving"
    case custom = "Custom"

    public var id: String { rawValue }
}

public struct SceneMonitorOverride: Codable, Equatable {
    public var bulbSetName: String?
    public var colorMode: ColorMode?
    public var brightness: Double?
    public var wallpaperID: String?

    public init(bulbSetName: String? = nil, colorMode: ColorMode? = nil, brightness: Double? = nil, wallpaperID: String? = nil) {
        self.bulbSetName = bulbSetName
        self.colorMode = colorMode
        self.brightness = brightness
        self.wallpaperID = wallpaperID
    }
}

public struct HolidayScene: Codable, Equatable, Identifiable {
    public var formatVersion: Int = 1
    public var id: String
    public var name: String
    public var subtitle: String
    public var season: SceneSeasonCategory
    public var isBuiltIn: Bool
    public var isFavorite: Bool

    // Lighting configuration
    public var lightsEnabled: Bool = true
    public var lightingCategory: LightingEngineCategory = .modern
    public var bulbSetName: String = "Outdoor"
    public var bulbSize: BulbSizeOption = .normal
    public var colorMode: ColorMode = .redGreen
    public var flashMode: FlashMode = .chase
    public var rate: FlashRate = .medium
    public var modernEffects: ModernEffectsConfig = ModernEffectsConfig()
    public var customTimelineID: String? = nil
    public var location: BulbLocation = .top
    public var drawMode: DrawMode = .desktop
    public var brightnessMultiplier: Double = 1.0

    // Audio / Screensaver / Wallpaper
    public var musicEnabled: Bool = false
    public var preferredTrackIDs: [String] = []
    public var ssModule: ScreenSaverModuleID = .blank
    public var activeWallpaperID: String = "holiday_bulbs_dark"
    public var wallpaperStyle: WallpaperStyle = .stretch

    // Desktop decorations & optional multi-monitor / external lighting
    public var interactiveEffectsEnabled: Bool = false
    public var perMonitorOverrides: [Int: SceneMonitorOverride] = [:]
    public var externalOutputEnabled: Bool = false

    public init(
        id: String,
        name: String,
        subtitle: String,
        season: SceneSeasonCategory,
        isBuiltIn: Bool = false,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.season = season
        self.isBuiltIn = isBuiltIn
        self.isFavorite = isFavorite
    }
}

public struct SavedSettingsSnapshot: Codable, Equatable {
    public var capturedAt: Date = Date()
    public var appSettings: AppSettings
    public var activeSceneID: String?
    public var activeTimelineID: String?

    public init(appSettings: AppSettings, activeSceneID: String? = nil, activeTimelineID: String? = nil) {
        self.appSettings = appSettings
        self.activeSceneID = activeSceneID
        self.activeTimelineID = activeTimelineID
    }
}

// MARK: - Part II: Seasonal Automation & Countdown Schedule Models

public enum ScheduleRuleKind: String, CaseIterable, Codable, Identifiable {
    case specificDate = "Specific Date"
    case dateRange = "Date Range"
    case weekdays = "Selected Weekdays"
    case dailyTime = "Daily Time Window"
    case annualHoliday = "Recurring Annual Date"
    case solarOffset = "Sunrise / Sunset Relative"

    public var id: String { rawValue }
}

public enum SolarReferenceEvent: String, CaseIterable, Codable {
    case sunrise = "Sunrise"
    case sunset = "Sunset"
}

public struct SeasonalScheduleRule: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    public var name: String
    public var isEnabled: Bool = true
    public var kind: ScheduleRuleKind
    public var sceneID: String
    public var priority: Int = 10 // higher wins conflicts

    // Date matching
    public var startMonth: Int = 12
    public var startDay: Int = 1
    public var endMonth: Int = 12
    public var endDay: Int = 31
    public var specificYear: Int? = nil

    // Weekdays (1=Sun..7=Sat)
    public var weekdays: Set<Int> = []

    // Daily clock minutes from midnight (0..1439)
    public var startMinuteOfDay: Int? = nil
    public var endMinuteOfDay: Int? = nil

    // Solar offset
    public var solarEvent: SolarReferenceEvent = .sunset
    public var solarOffsetMinutes: Int = 0
    public var durationMinutes: Int = 240

    public init(
        id: String = UUID().uuidString,
        name: String,
        isEnabled: Bool = true,
        kind: ScheduleRuleKind,
        sceneID: String,
        priority: Int = 10,
        startMonth: Int = 12,
        startDay: Int = 1,
        endMonth: Int = 12,
        endDay: Int = 31
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.kind = kind
        self.sceneID = sceneID
        self.priority = priority
        self.startMonth = startMonth
        self.startDay = startDay
        self.endMonth = endMonth
        self.endDay = endDay
    }
}

public struct QuietHoursConfig: Codable, Equatable {
    public var enabled: Bool = false
    public var startHour: Int = 22
    public var startMinute: Int = 30
    public var endHour: Int = 7
    public var endMinute: Int = 0
    public var muteMusicDuringQuietHours: Bool = true
    public var dimBrightnessScale: Double = 0.25

    public init() {}
}

public struct CountdownCelebrationEvent: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    public var title: String
    public var month: Int
    public var day: Int
    public var hour: Int = 0
    public var minute: Int = 0
    public var celebrationKind: String = "sparkleBurst" // christmas, newYear, halloween, birthday
    public var showNotification: Bool = true
    public var playSoundEffect: Bool = true
    public var switchScreenSaverTo: ScreenSaverModuleID? = nil
    public var lastTriggeredYear: Int? = nil

    public init(id: String = UUID().uuidString, title: String, month: Int, day: Int, hour: Int = 0, minute: Int = 0, celebrationKind: String = "sparkleBurst") {
        self.id = id
        self.title = title
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.celebrationKind = celebrationKind
    }
}

public struct SeasonalAutomationConfig: Codable, Equatable {
    public var automationEnabled: Bool = false // User MUST explicitly enable!
    public var vacationMode: Bool = false
    public var autoShutdownEnabled: Bool = false
    public var shutdownHour: Int = 23
    public var shutdownMinute: Int = 59
    public var resumeHour: Int = 7
    public var resumeMinute: Int = 0
    public var manualOverrideSceneID: String? = nil
    public var manualOverrideExpiresAt: Date? = nil
    public var locationCityName: String = ""
    public var latitude: Double? = nil
    public var longitude: Double? = nil
    public var quietHours: QuietHoursConfig = QuietHoursConfig()
    public var rules: [SeasonalScheduleRule] = SeasonalAutomationConfig.defaultExampleRules
    public var celebrations: [CountdownCelebrationEvent] = SeasonalAutomationConfig.defaultCelebrations

    public static let defaultExampleRules: [SeasonalScheduleRule] = [
        SeasonalScheduleRule(id: "rule_autumn", name: "Autumn Harvest Season", isEnabled: true, kind: .dateRange, sceneID: "scene:autumn_harvest", priority: 10, startMonth: 10, startDay: 1, endMonth: 10, endDay: 14),
        SeasonalScheduleRule(id: "rule_halloween", name: "Haunted Halloween", isEnabled: true, kind: .dateRange, sceneID: "scene:haunted_halloween", priority: 20, startMonth: 10, startDay: 15, endMonth: 10, endDay: 31),
        SeasonalScheduleRule(id: "rule_thanksgiving", name: "Thanksgiving Warmth", isEnabled: true, kind: .dateRange, sceneID: "scene:thanksgiving", priority: 20, startMonth: 11, startDay: 1, endMonth: 11, endDay: 30),
        SeasonalScheduleRule(id: "rule_christmas", name: "Classic Christmas Season", isEnabled: true, kind: .dateRange, sceneID: "scene:classic_christmas", priority: 30, startMonth: 12, startDay: 1, endMonth: 12, endDay: 23),
        SeasonalScheduleRule(id: "rule_christmas_eve", name: "Christmas Eve & Day Fireplace", isEnabled: true, kind: .dateRange, sceneID: "scene:christmas_fireplace", priority: 40, startMonth: 12, startDay: 24, endMonth: 12, endDay: 25),
        SeasonalScheduleRule(id: "rule_newyear", name: "New Year's Celebration", isEnabled: true, kind: .dateRange, sceneID: "scene:new_years_celebration", priority: 35, startMonth: 12, startDay: 31, endMonth: 1, endDay: 3),
        SeasonalScheduleRule(id: "rule_valentine", name: "Valentine's Romance", isEnabled: true, kind: .dateRange, sceneID: "scene:valentines_romance", priority: 25, startMonth: 2, startDay: 1, endMonth: 2, endDay: 15)
    ]

    public static let defaultCelebrations: [CountdownCelebrationEvent] = [
        CountdownCelebrationEvent(id: "celeb_xmas", title: "Christmas Day Midnight Celebration", month: 12, day: 25, hour: 0, minute: 0, celebrationKind: "christmas"),
        CountdownCelebrationEvent(id: "celeb_ny", title: "New Year's Midnight Celebration", month: 1, day: 1, hour: 0, minute: 0, celebrationKind: "newYear")
    ]

    public init() {}
}

// MARK: - Part III: Lighting Effect Studio Timeline Models (.twinklefx v1)

public enum TimelineCurve: Codable, Equatable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case step
    case cubicBezier(c1x: Double, c1y: Double, c2x: Double, c2y: Double)

    public var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .easeIn: return "Ease In"
        case .easeOut: return "Ease Out"
        case .easeInOut: return "Ease In-Out"
        case .step: return "Step"
        case .cubicBezier: return "Custom Bezier"
        }
    }
}

public enum TimelineEventKind: String, CaseIterable, Codable, Identifiable {
    case setColor = "Set Color"
    case setBrightness = "Set Brightness"
    case startChase = "Start Chase"
    case reverseChase = "Reverse Chase"
    case beginTwinkle = "Begin Twinkle"
    case triggerSparkleBurst = "Trigger Sparkle Burst"
    case fadeIn = "Fade In"
    case fadeOut = "Fade Out"
    case changeEffect = "Change Effect"
    case changeSpeed = "Change Speed"
    case pause = "Pause"
    case `repeat` = "Repeat"
    case triggerOnMIDI = "Trigger on MIDI Event"

    public var id: String { rawValue }
}

public enum TimelineTrackKind: String, CaseIterable, Codable {
    case color
    case brightness
    case speed
    case effects
    case midiTriggers
}

public struct TimelineColorRGB: Codable, Equatable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }
}

public struct TimelineKeyframe: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    public var timeSeconds: Double
    public var eventKind: TimelineEventKind
    public var curve: TimelineCurve = .linear
    public var color: TimelineColorRGB? = nil
    public var value: Double? = nil // brightness / speed / duration scalar
    public var effectID: ModernEffectID? = nil
    public var midiNoteFilter: UInt8? = nil
    public var noteLabel: String = ""

    public init(
        id: String = UUID().uuidString,
        timeSeconds: Double,
        eventKind: TimelineEventKind,
        curve: TimelineCurve = .linear,
        color: TimelineColorRGB? = nil,
        value: Double? = nil,
        effectID: ModernEffectID? = nil,
        midiNoteFilter: UInt8? = nil,
        noteLabel: String = ""
    ) {
        self.id = id
        self.timeSeconds = max(0, timeSeconds)
        self.eventKind = eventKind
        self.curve = curve
        self.color = color
        self.value = value
        self.effectID = effectID
        self.midiNoteFilter = midiNoteFilter
        self.noteLabel = noteLabel
    }
}

public struct TimelineTrack: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    public var name: String
    public var kind: TimelineTrackKind
    public var isMuted: Bool = false
    public var zoneID: String = "main"
    public var keyframes: [TimelineKeyframe] = []

    public init(id: String = UUID().uuidString, name: String, kind: TimelineTrackKind, zoneID: String = "main", keyframes: [TimelineKeyframe] = []) {
        self.id = id
        self.name = name
        self.kind = kind
        self.zoneID = zoneID
        self.keyframes = keyframes
    }
}

public struct TimelineEffectDocument: Codable, Equatable, Identifiable {
    public static let currentFormatVersion = 1

    public var formatVersion: Int = TimelineEffectDocument.currentFormatVersion
    public var id: String = UUID().uuidString
    public var name: String
    public var author: String = "User"
    public var bulbSetID: String = "Outdoor" // Stable identifier (never machine-specific path)
    public var durationSeconds: Double = 12.0
    public var loop: Bool = true
    public var baseSpeed: Double = 1.0
    public var midiSyncTrackID: String? = nil
    public var midiSyncBPMHint: Double? = nil
    public var tracks: [TimelineTrack] = []

    public init(id: String = UUID().uuidString, name: String, bulbSetID: String = "Outdoor", durationSeconds: Double = 12.0, loop: Bool = true, tracks: [TimelineTrack] = []) {
        self.id = id
        self.name = name
        self.bulbSetID = bulbSetID
        self.durationSeconds = max(0.5, durationSeconds)
        self.loop = loop
        self.tracks = tracks
    }
}

// MARK: - Part IV: MIDI Light Show Composer Models

public struct MIDITrackLightMapping: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    public var trackOrChannelIndex: Int // 0..15 channel index
    public var label: String
    public var targetZoneID: String = "main"
    public var mode: MIDIReactiveMode = .velocityBrightness
    public var overrideColor: TimelineColorRGB? = nil
    public var percussionEffect: String = "sparkleBurst" // sparkleBurst, flash, colorFlip

    public init(trackOrChannelIndex: Int, label: String, targetZoneID: String = "main", mode: MIDIReactiveMode = .velocityBrightness, overrideColor: TimelineColorRGB? = nil) {
        self.trackOrChannelIndex = trackOrChannelIndex
        self.label = label
        self.targetZoneID = targetZoneID
        self.mode = mode
        self.overrideColor = overrideColor
    }
}

public struct MIDICueMarker: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    public var timeSeconds: Double
    public var label: String
    public var effectTrigger: TimelineEventKind = .triggerSparkleBurst
    public var color: TimelineColorRGB? = nil

    public init(id: String = UUID().uuidString, timeSeconds: Double, label: String, effectTrigger: TimelineEventKind = .triggerSparkleBurst, color: TimelineColorRGB? = nil) {
        self.id = id
        self.timeSeconds = max(0, timeSeconds)
        self.label = label
        self.effectTrigger = effectTrigger
        self.color = color
    }
}

public struct MIDIShowProject: Codable, Equatable, Identifiable {
    public var formatVersion: Int = 1
    public var id: String = UUID().uuidString
    public var name: String
    public var musicTrackID: String
    public var loopStartSeconds: Double = 0.0
    public var loopEndSeconds: Double? = nil
    public var loopEnabled: Bool = true
    public var audioReactiveFallbackEnabled: Bool = false // Never triggers mic permission unless opted in
    public var channelMappings: [MIDITrackLightMapping] = []
    public var cueMarkers: [MIDICueMarker] = []

    public init(id: String = UUID().uuidString, name: String, musicTrackID: String) {
        self.id = id
        self.name = name
        self.musicTrackID = musicTrackID
    }
}

// MARK: - Part V: Interactive Desktop Decorations Config (Disabled by Default)

public struct InteractiveDesktopConfig: Codable, Equatable {
    public var enabled: Bool = false
    public var mouseProximityGlow: Bool = false
    public var proximityRadiusPx: Double = 110.0
    public var mouseRipple: Bool = false
    public var sparkleTrail: Bool = false
    public var particlePointerInteraction: Bool = false

    public init() {}
}

// MARK: - Part VI: Virtual Lighting Layout Designer Models

public enum VirtualStrandShape: String, CaseIterable, Codable, Identifiable {
    case line = "Straight Strand"
    case roofline = "Roofline Gables"
    case tree = "Christmas Tree"
    case wreath = "Holiday Wreath"
    case window = "Window Outline"
    case door = "Door Frame"
    case porch = "Porch Railing"
    case yard = "Yard Border"
    case custom = "Custom Curve"

    public var id: String { rawValue }
}

public struct VirtualStrandItem: Codable, Equatable, Identifiable {
    public var id: String = UUID().uuidString
    public var name: String
    public var shape: VirtualStrandShape
    public var zoneID: String = "main"
    public var originX: Double // normalized 0...1 canvas coordinate
    public var originY: Double
    public var width: Double
    public var height: Double
    public var rotationDegrees: Double = 0
    public var bulbCount: Int = 24
    public var spacingScale: Double = 1.0
    public var bulbSetID: String = "Outdoor"
    public var assignedEffect: ModernEffectID = .twinklefox
    public var palette: ModernColorPalette = .classicHoliday

    public init(
        id: String = UUID().uuidString,
        name: String,
        shape: VirtualStrandShape,
        zoneID: String = "main",
        originX: Double = 0.2,
        originY: Double = 0.2,
        width: Double = 0.6,
        height: Double = 0.35,
        bulbCount: Int = 24
    ) {
        self.id = id
        self.name = name
        self.shape = shape
        self.zoneID = zoneID
        self.originX = originX
        self.originY = originY
        self.width = max(0.05, width)
        self.height = max(0.05, height)
        self.bulbCount = max(4, min(300, bulbCount))
    }
}

public struct VirtualLayoutDocument: Codable, Equatable, Identifiable {
    public var formatVersion: Int = 1
    public var id: String = UUID().uuidString
    public var name: String
    public var backgroundImageFilename: String? = nil // Stored inside local Application Support/LayoutAssets/
    public var strands: [VirtualStrandItem] = []

    public init(id: String = UUID().uuidString, name: String, strands: [VirtualStrandItem] = []) {
        self.id = id
        self.name = name
        self.strands = strands
    }
}

// MARK: - Part VII–XV: API, Remote, Weather, Time-of-Day, Screen Sync, Packs, Performance, UI

public struct TwinkleAPIConfig: Codable, Equatable {
    public var enabled: Bool = false // Disabled by default
    public var bindLocalhostOnly: Bool = true
    public var allowLANAccess: Bool = false
    public var allowControlCommands: Bool = false
    public var port: UInt16 = 49152
    public var maxFrameRateHz: Int = 30
    public var readOnlyToken: String = TwinkleAPIConfig.generateRandomToken(prefix: "tk_ro_")
    public var controlToken: String = TwinkleAPIConfig.generateRandomToken(prefix: "tk_ctrl_")
    public var webRemoteEnabled: Bool = false
    public var externalHardwareEnabled: Bool = false
    public var electricalSafetyAcknowledged: Bool = false

    public static func generateRandomToken(prefix: String) -> String {
        let raw = (0..<12).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        return prefix + raw
    }

    public init() {}
}

public enum SimulatedWeatherCondition: String, CaseIterable, Codable, Identifiable {
    case none = "Auto / Live (When Enabled)"
    case clearNight = "Clear Winter Night"
    case snow = "Snowfall"
    case rain = "Rainy"
    case windy = "Windy / Gusts"
    case cloudy = "Mild Overcast"

    public var id: String { rawValue }
}

public struct WeatherAtmosphereConfig: Codable, Equatable {
    public var enabled: Bool = false
    public var manualLocationName: String = "North Pole, AK"
    public var latitude: Double = 64.7511
    public var longitude: Double = -147.3494
    public var networkWeatherDisclosedAndAllowed: Bool = false
    public var simulatedOverride: SimulatedWeatherCondition = .none

    public init() {}
}

public struct TimeOfDayConfig: Codable, Equatable {
    public var enabled: Bool = false
    public var morningBrightness: Double = 0.65
    public var afternoonBrightness: Double = 0.85
    public var eveningBrightness: Double = 1.00
    public var nightBrightness: Double = 0.45

    public init() {}
}

public struct ScreenColorSyncConfig: Codable, Equatable {
    public var enabled: Bool = false // NEVER auto-activated at launch
    public var sampleRateHz: Double = 8.0
    public var smoothing: Double = 0.72
    public var brightnessBoost: Double = 1.0
    public var privacyNoticeAccepted: Bool = false

    public init() {}
}

public struct PerformancePolicyConfig: Codable, Equatable {
    public var adaptiveManagementEnabled: Bool = true
    public var throttleOnBattery: Bool = true
    public var throttleUnderHighLoad: Bool = true
    public var highContrastMode: Bool = false

    public init() {}
}

public struct ThemePackManifest: Codable, Equatable {
    public var formatVersion: Int = 1
    public var packageID: String
    public var title: String
    public var author: String
    public var minAppVersion: String = "1.0.6"
    public var license: String = "CC-BY-4.0"
    public var dependencies: [String] = []
    public var contentHashes: [String: String] = [:]
    public var scenes: [HolidayScene] = []
    public var timelines: [TimelineEffectDocument] = []
    public var layouts: [VirtualLayoutDocument] = []

    public init(packageID: String, title: String, author: String) {
        self.packageID = packageID
        self.title = title
        self.author = author
    }
}

public struct NextGenStateContainer: Codable, Equatable {
    public var activeSceneID: String? = nil
    public var favoriteSceneIDs: Set<String> = []
    public var userScenes: [HolidayScene] = []
    public var previousSnapshot: SavedSettingsSnapshot? = nil
    public var automation: SeasonalAutomationConfig = SeasonalAutomationConfig()
    public var timelines: [TimelineEffectDocument] = []
    public var activeTimelineID: String? = nil
    public var midiShows: [MIDIShowProject] = []
    public var activeMIDIShowID: String? = nil
    public var interactive: InteractiveDesktopConfig = InteractiveDesktopConfig()
    public var layouts: [VirtualLayoutDocument] = []
    public var activeLayoutID: String? = nil
    public var apiConfig: TwinkleAPIConfig = TwinkleAPIConfig()
    public var weatherConfig: WeatherAtmosphereConfig = WeatherAtmosphereConfig()
    public var timeOfDay: TimeOfDayConfig = TimeOfDayConfig()
    public var screenSync: ScreenColorSyncConfig = ScreenColorSyncConfig()
    public var performance: PerformancePolicyConfig = PerformancePolicyConfig()
    public var uiMode: Int = 0 // 0=Classic XP UI (Default!), 1=Modern Studio UI

    public init() {}
}
