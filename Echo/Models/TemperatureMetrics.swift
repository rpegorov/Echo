//
//  TemperatureMetrics.swift
//  Echo
//

import Foundation

/// Current CPU/GPU temperatures in degrees Celsius — the maximum across each
/// component's SMC sensors. A nil component has no readable sensors.
struct TemperatureSample: Sendable, Equatable {
    var cpu: Double?
    var gpu: Double?
}
