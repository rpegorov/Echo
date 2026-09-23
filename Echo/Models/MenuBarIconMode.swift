//
//  MenuBarIconMode.swift
//  MonitorBarApp
//

/// Что показывать в строке меню.
enum MenuBarIconMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case appIcon
    case metrics
    case custom

    var id: String { rawValue }
}
