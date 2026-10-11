import ApplicationServices
import CoreGraphics
import Foundation
import Testing
@testable import Echo

// Capture, save and apply of arrangements through the service, with the catalog and the frame writer replaced.

private let displayKey = "uuid:AAAA"
private let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)

/// Windows of different pid and ordinal get different AX elements.
private func catalogWindow(
    bundleID: String = "com.apple.Terminal", appName: String = "Terminal", title: String? = nil,
    pid: Int32 = 70_001, ordinal: Int = 0, frame: CGRect
) -> CatalogWindow {
    CatalogWindow(
        snapshot: snapshotWindow(bundleID, appName: appName, title: title, pid: pid, ordinal: ordinal, frame: frame),
        element: AXUIElementCreateApplication(pid + Int32(ordinal)))
}

@MainActor
private final class StubCatalog: WindowCataloging {
    var windowList: [CatalogWindow] = []
    var running: Set<String> = []
    private(set) var windowReads = 0

    func windows() -> [CatalogWindow] {
        windowReads += 1
        return windowList
    }

    func runningBundleIDs() -> Set<String> { running }
}

@MainActor
private final class RecordingWriter: WindowFrameSetting {
    private(set) var moves: [(frame: CGRect, element: AXUIElement)] = []

    func setFrame(_ frameCocoa: CGRect, for window: AXUIElement) { moves.append((frameCocoa, window)) }
}

@MainActor
private struct ServiceRig {
    let storage: InMemoryGridStorage
    let store: GridStore
    let settings: AppSettings
    let catalog = StubCatalog()
    let writer = RecordingWriter()
    let service: ArrangementService

    init(
        defaults: UserDefaults, arrangements: [Arrangement] = [], loadError: GridStorageError? = nil,
        displays: [DisplaySnapshot]? = nil, hasPermission: Bool = true, gap: Double = 0
    ) {
        storage = InMemoryGridStorage(
            document: GridDocument(grids: [], activeByDisplay: [:], arrangements: arrangements, autoRules: nil),
            loadError: loadError)
        store = GridStore(storage: storage)
        settings = AppSettings(defaults: defaults)
        settings.windowGap = gap
        let connected = displays ?? [snapshotDisplay(key: displayKey, frame: visibleFrame)]
        service = ArrangementService(
            store: store, settings: settings, catalog: catalog, frames: writer,
            displays: { connected }, hasPermission: { hasPermission })
    }
}

@MainActor
@Suite("Arrangement service: capture")
struct ArrangementCaptureServiceTests {

    @Test("capturing stores the open windows with the zone each one is nearest to")
    func captureStoresArrangement() throws {
        try withScratchDefaults { defaults in
            let rig = ServiceRig(defaults: defaults)
            rig.catalog.windowList = [
                catalogWindow(title: "build", ordinal: 0, frame: CGRect(x: 50, y: 100, width: 300, height: 400)),
                catalogWindow(
                    bundleID: "com.apple.Safari", appName: "Safari", pid: 70_100, frame: CGRect(x: 600, y: 100, width: 300, height: 400))
            ]

            let arrangement = try rig.service.captureCurrent(named: "Review")

            let stored = try #require(rig.store.document.savedArrangements.first)
            #expect(stored == arrangement)
            #expect(rig.store.document.savedArrangements.count == 1)
            #expect(arrangement.name == "Review")
            #expect(arrangement.windows.map(\.bundleID) == ["com.apple.Terminal", "com.apple.Safari"])
            #expect(arrangement.windows.map(\.titleHint) == ["build", nil])
            #expect(arrangement.windows.map(\.slot.display) == [displayKey, displayKey])
            #expect(arrangement.windows.map(\.slot.rect) == GridTemplate.twoColumns.zones)
            #expect(Set(arrangement.displays.keys) == [displayKey])
            #expect(rig.storage.saveCount == 1)
            #expect(rig.service.arrangementIDs == [arrangement.id])
        }
    }

