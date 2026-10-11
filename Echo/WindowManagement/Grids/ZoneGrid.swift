//
//  ZoneGrid.swift
//  Echo
//

import Foundation

/// A saved grid. `zones` cover the visible area without overlap, in reading order; zone number = index + 1.
/// Persisted: any change to the stored shape bumps `GridFileStorage.schemaVersion`; new fields are Optional
/// so files of the previous version still decode.
struct ZoneGrid: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var zones: [UnitRect]
}
