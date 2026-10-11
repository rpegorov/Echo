import Foundation
import Testing
@testable import Echo

// The grid file is user data: a read never loses, rewrites or replaces what is on disk
// unless the file is provably unreadable, and then a copy is kept.

private let fileName = "window-zones.json"
private let backupPrefix = "window-zones.corrupt-"

private let sampleDocument = GridDocument(
    grids: [ZoneGrid(id: UUID(), name: "Work", zones: GridTemplate.twoByTwo.zones)],
    activeByDisplay: ["uuid:AAAA": .template(kind: .threeColumns)]
)

/// A moment in the middle of a day, so the expected name is the same in every time zone.
private func moment(second: Int) -> Date {
    let parts = DateComponents(year: 2026, month: 10, day: 11, hour: 13, minute: 45, second: second)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
}

private func backupName(second: Int) -> String {
    "\(backupPrefix)20261011-1345\(String(format: "%02d", second)).json"
}

@MainActor
private func storage(in directory: URL, at second: Int = 7) -> GridFileStorage {
    GridFileStorage(fileURL: directory.appendingPathComponent(fileName), now: { moment(second: second) })
}

@MainActor
private func loadFailure(_ files: GridFileStorage) -> GridStorageError? {
    do {
        _ = try files.load()
        return nil
    } catch {
        return error
    }
}

@MainActor
private func saveFailure(_ files: GridFileStorage, _ document: GridDocument) -> GridStorageError? {
    do {
        try files.save(document)
        return nil
    } catch {
        return error
    }
}

private func write(_ text: String, to url: URL) throws {
    try Data(text.utf8).write(to: url)
}

@MainActor
@Suite("Grid file storage")
struct GridFileStorageTests {

    // MARK: Absent and round trip

    @Test("no file loads as empty and creates nothing")
    func missingFileIsEmpty() throws {
        try withTemporaryDirectory { directory in
            let document = try storage(in: directory).load()
            #expect(document == .empty)
            #expect(try fileNames(in: directory).isEmpty)
        }
    }

    @Test("a saved document loads back identical")
    func roundTrip() throws {
        try withTemporaryDirectory { directory in
            let files = storage(in: directory)
            try files.save(sampleDocument)
            #expect(try files.load() == sampleDocument)
            #expect(try fileNames(in: directory) == [fileName])
        }
    }

    @Test("a second save replaces the first and leaves no stray files")
    func saveReplaces() throws {
        try withTemporaryDirectory { directory in
            let files = storage(in: directory)
            try files.save(sampleDocument)
            var changed = sampleDocument
            changed.rename(changed.grids[0].id, to: "Home")
            try files.save(changed)
            #expect(try files.load() == changed)
            #expect(try fileNames(in: directory) == [fileName])
        }
    }

    @Test("saving into a missing directory fails with writeFailed")
    func saveIntoMissingDirectory() throws {
        try withTemporaryDirectory { directory in
            let missing = directory.appendingPathComponent("absent", isDirectory: true)
            guard case .writeFailed? = saveFailure(storage(in: missing), sampleDocument) else {
                Issue.record("expected writeFailed")
                return
            }
            let names = try fileNames(in: directory)
            #expect(names.isEmpty)
        }
    }

    @Test("a directory that cannot be written fails with writeFailed and keeps the previous file")
    func saveIntoReadOnlyDirectory() throws {
        try withTemporaryDirectory { directory in
            let files = storage(in: directory)
            try files.save(sampleDocument)
            let before = try Data(contentsOf: files.fileURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)

            let failure = saveFailure(files, .empty)

            guard case .writeFailed? = failure else {
                Issue.record("expected writeFailed, got \(String(describing: failure))")
                return
            }
            #expect(try Data(contentsOf: files.fileURL) == before)
        }
    }

    // MARK: Unreadable content

    @Test("content that is not a grid file is set aside under a time-stamped name",
          arguments: ["", "not json", "[]", "{\"schemaVersion\":1}", "{\"schemaVersion\":\"1\",\"document\":{}}",
                      "{\"schemaVersion\":1,\"document\":{\"grids\":\"x\",\"activeByDisplay\":{}}}"])
    func garbageIsSetAside(content: String) throws {
        try withTemporaryDirectory { directory in
            let files = storage(in: directory)
            try write(content, to: files.fileURL)

            let failure = loadFailure(files)

            #expect(failure == .unreadable(backupName(second: 7)))
            let backup = directory.appendingPathComponent(backupName(second: 7))
            #expect(try Data(contentsOf: backup) == Data(content.utf8))
            #expect(try fileNames(in: directory) == [backupName(second: 7)])
            #expect(try files.load() == .empty)
        }
    }

    @Test("a second unreadable file does not overwrite the first backup")
    func secondFailureKeepsFirstBackup() throws {
        try withTemporaryDirectory { directory in
            try write("first", to: directory.appendingPathComponent(fileName))
            _ = loadFailure(storage(in: directory, at: 1))
            try write("second", to: directory.appendingPathComponent(fileName))
            _ = loadFailure(storage(in: directory, at: 2))

            let first = try Data(contentsOf: directory.appendingPathComponent(backupName(second: 1)))
            let second = try Data(contentsOf: directory.appendingPathComponent(backupName(second: 2)))
            #expect(first == Data("first".utf8))
            #expect(second == Data("second".utf8))
        }
    }

