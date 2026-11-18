import Foundation
import AppKit

// MARK: - Core Enums Matching Twinkle Bulbs v6.0 Binary IDs

public enum FlashMode: Int, CaseIterable, Codable, Identifiable {
    case none = 0
    case random = 1
    case allTogether = 2
    case chase = 3
    case alternating = 4
    case someFlash = 5
    case single = 6
    case pairs = 7
    case pingPong = 8

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "None (Always On)"
        case .random: return "Random"
        case .allTogether: return "All Together"
        case .chase: return "Chase"
        case .alternating: return "Alternating"
        case .someFlash: return "Some Bulbs Flash"
        case .single: return "Single"
        case .pairs: return "Pairs"
        case .pingPong: return "Ping-Pong"
        }
    }
}

public enum FlashRate: Int, CaseIterable, Codable, Identifiable {
    case slow = 0
    case slowMedium = 1
    case medium = 2
    case mediumFast = 3
    case fast = 4
    case veryFast = 5

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .slow: return "Slow"
        case .slowMedium: return "Slow / Medium"
        case .medium: return "Medium"
        case .mediumFast: return "Medium / Fast"
        case .fast: return "Fast"
        case .veryFast: return "Very Fast"
        }
    }

    /// Exact fixed-pattern interval in milliseconds from tbulbs.mem @ 0x00484fd0
    public var fixedIntervalMs: UInt64 {
        switch self {
        case .slow: return 1200
        case .slowMedium: return 800
        case .medium: return 500
        case .mediumFast: return 350
        case .fast: return 200
        case .veryFast: return 80
        }
    }

    /// Exact random-bulb hold duration range (minMs, inclusiveRandomSpan) from tbulbs.mem @ 0x00485260
    public var randomHoldRangeMs: (min: UInt64, span: UInt64) {
        switch self {
        case .slow: return (2000, 701)       // 2000..2700 ms
        case .slowMedium: return (1600, 601) // 1600..2200 ms
        case .medium: return (1000, 601)     // 1000..1600 ms
        case .mediumFast: return (600, 401)  // 600..1000 ms
        case .fast: return (150, 301)        // 150..450 ms
        case .veryFast: return (50, 71)      // 50..120 ms
        }
    }
}

public enum ColorMode: Int, CaseIterable, Codable, Identifiable {
    case random = 0
    case purple = 1
    case blue = 2
    case red = 3
    case green = 4
    case yellow = 5
    case lightBlue = 6
    case white = 7
    case redGreen = 8
    case multiColor = 9
    case blues = 10
    case allColorsWhite = 11
    case redBlue = 12
    case purpleGreen = 13
    case redYellowGreen = 14
    case redGreenBlue = 15
    case coolColors = 16
    case yellowWhite = 17
    case redYellow = 18
    case redGreenYellowBlue = 19
    case redWhiteBlue = 20

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .random: return "Random"
        case .purple: return "Purple"
        case .blue: return "Blue"
        case .red: return "Red"
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .lightBlue: return "Light Blue"
        case .white: return "White"
        case .redGreen: return "Red / Green"
        case .multiColor: return "Multi-Color"
        case .blues: return "Blues"
        case .allColorsWhite: return "All Colors (+ White)"
        case .redBlue: return "Red / Blue"
        case .purpleGreen: return "Purple / Green"
        case .redYellowGreen: return "Red / Yellow / Green"
        case .redGreenBlue: return "Red / Green / Blue"
        case .coolColors: return "Cool Colors"
        case .yellowWhite: return "Yellow / White"
        case .redYellow: return "Red / Yellow"
        case .redGreenYellowBlue: return "Red / Green / Yellow / Blue"
        case .redWhiteBlue: return "Red / White / Blue"
        }
    }
}

public enum BulbColorSlot: Int, CaseIterable, Codable {
    case purple = 0
    case blue = 1
    case red = 2
    case green = 3
    case yellow = 4
    case lightBlue = 5
    case white = 6
}

public enum DrawMode: Int, CaseIterable, Codable, Identifiable {
    case desktop = 0
    case alwaysOnTop = 1
    case menuBarTaskbar = 2

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .desktop: return "On the Desktop"
        case .alwaysOnTop: return "Always On Top"
        case .menuBarTaskbar: return "Menu Bar / Taskbar"
        }
    }
}

