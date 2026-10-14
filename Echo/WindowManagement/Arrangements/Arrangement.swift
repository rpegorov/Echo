//
//  Arrangement.swift
//  Echo
//

import Foundation

/// A saved layout of several apps' windows. Persisted: any change bumps `GridFileStorage.schemaVersion`.
struct Arrangement: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    /// Entries of one app keep the order the app reports its windows in at capture time.
    var windows: [ArrangedWindow]
    var displays: [String: SavedDisplay]
}

struct ArrangedWindow: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let bundleID: String
    let appName: String
    let titleHint: String?
    var slot: ZoneSlot
}
