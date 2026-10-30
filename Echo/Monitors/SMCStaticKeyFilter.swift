//
//  SMCStaticKeyFilter.swift
//  Echo
//

import Foundation

/// Tells sensor keys from stored limits: a key that has never moved, or that
/// holds one value across the whole observation window, is a limit kept in
/// the SMC (per-cluster throttle points read ~90–105 °C on M4 Max), not a
/// measurement, and must not drive the maximum. Real sensors wobble even at
/// idle, so a key joins the maximum at its first movement; a settled key
/// re-enters when it moves again.
struct SMCStaticKeyFilter {
    private struct Observation {
        var lastValue: Double
        var stableReads = 0
        var hasMoved = false
    }

    /// Real sensors wobble even at idle; a key holding one value across this
    /// many reads has settled into a stored constant.
    static let defaultSampleThreshold = 12

    private var observations: [String: Observation] = [:]
    private let sampleThreshold: Int

    init(sampleThreshold: Int = SMCStaticKeyFilter.defaultSampleThreshold) {
        self.sampleThreshold = sampleThreshold
    }

    /// True while the key has never moved or has held one value for the
    /// whole window.
    mutating func isStatic(key: String, value: Double) -> Bool {
        var observation = observations[key] ?? Observation(lastValue: value)
        defer { observations[key] = observation }

        if value != observation.lastValue {
            observation.lastValue = value
            observation.stableReads = 0
            observation.hasMoved = true
            return false
        }
        observation.stableReads += 1
        return !observation.hasMoved || observation.stableReads > sampleThreshold
    }
}
