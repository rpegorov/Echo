import CoreGraphics
import Foundation
import Testing
@testable import Echo

@MainActor
private final class ArrangementServiceDouble: ArrangementManaging {
    var saveFailure: ArrangementError?
    private(set) var saved: [Arrangement] = []

    var arrangementIDs: Set<UUID> { [] }

    func apply(_ id: UUID) -> ArrangementApplyReport { ArrangementApplyReport() }

    func captureCurrent(named name: String) throws(ArrangementError) -> Arrangement {
        throw .noWindows
    }

    func save(_ arrangement: Arrangement) throws(ArrangementError) {
        if let saveFailure { throw saveFailure }
        saved.append(arrangement)
    }

    func delete(_ id: UUID) throws(ArrangementError) {}
}

private let laptopKey = "uuid:LAPTOP"
private let studioKey = "uuid:STUDIO"
private let goneKey = "uuid:GONE"
private let deskKey = "uuid:DESK"

private func connectedDisplay(_ key: String, _ name: String, zones: [UnitRect], width: Double = 1600, height: Double = 1000) -> DisplaySnapshot {
    let frame = CGRect(x: 0, y: 0, width: width, height: height)
    return DisplaySnapshot(key: DisplayKey(rawValue: key), name: name, frame: frame, visibleFrame: frame, zones: zones)
}

private let laptopZones = GridTemplate.twoColumns.zones
private let studioZones = GridTemplate.threeColumns.zones

@MainActor
private struct Rig {
    let model: ArrangementEditorModel
    let service: ArrangementServiceDouble
    let terminal: ArrangedWindow
    let safari: ArrangedWindow
    let mail: ArrangedWindow

    /// Terminal and Safari on the laptop (zones 1 and 2), Mail on the studio display (zone 1);
    /// a desk display is connected but not part of the arrangement.
    init(store: GridStore = GridStore(storage: InMemoryGridStorage()), extraDisplays: [String: SavedDisplay] = [:]) {
        terminal = fixtureWindow(bundleID: "t", appName: "Terminal", slot: ZoneSlot(display: laptopKey, rect: laptopZones[0]))
        safari = fixtureWindow(bundleID: "s", appName: "Safari", slot: ZoneSlot(display: laptopKey, rect: laptopZones[1]))
        mail = fixtureWindow(bundleID: "m", appName: "Mail", slot: ZoneSlot(display: studioKey, rect: studioZones[0]))
        let arrangement = Arrangement(
            id: UUID(), name: "Work", windows: [terminal, safari, mail],
            displays: [
                laptopKey: SavedDisplay(name: "Laptop", aspect: 1.6),
                studioKey: SavedDisplay(name: "Studio", aspect: 1.6)
            ].merging(extraDisplays) { _, new in new })
        service = ArrangementServiceDouble()
        model = ArrangementEditorModel(
            store: store, arrangements: service, arrangement: arrangement,
            connected: [
                connectedDisplay(laptopKey, "Laptop", zones: laptopZones),
                connectedDisplay(studioKey, "Studio", zones: studioZones, width: 3440, height: 1440),
                connectedDisplay(deskKey, "Desk", zones: laptopZones, width: 2560, height: 1440)
            ])
    }

    func slot(of window: ArrangedWindow) -> ZoneSlot? { model.window(window.id)?.slot }
}

struct ArrangementEditorModelEditingTests {
    @Test @MainActor func freshModelIsClean() {
        let rig = Rig()
        #expect(!rig.model.isDirty)
        #expect(rig.model.saveMessage == nil)
        #expect(rig.model.drag == nil)
    }

    @Test @MainActor func movingToAnotherZoneChangesTheSlotToThatZonesRect() {
        let rig = Rig()
        rig.model.move(window: rig.terminal.id, toDisplay: laptopKey, zone: 1)
        #expect(rig.slot(of: rig.terminal) == ZoneSlot(display: laptopKey, rect: laptopZones[1]))
        #expect(rig.model.isDirty)
    }

    @Test @MainActor func movingToAnotherDisplayUsesThatDisplaysGrid() {
        let rig = Rig()
        rig.model.move(window: rig.terminal.id, toDisplay: studioKey, zone: 2)
        #expect(rig.slot(of: rig.terminal) == ZoneSlot(display: studioKey, rect: studioZones[2]))
    }