    @Test("a backup name already taken fails the load and keeps both files")
    func occupiedBackupNameLosesNothing() throws {
        try withTemporaryDirectory { directory in
            let taken = directory.appendingPathComponent(backupName(second: 7))
            try write("older copy", to: taken)
            let original = directory.appendingPathComponent(fileName)
            try write("garbage", to: original)

            let failure = loadFailure(storage(in: directory))

            guard case .writeFailed? = failure else {
                Issue.record("expected writeFailed, got \(String(describing: failure))")
                return
            }
            #expect(try Data(contentsOf: taken) == Data("older copy".utf8))
            #expect(try Data(contentsOf: original) == Data("garbage".utf8))
        }
    }

    // MARK: Newer schema

    @Test("a newer schema version is reported and the file is left byte for byte",
          arguments: [2, 99])
    func newerSchemaIsUntouched(version: Int) throws {
        try withTemporaryDirectory { directory in
            let files = storage(in: directory)
            let content = "{\"schemaVersion\":\(version),\"document\":\"a shape this version cannot read\"}"
            try write(content, to: files.fileURL)

            let failure = loadFailure(files)

            #expect(failure == .newerSchema(version))
            #expect(try Data(contentsOf: files.fileURL) == Data(content.utf8))
            #expect(try fileNames(in: directory) == [fileName])
        }
    }

    // MARK: Unknown fields

    @Test("fields this version does not know are ignored at every level")
    func unknownFieldsAreIgnored() throws {
        try withTemporaryDirectory { directory in
            let files = storage(in: directory)
            let id = UUID()
            try write("""
            {"schemaVersion":1,"futureEnvelope":true,"document":{"futureDocument":[1],
            "activeByDisplay":{"uuid:AAAA":{"saved":{"id":"\(id.uuidString)"}}},
            "grids":[{"id":"\(id.uuidString)","name":"Work","futureGrid":"x",
            "zones":[{"x":0,"y":0,"width":1,"height":1,"futureZone":0}]}]}}
            """, to: files.fileURL)

            let document = try files.load()

            #expect(document.grids == [ZoneGrid(id: id, name: "Work",
                                                zones: [UnitRect(x: 0, y: 0, width: 1, height: 1)])])
            #expect(document.activeByDisplay == ["uuid:AAAA": .saved(id: id)])
        }
    }

    // MARK: Files Echo cannot read

    @Test("a link to a missing target is a read failure, not an empty file")
    func danglingLinkIsReadFailure() throws {
        try withTemporaryDirectory { directory in
            let files = storage(in: directory)
            try FileManager.default.createSymbolicLink(
                at: files.fileURL, withDestinationURL: directory.appendingPathComponent("nowhere"))

            let failure = loadFailure(files)

            guard case .readFailed? = failure else {
                Issue.record("expected readFailed, got \(String(describing: failure))")
                return
            }
            #expect(try fileNames(in: directory) == [fileName])
        }
    }

    @Test("a directory in place of the file is a read failure and is left alone")
    func directoryInPlaceOfFile() throws {
        try withTemporaryDirectory { directory in
            let files = storage(in: directory)
            try FileManager.default.createDirectory(at: files.fileURL, withIntermediateDirectories: false)

            let failure = loadFailure(files)

            guard case .readFailed? = failure else {
                Issue.record("expected readFailed, got \(String(describing: failure))")
                return
            }
            #expect(try fileNames(in: directory) == [fileName])
        }
    }

    @Test("a file without read permission is a read failure and is left alone")
    func unreadablePermissions() throws {
        try withTemporaryDirectory { directory in
            let files = storage(in: directory)
            try files.save(sampleDocument)
            try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: files.fileURL.path)
            defer {
                do {
                    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: files.fileURL.path)
                } catch {
                    Issue.record("could not restore permissions: \(error)")
                }
            }

            let failure = loadFailure(files)

            guard case .readFailed? = failure else {
                Issue.record("expected readFailed, got \(String(describing: failure))")
                return
            }
            #expect(try fileNames(in: directory) == [fileName])
        }
    }

    // MARK: Store over a real file

    @Test("a file that cannot be moved aside leaves the store read-only and the file untouched")
    func failedQuarantineMakesStoreReadOnly() throws {
        try withTemporaryDirectory { directory in
            let files = storage(in: directory)
            try write("garbage", to: files.fileURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)

            let store = GridStore(storage: files)

            #expect(store.isReadOnly)
            #expect(store.loadNotice == .unavailable)
            #expect(throws: GridStorageError.readOnly) { try store.save(sampleDocument.grids[0]) }
            #expect(try Data(contentsOf: files.fileURL) == Data("garbage".utf8))
        }
    }

    @Test("after an unreadable file was set aside the store writes a fresh file and keeps the copy")
    func storeRecoversAfterQuarantine() throws {
        try withTemporaryDirectory { directory in
            let files = storage(in: directory)
            try write("garbage", to: files.fileURL)

            let store = GridStore(storage: files)
            #expect(!store.isReadOnly)
            #expect(store.loadNotice == .loadFailed(fileName: backupName(second: 7)))
            try store.save(sampleDocument.grids[0])

            #expect(try storage(in: directory).load().grids == sampleDocument.grids)
            #expect(try Data(contentsOf: directory.appendingPathComponent(backupName(second: 7))) == Data("garbage".utf8))
        }
    }

    @Test("a newer-version file is never replaced by a store save")
    func newerFileSurvivesStoreSave() throws {
        try withTemporaryDirectory { directory in
            let files = storage(in: directory)
            let content = "{\"schemaVersion\":2,\"document\":{}}"
            try write(content, to: files.fileURL)

            let store = GridStore(storage: files)
            #expect(throws: GridStorageError.readOnly) { try store.setActive(.template(kind: .twoByTwo), for: DisplayKey(rawValue: "k")) }

            #expect(try Data(contentsOf: files.fileURL) == Data(content.utf8))
        }
    }
}
