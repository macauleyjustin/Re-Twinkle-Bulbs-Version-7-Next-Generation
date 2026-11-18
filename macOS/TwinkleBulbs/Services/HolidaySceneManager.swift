import Foundation
import Combine

// MARK: - Persistent Next-Generation State Coordinator

public final class NextGenStateStore: ObservableObject {
    public static let shared = NextGenStateStore()

    @Published public var state: NextGenStateContainer {
        didSet { save() }
    }

    public static var storageDirectory: URL {
        let appSup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSup.appendingPathComponent("TwinkleBulbs/NextGen", isDirectory: true)
    }

    private let fileURL: URL

    public init(storageURL: URL? = nil) {
        let dir = Self.storageDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = storageURL ?? dir.appendingPathComponent("nextgen_config.json")

        if let data = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode(NextGenStateContainer.self, from: data) {
            self.state = decoded
        } else {
            self.state = NextGenStateContainer()
        }
    }

    public func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(state) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

// MARK: - Part I: Holiday Scene Manager (16 Required Built-in Presets + User Scenes)

public final class HolidaySceneManager: ObservableObject {
    public static let shared = HolidaySceneManager()

    public let builtInScenes: [HolidayScene]
    @Published public private(set) var allScenes: [HolidayScene] = []

    public var onApplyAppSettings: ((AppSettings) -> Void)?

    private let store: NextGenStateStore
    private var cancellable: AnyCancellable?

