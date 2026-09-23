//
//  AppEnergyUsage.swift
//  Echo
//

import Foundation

/// Energy consumed by one app over an ``EnergyInterval``.
struct AppEnergyUsage: Equatable, Codable, Identifiable {
    let id: String
    let appName: String
    let bundleID: String?
    let energyNJ: UInt64
}
