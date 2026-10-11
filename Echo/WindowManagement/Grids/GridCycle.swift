//
//  GridCycle.swift
//  Echo
//

import Foundation

/// The sequence the "next grid" command walks through: saved grids first, then templates.
enum GridCycle {

    static func order(saved: [ZoneGrid]) -> [ActiveGridRef] {
        saved.filter { !$0.zones.isEmpty }.map { .saved(id: $0.id) }
            + GridTemplate.allCases.map { .template(kind: $0) }
    }

    /// The ref after `current` in `order(saved:)`; a nil `current` or one missing from
    /// the list resumes from the default template for `aspect`.
    static func next(after current: ActiveGridRef?, saved: [ZoneGrid], aspect: Double) -> ActiveGridRef {
        let list = order(saved: saved)
        let defaultTemplate = ActiveGridRef.template(kind: GridTemplate.default(forAspect: aspect))
        let effectiveIndex = current.flatMap { list.firstIndex(of: $0) }
            ?? list.firstIndex(of: defaultTemplate)
            ?? list.startIndex
        return list[(effectiveIndex + 1) % list.count]
    }
}
