//
//  SMCStaticKeyFilter.swift
//  Echo
//

import Foundation

/// Tells sensor keys from threshold constants: a key whose value stays
/// identical across the whole observation window is a limit stored in the SMC
/// (per-cluster throttle points read ~90–105 °C on M4 Max), not a measurement,
/// and must not drive the maximum. A key that has moved is trusted from then
/// on; a proven-static key re-enters if it ever moves.
struct SMCStaticKeyFilter {
    private struct Observation {
        var initialValue: Double
        var identicalReads = 0
        var hasMoved = false
    }

    /// Real sensors wobble even at idle; a key identical for this many
    /// consecutive reads is a stored constant.
    static let defaultSampleThreshold = 12

    private var observations: [String: Observation] = [:]
    private let sampleThreshold: Int

    init(sampleThreshold: Int = SMCStaticKeyFilter.defaultSampleThreshold) {
        self.sampleThreshold = sampleThreshold
    }

    /// True once the key has stayed identical for the whole window.
    mutating func isStatic(key: String, value: Double) -> Bool {
        var observation = observations[key] ?? Observation(initialValue: value)
        defer { observations[key] = observation }

        if value != observation.initialValue {
            observation.hasMoved = true
            return false
        }
        guard !observation.hasMoved else { return false }
        observation.identicalReads += 1
        return observation.identicalReads > sampleThreshold
    }
}
