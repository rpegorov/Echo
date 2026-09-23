//
//  AppearanceMode.swift
//  MonitorBarApp
//

import AppKit

/// Режим оформления приложения.
enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system, light, dark

    var id: String { rawValue }

    /// Соответствующий `NSAppearance` (nil — следовать системе).
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }
}
