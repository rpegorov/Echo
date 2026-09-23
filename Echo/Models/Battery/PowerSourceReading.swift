//
//  PowerSourceReading.swift
//  Echo
//

import Foundation

/// One-shot read of the current power source state.
protocol PowerSourceReading: Sendable {
    func hasBattery() -> Bool
    func read() -> BatteryReading?
}
