import Foundation
import Testing
@testable import Echo

// Arrangements and rules live in the same window-zones.json as the grids. A file from the previous
// release must read without a migration and without a backup, a file from a newer release must
// stay byte for byte, and no mutation may drop what is already stored.

private let fileName = "window-zones.json"
private let backupPrefix = "window-zones.corrupt-"

@MainActor
private func files(in directory: URL) -> GridFileStorage {
    GridFileStorage(fileURL: directory.appendingPathComponent(fileName))
}

private func write(_ text: String, to url: URL) throws {
    try Data(text.utf8).write(to: url)
}

@MainActor
private func loadFailure(_ storage: GridFileStorage) -> GridStorageError? {
    do {
        _ = try storage.load()
        return nil
    } catch {
        return error
    }
}

private func storedVersion(of url: URL) throws -> Int {
    let object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    return try #require(object["schemaVersion"] as? Int)
}

@MainActor
@Suite("Arrangement file storage")
struct ArrangementFileStorageTests {

    // MARK: Reading

    @Test("a version 1 file loads without arrangements or rules, and is not touched")
    func versionOneFileLoadsUntouched() throws {
        try withTemporaryDirectory { directory in
            let storage = files(in: directory)
            try write(v1ReferenceJSON, to: storage.fileURL)

            let document = try storage.load()

            #expect(document.arrangements == nil)
            #expect(document.autoRules == nil)
            #expect(document.savedArrangements.isEmpty)
            #expect(document.rules.isEmpty)
            #expect(document.grids.map(\.name) == ["Thirds"])
            #expect(try fileNames(in: directory) == [fileName])
            #expect(try Data(contentsOf: storage.fileURL) == Data(v1ReferenceJSON.utf8))
        }
    }

    @Test("a version 2 reference file loads to the reference document")
    func versionTwoFileLoads() throws {
        try withTemporaryDirectory { directory in
            let storage = files(in: directory)
            try write(v2ReferenceJSON, to: storage.fileURL)

            #expect(try storage.load() == v2ReferenceDocument())
            #expect(try fileNames(in: directory) == [fileName])
        }
    }

    @Test("a full document written by the storage loads back identical and as version 2")
    func fullDocumentRoundTrip() throws {
        try withTemporaryDirectory { directory in
            let storage = files(in: directory)

            try storage.save(v2ReferenceDocument())

            #expect(try storage.load() == v2ReferenceDocument())
            #expect(try storage.load().savedArrangements.first?.windows.map(\.titleHint) == ["build", nil])
            #expect(try storedVersion(of: storage.fileURL) == 2)
        }
    }

    @Test("fields this version does not know are ignored inside arrangements and rules")
    func unknownFieldsInArrangementsAreIgnored() throws {
        try withTemporaryDirectory { directory in
            let storage = files(in: directory)
            let id = fixtureArrangementID.uuidString
            let windowID = fixtureTitledWindowID.uuidString
            try write("""
            {"schemaVersion":2,"document":{"grids":[],"activeByDisplay":{},
            "arrangements":[{"id":"\(id)","name":"Review","futureField":1,
            "displays":{"uuid:AAAA":{"name":"Studio Display","aspect":1.6,"futureDisplay":true}},
            "windows":[{"id":"\(windowID)","bundleID":"com.apple.Terminal","appName":"Terminal",
            "futureWindow":"x","slot":{"display":"uuid:AAAA","futureSlot":0,
            "rect":{"x":0,"y":0,"width":0.5,"height":1}}}]}]}}
            """, to: storage.fileURL)

            let document = try storage.load()

            let arrangement = try #require(document.savedArrangements.first)
            #expect(arrangement.name == "Review")
            #expect(arrangement.windows.map(\.id) == [fixtureTitledWindowID])
            #expect(arrangement.windows.first?.titleHint == nil)
            #expect(try fileNames(in: directory) == [fileName])
        }
    }

