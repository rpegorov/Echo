//
//  ZoneSlot.swift
//  Echo
//

import Foundation

/// Where a window goes: a zone rect snapshot on one display. Persisted: any change bumps the schema version.
struct ZoneSlot: Codable, Hashable, Sendable {
    /// `DisplayKey.rawValue`.
    let display: String
    let rect: UnitRect

    /// Inside the unit square with a positive extent on both axes, within `GridEditing.tolerance`.
    var isValid: Bool {
        let tolerance = GridEditing.tolerance
        return rect.x >= -tolerance
            && rect.y >= -tolerance
            && rect.x + rect.width <= 1 + tolerance
            && rect.y + rect.height <= 1 + tolerance
            && rect.width > tolerance
            && rect.height > tolerance
    }
}

struct SavedDisplay: Codable, Equatable, Sendable {
    let name: String
    let aspect: Double
}
