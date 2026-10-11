import Foundation
import Testing
@testable import Echo

private let display = DisplayKey(rawValue: "uuid:DISPLAY-A")
private let otherDisplay = DisplayKey(rawValue: "uuid:DISPLAY-B")

private func grid(_ name: String = "Work", zones: [UnitRect] = GridTemplate.twoByTwo.zones) -> ZoneGrid {
    ZoneGrid(id: UUID(), name: name, zones: zones)
}

/// Load errors after which the file on disk must stay exactly as found.
private let readOnlyErrors: [GridStorageError] = [
    .newerSchema(2), .readFailed("denied"), .writeFailed("could not move"), .locationUnavailable
]

@MainActor
@Suite("Grid store")
struct GridStoreTests {

    // MARK: Publishing

    @Test("a successful change is written and published")
    func successfulChangePublishes() throws {
        let storage = InMemoryGridStorage()
        let store = GridStore(storage: storage)
        let work = grid()

        try store.save(work)

        #expect(store.document.grids == [work])
        #expect(storage.document == store.document)
        #expect(storage.saveCount == 1)
    }

    @Test("a refused write leaves the published document as it was and reports the error")
    func failedWriteKeepsDocument() throws {
        let storage = InMemoryGridStorage()
        let store = GridStore(storage: storage)
        let kept = grid("Kept")
        try store.save(kept)
        let before = store.document
        storage.saveError = .writeFailed("disk full")

        #expect(throws: GridStorageError.writeFailed("disk full")) { try store.save(grid("Lost")) }
        #expect(throws: GridStorageError.writeFailed("disk full")) { try store.delete(kept.id) }
        #expect(throws: GridStorageError.writeFailed("disk full")) { try store.setActive(.saved(id: kept.id), for: display) }
        #expect(throws: GridStorageError.writeFailed("disk full")) { try store.rename(kept.id, to: "Renamed") }

        #expect(store.document == before)
        #expect(storage.document == before)
    }

    @Test("the store accepts changes again once the storage recovers")
    func recoversAfterFailedWrite() throws {
        let storage = InMemoryGridStorage(saveError: .writeFailed("busy"))
        let store = GridStore(storage: storage)
        #expect(throws: GridStorageError.writeFailed("busy")) { try store.save(grid()) }

        storage.saveError = nil
        try store.save(grid("Second"))

        #expect(store.document.grids.map(\.name) == ["Second"])
    }

    @Test("saved grids are read from storage at launch")
    func loadsSavedDocument() {
        let work = grid()
        let stored = GridDocument(grids: [work], activeByDisplay: [display.rawValue: .saved(id: work.id)])
        let store = GridStore(storage: InMemoryGridStorage(document: stored))

        #expect(store.document == stored)
        #expect(store.loadNotice == nil)
        #expect(!store.isReadOnly)
        #expect(store.activeZones(for: display, aspect: 1.6) == work.zones)
    }

    // MARK: Read-only states

    @Test("a load that leaves the file untouched makes every change fail without writing",
          arguments: readOnlyErrors)
    func readOnlyAfterLoadError(error: GridStorageError) {
        let storage = InMemoryGridStorage(loadError: error)
        let store = GridStore(storage: storage)
        let work = grid()

        #expect(store.isReadOnly)
        #expect(throws: GridStorageError.readOnly) { try store.save(work) }
        #expect(throws: GridStorageError.readOnly) { try store.rename(work.id, to: "x") }
        #expect(throws: GridStorageError.readOnly) { try store.delete(work.id) }
        #expect(throws: GridStorageError.readOnly) { try store.setActive(.template(kind: .twoByTwo), for: display) }
        #expect(storage.saveCount == 0)
        #expect(store.document == .empty)
    }

    @Test("a store over unavailable storage is read-only")
    func unavailableStorageIsReadOnly() {
        let store = GridStore(storage: UnavailableGridStorage(error: .locationUnavailable))
        #expect(store.isReadOnly)
        #expect(throws: GridStorageError.readOnly) { try store.save(grid()) }
    }

    @Test("an unreadable file that was set aside leaves the store writable with an empty document")
    func unreadableAfterQuarantineIsWritable() throws {
        let storage = InMemoryGridStorage(loadError: .unreadable("backup.json"))
        let store = GridStore(storage: storage)

        #expect(!store.isReadOnly)
        #expect(store.document == .empty)
        try store.save(grid())

        #expect(storage.saveCount == 1)
        #expect(store.document.grids.count == 1)
    }

    // MARK: Notices

    @Test("the notice follows the load error")
    func noticeByError() {
        func notice(_ error: GridStorageError?) -> GridLoadNotice? {
            GridStore(storage: InMemoryGridStorage(loadError: error)).loadNotice
        }
        #expect(notice(nil) == nil)
        #expect(notice(.unreadable("backup.json")) == .loadFailed(fileName: "backup.json"))
        #expect(notice(.newerSchema(5)) == .newerVersion)
        #expect(notice(.readFailed("denied")) == .unavailable)
        #expect(notice(.writeFailed("could not move")) == .unavailable)
        #expect(notice(.locationUnavailable) == .unavailable)
    }

    @Test("every notice has a message in English and Russian")
    func noticeMessagesExist() {
        let en = Localizer(preference: .fixed(.en))
        let ru = Localizer(preference: .fixed(.ru))
        let notices: [GridLoadNotice] = [.loadFailed(fileName: "backup.json"), .newerVersion, .unavailable]
        for notice in notices {
            #expect(en.t(notice.messageKey) != notice.messageKey.rawValue, "\(notice) en")
            #expect(ru.t(notice.messageKey) != notice.messageKey.rawValue, "\(notice) ru")
        }
        #expect(Set(notices.map(\.messageKey)).count == notices.count)
    }

    // MARK: Deleting

    @Test("deleting a grid releases every display that used it and keeps the others")
    func deleteReleasesDisplays() throws {
        let doomed = grid("Doomed")
        let kept = grid("Kept")
        let store = GridStore(storage: InMemoryGridStorage())
        try store.save(doomed)
        try store.save(kept)
        try store.setActive(.saved(id: doomed.id), for: display)
        try store.setActive(.saved(id: doomed.id), for: otherDisplay)
        let third = DisplayKey(rawValue: "uuid:DISPLAY-C")
        try store.setActive(.saved(id: kept.id), for: third)

        try store.delete(doomed.id)

        #expect(store.document.grids == [kept])
        #expect(store.document.activeRef(for: display) == nil)
        #expect(store.document.activeRef(for: otherDisplay) == nil)
        #expect(store.document.activeRef(for: third) == .saved(id: kept.id))
        #expect(store.activeZones(for: display, aspect: 1.6) == GridTemplate.twoColumns.zones)
    }
}
