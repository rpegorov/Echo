import Foundation
import Testing
@testable import Echo

// Every arrangement and rule mutation goes through the store's commit: refused while the file may not
// be written, written before it is published, and never half done.

private typealias Mutation = (label: String, run: @MainActor (GridStore) throws -> Void)

private let knownArrangement = fixtureArrangement(id: fixtureArrangementID, name: "Known")
private let knownRule = fixtureRule(id: fixtureRuleID)

private let mutations: [Mutation] = [
    ("saveArrangement", { try $0.saveArrangement(fixtureArrangement()) }),
    ("deleteArrangement", { try $0.deleteArrangement(fixtureArrangementID) }),
    ("saveRule", { try $0.saveRule(fixtureRule(bundleID: "com.apple.Notes", appName: "Notes")) }),
    ("deleteRule", { try $0.deleteRule(fixtureRuleID) }),
    ("setRuleEnabled", { try $0.setRuleEnabled(fixtureRuleID, false) })
]

private let populated = GridDocument(
    grids: [], activeByDisplay: [:], arrangements: [knownArrangement], autoRules: [knownRule])

/// A load failure after which the store may not write, as the settings screen sees it.
private let readOnlyLoadErrors: [GridStorageError] = [.newerSchema(3), .readFailed("denied"), .writeFailed("no room")]

@MainActor
@Suite("Grid store arrangements and rules")
struct GridStoreArrangementTests {

    // MARK: Saving

    @Test("a valid arrangement is written, then published")
    func arrangementIsSavedAndPublished() throws {
        let storage = InMemoryGridStorage()
        let store = GridStore(storage: storage)
        let arrangement = fixtureArrangement()

        try store.saveArrangement(arrangement)

        #expect(store.document.savedArrangements == [arrangement])
        #expect(storage.document == store.document)
        #expect(storage.saveCount == 1)
    }

    @Test("saving an arrangement with a known id replaces it")
    func arrangementIsReplaced() throws {
        let storage = InMemoryGridStorage(document: populated)
        let store = GridStore(storage: storage)
        var renamed = knownArrangement
        renamed.name = "Renamed"

        try store.saveArrangement(renamed)

        #expect(store.document.savedArrangements == [renamed])
    }

    @Test("an arrangement without windows is accepted")
    func emptyArrangementIsAccepted() throws {
        let storage = InMemoryGridStorage()
        let store = GridStore(storage: storage)
        let empty = Arrangement(id: UUID(), name: "Nothing", windows: [], displays: [:])

        try store.saveArrangement(empty)

        #expect(store.document.savedArrangements == [empty])
    }

    @Test("one invalid slot rejects the whole arrangement before storage is touched",
          arguments: [(1.2, 0.0, 0.5, 1.0), (0.0, 0.0, 0.0, 1.0), (0.0, 0.0, 1.0, 0.0), (-0.2, 0.0, 0.5, 1.0), (0.6, 0.0, 0.6, 1.0)])
    func invalidSlotRejectsArrangement(x: Double, y: Double, width: Double, height: Double) {
        let storage = InMemoryGridStorage(document: populated)
        let store = GridStore(storage: storage)
        let broken = fixtureArrangement(windows: [
            fixtureWindow(slot: fixtureSlot("uuid:AAAA", 0, 0, 0.5, 1)),
            fixtureWindow(slot: fixtureSlot("uuid:AAAA", x, y, width, height))
        ])

        #expect(throws: GridStorageError.invalidSlot) { try store.saveArrangement(broken) }

        #expect(store.document == populated)
        #expect(storage.document == populated)
        #expect(storage.saveCount == 0)
    }

    @Test("an invalid edit of a stored arrangement keeps the stored version")
    func invalidEditKeepsStoredArrangement() {
        let storage = InMemoryGridStorage(document: populated)
        let store = GridStore(storage: storage)
        var broken = knownArrangement
        broken.windows = [fixtureWindow(slot: fixtureSlot("uuid:AAAA", 1.2, 0, 0.5, 1))]

        #expect(throws: GridStorageError.invalidSlot) { try store.saveArrangement(broken) }

        #expect(store.document.savedArrangements == [knownArrangement])
    }

    @Test("a valid rule is saved, and a rule for the same app replaces it")
    func ruleIsSavedAndReplaced() throws {
        let storage = InMemoryGridStorage(document: populated)
        let store = GridStore(storage: storage)
        let replacement = fixtureRule(bundleID: knownRule.bundleID, slot: fixtureSlot("uuid:AAAA", 0, 0, 0.5, 1))

        try store.saveRule(replacement)

        #expect(store.document.rules == [replacement])
        #expect(storage.document.rules == [replacement])
    }

