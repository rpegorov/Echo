import Foundation
import Testing
@testable import Echo

// The order the "next grid" command walks: saved grids with zones, then the five templates.

private let declaredTemplates: [GridTemplate] = [.twoColumns, .threeColumns, .twoByTwo, .mainAndSide, .mainAndTwoSides]
private let regularAspect = 1.6
private let ultrawideAspect = 2.4

private func savedGrid(_ name: String, zones: [UnitRect]? = nil) -> ZoneGrid {
    ZoneGrid(id: UUID(), name: name, zones: zones ?? GridTemplate.threeColumns.zones)
}

@Suite("Grid cycle order")
struct GridCycleOrderTests {

    @Test("with no saved grids the order is the templates in declaration order")
    func templatesOnly() {
        #expect(GridCycle.order(saved: []) == declaredTemplates.map { .template(kind: $0) })
    }

    @Test("saved grids come first in document order, templates after them")
    func savedBeforeTemplates() {
        let first = savedGrid("First")
        let second = savedGrid("Second")

        let order = GridCycle.order(saved: [first, second])

        #expect(order == [.saved(id: first.id), .saved(id: second.id)] + declaredTemplates.map { .template(kind: $0) })
    }

    @Test("a saved grid with no zones is skipped")
    func emptySavedGridSkipped() {
        let empty = savedGrid("Empty", zones: [])
        let usable = savedGrid("Usable")

        let order = GridCycle.order(saved: [empty, usable])

        #expect(!order.contains(.saved(id: empty.id)))
        #expect(order.first == .saved(id: usable.id))
        #expect(order.count == declaredTemplates.count + 1)
    }
}

@Suite("Grid cycle next")
struct GridCycleNextTests {

    @Test("the next entry follows the current one")
    func nextFollowsCurrent() {
        let saved = savedGrid("Thirds")

        #expect(GridCycle.next(after: .saved(id: saved.id), saved: [saved], aspect: regularAspect)
            == .template(kind: .twoColumns))
        #expect(GridCycle.next(after: .template(kind: .twoByTwo), saved: [saved], aspect: regularAspect)
            == .template(kind: .mainAndSide))
    }

    @Test("the last template wraps to the first saved grid")
    func wrapsToSavedGrid() {
        let saved = savedGrid("Thirds")

        let next = GridCycle.next(after: .template(kind: .mainAndTwoSides), saved: [saved], aspect: regularAspect)

        #expect(next == .saved(id: saved.id))
    }

    @Test("the last template wraps to the first template when nothing is saved")
    func wrapsToFirstTemplate() {
        let next = GridCycle.next(after: .template(kind: .mainAndTwoSides), saved: [], aspect: regularAspect)

        #expect(next == .template(kind: .twoColumns))
    }

    @Test("walking the cycle visits every entry once and returns to the start")
    func fullLoop() {
        let saved = [savedGrid("A"), savedGrid("B")]
        let order = GridCycle.order(saved: saved)
        var current: ActiveGridRef? = order[0]
        var visited: [ActiveGridRef] = []

        for _ in order {
            current = GridCycle.next(after: current, saved: saved, aspect: regularAspect)
            if let current { visited.append(current) }
        }

        #expect(visited == Array(order.dropFirst()) + [order[0]])
    }

    @Test("a deleted saved grid resumes after the default template of a regular display")
    func deletedSavedGridRegularDisplay() {
        let next = GridCycle.next(after: .saved(id: UUID()), saved: [], aspect: regularAspect)

        #expect(next == .template(kind: .threeColumns))
    }

    @Test("a deleted saved grid resumes after the default template of an ultrawide display")
    func deletedSavedGridUltrawideDisplay() {
        let next = GridCycle.next(after: .saved(id: UUID()), saved: [], aspect: ultrawideAspect)

        #expect(next == .template(kind: .twoByTwo))
    }

    @Test("no current grid resumes after the default template for the aspect")
    func nilCurrent() {
        #expect(GridCycle.next(after: nil, saved: [], aspect: regularAspect) == .template(kind: .threeColumns))
        #expect(GridCycle.next(after: nil, saved: [], aspect: ultrawideAspect) == .template(kind: .twoByTwo))
    }

    @Test("a saved grid emptied of zones counts as missing from the order")
    func emptiedSavedGridCountsAsMissing() {
        let emptied = savedGrid("Emptied", zones: [])

        let next = GridCycle.next(after: .saved(id: emptied.id), saved: [emptied], aspect: regularAspect)

        #expect(next == .template(kind: .threeColumns))
    }
}
