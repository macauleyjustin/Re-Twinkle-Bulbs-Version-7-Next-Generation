import Foundation
import CoreGraphics

// MARK: - Part IX: Weather-Reactive Decorations & Time-of-Day Brightness Curve

public struct AtmosphereModulation {
    public var brightnessMultiplier: Double = 1.0
    public var warmthShift: Double = 0.0 // >0 warmer candlelight, <0 crisp icy blue
    public var speedMultiplier: Double = 1.0
    public var suggestedScreenSaver: ScreenSaverModuleID? = nil
    public var description: String = "Standard"
}

public final class WeatherAtmosphereService {
    public static let shared = WeatherAtmosphereService()

    public private(set) var lastObservedWeather: SimulatedWeatherCondition = .none
    public private(set) var lastNetworkWeatherSummary: String = "Offline / Manual"

    private let store: NextGenStateStore

    public init(store: NextGenStateStore = .shared) {
        self.store = store
    }

    /// Computes clean, smooth Time-of-Day brightness envelope (Morning, Afternoon, Evening, Night).
    public func timeOfDayBrightness(at date: Date = Date(), config: TimeOfDayConfig? = nil, calendar: Calendar = .current) -> Double {
        let cfg = config ?? store.state.timeOfDay
        guard cfg.enabled else { return 1.0 }
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hourFloat = Double(comps.hour ?? 12) + Double(comps.minute ?? 0) / 60.0

        // Piecewise smooth curve across 24 hours
        switch hourFloat {
        case 6.0..<11.0:
            return cfg.morningBrightness
        case 11.0..<17.0:
            return cfg.afternoonBrightness
        case 17.0..<22.0:
            return cfg.eveningBrightness
        default:
            return cfg.nightBrightness
        }
    }

    /// Computes combined Time-of-Day + Solar/Weather modulation without unexpected network access.
    public func currentModulation(at date: Date = Date()) -> AtmosphereModulation {
        var mod = AtmosphereModulation()
        let todBright = timeOfDayBrightness(at: date)
        mod.brightnessMultiplier = todBright

        let wCfg = store.state.weatherConfig
        guard wCfg.enabled else { return mod }

        var effectiveWeather = wCfg.simulatedOverride
        if effectiveWeather == .none {
            // Compute local solar elevation cue purely offline via SolarCalculator
            if let sol = SolarCalculator.sunriseSunset(date: date, latitude: wCfg.latitude, longitude: wCfg.longitude) {
                if date < sol.sunrise || date > sol.sunset {
                    effectiveWeather = .clearNight
                } else {
                    effectiveWeather = .cloudy
                }
            } else {
                effectiveWeather = .clearNight
            }
        }
        lastObservedWeather = effectiveWeather

        switch effectiveWeather {
        case .snow:
            mod.warmthShift = -0.25
            mod.speedMultiplier = 0.85
            mod.suggestedScreenSaver = .snowfallVillage
            mod.description = "Snowfall Atmosphere (Cool Shimmer)"
        case .clearNight:
            mod.warmthShift = -0.15
            mod.speedMultiplier = 0.90
            mod.suggestedScreenSaver = .summerNightSky
            mod.description = "Clear Night Sky (Starry Twinkle)"
        case .rain:
            mod.warmthShift = -0.30
            mod.speedMultiplier = 0.78
            mod.suggestedScreenSaver = .springRain
            mod.description = "Gentle Rain (Soft Ripple Flow)"
        case .windy:
            mod.warmthShift = 0.05
            mod.speedMultiplier = 1.35
            mod.description = "Breezy / Gusty Motion"
        case .cloudy:
            mod.warmthShift = 0.20
            mod.speedMultiplier = 0.95
            mod.description = "Warm Cozy Indoor Glow"
        case .none:
            break
        }
        return mod
    }

    /// Explicit opt-in network fetch (Open-Meteo public keyless API) ONLY when user enables BOTH
    /// `weatherConfig.enabled` AND `weatherConfig.networkWeatherDisclosedAndAllowed`.
    public func refreshLiveWeatherIfAuthorized(completion: ((SimulatedWeatherCondition, String) -> Void)? = nil) {
        let cfg = store.state.weatherConfig
        guard cfg.enabled, cfg.networkWeatherDisclosedAndAllowed, cfg.simulatedOverride == .none else {
            let cond = currentModulation().description
            completion?(lastObservedWeather, cond)
            return
        }
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(cfg.latitude)&longitude=\(cfg.longitude)&current=weather_code"
        guard let url = URL(string: urlStr) else { return }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, err in
            guard let self else { return }
            guard err == nil, let data,
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let wmo = current["weather_code"] as? Int else {
                DispatchQueue.main.async {
                    self.lastNetworkWeatherSummary = "Offline fallback active"
                    completion?(self.lastObservedWeather, self.lastNetworkWeatherSummary)
                }
                return
            }
            let mapped: SimulatedWeatherCondition
            switch wmo {
            case 71...77, 85...86: mapped = .snow
            case 51...67, 80...82, 95...99: mapped = .rain
            case 2...48: mapped = .cloudy
            default: mapped = .clearNight
            }
            DispatchQueue.main.async {
                self.lastObservedWeather = mapped
                self.lastNetworkWeatherSummary = "Live WMO=\(wmo) (\(mapped.rawValue))"
                completion?(mapped, self.lastNetworkWeatherSummary)
            }
        }
        task.resume()
    }
}
