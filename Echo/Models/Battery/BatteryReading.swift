//
//  BatteryReading.swift
//  Echo
//

import Foundation

/// A single point-in-time battery sample.
struct BatteryReading: Equatable, Codable {
    let date: Date
    let level: Int
    let isCharging: Bool
    let isOnAC: Bool
}