public enum BulbLocation: Int, CaseIterable, Codable, Identifiable {
    case top = 0
    case topAndBottom = 1
    case aroundScreen = 2
    case sidesOnly = 3
    case topAndSides = 4
    case bottomOnly = 5

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .top: return "Top"
        case .topAndBottom: return "Top and Bottom"
        case .aroundScreen: return "Around Screen"
        case .sidesOnly: return "Sides Only"
        case .topAndSides: return "Top and Sides"
        case .bottomOnly: return "Bottom Only"
        }
    }
}

public enum BulbEdge: Int, Codable {
    case top = 0
    case bottom = 1
    case left = 2
    case right = 3

    /// Rotation degrees matching RotateIcon() @ 0x0043de50 when Draw Inward is enabled
    public func inwardRotationDegrees(inward: Bool) -> Int {
        guard inward else { return 0 }
        switch self {
        case .top: return 0
        case .bottom: return 180
        case .left: return -90
        case .right: return 90
        }
    }
}

public enum BulbSizeOption: Int, CaseIterable, Codable, Identifiable {
    case normal = 0 // 32 px
    case large = 1  // 48 px

    public var id: Int { rawValue }

    public var pixels: Int {
        self == .large ? 48 : 32
    }

    public var displayName: String {
        self == .large ? "Large (48×48)" : "Normal (32×32)"
    }
}

public enum TrayClickAction: Int, CaseIterable, Codable, Identifiable {
    case popupMenu = 0
    case configuration = 1
    case toggleMusic = 2
    case exitProgram = 3
    case playNextMusic = 4
    case startScreenSaver = 5
    case viewCalendar = 6

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .popupMenu: return "Popup Menu"
        case .configuration: return "Settings..."
        case .toggleMusic: return "Toggle Music"
        case .exitProgram: return "Exit Program"
        case .playNextMusic: return "Play Next Music"
        case .startScreenSaver: return "Start Screen Saver"
        case .viewCalendar: return "View Calendar"
        }
    }
}

public enum ScreenSaverModuleID: String, CaseIterable, Codable, Identifiable {
    // 4 Original Twinkle Bulbs v6.0 Classic Screen Savers
    case blank = "blank"
    case clock = "clock"
    case fireworks = "fireworks"
    case snowfall = "snowfall"

    // Documented Historical CD Slideshow Module
    case wallpaperSlideshow = "wallpaper_slideshow"

    // 20 New Complete Holiday Edition Seasonal Screen Savers
    case twinklingWreath = "twinkling_wreath"
    case christmasTreeGlow = "christmas_tree_glow"
    case snowfallVillage = "snowfall_village"
    case fireplaceChristmas = "fireplace_christmas"
    case winterFrost = "winter_frost"
    case gingerbreadVillage = "gingerbread_village"
    case fallingAutumnLeaves = "falling_autumn_leaves"
    case glowingPumpkin = "glowing_pumpkin"
    case hauntedHouse = "haunted_house"
    case autumnForest = "autumn_forest"
    case harvestPumpkinPatch = "harvest_pumpkin_patch"
    case springBlossoms = "spring_blossoms"
    case springRain = "spring_rain"
    case easterGarden = "easter_garden"
    case summerFireflies = "summer_fireflies"
    case summerNightSky = "summer_night_sky"
    case beachSunset = "beach_sunset"
    case valentineHearts = "valentine_hearts"
    case newYearsCelebration = "new_years_celebration"
    case patrioticCelebration = "patriotic_celebration"

    public var id: String { rawValue }

    public var isClassicModule: Bool {
        switch self {
        case .blank, .clock, .fireworks, .snowfall: return true
        default: return false
        }
    }

    public static var seasonal20Modules: [ScreenSaverModuleID] {
        allCases.filter { !$0.isClassicModule && $0 != .wallpaperSlideshow }
    }

    public var displayName: String {
        switch self {
        case .blank: return "Blank Screen (Classic)"
        case .clock: return "Clock (Classic)"
        case .fireworks: return "Fireworks (Classic)"
        case .snowfall: return "Snowfall (Classic)"
        case .wallpaperSlideshow: return "Wallpaper Slideshow (CD)"
        case .twinklingWreath: return "1. Twinkling Christmas Wreath"
        case .christmasTreeGlow: return "2. Christmas Tree Glow"
        case .snowfallVillage: return "3. Snowfall Village"
        case .fireplaceChristmas: return "4. Fireplace Christmas"
        case .winterFrost: return "5. Winter Frost"
        case .gingerbreadVillage: return "6. Gingerbread Village"
        case .fallingAutumnLeaves: return "7. Falling Autumn Leaves"
        case .glowingPumpkin: return "8. Glowing Halloween Pumpkin"
        case .hauntedHouse: return "9. Haunted House"
        case .autumnForest: return "10. Autumn Forest"
        case .harvestPumpkinPatch: return "11. Harvest Pumpkin Patch"
        case .springBlossoms: return "12. Spring Blossoms"
        case .springRain: return "13. Spring Rain"
        case .easterGarden: return "14. Easter Garden"
        case .summerFireflies: return "15. Summer Fireflies"
        case .summerNightSky: return "16. Summer Night Sky"
        case .beachSunset: return "17. Beach Sunset"
        case .valentineHearts: return "18. Valentine's Hearts"
        case .newYearsCelebration: return "19. New Year's Celebration"
        case .patrioticCelebration: return "20. Patriotic Celebration"
        }
    }
}