    @Test("without the accessibility permission nothing is read and nothing is written")
    func deniedReadsNothing() throws {
        try withScratchDefaults { defaults in
            let rig = ServiceRig(defaults: defaults, hasPermission: false)
            rig.catalog.windowList = [catalogWindow(frame: CGRect(x: 50, y: 100, width: 300, height: 400))]

            #expect(throws: ArrangementError.accessibilityDenied) { try rig.service.captureCurrent(named: "Work") }

            #expect(rig.catalog.windowReads == 0)
            #expect(rig.storage.saveCount == 0)
        }
    }

    @Test("no windows reports noWindows and leaves the file alone")
    func noWindowsWritesNothing() throws {
        try withScratchDefaults { defaults in
            let rig = ServiceRig(defaults: defaults)

            #expect(throws: ArrangementError.noWindows) { try rig.service.captureCurrent(named: "Work") }

            #expect(rig.storage.saveCount == 0)
            #expect(rig.store.document.savedArrangements.isEmpty)
        }
    }

    @Test("windows that only sit on a display without a key count as no windows")
    func keylessDisplayOnly() throws {
        try withScratchDefaults { defaults in
            let rig = ServiceRig(defaults: defaults, displays: [snapshotDisplay(key: nil, frame: visibleFrame)])
            rig.catalog.windowList = [catalogWindow(frame: CGRect(x: 50, y: 100, width: 300, height: 400))]

            #expect(throws: ArrangementError.noWindows) { try rig.service.captureCurrent(named: "Work") }

            #expect(rig.storage.saveCount == 0)
        }
    }

    @Test("a failed write reports the storage error and publishes nothing")
    func failedWriteKeepsDocument() throws {
        try withScratchDefaults { defaults in
            let rig = ServiceRig(defaults: defaults)
            rig.storage.saveError = .writeFailed("disk full")
            rig.catalog.windowList = [catalogWindow(frame: CGRect(x: 50, y: 100, width: 300, height: 400))]

            #expect(throws: ArrangementError.storage(.writeFailed("disk full"))) {
                try rig.service.captureCurrent(named: "Work")
            }

            #expect(rig.store.document.savedArrangements.isEmpty)
            #expect(rig.service.arrangementIDs.isEmpty)
        }
    }

    @Test("a read-only store refuses to capture and writes nothing")
    func readOnlyRefusesCapture() throws {
        try withScratchDefaults { defaults in
            let rig = ServiceRig(defaults: defaults, loadError: .newerSchema(3))
            rig.catalog.windowList = [catalogWindow(frame: CGRect(x: 50, y: 100, width: 300, height: 400))]

            #expect(throws: ArrangementError.storage(.readOnly)) { try rig.service.captureCurrent(named: "Work") }

            #expect(rig.storage.saveCount == 0)
        }
    }
}

@MainActor
@Suite("Arrangement service: save")
struct ArrangementSaveServiceTests {

    @Test("saving replaces the arrangement with the same id in place")
    func saveReplaces() throws {
        try withScratchDefaults { defaults in
            let original = fixtureArrangement(name: "Work")
            let other = fixtureArrangement(name: "Other")
            let rig = ServiceRig(defaults: defaults, arrangements: [original, other])
            var renamed = original
            renamed.name = "Renamed"

            try rig.service.save(renamed)

            #expect(rig.store.document.savedArrangements.map(\.name) == ["Renamed", "Other"])
            #expect(rig.store.document.savedArrangements.map(\.id) == [original.id, other.id])
            #expect(rig.storage.saveCount == 1)
        }
    }

    @Test("saving an unknown id throws notFound and does not bring the arrangement back")
    func saveUnknownIdThrowsNotFound() throws {
        try withScratchDefaults { defaults in
            let rig = ServiceRig(defaults: defaults, arrangements: [fixtureArrangement(name: "Kept")])

            #expect(throws: ArrangementError.notFound) { try rig.service.save(fixtureArrangement(name: "Deleted")) }

            #expect(rig.store.document.savedArrangements.map(\.name) == ["Kept"])
            #expect(rig.storage.saveCount == 0)
        }
    }

