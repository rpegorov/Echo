//
//  PowerSourceReading.swift
//  Echo
//

import Foundation

/// One-shot read of the current power source state.
protocol PowerSourceReading {
    func hasBattery() -> Bool
    func read() -> BatteryReading?
}
