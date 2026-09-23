//
//  ProcessEnergyReading.swift
//  Echo
//

import Foundation

/// Samples per-process energy counters for all visible processes.
protocol ProcessEnergyReading: Sendable {
    func snapshot() async -> ProcessEnergySnapshot
}
