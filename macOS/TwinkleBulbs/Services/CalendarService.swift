import Foundation

public struct CountdownSummary {
    public let headline: String
    public let daysRemaining: Int
    public let targetDate: Date
}

public final class CalendarService {
    public static let shared = CalendarService()

    /// 38 Tips matching the feature breadth of Twinkle Bulbs v6.0 TEXT/281 (clean-room authored)
    public static let tipsOfTheDay: [String] = [
        "Right-click or left-click the menu bar bulb icon anytime—you can customize left, middle, and right click actions in General Settings.",
        "Enable \"Fewer Bulbs\" and \"Bare Wire\" in Bulbs Settings for a classic realistic holiday strand spaced every second socket.",
        "Use \"Around Screen\" with \"Leave Corners Blank\" enabled to frame your Mac display cleanly without overlapping corners.",
        "Try \"Point Bulbs Inward\" so lights along the left, right, and bottom edges angle gracefully toward the center of your screen.",
        "You can double your strand scale anytime by switching Bulb Size from Normal (32×32) to Large (48×48).",
        "Switch Display Layer between Desktop, Always On Top, and Menu Bar / Taskbar in Bulbs Settings.",
        "Turn on \"Flash Menu Bar Icon\" in General Settings to blink the menu bar icon in sync with your screen's first bulb.",
        "Mix things up by enabling \"Mix Bulbs\" to blend Outdoor, Normal, Large, Stars, Candy Canes, and more onto one strand.",
        "Add authentic imperfections with \"Broken Bulbs\" (16%), \"Burned Out\" (30%), and \"Missing\" (20%).",
        "All 21 authentic color modes are available in Bulbs Settings—from Classic Red/Green and Multi-Color to Red/White/Blue and Cool Colors.",
        "Use the Quick Access floating bar to switch flashing patterns, colors, music, and screen saver with one click.",
        "Enable Bulb Changer to automatically rotate through your favorite bulb designs on a timer.",
        "Hold Shift while launching Twinkle Bulbs to start cleanly with music and sound effects muted.",
        "Hold Option while launching Twinkle Bulbs if you ever want to reset settings back to v6.0 factory defaults.",
        "Built-in Screen Savers include Blank Screen, customizable digital Clock, Fireworks, and Snowfall—all supporting perimeter lights.",
        "In Snowfall Screen Saver settings, turn on Blizzard Mode or Gusting Wind and watch snowdrift accumulate.",
        "Set a Hot Corner in Screen Saver Settings so moving your cursor to a screen corner launches the holiday screen saver immediately.",
        "Display a custom holiday greeting right inside the screen saver—and optionally scroll it smoothly across your screen.",
        "Want carols only while your screen saver runs? Check \"Play Music Only During Screen Saver\" in Music Settings.",
        "You can set a Music Pause Timer so holiday tunes gently stop automatically after your chosen duration.",
        "Twinkle Bulbs natively supports importing your own Windows .blb, .icl, and .ico bulb files from Tools / Import Assets.",
        "You can also drop .mid, .wav, .mp3, or .m4a music tracks and custom desktop wallpapers into Twinkle Bulbs' Application Support folders.",
        "In Calendar Settings, pick a Holiday Countdown (Christmas, Thanksgiving, Hanukkah, Valentine's Day, Halloween, New Year's, or Custom).",
        "Click \"On the Desktop\" draw mode when you want festive lights sitting peacefully behind your open application windows.",
        "All screen-edge light overlays ignore mouse clicks so your workflow across apps, Dock, and Mission Control stays uninterrupted.",
        "Experiment with \"Reverse\" in Chase, Single, Pairs, or Ping-Pong flashing modes to change light motion direction.",
        "\"Some Bulbs Flash\" keeps ~70% of bulbs glowing steadily while ~30% twinkle organically.",
        "Set multiple displays to light up simultaneously via \"Use All Monitors\" or choose a specific display in Bulbs Settings.",
        "Enable \"Start Screen Saver Only\" if you want to use Twinkle Bulbs strictly as your screen saver launcher.",
        "Use Wallpaper Changer to rotate festive winter tiles and backgrounds across your macOS Spaces automatically.",
        "Use the live Monitor Preview inside Settings to inspect color sequences and animations before applying.",
        "Each built-in bulb set preserves v6.0's wire row geometry so adjacent bare-wire and lit bulbs align seamlessly.",
        "Customize keyboard, click, move, and scroll wheel dismiss sensitivity in Screen Saver Settings.",
        "Classic Outdoor and Bare Bulbs compute their dimmed off state using 50% highlight blending—customizable via Advanced Highlight Color.",
        "Add your own anniversaries or family holidays in the Calendar tab for automatic desktop greetings at startup.",
        "Adjust Flash Rate from Slow (1200ms) all the way up to Very Fast (80ms) to match your mood.",
        "Use the Help tab anytime for complete documentation on every Twinkle Bulbs v6.0 feature and keyboard shortcut.",
        "Happy Holidays from Twinkle Bulbs for macOS!"
    ]