    @Test @MainActor func movingToTheCurrentSlotKeepsTheModelClean() {
        let rig = Rig()
        rig.model.move(window: rig.terminal.id, toDisplay: laptopKey, zone: 0)
        #expect(!rig.model.isDirty)
    }

    @Test @MainActor func invalidMovesChangeNothing() {
        let rig = Rig()
        rig.model.move(window: UUID(), toDisplay: laptopKey, zone: 0)
        rig.model.move(window: rig.terminal.id, toDisplay: "uuid:NOPE", zone: 0)
        rig.model.move(window: rig.terminal.id, toDisplay: laptopKey, zone: laptopZones.count)
        rig.model.move(window: rig.terminal.id, toDisplay: laptopKey, zone: -1)
        #expect(!rig.model.isDirty)
        #expect(rig.slot(of: rig.terminal)?.rect == laptopZones[0])
    }

    @Test @MainActor func movingToADisconnectedDisplayUsesTheGridTheStoreKnowsForIt() {
        let document = GridDocument(
            grids: [], activeByDisplay: [goneKey: .template(kind: .twoByTwo)], arrangements: nil, autoRules: nil)
        let rig = Rig(
            store: GridStore(storage: InMemoryGridStorage(document: document)),
            extraDisplays: [goneKey: SavedDisplay(name: "Dell", aspect: 1.6)])
        #expect(rig.model.moveTargets.map(\.key).contains(goneKey))
        rig.model.move(window: rig.terminal.id, toDisplay: goneKey, zone: 3)
        #expect(rig.slot(of: rig.terminal) == ZoneSlot(display: goneKey, rect: GridTemplate.twoByTwo.zones[3]))
    }

    @Test @MainActor func removingDropsOnlyThatWindow() {
        let rig = Rig()
        rig.model.remove(window: rig.safari.id)
        #expect(rig.model.draft.windows.map(\.id) == [rig.terminal.id, rig.mail.id])
        #expect(rig.model.isDirty)
    }

    @Test @MainActor func removingAnUnknownWindowChangesNothing() {
        let rig = Rig()
        rig.model.remove(window: UUID())
        #expect(!rig.model.isDirty)
        #expect(rig.model.draft.windows.count == 3)
    }

    @Test @MainActor func renamingMarksTheModelDirty() {
        let rig = Rig()
        rig.model.name = "Focus"
        #expect(rig.model.draft.name == "Focus")
        #expect(rig.model.isDirty)
    }

    @Test @MainActor func movingAWindowToAConnectedDisplayNewToTheArrangementAddsItToTheDrawnDisplays() {
        let rig = Rig()
        #expect(!rig.model.displays.map(\.key).contains(deskKey))
        #expect(rig.model.moveTargets.map(\.key).contains(deskKey))
        rig.model.move(window: rig.terminal.id, toDisplay: deskKey, zone: 1)
        #expect(rig.model.displays.map(\.key).contains(deskKey))
        #expect(rig.model.draft.displays[deskKey] == SavedDisplay(name: "Desk", aspect: 2560.0 / 1440.0))
    }
}

struct ArrangementEditorModelSaveTests {
    @Test @MainActor func saveHandsTheDraftToTheServiceAndClosesClean() {
        let rig = Rig()
        rig.model.move(window: rig.terminal.id, toDisplay: laptopKey, zone: 1)
        #expect(rig.model.save())
        #expect(rig.service.saved.count == 1)
        #expect(rig.service.saved.first?.windows.first { $0.id == rig.terminal.id }?.slot.rect == laptopZones[1])
        #expect(!rig.model.isDirty)
        #expect(rig.model.saveMessage == nil)
    }

    @Test @MainActor func saveDropsDisplaysNoWindowPointsAtAnymore() {
        let rig = Rig()
        rig.model.remove(window: rig.mail.id)
        #expect(rig.model.save())
        #expect(rig.service.saved.first?.displays.keys.sorted() == [laptopKey])
    }

    @Test @MainActor func saveKeepsADisplayEvenWhenItIsDisconnected() {
        let rig = Rig(extraDisplays: [goneKey: SavedDisplay(name: "Dell", aspect: 2.4)])
        rig.model.move(window: rig.safari.id, toDisplay: goneKey, zone: 0)
        #expect(rig.model.save())
        #expect(rig.service.saved.first?.displays.keys.sorted() == [goneKey, laptopKey, studioKey].sorted())
    }