    public init(store: NextGenStateStore = .shared) {
        self.store = store
        self.builtInScenes = Self.create16BuiltInScenes()
        rebuildSceneList()
        self.cancellable = store.$state.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.rebuildSceneList()
            }
        }
    }

    public func rebuildSceneList() {
        let favs = store.state.favoriteSceneIDs
        let built = builtInScenes.map { sc -> HolidayScene in
            var copy = sc
            copy.isFavorite = favs.contains(sc.id)
            return copy
        }
        let custom = store.state.userScenes.map { sc -> HolidayScene in
            var copy = sc
            copy.isFavorite = favs.contains(sc.id) || sc.isFavorite
            copy.isBuiltIn = false
            return copy
        }
        allScenes = built + custom
    }

    public func scene(withID id: String) -> HolidayScene? {
        allScenes.first { $0.id == id }
    }

    /// Captures all current Settings fields + NextGen options into a reusable scene object.
    public func snapshotCurrentSettings(
        name: String,
        subtitle: String = "Custom Holiday Scene",
        season: SceneSeasonCategory = .custom,
        from s: AppSettings
    ) -> HolidayScene {
        var sc = HolidayScene(
            id: "user_scene:\(UUID().uuidString.prefix(8))",
            name: name,
            subtitle: subtitle,
            season: season,
            isBuiltIn: false,
            isFavorite: false
        )
        sc.lightsEnabled = s.lightsEnabled
        sc.lightingCategory = s.lightingCategory
        sc.bulbSetName = s.bulbSetName
        sc.bulbSize = s.bulbSize
        sc.colorMode = s.colorMode
        sc.flashMode = s.flashMode
        sc.rate = s.rate
        sc.modernEffects = s.modernEffects
        sc.location = s.location
        sc.drawMode = s.drawMode
        sc.musicEnabled = s.musicEnabled
        sc.preferredTrackIDs = s.enabledTrackIDs
        sc.ssModule = s.ssModule
        sc.activeWallpaperID = s.activeWallpaperID
        sc.wallpaperStyle = s.wallpaperType
        sc.interactiveEffectsEnabled = store.state.interactive.enabled
        sc.externalOutputEnabled = store.state.apiConfig.externalHardwareEnabled
        sc.customTimelineID = store.state.activeTimelineID
        return sc
    }

    /// Pure deterministic transformation applying a scene onto base AppSettings cleanly.
    public func applySceneConfiguration(_ scene: HolidayScene, to base: AppSettings) -> AppSettings {
        var next = base
        next.lightsEnabled = scene.lightsEnabled
        next.lightingCategory = scene.lightingCategory
        next.bulbSetName = scene.bulbSetName
        next.bulbSize = scene.bulbSize
        next.colorMode = scene.colorMode
        next.flashMode = scene.flashMode
        next.rate = scene.rate
        var mod = scene.modernEffects
        mod.brightness = max(0.05, min(1.0, mod.brightness * scene.brightnessMultiplier))
        next.modernEffects = mod
        next.location = scene.location
        next.drawMode = scene.drawMode
        next.musicEnabled = scene.musicEnabled
        next.enabledTrackIDs = scene.preferredTrackIDs
        next.ssModule = scene.ssModule
        next.activeWallpaperID = scene.activeWallpaperID
        next.wallpaperType = scene.wallpaperStyle
        return next
    }

    @discardableResult
    public func activateScene(id: String, settingsStore: SettingsStore = .shared, applyWallpaper: Bool = true) -> Bool {
        guard let sc = scene(withID: id) else { return false }
        // Record previous state so Restore Previous Scene always works
        let prevSnap = SavedSettingsSnapshot(
            appSettings: settingsStore.settings,
            activeSceneID: store.state.activeSceneID,
            activeTimelineID: store.state.activeTimelineID
        )
        var nextState = store.state
        nextState.previousSnapshot = prevSnap
        nextState.activeSceneID = sc.id
        nextState.activeTimelineID = sc.customTimelineID
        nextState.interactive.enabled = sc.interactiveEffectsEnabled
        store.state = nextState

        let updatedApp = applySceneConfiguration(sc, to: settingsStore.settings)
        settingsStore.settings = updatedApp
        if applyWallpaper {
            _ = WallpaperService.shared.applyWallpaper(id: sc.activeWallpaperID, style: sc.wallpaperStyle)
        }
        onApplyAppSettings?(updatedApp)
        return true
    }

    @discardableResult
    public func restorePreviousScene(settingsStore: SettingsStore = .shared) -> Bool {
        guard let prev = store.state.previousSnapshot else { return false }
        var nextState = store.state
        nextState.activeSceneID = prev.activeSceneID
        nextState.activeTimelineID = prev.activeTimelineID
        nextState.previousSnapshot = nil
        store.state = nextState

        settingsStore.settings = prev.appSettings
        onApplyAppSettings?(prev.appSettings)
        return true
    }

    public func returnToClassicTwinkleBulbs(settingsStore: SettingsStore = .shared) {
        let current = settingsStore.settings
        let prevSnap = SavedSettingsSnapshot(
            appSettings: current,
            activeSceneID: store.state.activeSceneID,
            activeTimelineID: store.state.activeTimelineID
        )
        var nextState = store.state
        nextState.previousSnapshot = prevSnap
        nextState.activeSceneID = nil
        nextState.activeTimelineID = nil
        nextState.interactive.enabled = false
        store.state = nextState

        var classic = AppSettings.defaultSettings()
        classic.musicDirectoryPath = current.musicDirectoryPath
        classic.customSoundBankPath = current.customSoundBankPath
        classic.openedAdventDoors = current.openedAdventDoors
        classic.favoriteBulbSetIDs = current.favoriteBulbSetIDs
        classic.favoriteWallpaperIDs = current.favoriteWallpaperIDs
        classic.calendarEvents = current.calendarEvents
        settingsStore.settings = classic
        onApplyAppSettings?(classic)
    }

    @discardableResult
    public func saveUserScene(_ scene: HolidayScene) -> HolidayScene {
        var clean = scene
        clean.isBuiltIn = false
        if clean.id.isEmpty { clean.id = "user_scene:\(UUID().uuidString.prefix(8))" }
        var next = store.state
        if let idx = next.userScenes.firstIndex(where: { $0.id == clean.id }) {
            next.userScenes[idx] = clean
        } else {
            next.userScenes.append(clean)
        }
        store.state = next
        rebuildSceneList()
        return clean
    }

    @discardableResult
    public func duplicateScene(id: String) -> HolidayScene? {
        guard let orig = scene(withID: id) else { return nil }
        var copy = orig
        copy.id = "user_scene:\(UUID().uuidString.prefix(8))"
        copy.name = "\(orig.name) Copy"
        copy.isBuiltIn = false
        return saveUserScene(copy)
    }

    @discardableResult
    public func renameUserScene(id: String, newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        var next = store.state
        guard let idx = next.userScenes.firstIndex(where: { $0.id == id }) else { return false }
        next.userScenes[idx].name = trimmed
        store.state = next
        rebuildSceneList()
        return true
    }

    /// Protects built-in scenes from accidental deletion (only deletes user-created scenes).
    @discardableResult
    public func deleteScene(id: String) -> Bool {
        if builtInScenes.contains(where: { $0.id == id }) {
            return false
        }
        var next = store.state
        let before = next.userScenes.count
        next.userScenes.removeAll { $0.id == id }
        guard next.userScenes.count < before else { return false }
        next.favoriteSceneIDs.remove(id)
        if next.activeSceneID == id { next.activeSceneID = nil }
        store.state = next
        rebuildSceneList()
        return true
    }

    public func toggleFavorite(id: String) {
        var next = store.state
        if next.favoriteSceneIDs.contains(id) {
            next.favoriteSceneIDs.remove(id)
        } else {
            next.favoriteSceneIDs.insert(id)
        }
        store.state = next
        rebuildSceneList()
    }

    public func exportScene(id: String) throws -> Data {
        guard let sc = scene(withID: id) else {
            throw NSError(domain: "TwinkleScene", code: 404, userInfo: [NSLocalizedDescriptionKey: "Scene not found: \(id)"])
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(sc)
    }

    public func importScene(data: Data) throws -> HolidayScene {
        var decoded = try JSONDecoder().decode(HolidayScene.self, from: data)
        decoded.isBuiltIn = false
        if builtInScenes.contains(where: { $0.id == decoded.id }) || scene(withID: decoded.id) != nil {
            decoded.id = "user_scene:\(UUID().uuidString.prefix(8))"
        }
        return saveUserScene(decoded)
    }

    // MARK: - All 16 Required Built-In Holiday Scenes

    private static func create16BuiltInScenes() -> [HolidayScene] {
        func make(
            _ id: String, _ name: String, _ sub: String, _ season: SceneSeasonCategory,
            bulb: String, category: LightingEngineCategory = .modern,
            colorMode: ColorMode = .redGreen, flash: FlashMode = .chase,
            effect: ModernEffectID = .twinklefox, palette: ModernColorPalette = .classicHoliday,
            speed: Double = 1.0, brightness: Double = 1.0,
            saver: ScreenSaverModuleID, wallpaper: String, tracks: [String] = [],
            musicOn: Bool = false
        ) -> HolidayScene {
            var s = HolidayScene(id: id, name: name, subtitle: sub, season: season, isBuiltIn: true)
            s.bulbSetName = bulb
            s.lightingCategory = category
            s.colorMode = colorMode
            s.flashMode = flash
            s.modernEffects.effect = effect
            s.modernEffects.palette = palette
            s.modernEffects.speed = speed
            s.modernEffects.brightness = brightness
            s.ssModule = saver
            s.activeWallpaperID = wallpaper
            s.preferredTrackIDs = tracks
            s.musicEnabled = musicOn
            return s
        }

        return [
            make("scene:classic_christmas", "Classic Christmas", "Authentic v6.0 Outdoor red & green C7 strands with Jingle Bells", .christmas,
                 bulb: "Outdoor", category: .classic, colorMode: .redGreen, flash: .chase,
                 effect: .gentleTwinkle, palette: .classicHoliday, speed: 1.0, brightness: 1.0,
                 saver: .christmasTreeGlow, wallpaper: "holiday_bulbs_dark", tracks: ["builtin:jingle_bells", "builtin:deck_halls"]),
            make("scene:victorian_christmas", "Victorian Christmas", "Warm candle-glow incandescents with classic parlor carols", .christmas,
                 bulb: "holiday250:009", colorMode: .yellowWhite,
                 effect: .candleFlicker, palette: .warmWhite, speed: 0.85, brightness: 0.92,
                 saver: .twinklingWreath, wallpaper: "holiday_wp_019", tracks: ["builtin:silent_night", "builtin:first_noel"]),
            make("scene:winter_wonderland", "Winter Wonderland", "Crisp ice-blue & silver snowflake strands", .winter,
                 bulb: "holiday250:021", colorMode: .blues,
                 effect: .colorWave, palette: .coolIce, speed: 0.9, brightness: 0.95,
                 saver: .winterFrost, wallpaper: "holiday_wp_022", tracks: ["builtin:greensleeves"]),
            make("scene:christmas_fireplace", "Christmas Fireplace", "Warm ember shimmer with cozy hearth stockings", .christmas,
                 bulb: "holiday250:019", colorMode: .redYellow,
                 effect: .candleFlicker, palette: .warmWhite, speed: 0.8, brightness: 0.90,
                 saver: .fireplaceChristmas, wallpaper: "holiday_wp_008", tracks: ["builtin:little_town", "builtin:silent_night"]),
            make("scene:snowy_village", "Snowy Village", "Gingerbread & frosted snowfall lights across the screen", .winter,
                 bulb: "holiday250:030", colorMode: .allColorsWhite,
                 effect: .twinklefox, palette: .blueSilver, speed: 0.95, brightness: 0.95,
                 saver: .snowfallVillage, wallpaper: "holiday_wp_007", tracks: ["builtin:deck_halls", "builtin:we_wish"]),
            make("scene:new_years_celebration", "New Year's Celebration", "Midnight champagne gold & firework burst chasing strands", .newYear,
                 bulb: "holiday250:201", colorMode: .yellowWhite,
                 effect: .fireworks, palette: .rainbowSpectrum, speed: 1.45, brightness: 1.0,
                 saver: .newYearsCelebration, wallpaper: "holiday_wp_109", tracks: ["builtin:cd_000_25"]),
            make("scene:valentines_romance", "Valentine's Romance", "Glowing crimson & rose hearts with gentle pulse", .valentines,
                 bulb: "holiday250:061", colorMode: .red,
                 effect: .heartbeat, palette: .candyCane, speed: 0.9, brightness: 0.92,
                 saver: .valentineHearts, wallpaper: "holiday_wp_075"),
            make("scene:st_patricks_day", "St. Patrick's Day", "Emerald clover shamrock & pot-of-gold waves", .stPatricks,
                 bulb: "holiday250:071", colorMode: .green,
                 effect: .colorWave, palette: .forestGold, speed: 1.15, brightness: 0.95,
                 saver: .springRain, wallpaper: "holiday_wp_125"),
            make("scene:easter_garden", "Easter Garden", "Pastel decorated eggs & spring pastel shimmer", .easter,
                 bulb: "holiday250:081", colorMode: .multiColor,
                 effect: .softRandomFade, palette: .rainbowSpectrum, speed: 0.85, brightness: 0.95,
                 saver: .easterGarden, wallpaper: "holiday_wp_085"),
            make("scene:spring_awakening", "Spring Awakening", "Cherry blossom pink petals & fresh morning dew glow", .spring,
                 bulb: "holiday250:091", colorMode: .allColorsWhite,
                 effect: .slowGlow, palette: .warmWhite, speed: 0.9, brightness: 0.95,
                 saver: .springBlossoms, wallpaper: "holiday_wp_053"),
            make("scene:summer_nights", "Summer Nights", "Warm twinkling firefly lanterns beneath midnight stars", .summer,
                 bulb: "holiday250:129", colorMode: .yellowWhite,
                 effect: .glitter, palette: .forestGold, speed: 0.95, brightness: 0.92,
                 saver: .summerFireflies, wallpaper: "holiday_wp_065"),
            make("scene:fourth_of_july", "Fourth of July", "Red, white & blue patriotic stars and aerial bursts", .patriotic,
                 bulb: "holiday250:131", colorMode: .redWhiteBlue,
                 effect: .fireworks, palette: .redWhiteBlue, speed: 1.35, brightness: 1.0,
                 saver: .patrioticCelebration, wallpaper: "holiday_wp_114", tracks: ["builtin:cd_000_36"]),
            make("scene:autumn_harvest", "Autumn Harvest", "Maple leaf amber, crimson & russet oak gradients", .autumn,
                 bulb: "holiday250:151", colorMode: .redYellow,
                 effect: .colorWave, palette: .classicHoliday, speed: 0.85, brightness: 0.92,
                 saver: .fallingAutumnLeaves, wallpaper: "holiday_wp_031"),
            make("scene:haunted_halloween", "Haunted Halloween", "Glowing Jack-o'-lanterns & eerie purple scanner pulses", .halloween,
                 bulb: "holiday250:171", colorMode: .purple,
                 effect: .scanner, palette: .royalPurpleGold, speed: 1.25, brightness: 0.95,
                 saver: .hauntedHouse, wallpaper: "holiday_wp_042"),
            make("scene:thanksgiving", "Thanksgiving", "Warm golden harvest cornucopia glow for family gatherings", .thanksgiving,
                 bulb: "holiday250:192", colorMode: .redYellow,
                 effect: .slowGlow, palette: .warmWhite, speed: 0.75, brightness: 0.92,
                 saver: .autumnForest, wallpaper: "holiday_wp_095", tracks: ["builtin:cd_000_37"]),
            make("scene:peaceful_winter_evening", "Peaceful Winter Evening", "Dim, calm aurora-blue shimmer for quiet relaxation", .winter,
                 bulb: "holiday250:211", colorMode: .coolColors,
                 effect: .gentleTwinkle, palette: .coolIce, speed: 0.65, brightness: 0.60,
                 saver: .snowfall, wallpaper: "holiday_wp_021")
        ]
    }
}
