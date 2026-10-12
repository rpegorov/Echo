import Foundation
import Testing
@testable import Echo

private func zone(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> UnitRect {
    UnitRect(x: x, y: y, width: width, height: height)
}

private func grid(_ name: String = "Work", zones: [UnitRect]) -> ZoneGrid {
    ZoneGrid(id: UUID(), name: name, zones: zones)
}

/// Each case breaks exactly one rule of a valid grid.
private let invalidZoneLists: [(label: String, zones: [UnitRect])] = [
    ("empty list", []),
    ("overlapping zones", [zone(0, 0, 0.6, 1), zone(0.5, 0, 0.5, 1)]),
    ("hole between zones", [zone(0, 0, 0.4, 1), zone(0.6, 0, 0.4, 1)]),
    ("zone extending past the right edge", [zone(0, 0, 0.5, 1), zone(0.5, 0, 0.6, 1)]),
    ("zone outside the unit square", [zone(1.2, 0, 0.5, 1)]),
    ("zone with negative origin", [zone(-0.1, 0, 1.1, 1)]),
    ("zero-width zone", [zone(0, 0, 1, 1), zone(0.5, 0, 0, 1)]),
]

@MainActor
@Suite("Grid store validation")
struct GridStoreValidationTests {

    @Test("a valid grid is saved and published", arguments: GridTemplate.allCases)
    func validGridIsSaved(template: GridTemplate) throws {
        #expect(GridEditing.isValid(template.zones))
        let storage = InMemoryGridStorage()
        let store = GridStore(storage: storage)
        let work = grid(zones: template.zones)

        try store.save(work)

        #expect(store.document.grids == [work])
        #expect(storage.document == store.document)
        #expect(storage.saveCount == 1)
    }

    @Test("an invalid grid is rejected before storage is touched", arguments: invalidZoneLists)
    func invalidGridIsRejected(case entry: (label: String, zones: [UnitRect])) {
        #expect(!GridEditing.isValid(entry.zones))
        let storage = InMemoryGridStorage()
        let store = GridStore(storage: storage)
        let before = store.document

        #expect(throws: GridStorageError.invalidGrid) { try store.save(grid(zones: entry.zones)) }

        #expect(store.document == before)
        #expect(storage.document == before)
        #expect(storage.saveCount == 0)
    }

    @Test("an invalid edit of an existing grid keeps the stored version")
    func invalidUpdateKeepsStoredGrid() throws {
        let storage = InMemoryGridStorage()
        let store = GridStore(storage: storage)
        let original = grid("Kept", zones: GridTemplate.twoByTwo.zones)
        try store.save(original)
        let before = store.document

        var broken = original
        broken.zones = [zone(0, 0, 0.6, 1), zone(0.5, 0, 0.5, 1)]
        #expect(throws: GridStorageError.invalidGrid) { try store.save(broken) }

        #expect(store.document == before)
        #expect(store.document.grids == [original])
        #expect(storage.saveCount == 1)
    }

    @Test("a rejected save does not block later valid saves")
    func storeAcceptsValidGridAfterRejection() throws {
        let storage = InMemoryGridStorage()
        let store = GridStore(storage: storage)
        #expect(throws: GridStorageError.invalidGrid) { try store.save(grid(zones: [])) }

        let good = grid("Good", zones: GridTemplate.twoColumns.zones)
        try store.save(good)

        #expect(store.document.grids == [good])
        #expect(storage.saveCount == 1)
    }
}
