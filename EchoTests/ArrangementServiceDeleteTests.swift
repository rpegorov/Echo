import ApplicationServices
import CoreGraphics
import Foundation
import Testing
@testable import Echo

// Deleting an arrangement removes it from the file first and its hotkey second; a failed write keeps both.

@MainActor
private final class EmptyCatalog: WindowCataloging {
    func windows() -> [CatalogWindow] { [] }
    func runningBundleIDs() -> Set<String> { [] }
}

@MainActor
private final class RecordingFrames: WindowFrameSetting {
    private(set) var calls = 0
    func setFrame(_ frameCocoa: CGRect, for window: AXUIElement) { calls += 1 }
}

/// Logs each write so a test can order it against the hotkey removal.
@MainActor
private final class LoggingStorage: GridDocumentStoring {
    var document: GridDocument
    var loadError: GridStorageError?
    var saveError: GridStorageError?
    var onSave: (() -> Void)?

    init(document: GridDocument, loadError: GridStorageError? = nil) {
        self.document = document
        self.loadError = loadError
    }

    func load() throws(GridStorageError) -> GridDocument {
        if let loadError { throw loadError }
        return document
    }

    func save(_ document: GridDocument) throws(GridStorageError) {
        onSave?()
        if let saveError { throw saveError }
        self.document = document
    }
}

private let hotkey = KeyboardShortcut(keyCode: 11, flags: [.control, .command])

@MainActor
private struct Rig {
    let storage: LoggingStorage
    let settings: AppSettings
    let service: ArrangementService
    let frames = RecordingFrames()
    let arrangement: Arrangement

    init(defaults: UserDefaults, loadError: GridStorageError? = nil) {
        arrangement = fixtureArrangement()
        storage = LoggingStorage(
            document: GridDocument(grids: [], activeByDisplay: [:], arrangements: [arrangement], autoRules: nil),
            loadError: loadError)
        settings = AppSettings(defaults: defaults)
        settings.setShortcut(hotkey, for: .arrangement(arrangement.id))
        service = ArrangementService(
            store: GridStore(storage: storage), settings: settings, catalog: EmptyCatalog(), frames: frames,
            displays: { [] }, hasPermission: { true })
    }
}

@MainActor
@Suite("Arrangement deletion and hotkeys")
struct ArrangementServiceDeleteTests {

    @Test("the hotkey is removed after the file was written, not before")
    func hotkeyGoesAfterTheWrite() throws {
        try withScratchDefaults { defaults in
            let rig = Rig(defaults: defaults)
            var events: [String] = []
            let id = rig.arrangement.id
            rig.storage.onSave = {
                events.append(rig.settings.shortcut(for: .arrangement(id)) == nil ? "save:hotkey-gone" : "save")
            }
            rig.settings.onChange = {
                let stale = rig.storage.document.savedArrangements.contains { $0.id == id }
                events.append(stale ? "change:file-stale" : "change")
            }

            try rig.service.delete(id)

            #expect(events == ["save", "change"])
            #expect(rig.settings.shortcut(for: .arrangement(id)) == nil)
            #expect(rig.service.arrangementIDs.isEmpty)
            #expect(rig.storage.document.savedArrangements.isEmpty)
        }
    }

    @Test("a failed write keeps the arrangement and its hotkey")
    func failedWriteKeepsBoth() throws {
        withScratchDefaults { defaults in
            let rig = Rig(defaults: defaults)
            rig.storage.saveError = .writeFailed("disk full")
            var changes = 0
            rig.settings.onChange = { changes += 1 }

            #expect(throws: ArrangementError.storage(.writeFailed("disk full"))) {
                try rig.service.delete(rig.arrangement.id)
            }

            #expect(rig.settings.shortcut(for: .arrangement(rig.arrangement.id)) == hotkey)
            #expect(rig.service.arrangementIDs == [rig.arrangement.id])
            #expect(changes == 0)
        }
    }

    @Test("a read-only store refuses to delete and keeps the hotkey")
    func readOnlyKeepsTheHotkey() throws {
        withScratchDefaults { defaults in
            let rig = Rig(defaults: defaults, loadError: .newerSchema(3))

            #expect(throws: ArrangementError.storage(.readOnly)) { try rig.service.delete(rig.arrangement.id) }

            #expect(rig.settings.shortcut(for: .arrangement(rig.arrangement.id)) == hotkey)
        }
    }

    @Test("applying an unknown arrangement reports nothing and moves no window, even when the store is read-only")
    func applyUnknownIdIsEmpty() throws {
        withScratchDefaults { defaults in
            let rig = Rig(defaults: defaults, loadError: .newerSchema(3))

            let report = rig.service.apply(UUID())

            #expect(report.total == 0)
            #expect(rig.frames.calls == 0)
        }
    }
}