    @Test @MainActor func saveKeepsTheDisplayAWindowWasMovedOnto() {
        let rig = Rig()
        rig.model.move(window: rig.terminal.id, toDisplay: deskKey, zone: 1)
        #expect(rig.model.save())
        let saved = rig.service.saved.first
        #expect(saved?.displays[deskKey] == SavedDisplay(name: "Desk", aspect: 2560.0 / 1440.0))
        #expect(saved?.displays[laptopKey] != nil)
    }

    @Test @MainActor func everySavedSlotHasItsDisplayInTheSavedArrangement() {
        let rig = Rig()
        rig.model.move(window: rig.terminal.id, toDisplay: studioKey, zone: 1)
        rig.model.remove(window: rig.safari.id)
        #expect(rig.model.save())
        let saved = rig.service.saved.first
        for window in saved?.windows ?? [] {
            #expect(saved?.displays[window.slot.display] != nil)
        }
    }

    @Test @MainActor func saveTrimsTheName() {
        let rig = Rig()
        rig.model.name = "  Focus \n"
        #expect(rig.model.save())
        #expect(rig.service.saved.first?.name == "Focus")
    }

    @Test @MainActor func blankNameCannotBeSaved() {
        let rig = Rig()
        rig.model.name = "   "
        #expect(!rig.model.canSave)
        #expect(!rig.model.save())
        #expect(rig.service.saved.isEmpty)
    }

    @Test @MainActor func readOnlyStoreCannotSave() {
        let store = GridStore(storage: InMemoryGridStorage(loadError: .newerSchema(9)))
        let rig = Rig(store: store)
        rig.model.name = "Focus"
        #expect(rig.model.isReadOnly)
        #expect(!rig.model.canSave)
        #expect(!rig.model.save())
        #expect(rig.service.saved.isEmpty)
    }

    @Test @MainActor func failedSaveKeepsTheEditsAndStaysDirty() {
        let rig = Rig()
        rig.model.move(window: rig.terminal.id, toDisplay: laptopKey, zone: 1)
        rig.service.saveFailure = .storage(.writeFailed("disk full"))
        #expect(!rig.model.save())
        #expect(rig.model.isDirty)
        #expect(rig.slot(of: rig.terminal)?.rect == laptopZones[1])
        #expect(rig.model.saveError == .storage(.writeFailed("disk full")))
    }

    @Test @MainActor func aDeletedArrangementShowsTheSaveFailedLineAndKeepsTheEditorOpen() {
        let rig = Rig()
        rig.model.remove(window: rig.safari.id)
        rig.service.saveFailure = .notFound
        #expect(!rig.model.save())
        guard case .write? = rig.model.saveMessage else {
            Issue.record("expected the save-failed line, got \(String(describing: rig.model.saveMessage))")
            return
        }
        #expect(rig.model.isDirty)
    }

    @Test @MainActor func aRejectedSlotShowsTheSaveFailedLineAndKeepsTheEditorOpen() {
        let rig = Rig()
        rig.model.name = "Focus"
        rig.service.saveFailure = .storage(.invalidSlot)
        #expect(!rig.model.save())
        guard case .write? = rig.model.saveMessage else {
            Issue.record("expected the save-failed line, got \(String(describing: rig.model.saveMessage))")
            return
        }
        #expect(rig.model.isDirty)
    }

    @Test @MainActor func writeFailureCarriesTheReasonToTheLine() {
        let rig = Rig()
        rig.service.saveFailure = .storage(.writeFailed("disk full"))
        _ = rig.model.save()
        #expect(rig.model.saveMessage == .write(reason: "disk full"))
    }

    @Test @MainActor func successfulRetryClearsTheError() {
        let rig = Rig()
        rig.model.name = "Focus"
        rig.service.saveFailure = .notFound
        #expect(!rig.model.save())
        rig.service.saveFailure = nil
        #expect(rig.model.save())
        #expect(rig.model.saveError == nil)
        #expect(rig.model.saveMessage == nil)
        #expect(!rig.model.isDirty)
    }

    @Test @MainActor func editingAfterASaveMakesTheModelDirtyAgain() {
        let rig = Rig()
        rig.model.name = "Focus"
        #expect(rig.model.save())
        rig.model.remove(window: rig.mail.id)
        #expect(rig.model.isDirty)
    }
}

