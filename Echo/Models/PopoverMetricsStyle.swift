//
//  PopoverMetricsStyle.swift
//  Echo
//

import Foundation

/// How CPU, memory and disk load is drawn in the popover.
enum PopoverMetricsStyle: String, CaseIterable, Identifiable, Codable {
    case rings, bars

    var id: String { rawValue }
}