    public func countdownSummary(settings: AppSettings, from referenceDate: Date = Date()) -> CountdownSummary? {
        let holiday = settings.countdownHoliday
        guard holiday != .none else { return nil }
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: referenceDate)
        let year = cal.component(.year, from: todayStart)

        let targetName: String
        let target: Date

        func nextAnnual(month: Int, day: Int) -> Date {
            let thisYear = cal.date(from: DateComponents(year: year, month: month, day: day)) ?? todayStart
            if thisYear < todayStart {
                return cal.date(from: DateComponents(year: year + 1, month: month, day: day)) ?? todayStart
            }
            return thisYear
        }

        switch holiday {
        case .none:
            return nil
        case .christmas:
            targetName = "Christmas"
            target = nextAnnual(month: 12, day: 25)
        case .valentinesDay:
            targetName = "Valentine's Day"
            target = nextAnnual(month: 2, day: 14)
        case .halloween:
            targetName = "Halloween"
            target = nextAnnual(month: 10, day: 31)
        case .independenceDay:
            targetName = "Independence Day"
            target = nextAnnual(month: 7, day: 4)
        case .stPatricksDay:
            targetName = "St. Patrick's Day"
            target = nextAnnual(month: 3, day: 17)
        case .newYearsDay:
            targetName = "New Year's Day"
            target = nextAnnual(month: 1, day: 1)
        case .thanksgiving:
            targetName = "Thanksgiving"
            let tThis = Self.usThanksgivingDate(year: year)
            target = (tThis < todayStart) ? Self.usThanksgivingDate(year: year + 1) : tThis
        case .hanukkah:
            targetName = "Hanukkah"
            let hThis = Self.hanukkahStartDate(year: year)
            target = (hThis < todayStart) ? Self.hanukkahStartDate(year: year + 1) : hThis
        case .custom:
            targetName = settings.customHolidayName.isEmpty ? "Special Day" : settings.customHolidayName
            target = nextAnnual(month: max(1, min(12, settings.customHolidayMonth)),
                                day: max(1, min(31, settings.customHolidayDay)))
        }

        let days = cal.dateComponents([.day], from: todayStart, to: target).day ?? 0
        let headline: String
        if days == 0 {
            headline = "Today is \(targetName)!"
        } else if days == 1 {
            headline = "1 day until \(targetName)!"
        } else {
            headline = "\(days) days until \(targetName)"
        }
        return CountdownSummary(headline: headline, daysRemaining: days, targetDate: target)
    }

    func matchingEvents(on date: Date = Date(), settings: AppSettings) -> [CalendarEventItem] {
        guard settings.eventMsgs else { return [] }
        let cal = Calendar.current
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return settings.calendarEvents.filter { $0.enabled && $0.month == m && $0.day == d }
    }

    public static func usThanksgivingDate(year: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = 11
        comps.weekday = 5 // Thursday
        comps.weekdayOrdinal = 4
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date()
    }

    static func hanukkahStartDate(year: Int) -> Date {
        let hebrew = Calendar(identifier: .hebrew)
        let greg = Calendar(identifier: .gregorian)
        let jan1 = greg.date(from: DateComponents(year: year, month: 1, day: 1))!
        let hYear = hebrew.component(.year, from: greg.date(from: DateComponents(year: year, month: 12, day: 1))!)
        // Kislev 25 (in Hebrew calendar Kislev is month 3; verify programmatically)
        var c = DateComponents()
        c.year = hYear
        c.month = 3 // Kislev in Foundation Hebrew Calendar
        c.day = 25
        if let d = hebrew.date(from: c), greg.component(.year, from: d) == year {
            return d
        }
        return jan1
    }
}
