//
//  EnergyInterval.swift
//  Echo
//

import Foundation

/// Total on-battery energy draw over one sampling interval, with the top
/// consuming apps for that window (at most 10, descending by energy).
struct EnergyInterval: Equatable, Codable {
    let start: Date
    let end: Date
    let totalEnergyNJ: UInt64
    let top: [AppEnergyUsage]
}
