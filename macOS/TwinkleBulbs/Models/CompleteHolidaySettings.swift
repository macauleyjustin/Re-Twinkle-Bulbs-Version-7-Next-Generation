import Foundation

// MARK: - 25 Bulb Collections for the 250 Complete Holiday Edition Bulb Sets

public enum BulbCollectionCategory: Int, CaseIterable, Codable, Identifiable {
    case classicBuiltIn = 0
    case classicChristmasLights = 1
    case christmasDecorations = 2
    case winterWonderland = 3
    case traditionalChristmasSymbols = 4
    case santasWorkshop = 5
    case christmasCandy = 6
    case valentinesDay = 7
    case stPatricksDay = 8
    case easter = 9
    case springGarden = 10
    case springRain = 11
    case summerBeach = 12
    case summerOutdoors = 13
    case flagsAndPatriotic = 14
    case birthdaysAndCelebrations = 15
    case autumnLeaves = 16
    case autumnHarvest = 17
    case halloweenClassics = 18
    case hauntedHalloween = 19
    case thanksgiving = 20
    case newYearsEve = 21
    case celestialLights = 22
    case animals = 23
    case flowersAndPlants = 24
    case retroAndNovelty = 25

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .classicBuiltIn: return "Original v6.0 Classics"
        case .classicChristmasLights: return "1. Classic Christmas Lights"
        case .christmasDecorations: return "2. Christmas Decorations"
        case .winterWonderland: return "3. Winter Wonderland"
        case .traditionalChristmasSymbols: return "4. Traditional Christmas Symbols"
        case .santasWorkshop: return "5. Santa's Workshop"
        case .christmasCandy: return "6. Christmas Candy"
        case .valentinesDay: return "7. Valentine's Day"
        case .stPatricksDay: return "8. St. Patrick's Day"
        case .easter: return "9. Easter"
        case .springGarden: return "10. Spring Garden"
        case .springRain: return "11. Spring Rain"
        case .summerBeach: return "12. Summer Beach"
        case .summerOutdoors: return "13. Summer Outdoors"
        case .flagsAndPatriotic: return "14. Flags and Patriotic"
        case .birthdaysAndCelebrations: return "15. Birthdays and Celebrations"
        case .autumnLeaves: return "16. Autumn Leaves"
        case .autumnHarvest: return "17. Autumn Harvest"
        case .halloweenClassics: return "18. Halloween Classics"
        case .hauntedHalloween: return "19. Haunted Halloween"
        case .thanksgiving: return "20. Thanksgiving"
        case .newYearsEve: return "21. New Year's Eve"
        case .celestialLights: return "22. Celestial Lights"
        case .animals: return "23. Animals"
        case .flowersAndPlants: return "24. Flowers and Plants"
        case .retroAndNovelty: return "25. Retro & Novelty Lighting"
        }
    }

    public static var holiday25Collections: [BulbCollectionCategory] {
        allCases.filter { $0 != .classicBuiltIn }
    }
}

// MARK: - Seasonal Screen Saver Configurable Parameters (Part C)

public enum AutumnLeavesWind: Int, CaseIterable, Codable, Identifiable {
    case gentle = 0
    case breezy = 1
    case windy = 2

    public var id: Int { rawValue }
    public var displayName: String {
        switch self {
        case .gentle: return "Gentle Breeze"
        case .breezy: return "Crisp Breezy"
        case .windy: return "Autumn Gusts"
        }
    }
}

public enum AutumnLeavesBackground: Int, CaseIterable, Codable, Identifiable {
    case blackNight = 0
    case twilightSunset = 1
    case autumnLandscape = 2

    public var id: Int { rawValue }
    public var displayName: String {
        switch self {
        case .blackNight: return "Deep Midnight"
        case .twilightSunset: return "Warm Amber Twilight"
        case .autumnLandscape: return "Golden Autumn Horizon"
        }
    }
}

public struct SeasonalScreenSaverConfig: Codable, Equatable {
    public var speed: Double = 1.0                // 0.3 ... 2.5
    public var density: Double = 1.0              // 0.3 ... 2.0
    public var brightness: Double = 1.0           // 0.25 ... 1.0
    public var wreathSizeScale: Double = 1.0      // 0.6 ... 1.4
    public var windCondition: AutumnLeavesWind = .breezy
    public var leavesBackground: AutumnLeavesBackground = .twilightSunset
    public var pumpkinFaceStyle: Int = 0          // 0=Classic, 1=Grinning, 2=Spooky, 3=Cat/Friendly
    public var showMidnightCountdown: Bool = true
    public var slideshowIntervalSec: Double = 6.0
    public var reduceMotion: Bool = false

    public init() {}
}
