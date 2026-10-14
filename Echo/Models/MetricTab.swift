//
//  MetricTab.swift
//  MonitorBarApp
//

import SwiftUI

enum MetricTab: String, CaseIterable {
    case cpu         = "CPU"
    case temperature = "Temperature"
    case memory      = "Memory"
    case network     = "Network"
    case disk        = "Disk"
    case battery     = "Battery"

    var icon: String {
        switch self {
        case .cpu:         return "cpu"
        case .temperature: return "thermometer.medium"
        case .memory:      return "memorychip"
        case .network:     return "network"
        case .disk:        return "externaldrive"
        case .battery:     return "battery.100"
        }
    }

    /// Tabs to show given the hardware this Mac has — hides `.battery` on
    /// desktops and `.temperature` when no readable sensors exist.
    static func visibleCases(hasBattery: Bool, hasTemperature: Bool) -> [MetricTab] {
        var cases = allCases
        if !hasBattery { cases.removeAll { $0 == .battery } }
        if !hasTemperature { cases.removeAll { $0 == .temperature } }
        return cases
    }

    /// Tabs selectable for the menu bar display. Battery isn't a live-updating
    /// number suited to the status item, and temperature stays popover-only,
    /// so both are excluded regardless of hardware.
    static let menuBarSelectable: [MetricTab] = allCases.filter { $0 != .battery && $0 != .temperature }
}
