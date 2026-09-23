//
//  ContinuousTickSleeper.swift
//  Echo
//

import Foundation

/// Production ``TickSleeper`` backed by `ContinuousClock`, so the tick loop
/// keeps running across system sleep (unlike `SuspendingClock`).
struct ContinuousTickSleeper: TickSleeper {
    func sleep(for interval: Duration) async throws {
        try await ContinuousClock().sleep(for: interval, tolerance: .seconds(1))
    }
}
