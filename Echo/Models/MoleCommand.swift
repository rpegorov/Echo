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

    var title: String {
        switch self {
        case .clean:     return "Deep Clean"
        case .purge:     return "Dev Artifacts"
        case .analyze:   return "Analyze Disk"
        case .uninstall: return "Uninstall Apps"
        }
    }

    var subtitle: String {
        switch self {
        case .clean:     return "Кэши, логи, временные файлы, хвосты удалённых приложений"
        case .purge:     return "node_modules, DerivedData, target, build, dist"
        case .analyze:   return "Визуальный обзор, что занимает место"
        case .uninstall: return "Удаление приложений вместе с их данными"
        }
    }

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
