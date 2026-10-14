//
//  AutoRule.swift
//  Echo
//

import Foundation

/// "Always put new windows of this app into this zone". One rule per app.
/// Persisted: any change to the stored shape bumps `GridFileStorage.schemaVersion`.
struct AutoRule: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let bundleID: String
    /// Data, not a localization key.
    let appName: String
    var slot: ZoneSlot
    var display: SavedDisplay
    var isEnabled: Bool
}