    @Test("an arrangement deleted while being edited cannot be saved back")
    func saveAfterDeleteThrowsNotFound() throws {
        try withScratchDefaults { defaults in
            let arrangement = fixtureArrangement()
            let rig = ServiceRig(defaults: defaults, arrangements: [arrangement])
            try rig.service.delete(arrangement.id)

            #expect(throws: ArrangementError.notFound) { try rig.service.save(arrangement) }

            #expect(rig.service.arrangementIDs.isEmpty)
        }
    }

    @Test("a failed write keeps the stored arrangement as it was")
    func failedSaveKeepsOriginal() throws {
        try withScratchDefaults { defaults in
            let original = fixtureArrangement(name: "Work")
            let rig = ServiceRig(defaults: defaults, arrangements: [original])
            rig.storage.saveError = .writeFailed("disk full")
            var renamed = original
            renamed.name = "Renamed"

            #expect(throws: ArrangementError.storage(.writeFailed("disk full"))) { try rig.service.save(renamed) }

            #expect(rig.store.document.savedArrangements == [original])
        }
    }

    @Test("a read-only store refuses to save")
    func readOnlyRefusesSave() throws {
        try withScratchDefaults { defaults in
            let rig = ServiceRig(defaults: defaults, loadError: .newerSchema(3))

            #expect(throws: ArrangementError.storage(.readOnly)) { try rig.service.save(fixtureArrangement()) }

            #expect(rig.storage.saveCount == 0)
        }
    }
}

@MainActor
@Suite("Arrangement service: apply")
struct ArrangementApplyServiceTests {

    private static let leftSlot = fixtureSlot(displayKey, 0, 0, 0.5, 1)
    private static let rightSlot = fixtureSlot(displayKey, 0.5, 0, 0.5, 1)

    @Test("every running entry is moved to its zone and the rest is reported")
    func movesRunningEntriesAndReportsTheRest() throws {
        try withScratchDefaults { defaults in
            let arrangement = fixtureArrangement(windows: [
                fixtureWindow(slot: Self.leftSlot),
                fixtureWindow(bundleID: "com.apple.Safari", appName: "Safari", slot: Self.rightSlot)
            ])
            let rig = ServiceRig(defaults: defaults, arrangements: [arrangement])
            let terminal = catalogWindow(frame: CGRect(x: 10, y: 10, width: 100, height: 100))
            rig.catalog.windowList = [terminal]
            rig.catalog.running = ["com.apple.Terminal"]

            let report = rig.service.apply(arrangement.id)

            #expect(report.total == 2)
            #expect(report.placed == 1)
            #expect(report.notRunning == 1)
            #expect(report.notRunningApps == ["Safari"])
            #expect(rig.writer.moves.count == 1)
            #expect(rig.writer.moves.first?.frame == CGRect(x: 0, y: 0, width: 500, height: 800))
            #expect(rig.writer.moves.first.map { CFEqual($0.element, terminal.element) } == true)
        }
    }

    @Test("each window is moved by the title it was saved with, whatever order the catalog lists them in")
    func titlesPairWindowsWithElements() throws {
        try withScratchDefaults { defaults in
            let arrangement = fixtureArrangement(windows: [
                fixtureWindow(titleHint: "build", slot: Self.leftSlot),
                fixtureWindow(titleHint: "logs", slot: Self.rightSlot)
            ])
            let rig = ServiceRig(defaults: defaults, arrangements: [arrangement])
            let logs = catalogWindow(title: "logs", ordinal: 0, frame: CGRect(x: 10, y: 10, width: 100, height: 100))
            let build = catalogWindow(title: "build", pid: 70_050, ordinal: 1, frame: CGRect(x: 20, y: 20, width: 100, height: 100))
            rig.catalog.windowList = [logs, build]
            rig.catalog.running = ["com.apple.Terminal"]

            let report = rig.service.apply(arrangement.id)

            #expect(report.placed == 2)
            let buildMove = try #require(rig.writer.moves.first { CFEqual($0.element, build.element) })
            let logsMove = try #require(rig.writer.moves.first { CFEqual($0.element, logs.element) })
            #expect(rig.writer.moves.count == 2)
            #expect(buildMove.frame == CGRect(x: 0, y: 0, width: 500, height: 800))
            #expect(logsMove.frame == CGRect(x: 500, y: 0, width: 500, height: 800))
        }
    }