public enum WallpaperStyle: Int, CaseIterable, Codable, Identifiable {
    case tile = 0
    case center = 1
    case stretch = 2
    case fit = 3

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .tile: return "Tile"
        case .center: return "Center"
        case .stretch: return "Stretch"
        case .fit: return "Fit"
        }
    }
}

public enum HolidayCountdownType: Int, CaseIterable, Codable, Identifiable {
    case none = 0
    case christmas = 1
    case thanksgiving = 2
    case hanukkah = 3
    case valentinesDay = 4
    case halloween = 5
    case independenceDay = 6
    case stPatricksDay = 7
    case newYearsDay = 8
    case custom = 9

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "(None)"
        case .christmas: return "Christmas"
        case .thanksgiving: return "Thanksgiving"
        case .hanukkah: return "Hanukkah"
        case .valentinesDay: return "Valentine's Day"
        case .halloween: return "Halloween"
        case .independenceDay: return "Independence Day"
        case .stPatricksDay: return "St. Patrick's Day"
        case .newYearsDay: return "New Year's Day"
        case .custom: return "Custom Date..."
        }
    }
}

public struct CalendarEventItem: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var title: String
    public var month: Int
    public var day: Int
    public var message: String
    public var enabled: Bool = true
}

public struct ClockSaverConfig: Codable, Equatable {
    public var showSeconds: Bool = true
    public var use24Hour: Bool = false
    public var showDate: Bool = true
    public var bouncePosition: Bool = true
    public var textColorHex: String = "#33FF66"
    public var fontSize: Double = 64
    public var fontName: String = "Helvetica Bold"
}

public struct FireworksSaverConfig: Codable, Equatable {
    public var maxRockets: Int = 5
    public var particlesPerBurst: Int = 48
    public var trailLength: Int = 8
    public var soundEnabled: Bool = true
    public var showSkyline: Bool = true
}

public struct SnowfallSaverConfig: Codable, Equatable {
    public var flakeCount: Int = 120
    public var windEnabled: Bool = true
    public var blizzardMode: Bool = false
    public var accumulateSnow: Bool = true
    public var showTreeAndSnowman: Bool = true
    public var showSanta: Bool = true
}

// MARK: - Complete Settings Struct

public struct AppSettings: Codable, Equatable {
    // General (DIALOG/139)
    public var lightsEnabled: Bool = true
    public var trayIconIndex: Int = 0
    public var trayLeftClick: TrayClickAction = .configuration
    public var trayRightClick: TrayClickAction = .popupMenu
    public var trayMiddleClick: TrayClickAction = .popupMenu
    public var splashScreen: Bool = true
    public var toolTips: Bool = true
    public var warningMsgs: Bool = true
    public var cpuPriority: Int = 2
    public var confirmExit: Bool = true
    public var startupOptions: Bool = false
    public var startupCalendar: Bool = false
    public var runSSOnly: Bool = false
    public var soundFX: Bool = true
    public var bulbGen: Bool = false
    public var flashIcon: Bool = false
    public var zoom: Bool = false
    public var quickAccess: Bool = false
    public var enhancedMenu: Bool = true
    public var detectBulbChanges: Bool = false
    public var sysColorHighlight: Bool = true
    public var highlightColorHex: String = "#000080" // Classic COLOR_HIGHLIGHT navy
    public var lastTipIndex: Int = 0
    public var showTipsOnStartup: Bool = false

