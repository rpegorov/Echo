//
//  ProcessEnergyReading.swift
//  Echo
//

import Foundation

/// Samples per-process energy counters for all visible processes.
protocol ProcessEnergyReading {
    func snapshot() async -> ProcessEnergySnapshot
}
