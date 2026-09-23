//
//  SpeedFormatter.swift
//  MonitorBarApp
//

import Foundation

/// Единственное место форматирования скорости сети — используется и попапом,
/// и строкой меню, и моделью метрик, чтобы значения нигде не расходились.
enum SpeedFormatter {
    /// Legacy entry point kept for callers without access to a `Localizer`
    /// (e.g. the popover and the status item). Units stay in English.
    static func string(forKBPerSec speed: Double) -> String {
        format(speed, unitKB: "KB/s", unitMB: "MB/s")
    }

    /// Localized entry point: units follow the app's chosen language.
    @MainActor
    static func format(kbPerSec speed: Double, using localizer: Localizer) -> String {
        format(speed,
               unitKB: localizer.t(MetricsKey.speedUnitKB),
               unitMB: localizer.t(MetricsKey.speedUnitMB))
    }

    private static func format(_ speed: Double, unitKB: String, unitMB: String) -> String {
        speed < 1024
            ? String(format: "%.1f \(unitKB)", speed)
            : String(format: "%.2f \(unitMB)", speed / 1024)
    }
}
