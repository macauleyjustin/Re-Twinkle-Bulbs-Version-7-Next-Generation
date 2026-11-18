import Foundation
import Cocoa
import IOKit.ps

// MARK: - Part XIV: Adaptive Performance Management & Accessibility Coordinator

public struct PerformanceTelemetry {
    public var onBatteryPower: Bool
    public var isLowPowerMode: Bool
    public var thermalState: ProcessInfo.ThermalState
    public var recommendedModernFPS: Double
    public var effectiveFrameIntervalSeconds: Double
    public var reduceMotionActive: Bool
    public var highContrastActive: Bool
    public var summaryText: String
}

public final class PerformanceCoordinator {
    public static let shared = PerformanceCoordinator()

    public init() {}

    public func isOnBatteryPower() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let typeCF = IOPSGetProvidingPowerSourceType(blob)?.takeRetainedValue() else {
            return false
        }
        let typeStr = typeCF as String
        return typeStr == kIOPSBatteryPowerValue
    }

    public func currentTelemetry(
        settings optSettings: AppSettings? = nil,
        policy optPolicy: PerformancePolicyConfig? = nil
    ) -> PerformanceTelemetry {
        let settings = optSettings ?? SettingsStore.shared.settings
        let policy = optPolicy ?? NextGenStateStore.shared.state.performance
        let onBattery = isOnBatteryPower()
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let thermal = ProcessInfo.processInfo.thermalState
        let reduceMotion = settings.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let highContrast = policy.highContrastMode || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast

        // Never disturb historical Classic v6.0 exact 50 ms tick timing!
        guard settings.lightingCategory == .modern else {
            return PerformanceTelemetry(
                onBatteryPower: onBattery,
                isLowPowerMode: lowPower,
                thermalState: thermal,
                recommendedModernFPS: 20.0,
                effectiveFrameIntervalSeconds: 0.050,
                reduceMotionActive: reduceMotion,
                highContrastActive: highContrast,
                summaryText: "Classic Engine (Fixed 50ms Cadence)"
            )
        }

        if reduceMotion {
            return PerformanceTelemetry(
                onBatteryPower: onBattery,
                isLowPowerMode: lowPower,
                thermalState: thermal,
                recommendedModernFPS: 4.0,
                effectiveFrameIntervalSeconds: 0.250,
                reduceMotionActive: true,
                highContrastActive: highContrast,
                summaryText: "Reduce Motion Active (4 FPS Gentle Mode)"
            )
        }

        var targetFPS: Double = 30.0
        var reason = "Normal 30 FPS"

        if policy.adaptiveManagementEnabled {
            if lowPower || thermal == .serious || thermal == .critical {
                targetFPS = policy.throttleUnderHighLoad ? 15.0 : 30.0
                reason = "Throttled 15 FPS (\(lowPower ? "Low Power" : "Thermal"))"
            } else if onBattery && policy.throttleOnBattery {
                targetFPS = 20.0
                reason = "Battery Saver 20 FPS"
            } else if !onBattery && thermal == .nominal && !lowPower {
                targetFPS = 60.0
                reason = "AC Power Full 60 FPS"
            }
        }

        return PerformanceTelemetry(
            onBatteryPower: onBattery,
            isLowPowerMode: lowPower,
            thermalState: thermal,
            recommendedModernFPS: targetFPS,
            effectiveFrameIntervalSeconds: 1.0 / targetFPS,
            reduceMotionActive: reduceMotion,
            highContrastActive: highContrast,
            summaryText: reason
        )
    }
}
