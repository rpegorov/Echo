//
//  BatteryHistory.swift
//  Echo
//

import Foundation

/// In-memory battery timeline: level readings plus per-interval energy usage,
/// kept to a rolling window (24h) by callers via ``pruned(keepingSince:)``.
struct BatteryHistory: Equatable {
    var readings: [BatteryReading]
    var intervals: [EnergyInterval]

    init(readings: [BatteryReading] = [], intervals: [EnergyInterval] = []) {
        self.readings = readings
        self.intervals = intervals
    }

    /// Returns a copy with everything older than `cutoff` dropped.
    func pruned(keepingSince cutoff: Date) -> BatteryHistory {
        BatteryHistory(
            readings: readings.filter { $0.date >= cutoff },
            intervals: intervals.filter { $0.end >= cutoff }
        )
    }
}
