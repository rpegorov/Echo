//
//  MetricsKey.swift
//  Echo
//

import Foundation

/// Strings for the metrics detail window (S1b owns cases and the Metrics table).
enum MetricsKey: LocalizedKey {
    static var table: String { "Metrics" }

    var rawValue: String {
        switch self {}
    }
    init?(rawValue: String) { nil }
    static var allCases: [MetricsKey] { [] }
}
