//
//  FailingBatteryHistoryStore.swift
//  Echo
//

import Foundation

/// A `BatteryHistoryStoring` that fails every operation with a captured error.
///
/// Used when the real on-disk location cannot be determined (e.g.
/// `BatteryHistoryStore.defaultURL()` threw during composition). Handing this
/// to `BatteryService` instead surfaces the error through the normal
/// `lastError` path on first use, rather than crashing app launch or
/// silently dropping the failure.
struct FailingBatteryHistoryStore: BatteryHistoryStoring {
    let error: BatteryError

    func load(since: Date) async throws -> BatteryHistory { throw error }
    func append(_ reading: BatteryReading) async throws { throw error }
    func append(_ interval: EnergyInterval) async throws { throw error }
    func compact(keepingSince: Date) async throws { throw error }
}