struct ArrangementEditorModelDragTests {
    /// Laptop canvas at the container's left, studio canvas to its right; a 20 pt gap between them.
    @MainActor private func laidOut() -> Rig {
        let rig = Rig()
        rig.model.canvasFrames = [
            laptopKey: CGRect(x: 0, y: 0, width: 200, height: 100),
            studioKey: CGRect(x: 220, y: 0, width: 300, height: 100)
        ]
        return rig
    }

    @Test @MainActor func pointInsideACanvasTargetsTheZoneUnderIt() {
        let rig = laidOut()
        #expect(rig.model.target(at: CGPoint(x: 30, y: 50)) == .init(display: laptopKey, zone: 0))
        #expect(rig.model.target(at: CGPoint(x: 170, y: 50)) == .init(display: laptopKey, zone: 1))
        #expect(rig.model.target(at: CGPoint(x: 220 + 250, y: 10)) == .init(display: studioKey, zone: 2))
    }

    @Test @MainActor func pointOutsideEveryCanvasHasNoTarget() {
        let rig = laidOut()
        #expect(rig.model.target(at: CGPoint(x: 210, y: 50)) == nil)
        #expect(rig.model.target(at: CGPoint(x: 30, y: 150)) == nil)
        #expect(rig.model.target(at: CGPoint(x: -5, y: 50)) == nil)
    }

    @Test @MainActor func canvasTopIsTheTopOfTheGridNotTheBottom() {
        let document = GridDocument(
            grids: [], activeByDisplay: [laptopKey: .template(kind: .twoByTwo)], arrangements: nil, autoRules: nil)
        let zones = GridTemplate.twoByTwo.zones
        let terminal = fixtureWindow(slot: ZoneSlot(display: laptopKey, rect: zones[0]))
        let model = ArrangementEditorModel(
            store: GridStore(storage: InMemoryGridStorage(document: document)),
            arrangements: ArrangementServiceDouble(),
            arrangement: Arrangement(
                id: UUID(), name: "Work", windows: [terminal],
                displays: [laptopKey: SavedDisplay(name: "Laptop", aspect: 1.6)]),
            connected: [connectedDisplay(laptopKey, "Laptop", zones: zones)])
        model.canvasFrames = [laptopKey: CGRect(x: 0, y: 0, width: 200, height: 100)]
        let topLeft = model.target(at: CGPoint(x: 20, y: 10))
        let bottomLeft = model.target(at: CGPoint(x: 20, y: 90))
        let topZone = zones.firstIndex { $0.x == 0 && $0.y == 0.5 }
        let bottomZone = zones.firstIndex { $0.x == 0 && $0.y == 0 }
        #expect(topLeft?.zone == topZone)
        #expect(bottomLeft?.zone == bottomZone)
    }

    @Test @MainActor func dropOnAnotherCanvasMovesTheWindowThere() {
        let rig = laidOut()
        rig.model.dragEnded(window: rig.terminal.id, location: CGPoint(x: 220 + 150, y: 50))
        #expect(rig.slot(of: rig.terminal) == ZoneSlot(display: studioKey, rect: studioZones[1]))
        #expect(rig.model.drag == nil)
    }

    @Test @MainActor func dropOutsideEveryCanvasLeavesTheWindowInPlace() {
        let rig = laidOut()
        rig.model.dragChanged(window: rig.terminal.id, location: CGPoint(x: 30, y: 50))
        rig.model.dragEnded(window: rig.terminal.id, location: CGPoint(x: 210, y: 50))
        #expect(rig.slot(of: rig.terminal)?.rect == laptopZones[0])
        #expect(!rig.model.isDirty)
        #expect(rig.model.drag == nil)
    }

    @Test @MainActor func dragInProgressReportsTheZoneUnderThePointerWithoutEditing() {
        let rig = laidOut()
        rig.model.dragChanged(window: rig.terminal.id, location: CGPoint(x: 170, y: 50))
        #expect(rig.model.drag?.target == .init(display: laptopKey, zone: 1))
        #expect(rig.model.drag?.windowID == rig.terminal.id)
        #expect(!rig.model.isDirty)
    }

    @Test @MainActor func cancelClearsTheDragWithoutEditing() {
        let rig = laidOut()
        rig.model.dragChanged(window: rig.terminal.id, location: CGPoint(x: 170, y: 50))
        rig.model.cancelDrag()
        #expect(rig.model.drag == nil)
        #expect(!rig.model.isDirty)
    }
}
