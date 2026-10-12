//
//  GridDocument.swift
//  Echo
//

import Foundation

/// The grid a display uses.
/// Persisted: any change to the stored shape bumps `GridFileStorage.schemaVersion`.
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
    /// nil in files of schema version 1.
    var arrangements: [Arrangement]?
    /// nil in files of schema version 1.
    var autoRules: [AutoRule]?

    static let empty = GridDocument(grids: [], activeByDisplay: [:], arrangements: nil, autoRules: nil)

    var savedArrangements: [Arrangement] { arrangements ?? [] }
    var rules: [AutoRule] { autoRules ?? [] }

    func rule(forBundleID bundleID: String) -> AutoRule? {
        rules.first { $0.bundleID == bundleID }
    }

    func activeRef(for display: DisplayKey) -> ActiveGridRef? {
        activeByDisplay[display.rawValue]
    }

    func activeZones(for display: DisplayKey?, aspect: Double) -> [UnitRect] {
        switch display.flatMap(activeRef(for:)) {
        case .template(kind: let kind)?:
            return kind.zones
        case .saved(id: let id)?:
            if let grid = grids.first(where: { $0.id == id }), !grid.zones.isEmpty { return grid.zones }
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

    /// Replaces the arrangement with the same id, or appends it.
    mutating func saveArrangement(_ arrangement: Arrangement) {
        var list = savedArrangements
        if let index = list.firstIndex(where: { $0.id == arrangement.id }) {
            list[index] = arrangement
        } else {
            list.append(arrangement)
        }
        arrangements = list
    }

    mutating func deleteArrangement(_ id: UUID) {
        guard var list = arrangements else { return }
        list.removeAll { $0.id == id }
        arrangements = list
    }

    /// Replaces the rule with the same id or the same bundle id, or appends it.
    mutating func saveRule(_ rule: AutoRule) {
        var list = rules
        list.removeAll { $0.id == rule.id || $0.bundleID == rule.bundleID }
        list.append(rule)
        autoRules = list
    }

    mutating func deleteRule(_ id: UUID) {
        guard var list = autoRules else { return }
        list.removeAll { $0.id == id }
        autoRules = list
    }

    mutating func setRuleEnabled(_ id: UUID, _ isEnabled: Bool) {
        guard var list = autoRules, let index = list.firstIndex(where: { $0.id == id }) else { return }
        list[index].isEnabled = isEnabled
        autoRules = list
    }
}
