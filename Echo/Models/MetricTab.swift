//
//  MetricTab.swift
//  MonitorBarApp
//

import SwiftUI

enum MetricTab: String, CaseIterable {
    case cpu     = "CPU"
    case memory  = "Memory"
    case network = "Network"
    case disk    = "Disk"
    case battery = "Battery"

    var icon: String {
        switch self {
        case .cpu:     return "cpu"
        case .memory:  return "memorychip"
        case .network: return "network"
        case .disk:    return "externaldrive"
        case .battery: return "battery.100"
        }
    }

    /// Tabs to show given whether this Mac has a battery — hides `.battery` on desktops.
    static func visibleCases(hasBattery: Bool) -> [MetricTab] {
        hasBattery ? allCases : allCases.filter { $0 != .battery }
    }

    /// Tabs selectable for the menu bar display. Battery isn't a live-updating
    /// number suited to the status item, so it's excluded here regardless of hardware.
    static let menuBarSelectable: [MetricTab] = allCases.filter { $0 != .battery }
}
