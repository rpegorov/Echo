//
//  BatteryHistoryStoring.swift
//  Echo
//

import Foundation

/// Persists battery readings and energy intervals to durable storage.
protocol BatteryHistoryStoring {
    func load(since: Date) async throws -> BatteryHistory
    func append(_ reading: BatteryReading) async throws
    func append(_ interval: EnergyInterval) async throws
    func compact(keepingSince: Date) async throws
}
