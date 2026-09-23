//
//  MetricsKey.swift
//  Echo
//

import Foundation

/// Strings for the metrics detail window (S1b owns further cases and the Metrics table).
enum MetricsKey: String, LocalizedKey {
    case tabCPU
    case tabMemory
    case tabNetwork
    case tabDisk

    static var table: String { "Metrics" }
}

extension MetricTab {
    /// Localized display name; `rawValue` stays a persisted identifier.
    var titleKey: MetricsKey {
        switch self {
        case .cpu:     return .tabCPU
        case .memory:  return .tabMemory
        case .network: return .tabNetwork
        case .disk:    return .tabDisk
        }
    }
}
