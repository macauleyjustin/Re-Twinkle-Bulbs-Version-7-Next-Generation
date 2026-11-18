import Foundation
import AppKit

// MARK: - NOAA Pure-Swift Solar Sunrise / Sunset Calculator

public enum SolarCalculator {
    public static func sunriseSunset(
        date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone = .current
    ) -> (sunrise: Date, sunset: Date)? {
        let cal = Calendar(identifier: .gregorian)
        guard let doy = cal.ordinality(of: .day, in: .year, for: date) else { return nil }
        let startOfDay = cal.startOfDay(for: date)

        let gammaBase = (2.0 * .pi / 365.0) * Double(doy - 1)
        let eqTime = 229.18 * (0.000075
            + 0.001868 * cos(gammaBase)
            - 0.032077 * sin(gammaBase)
            - 0.014615 * cos(2 * gammaBase)
            - 0.040849 * sin(2 * gammaBase))
        let decl = 0.006918
            - 0.399912 * cos(gammaBase)
            + 0.070257 * sin(gammaBase)
            - 0.006758 * cos(2 * gammaBase)
            + 0.000907 * sin(2 * gammaBase)
            - 0.002697 * cos(3 * gammaBase)
            + 0.001480 * sin(3 * gammaBase)

        let latRad = latitude * .pi / 180.0
        let zenithRad = 90.833 * .pi / 180.0
        let cosHA = (cos(zenithRad) / (cos(latRad) * cos(decl))) - tan(latRad) * tan(decl)
        guard cosHA >= -1.0 && cosHA <= 1.0 else { return nil } // polar day/night fallback
        let haDeg = acos(cosHA) * 180.0 / .pi

        let tzMinutes = Double(timeZone.secondsFromGMT(for: date)) / 60.0
        let sunriseMin = 720.0 - 4.0 * (longitude + haDeg) - eqTime + tzMinutes
        let sunsetMin = 720.0 - 4.0 * (longitude - haDeg) - eqTime + tzMinutes

        return (
            startOfDay.addingTimeInterval(sunriseMin * 60.0),
            startOfDay.addingTimeInterval(sunsetMin * 60.0)
        )
    }
}

// MARK: - Part II: Seasonal Automation & Countdown Schedule Service

public struct ScheduleEvaluationResult: Equatable {
    public var targetSceneID: String?
    public var shouldShutdownLights: Bool
    public var isQuietHours: Bool
    public var brightnessMultiplier: Double
    public var activeRuleName: String?
    public var isManualOverride: Bool
}

public final class SeasonalScheduleService {
    public static let shared = SeasonalScheduleService()

    public var onSceneTriggered: ((String) -> Void)?
    public var onShutdownStateChanged: ((Bool) -> Void)?
    public var onQuietHoursChanged: ((Bool, Double, Bool) -> Void)?
    public var onCelebrationTriggered: ((CountdownCelebrationEvent) -> Void)?

    private var nextEventTimer: Timer?
    private var lastAppliedSceneID: String?
    private var lastShutdownState: Bool = false

    private let store: NextGenStateStore

    public init(store: NextGenStateStore = .shared) {
        self.store = store
    }