    @Test("a rule with an invalid slot is rejected before storage is touched",
          arguments: [(1.2, 0.0, 0.5, 1.0), (0.0, 0.0, 0.0, 1.0)])
    func invalidSlotRejectsRule(x: Double, y: Double, width: Double, height: Double) {
        let storage = InMemoryGridStorage(document: populated)
        let store = GridStore(storage: storage)
        let broken = fixtureRule(bundleID: "com.apple.Notes", slot: fixtureSlot("uuid:AAAA", x, y, width, height))

        #expect(throws: GridStorageError.invalidSlot) { try store.saveRule(broken) }

        #expect(store.document == populated)
        #expect(storage.saveCount == 0)
    }

    // MARK: Deleting and switching

    @Test("deleting an arrangement and a rule writes once each and publishes the result")
    func deletesArePublished() throws {
        let storage = InMemoryGridStorage(document: populated)
        let store = GridStore(storage: storage)

        try store.deleteArrangement(fixtureArrangementID)
        try store.deleteRule(fixtureRuleID)

        #expect(store.document.savedArrangements.isEmpty)
        #expect(store.document.rules.isEmpty)
        #expect(storage.document == store.document)
        #expect(storage.saveCount == 2)
    }

    @Test("switching a rule is written and published")
    func ruleSwitchIsPublished() throws {
        let storage = InMemoryGridStorage(document: populated)
        let store = GridStore(storage: storage)

        try store.setRuleEnabled(fixtureRuleID, false)

        #expect(store.document.rule(forBundleID: knownRule.bundleID)?.isEnabled == false)
        #expect(storage.document.rule(forBundleID: knownRule.bundleID)?.isEnabled == false)
    }

    @Test("arrangement and rule changes leave grids and active grids as they were")
    func gridsSurviveArrangementChanges() throws {
        let grid = ZoneGrid(id: UUID(), name: "Thirds", zones: GridTemplate.threeColumns.zones)
        let storage = InMemoryGridStorage(document: GridDocument(
            grids: [grid], activeByDisplay: ["uuid:AAAA": .saved(id: grid.id)], arrangements: nil, autoRules: nil))
        let store = GridStore(storage: storage)

        try store.saveArrangement(fixtureArrangement())
        try store.saveRule(fixtureRule())

        #expect(store.document.grids == [grid])
        #expect(store.document.activeByDisplay == ["uuid:AAAA": .saved(id: grid.id)])
    }

    // MARK: Read-only

    @Test("while the store is read-only every mutation fails with readOnly and nothing is written",
          arguments: readOnlyLoadErrors)
    func readOnlyRefusesEveryMutation(loadError: GridStorageError) {
        for mutation in mutations {
            let storage = InMemoryGridStorage(loadError: loadError)
            let store = GridStore(storage: storage)
            #expect(store.isReadOnly, "\(loadError)")

            #expect(throws: GridStorageError.readOnly, "\(mutation.label)") { try mutation.run(store) }

            #expect(store.document == .empty, "\(mutation.label)")
            #expect(storage.saveCount == 0, "\(mutation.label)")
        }
    }

    @Test("after an unreadable file was set aside the store accepts arrangements")
    func quarantinedStoreIsWritable() throws {
        let storage = InMemoryGridStorage(loadError: .unreadable("window-zones.corrupt-20261011-134507.json"))
        let store = GridStore(storage: storage)
        let arrangement = fixtureArrangement()

        try store.saveArrangement(arrangement)

        #expect(store.document.savedArrangements == [arrangement])
    }

    // MARK: Storage failure

    @Test("a failed write leaves the document as it was and reports the failure")
    func failedWriteKeepsDocument() {
        for mutation in mutations {
            let storage = InMemoryGridStorage(document: populated)
            let store = GridStore(storage: storage)
            storage.saveError = .writeFailed("disk full")

            #expect(throws: GridStorageError.writeFailed("disk full"), "\(mutation.label)") { try mutation.run(store) }

            #expect(store.document == populated, "\(mutation.label)")
            #expect(storage.document == populated, "\(mutation.label)")
        }
    }

    @Test("a mutation succeeds again once the write failure is gone")
    func storeRecoversAfterWriteFailure() throws {
        let storage = InMemoryGridStorage(document: populated)
        let store = GridStore(storage: storage)
        storage.saveError = .writeFailed("disk full")
        #expect(throws: GridStorageError.writeFailed("disk full")) { try store.deleteArrangement(fixtureArrangementID) }

        storage.saveError = nil
        try store.deleteArrangement(fixtureArrangementID)

        #expect(store.document.savedArrangements.isEmpty)
    }
}
