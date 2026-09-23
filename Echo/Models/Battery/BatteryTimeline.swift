//
//  BatteryTimeline.swift
//  Echo
//

import Foundation

/// Pure helpers that turn a flat, chronologically-sorted reading list into
/// chart-ready shapes: gap-separated segments (so the chart never bridges a
/// stretch where Echo wasn't running) and charging bands.
enum BatteryTimeline {
    /// Readings more than this far apart are treated as separate segments.
    static let maxGap: Duration = .seconds(12 * 60)

    private static var maxGapInterval: TimeInterval {
        let components = maxGap.components
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18
    }

    /// Splits readings into runs with no gap larger than ``maxGap`` between
    /// consecutive samples. Each returned array is sorted by date.
    static func segments(_ readings: [BatteryReading]) -> [[BatteryReading]] {
        let sorted = readings.sorted { $0.date < $1.date }
        guard let first = sorted.first else { return [] }

        var result: [[BatteryReading]] = [[first]]
        let gapThreshold = maxGapInterval
        for reading in sorted.dropFirst() {
            let previousDate = result[result.count - 1].last!.date
            if reading.date.timeIntervalSince(previousDate) > gapThreshold {
                result.append([reading])
            } else {
                result[result.count - 1].append(reading)
            }
        }
        return result
    }

    /// Contiguous date ranges where the device was charging, derived from
    /// consecutive `isCharging` readings.
    static func chargingIntervals(_ readings: [BatteryReading]) -> [ClosedRange<Date>] {
        let sorted = readings.sorted { $0.date < $1.date }
        var ranges: [ClosedRange<Date>] = []
        var runStart: Date?
        var runEnd: Date?

        for reading in sorted {
            guard reading.isCharging else {
                if let start = runStart, let end = runEnd {
                    ranges.append(start...end)
                }
                runStart = nil
                runEnd = nil
                continue
            }
            if runStart == nil { runStart = reading.date }
            runEnd = reading.date
        }
        if let start = runStart, let end = runEnd {
            ranges.append(start...end)
        }
        return ranges
    }
}