    public func startObservingSystemEvents() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleSystemClockOrCalendarChange), name: .NSCalendarDayChanged, object: nil)
        nc.addObserver(self, selector: #selector(handleSystemClockOrCalendarChange), name: .NSSystemTimeZoneDidChange, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleSystemWake), name: NSWorkspace.didWakeNotification, object: nil
        )
        evaluateAndScheduleNext(at: Date())
    }

    public func stop() {
        nextEventTimer?.invalidate()
        nextEventTimer = nil
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func handleSystemClockOrCalendarChange() {
        evaluateAndScheduleNext(at: Date())
    }

    @objc private func handleSystemWake() {
        // Handle missed celebrations & catch up cleanly on wake
        evaluateAndScheduleNext(at: Date())
    }

    public func setTemporaryManualOverride(sceneID: String, durationMinutes: Int, now: Date = Date()) {
        var next = store.state
        next.automation.manualOverrideSceneID = sceneID
        next.automation.manualOverrideExpiresAt = now.addingTimeInterval(Double(max(1, durationMinutes)) * 60.0)
        store.state = next
        evaluateAndScheduleNext(at: now)
    }

    public func clearTemporaryManualOverride(now: Date = Date()) {
        var next = store.state
        next.automation.manualOverrideSceneID = nil
        next.automation.manualOverrideExpiresAt = nil
        store.state = next
        evaluateAndScheduleNext(at: now)
    }

    /// Pure deterministic evaluator testable across time zones, DST, leap dates, quiet hours & conflicts.
    public func evaluate(at date: Date, automation: SeasonalAutomationConfig, calendar: Calendar = .current) -> ScheduleEvaluationResult {
        var res = ScheduleEvaluationResult(
            targetSceneID: nil,
            shouldShutdownLights: false,
            isQuietHours: false,
            brightnessMultiplier: 1.0,
            activeRuleName: nil,
            isManualOverride: false
        )

        guard automation.automationEnabled else { return res }

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: date)
        let year = comps.year ?? 2026
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        let minuteOfDay = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let weekday = comps.weekday ?? 1

        // 1. Vacation Mode or Auto-Shutdown Window
        if automation.vacationMode {
            res.shouldShutdownLights = true
            res.activeRuleName = "Vacation Mode (Paused)"
            return res
        }
        if automation.autoShutdownEnabled {
            let shutM = automation.shutdownHour * 60 + automation.shutdownMinute
            let resumeM = automation.resumeHour * 60 + automation.resumeMinute
            if isMinuteInWindow(minuteOfDay, start: shutM, end: resumeM) {
                res.shouldShutdownLights = true
                res.activeRuleName = "Auto Shutdown Window"
                return res
            }
        }

        // 2. Quiet Hours
        if automation.quietHours.enabled {
            let qs = automation.quietHours.startHour * 60 + automation.quietHours.startMinute
            let qe = automation.quietHours.endHour * 60 + automation.quietHours.endMinute
            if isMinuteInWindow(minuteOfDay, start: qs, end: qe) {
                res.isQuietHours = true
                res.brightnessMultiplier = automation.quietHours.dimBrightnessScale
            }
        }

        // 3. Temporary Manual Override
        if let ovID = automation.manualOverrideSceneID,
           let exp = automation.manualOverrideExpiresAt,
           exp > date {
            res.targetSceneID = ovID
            res.isManualOverride = true
            res.activeRuleName = "Temporary Manual Override"
            return res
        }

        // 4. Highest-priority enabled rule match
        let matchingRules = automation.rules.filter { rule in
            guard rule.isEnabled else { return false }
            return doesRuleMatch(
                rule,
                date: date,
                year: year,
                month: month,
                day: day,
                minuteOfDay: minuteOfDay,
                weekday: weekday,
                lat: automation.latitude,
                lon: automation.longitude,
                calendar: calendar
            )
        }

        if let winner = matchingRules.max(by: { $0.priority < $1.priority }) {
            res.targetSceneID = winner.sceneID
            res.activeRuleName = winner.name
        }
        return res
    }

    public func evaluateAndScheduleNext(at now: Date = Date()) {
        let cfg = store.state.automation
        let result = evaluate(at: now, automation: cfg)

        if cfg.automationEnabled {
            if result.shouldShutdownLights != lastShutdownState {
                lastShutdownState = result.shouldShutdownLights
                onShutdownStateChanged?(result.shouldShutdownLights)
            }
            if !result.shouldShutdownLights, let targetScene = result.targetSceneID, targetScene != lastAppliedSceneID {
                lastAppliedSceneID = targetScene
                onSceneTriggered?(targetScene)
            }
            onQuietHoursChanged?(result.isQuietHours, result.brightnessMultiplier, cfg.quietHours.muteMusicDuringQuietHours)
            checkCelebrations(at: now)
        }

        // Event-driven next transition timer (no polling loop!)
        nextEventTimer?.invalidate()
        nextEventTimer = nil
        if cfg.automationEnabled {
            let nextBoundary = computeNextBoundaryDate(after: now, automation: cfg)
            let waitSec = max(1.0, min(3600.0, nextBoundary.timeIntervalSince(now)))
            let t = Timer(timeInterval: waitSec, repeats: false) { [weak self] _ in
                self?.evaluateAndScheduleNext(at: Date())
            }
            RunLoop.main.add(t, forMode: .common)
            nextEventTimer = t
        }
    }

    private func checkCelebrations(at now: Date) {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let yr = c.year ?? 2026
        var changed = false
        var list = store.state.automation.celebrations

        for i in list.indices {
            guard list[i].month == c.month, list[i].day == c.day else { continue }
            guard list[i].lastTriggeredYear != yr else { continue }
            guard let target = cal.date(from: DateComponents(year: yr, month: list[i].month, day: list[i].day, hour: list[i].hour, minute: list[i].minute)) else { continue }
            let delta = now.timeIntervalSince(target)
            // Fire cleanly if right on time or woken up within 2 hours of missed celebration
            if delta >= -5.0 && delta <= 7200.0 {
                list[i].lastTriggeredYear = yr
                changed = true
                onCelebrationTriggered?(list[i])
            }
        }
        if changed {
            var next = store.state
            next.automation.celebrations = list
            store.state = next
        }
    }

    private func doesRuleMatch(
        _ rule: SeasonalScheduleRule,
        date: Date,
        year: Int,
        month: Int,
        day: Int,
        minuteOfDay: Int,
        weekday: Int,
        lat: Double?,
        lon: Double?,
        calendar: Calendar
    ) -> Bool {
        switch rule.kind {
        case .specificDate:
            if let sy = rule.specificYear, sy != year { return false }
            return month == rule.startMonth && day == rule.startDay && matchesTimeWindow(rule, minuteOfDay: minuteOfDay)

        case .annualHoliday:
            return month == rule.startMonth && day == rule.startDay && matchesTimeWindow(rule, minuteOfDay: minuteOfDay)

        case .dateRange:
            let md = month * 100 + day
            let sMD = rule.startMonth * 100 + rule.startDay
            let eMD = rule.endMonth * 100 + rule.endDay
            let dateOK = (sMD <= eMD) ? (md >= sMD && md <= eMD) : (md >= sMD || md <= eMD)
            return dateOK && matchesTimeWindow(rule, minuteOfDay: minuteOfDay)

        case .weekdays:
            let wdOK = rule.weekdays.isEmpty || rule.weekdays.contains(weekday)
            return wdOK && matchesTimeWindow(rule, minuteOfDay: minuteOfDay)

        case .dailyTime:
            return matchesTimeWindow(rule, minuteOfDay: minuteOfDay)

        case .solarOffset:
            let useLat = lat ?? 40.7128
            let useLon = lon ?? -74.0060
            guard let solar = SolarCalculator.sunriseSunset(date: date, latitude: useLat, longitude: useLon, timeZone: calendar.timeZone) else {
                return false
            }
            let base = (rule.solarEvent == .sunrise) ? solar.sunrise : solar.sunset
            let start = base.addingTimeInterval(Double(rule.solarOffsetMinutes) * 60.0)
            let end = start.addingTimeInterval(Double(max(5, rule.durationMinutes)) * 60.0)
            return date >= start && date <= end
        }
    }

    private func matchesTimeWindow(_ rule: SeasonalScheduleRule, minuteOfDay: Int) -> Bool {
        guard let sm = rule.startMinuteOfDay, let em = rule.endMinuteOfDay else { return true }
        return isMinuteInWindow(minuteOfDay, start: sm, end: em)
    }

    private func isMinuteInWindow(_ m: Int, start: Int, end: Int) -> Bool {
        if start <= end {
            return m >= start && m < end
        } else {
            return m >= start || m < end // Wraps past midnight
        }
    }

    private func computeNextBoundaryDate(after now: Date, automation: SeasonalAutomationConfig) -> Date {
        let cal = Calendar.current
        var candidates: [Date] = []
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) {
            candidates.append(tomorrow.addingTimeInterval(1.0))
        }
        if let exp = automation.manualOverrideExpiresAt, exp > now {
            candidates.append(exp.addingTimeInterval(0.5))
        }
        // Check today & tomorrow solar / daily clock minutes
        let todayStart = cal.startOfDay(for: now)
        for rule in automation.rules where rule.isEnabled {
            if let sm = rule.startMinuteOfDay {
                let d = todayStart.addingTimeInterval(Double(sm * 60))
                if d > now { candidates.append(d) }
            }
            if let em = rule.endMinuteOfDay {
                let d = todayStart.addingTimeInterval(Double(em * 60))
                if d > now { candidates.append(d) }
            }
        }
        if automation.quietHours.enabled {
            let qs = todayStart.addingTimeInterval(Double((automation.quietHours.startHour * 60 + automation.quietHours.startMinute) * 60))
            let qe = todayStart.addingTimeInterval(Double((automation.quietHours.endHour * 60 + automation.quietHours.endMinute) * 60))
            if qs > now { candidates.append(qs) }
            if qe > now { candidates.append(qe) }
        }
        return candidates.min() ?? now.addingTimeInterval(3600)
    }
}