    @Test("the window gap setting insets the target frames")
    func gapApplied() throws {
        try withScratchDefaults { defaults in
            let arrangement = fixtureArrangement(windows: [fixtureWindow(slot: Self.rightSlot)])
            let rig = ServiceRig(defaults: defaults, arrangements: [arrangement], gap: 10)
            rig.catalog.windowList = [catalogWindow(frame: CGRect(x: 10, y: 10, width: 100, height: 100))]
            rig.catalog.running = ["com.apple.Terminal"]

            rig.service.apply(arrangement.id)

            #expect(rig.writer.moves.first?.frame == CGRect(x: 505, y: 5, width: 490, height: 790))
        }
    }

    @Test("an app that runs but has no window left is reported and nothing is moved")
    func runningAppWithoutWindows() throws {
        try withScratchDefaults { defaults in
            let arrangement = fixtureArrangement(windows: [fixtureWindow(slot: Self.leftSlot)])
            let rig = ServiceRig(defaults: defaults, arrangements: [arrangement])
            rig.catalog.running = ["com.apple.Terminal"]

            let report = rig.service.apply(arrangement.id)

            #expect(report.noWindow == 1)
            #expect(report.placed == 0)
            #expect(rig.writer.moves.isEmpty)
        }
    }

    @Test("an entry on a display that is not connected is reported and nothing is moved")
    func displayNotConnected() throws {
        try withScratchDefaults { defaults in
            let arrangement = fixtureArrangement(windows: [fixtureWindow(slot: fixtureSlot("uuid:GONE", 0, 0, 0.5, 1))])
            let rig = ServiceRig(defaults: defaults, arrangements: [arrangement])
            rig.catalog.windowList = [catalogWindow(frame: CGRect(x: 10, y: 10, width: 100, height: 100))]
            rig.catalog.running = ["com.apple.Terminal"]

            let report = rig.service.apply(arrangement.id)

            #expect(report.displayMissing == 1)
            #expect(report.placed == 0)
            #expect(rig.writer.moves.isEmpty)
        }
    }

    @Test("without the permission no window is read or moved and running apps count as windowless")
    func deniedMovesNothing() throws {
        try withScratchDefaults { defaults in
            let arrangement = fixtureArrangement(windows: [fixtureWindow(slot: Self.leftSlot)])
            let rig = ServiceRig(defaults: defaults, arrangements: [arrangement], hasPermission: false)
            rig.catalog.windowList = [catalogWindow(frame: CGRect(x: 10, y: 10, width: 100, height: 100))]
            rig.catalog.running = ["com.apple.Terminal"]

            let report = rig.service.apply(arrangement.id)

            #expect(rig.catalog.windowReads == 0)
            #expect(rig.writer.moves.isEmpty)
            #expect(report.placed == 0)
            #expect(report.noWindow == 1)
        }
    }

    @Test("the report accounts for every entry exactly once")
    func reportSumsToTotal() throws {
        try withScratchDefaults { defaults in
            let arrangement = fixtureArrangement(windows: [
                fixtureWindow(slot: Self.leftSlot),
                fixtureWindow(slot: Self.rightSlot),
                fixtureWindow(bundleID: "com.apple.Safari", appName: "Safari", slot: Self.leftSlot),
                fixtureWindow(bundleID: "com.apple.Notes", appName: "Notes", slot: fixtureSlot("uuid:GONE", 0, 0, 1, 1))
            ])
            let rig = ServiceRig(defaults: defaults, arrangements: [arrangement])
            rig.catalog.windowList = [catalogWindow(frame: CGRect(x: 10, y: 10, width: 100, height: 100))]
            rig.catalog.running = ["com.apple.Terminal", "com.apple.Notes"]

            let report = rig.service.apply(arrangement.id)

            #expect(report.total == 4)
            #expect(report.placed + report.notRunning + report.noWindow + report.displayMissing == report.total)
            #expect(report.placed == 1)
            #expect(report.noWindow == 1)
            #expect(report.notRunning == 1)
            #expect(report.displayMissing == 1)
            #expect(rig.writer.moves.count == report.placed)
        }
    }
}
