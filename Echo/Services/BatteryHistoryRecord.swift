//
//  BatteryHistoryRecord.swift
//  Echo
//

import Foundation

/// Current on-disk line format version. Bump when the payload shape changes;
/// older/unknown versions are skipped rather than crashing the reader.
let batteryHistoryRecordVersion = 1

/// One JSON Lines record in the battery history file: either a level reading
/// or a per-interval energy summary, tagged by `kind` so a single file can
/// hold both without a wrapping array (which would force full-file rewrites).
struct BatteryHistoryRecord: Codable {
    enum Kind: String, Codable {
        case reading
        case interval
    }

    let v: Int
    let kind: Kind
    let reading: BatteryReading?
    let interval: EnergyInterval?

    init(reading: BatteryReading) {
        self.v = batteryHistoryRecordVersion
        self.kind = .reading
        self.reading = reading
        self.interval = nil
    }

    init(interval: EnergyInterval) {
        self.v = batteryHistoryRecordVersion
        self.kind = .interval
        self.reading = nil
        self.interval = interval
    }
}
