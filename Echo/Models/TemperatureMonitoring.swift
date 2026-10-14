//
//  TemperatureMonitoring.swift
//  Echo
//

import Foundation

protocol TemperatureMonitoring: Sendable {
    /// Max CPU/GPU sensor values, or nil when this Mac exposes no readable sensors.
    func read() async -> TemperatureSample?
}

// Mock for previews and tests.
struct MockTemperatureMonitor: TemperatureMonitoring {
    var sample: TemperatureSample?

    init(sample: TemperatureSample? = nil) {
        self.sample = sample
    }

    func read() async -> TemperatureSample? { sample }
}
