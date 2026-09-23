//
//  TickSleeper.swift
//  Echo
//

import Foundation

/// Injectable clock tick, so ``BatteryService``'s polling loop is testable
/// without real delays.
protocol TickSleeper {
    func sleep(for interval: Duration) async throws
}
