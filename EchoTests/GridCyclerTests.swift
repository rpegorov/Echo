import AppKit
import Foundation
import Testing
@testable import Echo

// The command works on whichever display the focused window or the pointer is on, so each test
// reads that display back from the flash instead of assuming a screen layout.

@MainActor
private final class FlashSpy: SnapOverlayPresenting {
    private(set) var flashes: [GridFlash] = []
    private(set) var shows = 0
    private(set) var hides = 0

    func show(_ preview: SnapPreview) { shows += 1 }
    func hide() { hides += 1 }
    func flash(_ grid: GridFlash) { flashes.append(grid) }
}

@MainActor
private struct Rig {
    let storage: InMemoryGridStorage
    let store: GridStore
    let overlay = FlashSpy()
    let cycler: GridCycler

    init(defaults: UserDefaults, document: GridDocument = .empty, loadError: GridStorageError? = nil) {
        storage = InMemoryGridStorage(document: document, loadError: loadError)
        store = GridStore(storage: storage)
        cycler = GridCycler(
            windowManager: WindowManagerService(), store: store,
            settings: AppSettings(defaults: defaults), overlay: overlay)
    }
}

/// The display the cycler picked, found from the frame it flashed on.
@MainActor
private func screenAndKey(of flash: GridFlash) throws -> (screen: NSScreen, key: DisplayKey) {
    let screen = try #require(NSScreen.screens.first { $0.frame == flash.screenFrame })
    let key = try #require(DisplayIdentity.key(for: screen))
    return (screen, key)
}

@MainActor
private func aspect(of screen: NSScreen) -> Double {
    screen.visibleFrame.width / screen.visibleFrame.height
}

@MainActor
@Suite("Next grid command")
struct GridCyclerTests {

    @Test("advancing stores the next grid for the display and flashes it")
    func advanceStoresAndFlashes() throws {
        try withScratchDefaults { defaults in
            let rig = Rig(defaults: defaults)

            rig.cycler.advance()

            let flash = try #require(rig.overlay.flashes.first)
            #expect(rig.overlay.flashes.count == 1)
            let (screen, key) = try screenAndKey(of: flash)
            let expected = GridCycle.next(after: nil, saved: [], aspect: aspect(of: screen))
            #expect(rig.store.document.activeRef(for: key) == expected)
            #expect(rig.storage.document.activeRef(for: key) == expected)
            #expect(flash.zoneFrames.count == rig.store.activeZones(for: key, aspect: aspect(of: screen)).count)
        }
    }

    @Test("advancing twice walks two steps")
    func advanceTwice() throws {
        try withScratchDefaults { defaults in
            let rig = Rig(defaults: defaults)

            rig.cycler.advance()
            rig.cycler.advance()

            let flash = try #require(rig.overlay.flashes.last)
            let (screen, key) = try screenAndKey(of: flash)
            let first = GridCycle.next(after: nil, saved: [], aspect: aspect(of: screen))
            let second = GridCycle.next(after: first, saved: [], aspect: aspect(of: screen))
            #expect(rig.overlay.flashes.count == 2)
            #expect(rig.store.document.activeRef(for: key) == second)
        }
    }

    @Test("stepping from the last template lands on a saved grid and flashes it by name")
    func landsOnSavedGrid() throws {
        try withScratchDefaults { defaults in
            let probe = Rig(defaults: defaults)
            probe.cycler.advance()
            let (_, key) = try screenAndKey(of: #require(probe.overlay.flashes.first))
            let thirds = ZoneGrid(id: UUID(), name: "Thirds", zones: GridTemplate.threeColumns.zones)
            let document = GridDocument(
                grids: [thirds], activeByDisplay: [key.rawValue: .template(kind: .mainAndTwoSides)],
                arrangements: nil, autoRules: nil)
            let rig = Rig(defaults: defaults, document: document)

            rig.cycler.advance()

            let flash = try #require(rig.overlay.flashes.first)
            #expect(rig.store.document.activeRef(for: key) == .saved(id: thirds.id))
            #expect(flash.title == .named("Thirds"))
            #expect(flash.zoneFrames.count == thirds.zones.count)
        }
    }

    @Test("a read-only store shows the current grid and writes nothing")
    func readOnlyStoreOnlyFlashes() throws {
        try withScratchDefaults { defaults in
            let rig = Rig(defaults: defaults, loadError: .newerSchema(3))

            rig.cycler.advance()

            let flash = try #require(rig.overlay.flashes.first)
            let (screen, key) = try screenAndKey(of: flash)
            #expect(rig.storage.saveCount == 0)
            #expect(rig.store.document.activeRef(for: key) == nil)
            #expect(flash.title == .template(GridTemplate.default(forAspect: aspect(of: screen))))
        }
    }

    @Test("a failed write keeps the grid and flashes the unchanged one")
    func failedWriteFlashesUnchangedGrid() throws {
        try withScratchDefaults { defaults in
            let rig = Rig(defaults: defaults)
            rig.storage.saveError = .writeFailed("disk full")

            rig.cycler.advance()

            let flash = try #require(rig.overlay.flashes.first)
            let (screen, key) = try screenAndKey(of: flash)
            #expect(rig.overlay.flashes.count == 1)
            #expect(rig.store.document.activeRef(for: key) == nil)
            #expect(flash.title == .template(GridTemplate.default(forAspect: aspect(of: screen))))
        }
    }
}