    // Bulbs (DIALOG/131)
    public var bulbSetName: String = "Outdoor"
    public var flashMode: FlashMode = .chase
    public var rate: FlashRate = .medium
    public var colorMode: ColorMode = .redGreen
    public var drawMode: DrawMode = .desktop
    public var transparency: Bool = false
    public var location: BulbLocation = .top
    public var bulbSize: BulbSizeOption = .normal
    public var bareWire: Bool = true
    public var noCorners: Bool = true
    public var notSoMany: Bool = true
    public var broken: Bool = false
    public var burnedOut: Bool = false
    public var missing: Bool = false
    public var mixBulbs: Bool = false
    public var mixedSetNames: [String] = ["Outdoor", "Normal", "Large"]
    public var randomProperties: Bool = false
    public var reverse: Bool = false
    public var inward: Bool = false
    public var noFlicker: Bool = true
    public var useAllMonitors: Bool = false
    public var drawMonitorIndex: Int = 0
    public var bulbChanger: Bool = false
    public var bulbChangeOrder: Int = 0 // 0=Sequential, 1=Random
    public var bulbChangeFreqMinutes: Int = 30

    // Music (DIALOG/133)
    public var musicEnabled: Bool = false
    public var enablePause: Bool = false
    public var pauseMinutes: Int = 10
    public var resetMusic: Bool = true
    public var ssMusic: Bool = false
    public var musicPlayMode: Int = 0 // 0=Sequential, 1=Random
    public var enabledTrackIDs: [String] = []

    // Version 2 Music & Lighting Extensions (Optional backing keeps v1 JSON 100% backward-compatible)
    private var v2MusicRepeatMode: MusicRepeatMode? = nil
    private var v2MusicTrackDelaySeconds: Double? = nil
    private var v2MusicVolume: Double? = nil
    private var v2MusicDirectoryPath: String? = nil
    private var v2CustomSoundBankPath: String? = nil
    private var v2LightingCategory: LightingEngineCategory? = nil
    private var v2ModernEffects: ModernEffectsConfig? = nil

    public var musicRepeatMode: MusicRepeatMode {
        get { v2MusicRepeatMode ?? .repeatAll }
        set { v2MusicRepeatMode = newValue }
    }
    public var musicTrackDelaySeconds: Double {
        get { v2MusicTrackDelaySeconds ?? 0.5 }
        set { v2MusicTrackDelaySeconds = max(0.0, min(15.0, newValue)) }
    }
    public var musicVolume: Double {
        get { v2MusicVolume ?? 0.85 }
        set { v2MusicVolume = max(0.0, min(1.0, newValue)) }
    }
    public var musicDirectoryPath: String {
        get { v2MusicDirectoryPath ?? "" }
        set { v2MusicDirectoryPath = newValue }
    }
    public var customSoundBankPath: String {
        get { v2CustomSoundBankPath ?? "" }
        set { v2CustomSoundBankPath = newValue }
    }
    public var lightingCategory: LightingEngineCategory {
        get { v2LightingCategory ?? .classic }
        set { v2LightingCategory = newValue }
    }
    public var modernEffects: ModernEffectsConfig {
        get { v2ModernEffects ?? ModernEffectsConfig() }
        set { v2ModernEffects = newValue }
    }

    // Complete Holiday Edition Extensions (Optional backing preserves v1/v2 JSON compatibility)
    private var v3SeasonalSSConfig: SeasonalScreenSaverConfig? = nil
    private var v3OpenedAdventDoors: [Int]? = nil
    private var v3AdventPreviewAnyDate: Bool? = nil
    private var v3FavoriteBulbSetIDs: [String]? = nil
    private var v3RecentBulbSetIDs: [String]? = nil
    private var v3FavoriteWallpaperIDs: [String]? = nil
    private var v3ReduceMotion: Bool? = nil

    public var seasonalSSConfig: SeasonalScreenSaverConfig {
        get { v3SeasonalSSConfig ?? SeasonalScreenSaverConfig() }
        set { v3SeasonalSSConfig = newValue }
    }
    public var openedAdventDoors: Set<Int> {
        get { Set(v3OpenedAdventDoors ?? []) }
        set { v3OpenedAdventDoors = Array(newValue).sorted() }
    }
    public var adventAllowAnyDatePreview: Bool {
        get { v3AdventPreviewAnyDate ?? false }
        set { v3AdventPreviewAnyDate = newValue }
    }
    public var favoriteBulbSetIDs: [String] {
        get { v3FavoriteBulbSetIDs ?? [] }
        set { v3FavoriteBulbSetIDs = newValue }
    }
    public var recentBulbSetIDs: [String] {
        get { v3RecentBulbSetIDs ?? [] }
        set { v3RecentBulbSetIDs = Array(newValue.prefix(20)) }
    }
    public var favoriteWallpaperIDs: [String] {
        get { v3FavoriteWallpaperIDs ?? [] }
        set { v3FavoriteWallpaperIDs = newValue }
    }
    public var reduceMotion: Bool {
        get { v3ReduceMotion ?? false }
        set { v3ReduceMotion = newValue }
    }