    @Test("arrangements of the wrong shape make the file unreadable and keep a copy",
          arguments: [
            "\"arrangements\":\"x\"",
            "\"arrangements\":[{\"id\":\"not-a-uuid\",\"name\":\"A\",\"windows\":[],\"displays\":{}}]",
            "\"autoRules\":{}"
          ])
    func malformedArrangementsAreSetAside(fragment: String) throws {
        try withTemporaryDirectory { directory in
            let storage = files(in: directory)
            let content = "{\"schemaVersion\":2,\"document\":{\"grids\":[],\"activeByDisplay\":{},\(fragment)}}"
            try write(content, to: storage.fileURL)

            guard case .unreadable(let backup)? = loadFailure(storage) else {
                Issue.record("expected the file to be reported unreadable")
                return
            }
            #expect(backup.hasPrefix(backupPrefix))
            #expect(try Data(contentsOf: directory.appendingPathComponent(backup)) == Data(content.utf8))
        }
    }

    // MARK: Newer schema

    @Test("a file of a newer schema is read-only for the store and is never rewritten")
    func newerSchemaFileSurvivesEveryMutation() throws {
        try withTemporaryDirectory { directory in
            let storage = files(in: directory)
            let content = """
            {"schemaVersion":\(GridFileStorage.schemaVersion + 1),\
            "document":{"grids":[],"activeByDisplay":{},"arrangements":[],"futureThing":1}}
            """
            try write(content, to: storage.fileURL)
            let store = GridStore(storage: storage)

            #expect(store.isReadOnly)
            #expect(store.loadNotice == .newerVersion)
            let arrangement = fixtureArrangement()
            let rule = fixtureRule()
            #expect(throws: GridStorageError.readOnly) { try store.saveArrangement(arrangement) }
            #expect(throws: GridStorageError.readOnly) { try store.deleteArrangement(arrangement.id) }
            #expect(throws: GridStorageError.readOnly) { try store.saveRule(rule) }
            #expect(throws: GridStorageError.readOnly) { try store.deleteRule(rule.id) }
            #expect(throws: GridStorageError.readOnly) { try store.setRuleEnabled(rule.id, false) }

            #expect(try Data(contentsOf: storage.fileURL) == Data(content.utf8))
            #expect(try fileNames(in: directory) == [fileName])
            #expect(store.document == .empty)
        }
    }

    // MARK: Upgrading a version 1 file

    @Test("saving an arrangement into a version 1 file keeps its grids and rewrites it as version 2")
    func firstArrangementUpgradesFileAndKeepsGrids() throws {
        try withTemporaryDirectory { directory in
            let storage = files(in: directory)
            try write(v1ReferenceJSON, to: storage.fileURL)
            let store = GridStore(storage: storage)
            #expect(!store.isReadOnly)
            #expect(store.loadNotice == nil)
            let arrangement = fixtureArrangement(name: "Review")

            try store.saveArrangement(arrangement)

            let reloaded = try files(in: directory).load()
            #expect(reloaded.savedArrangements == [arrangement])
            #expect(reloaded.grids == v2ReferenceDocument().grids)
            #expect(reloaded.activeByDisplay == v2ReferenceDocument().activeByDisplay)
            #expect(try storedVersion(of: storage.fileURL) == 2)
            #expect(try fileNames(in: directory) == [fileName])
        }
    }

    @Test("a grid saved after arrangements exist keeps the arrangements and rules")
    func gridSaveKeepsArrangementsAndRules() throws {
        try withTemporaryDirectory { directory in
            let storage = files(in: directory)
            try storage.save(v2ReferenceDocument())
            let store = GridStore(storage: storage)

            try store.save(ZoneGrid(id: UUID(), name: "Halves", zones: GridTemplate.twoColumns.zones))

            let reloaded = try files(in: directory).load()
            #expect(reloaded.savedArrangements == v2ReferenceDocument().savedArrangements)
            #expect(reloaded.rules == v2ReferenceDocument().rules)
            #expect(reloaded.grids.count == 2)
        }
    }

    @Test("an arrangement with no windows is stored and loaded")
    func emptyArrangementRoundTrips() throws {
        try withTemporaryDirectory { directory in
            let storage = files(in: directory)
            let empty = Arrangement(id: UUID(), name: "Nothing", windows: [], displays: [:])

            try GridStore(storage: storage).saveArrangement(empty)

            #expect(try storage.load().savedArrangements == [empty])
        }
    }
}
