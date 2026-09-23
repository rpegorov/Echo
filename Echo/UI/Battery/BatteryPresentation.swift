//
//  BatteryPresentation.swift
//  Echo
//
//  Pure, view-independent mapping from raw battery state (charging / on-AC /
//  level) to the SF Symbol, tint color and status text used by BatteryRow and
//  BatteryDetailView. No SwiftUI view logic here — keep it testable in
//  isolation (see BatteryPresentationTests).
//

import SwiftUI

enum BatteryPresentation {

    /// The status line shown next to the level percentage.
    enum Status {
        case charging
        case onPowerAdapter
        case charged
        case onBattery

        var localizedKey: BatteryKey {
            switch self {
            case .charging:       return .charging
            case .onPowerAdapter: return .onPowerAdapter
            case .charged:        return .charged
            case .onBattery:      return .onBattery
            }
        }
    }

    /// SF Symbol for the battery icon: `battery.100.bolt` while charging,
    /// otherwise stepped by level.
    static func symbolName(isCharging: Bool, level: Int) -> String {
        if isCharging { return "battery.100.bolt" }
        switch level {
        case 88...:   return "battery.100"
        case 63..<88: return "battery.75"
        case 38..<63: return "battery.50"
        case 13..<38: return "battery.25"
        default:      return "battery.0"
        }
    }

    /// Tint color following battery semantics (high level is good): green
    /// above 20%, orange between 10–20%, red below 10%. Always green while
    /// charging, regardless of the current level.
    static func tintColor(isCharging: Bool, level: Int) -> Color {
        if isCharging { return .green }
        switch level {
        case ..<10:  return .red
        case 10...20: return .orange
        default:      return .green
        }
    }

    /// Status derived from the raw reading fields. `isOnAC && level >= 100`
    /// (and not currently charging) reads as `.charged`, not `.onBattery`.
    static func status(isCharging: Bool, isOnAC: Bool, level: Int) -> Status {
        if isCharging { return .charging }
        if isOnAC { return level >= 100 ? .charged : .onPowerAdapter }
        return .onBattery
    }
}