    // Screen Saver (DIALOG/134)
    public var ssModule: ScreenSaverModuleID = .blank
    public var ssEnable: Bool = false
    public var ssDelayMinutes: Int = 10
    public var ssLights: Bool = true
    public var keyLights: Bool = false
    public var ssMusicOnly: Bool = false
    public var ssLogo: Bool = true
    public var ssUsePassword: Bool = false
    public var ssMsgColorHex: String = "#FF0000"
    public var ssMsgSize: Double = 14
    public var ssMsgFont: String = "Arial"
    public var ssMsgBold: Bool = true
    public var ssMouseClick: Bool = true
    public var ssMouseMove: Bool = true
    public var ssMouseWheel: Bool = true
    public var ssKeyboard: Bool = true
    public var ssEnableMsg: Bool = true
    public var ssClearTime: Bool = false
    public var ssScrollMsg: Bool = false
    public var ssBottomTextAboveBulbs: Bool = false
    public var ssMsg: String = "YOUR MESSAGE HERE"
    public var useHotCorners: Bool = false
    public var hotCornerTopLeft: Bool = false
    public var hotCornerTopRight: Bool = true
    public var hotCornerBottomLeft: Bool = false
    public var hotCornerBottomRight: Bool = false
    public var clockConfig: ClockSaverConfig = ClockSaverConfig()
    public var fireworksConfig: FireworksSaverConfig = FireworksSaverConfig()
    public var snowfallConfig: SnowfallSaverConfig = SnowfallSaverConfig()

    // Wallpaper (DIALOG/135)
    public var wallpaperType: WallpaperStyle = .tile
    public var wallpaperChangeFreqMinutes: Int = 60
    public var wallpaperChangeOrder: Int = 0
    public var wallpaperChangeFlag: Bool = false
    public var wallpaperPreview: Bool = true
    public var activeWallpaperID: String = "holiday_bulbs_dark"

    // Calendar (DIALOG/132)
    public var eventMsgs: Bool = true
    public var countdownHoliday: HolidayCountdownType = .christmas
    public var customHolidayMonth: Int = 12
    public var customHolidayDay: Int = 25
    public var customHolidayName: String = "Special Day"
    public var calendarEvents: [CalendarEventItem] = AppSettings.defaultCalendarEvents

    public static let defaultCalendarEvents: [CalendarEventItem] = [
        CalendarEventItem(title: "New Year's Day", month: 1, day: 1, message: "Happy New Year!"),
        CalendarEventItem(title: "Valentine's Day", month: 2, day: 14, message: "Happy Valentine's Day!"),
        CalendarEventItem(title: "St. Patrick's Day", month: 3, day: 17, message: "Happy St. Patrick's Day!"),
        CalendarEventItem(title: "Independence Day", month: 7, day: 4, message: "Happy 4th of July!"),
        CalendarEventItem(title: "Halloween", month: 10, day: 31, message: "Happy Halloween!"),
        CalendarEventItem(title: "Christmas Eve", month: 12, day: 24, message: "Merry Christmas Eve!"),
        CalendarEventItem(title: "Christmas Day", month: 12, day: 25, message: "Merry Christmas from Twinkle Bulbs!"),
        CalendarEventItem(title: "New Year's Eve", month: 12, day: 31, message: "Happy New Year's Eve!")
    ]

    public init() {}

    public static func defaultSettings() -> AppSettings {
        AppSettings()
    }
}

// MARK: - Persistence Store

public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()
    private static let defaultsKey = "com.twinklebulbs.mac.v6.settings"

    @Published public var settings: AppSettings {
        didSet { save() }
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings.defaultSettings()
        }
    }

    private let userDefaults: UserDefaults

    public func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: Self.defaultsKey)
        }
    }

    public func resetToDefaults() {
        settings = AppSettings.defaultSettings()
    }
}

// MARK: - Color Hex Helpers

extension NSColor {
    convenience init(hex: String, fallback: NSColor = .red) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&int) else {
            self.init(cgColor: fallback.cgColor)!
            return
        }
        let r, g, b: CGFloat
        if cleaned.count == 6 {
            r = CGFloat((int >> 16) & 0xFF) / 255.0
            g = CGFloat((int >> 8) & 0xFF) / 255.0
            b = CGFloat(int & 0xFF) / 255.0
            self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
        } else {
            self.init(cgColor: fallback.cgColor)!
        }
    }

    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "#FF0000" }
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
