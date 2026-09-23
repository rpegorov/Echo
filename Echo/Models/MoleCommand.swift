//
//  MoleCommand.swift
//  MonitorBarApp
//

import Foundation

/// Команды Mole (https://github.com/tw93/Mole), которые мы предлагаем из UI.
enum MoleCommand: String, CaseIterable, Identifiable {
    case clean
    case purge
    case analyze
    case uninstall

    var id: String { rawValue }

    /// Localized title/subtitle live in `MetricsKey` (`titleKey`/`subtitleKey`)
    /// next to the rest of the Metrics table's keys.

    var icon: String {
        switch self {
        case .clean:     return "sparkles"
        case .purge:     return "hammer"
        case .analyze:   return "chart.pie"
        case .uninstall: return "trash"
        }
    }

    /// Поддерживает ли команда безопасное превью через --dry-run.
    var supportsDryRun: Bool {
        switch self {
        case .clean, .purge, .uninstall: return true
        case .analyze:                   return false
        }
    }
}
