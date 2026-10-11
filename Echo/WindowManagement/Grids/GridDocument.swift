//
//  GridDocument.swift
//  Echo
//

import Foundation

/// The grid a display uses.
enum ActiveGridRef: Codable, Hashable, Sendable {
    case template(kind: GridTemplate)
    case saved(id: UUID)
}

/// Everything persisted about grids. Any change to the stored shape bumps `GridFileStorage.schemaVersion`;
/// new fields are Optional so files of the previous version still decode.
struct GridDocument: Codable, Equatable, Sendable {
    var grids: [ZoneGrid]
    /// Keyed by `DisplayKey.rawValue` so the file holds a plain JSON object.
    var activeByDisplay: [String: ActiveGridRef]

    static let empty = GridDocument(grids: [], activeByDisplay: [:])

    func activeRef(for display: DisplayKey) -> ActiveGridRef? {
        activeByDisplay[display.rawValue]
    }

    func activeZones(for display: DisplayKey?, aspect: Double) -> [UnitRect] {
        switch display.flatMap(activeRef(for:)) {
        case .template(kind: let kind)?:
            return kind.zones
        case .saved(id: let id)?:
            if let grid = grids.first(where: { $0.id == id }) { return grid.zones }
        case nil:
            break
        }
        return GridTemplate.default(forAspect: aspect).zones
    }

    /// Replaces the grid with the same id, or appends it.
    mutating func save(_ grid: ZoneGrid) {
        if let index = grids.firstIndex(where: { $0.id == grid.id }) {
            grids[index] = grid
        } else {
            grids.append(grid)
        }
    }

    mutating func rename(_ id: UUID, to name: String) {
        guard let index = grids.firstIndex(where: { $0.id == id }) else { return }
        grids[index].name = name
    }

    /// Removes the grid; displays that used it fall back to their default template.
    mutating func delete(_ id: UUID) {
        grids.removeAll { $0.id == id }
        activeByDisplay = activeByDisplay.filter { $0.value != .saved(id: id) }
    }

    mutating func setActive(_ ref: ActiveGridRef, for display: DisplayKey) {
        activeByDisplay[display.rawValue] = ref
    }
}
