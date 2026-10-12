import Foundation
import Testing
@testable import Echo

private let primaryDisplay = ConnectedDisplay(
    key: DisplayKey(rawValue: "uuid:primary"), name: "Primary", visibleSize: CGSize(width: 1600, height: 900))

private func title(_ template: GridTemplate) -> String { "Title \(template.rawValue)" }

@MainActor private func makeModel(
    source: GridEditorRequest.Source = .template(.threeColumns),
    activatesOnSave: Bool = false,
    display: ConnectedDisplay? = primaryDisplay,
    store: GridStore = GridStore(storage: InMemoryGridStorage())
) -> GridEditorModel {
    let request = GridEditorRequest(source: source, display: display?.key, activatesOnSave: activatesOnSave)
    return GridEditorModel(store: store, request: request, display: display, templateTitle: title)
}

@MainActor private func verticalEdge(of model: GridEditorModel, near position: Double) throws -> GridEdge {
    try #require(model.edges.first { $0.axis == .vertical && abs($0.position - position) < 0.01 })
}

private func expectZones(_ actual: [UnitRect], _ expected: [UnitRect], sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(actual.count == expected.count, sourceLocation: sourceLocation)
    for (a, e) in zip(actual, expected) {
        #expect(abs(a.x - e.x) < 1e-9 && abs(a.y - e.y) < 1e-9
                && abs(a.width - e.width) < 1e-9 && abs(a.height - e.height) < 1e-9,
                "\(a) is not \(e)", sourceLocation: sourceLocation)
    }
}

/// Fails every write from the `failingWrite`-th on; counts the writes it accepted.
@MainActor
private final class FlakyGridStorage: GridDocumentStoring {
    var document: GridDocument = .empty
    private let failingWrite: Int
    private(set) var writeAttempts = 0

    init(failingWrite: Int) { self.failingWrite = failingWrite }

    func load() throws(GridStorageError) -> GridDocument { document }

    func save(_ document: GridDocument) throws(GridStorageError) {
        writeAttempts += 1
        if writeAttempts >= failingWrite { throw .writeFailed("disk full") }
        self.document = document
    }
}

@MainActor
@Suite("Grid editor model")
struct GridEditorModelTests {

    // MARK: - Border drag

    @Test("pressing a border without moving leaves the zones and the dirty flag alone")
    func pressWithoutMovementChangesNothing() throws {
        let model = makeModel(source: .template(.threeColumns))
        let original = model.draft.zones
        let edge = try verticalEdge(of: model, near: 1.0 / 3)

        model.beginDrag(of: edge, pointerPosition: edge.position)
        model.drag(toPointerPosition: edge.position)
        model.endDrag()

        expectZones(model.draft.zones, original)
        #expect(!model.isDirty)
    }

    @Test("dragging a border away and back to the press point restores the grid")
    func dragBackToStartRestoresZones() throws {
        let model = makeModel(source: .template(.threeColumns))
        let original = model.draft.zones
        let edge = try verticalEdge(of: model, near: 1.0 / 3)

        model.beginDrag(of: edge, pointerPosition: edge.position)
        model.drag(toPointerPosition: edge.position + 0.1)
        model.drag(toPointerPosition: edge.position)
        model.endDrag()

        expectZones(model.draft.zones, original)
        #expect(!model.isDirty)
    }

    @Test("pressing a border off its centre and not moving does not shift it")
    func pressOffCentreDoesNotJump() throws {
        let model = makeModel(source: .template(.threeColumns))
        let original = model.draft.zones
        let edge = try verticalEdge(of: model, near: 2.0 / 3)

        model.beginDrag(of: edge, pointerPosition: edge.position + 0.013)
        model.drag(toPointerPosition: edge.position + 0.013)
        model.endDrag()

        expectZones(model.draft.zones, original)
        #expect(!model.isDirty)
    }

    @Test("a drag moves the border by the pointer's travel")
    func dragFollowsPointerTravel() throws {
        let model = makeModel(source: .template(.twoColumns))
        let edge = try verticalEdge(of: model, near: 0.5)

        model.beginDrag(of: edge, pointerPosition: 0.52)
        model.drag(toPointerPosition: 0.62)
        model.endDrag()

        expectZones(model.draft.zones, [
            UnitRect(x: 0, y: 0, width: 0.6, height: 1),
            UnitRect(x: 0.6, y: 0, width: 0.4, height: 1),
        ])
        #expect(model.isDirty)
    }

    @Test("repeated drag frames do not accumulate the shift")
    func repeatedFramesDoNotAccumulate() throws {
        let model = makeModel(source: .template(.twoColumns))
        let edge = try verticalEdge(of: model, near: 0.5)

        model.beginDrag(of: edge, pointerPosition: 0.5)
        model.drag(toPointerPosition: 0.6)
        model.drag(toPointerPosition: 0.6)
        model.drag(toPointerPosition: 0.6)
        model.endDrag()

        expectZones(model.draft.zones, [
            UnitRect(x: 0, y: 0, width: 0.6, height: 1),
            UnitRect(x: 0.6, y: 0, width: 0.4, height: 1),
        ])
    }

    @Test("a frame is computed from the gesture start, not from the previous frame")
    func frameIsRelativeToGestureStart() throws {
        let model = makeModel(source: .template(.twoColumns))
        let edge = try verticalEdge(of: model, near: 0.5)

        model.beginDrag(of: edge, pointerPosition: 0.5)
        model.drag(toPointerPosition: 0.7)
        model.drag(toPointerPosition: 0.55)
        model.endDrag()

        expectZones(model.draft.zones, [
            UnitRect(x: 0, y: 0, width: 0.55, height: 1),
            UnitRect(x: 0.55, y: 0, width: 0.45, height: 1),
        ])
    }

    @Test("a drag outside a gesture does nothing")
    func dragWithoutBeginIsIgnored() {
        let model = makeModel(source: .template(.twoColumns))
        let original = model.draft.zones

        model.drag(toPointerPosition: 0.8)

        #expect(model.draft.zones == original)
        #expect(!model.isDragging)
    }

    // MARK: - Dirty state

    @Test("a fresh editor is not dirty")
    func freshEditorIsClean() {
        #expect(!makeModel().isDirty)
    }

    @Test("splitting a zone makes the editor dirty")
    func splitMakesDirty() {
        let model = makeModel(source: .template(.twoColumns))

        model.split(zone: 0, along: .rows)

        #expect(model.draft.zones.count == 3)
        #expect(model.isDirty)
    }

    @Test("a successful save clears the dirty flag and the error")
    func saveClearsDirty() throws {
        let store = GridStore(storage: InMemoryGridStorage())
        let model = makeModel(source: .template(.twoColumns), store: store)
        model.split(zone: 0, along: .rows)

        #expect(model.save())

        #expect(!model.isDirty)
        #expect(model.saveError == nil)
        #expect(store.document.grids.map(\.zones) == [model.draft.zones])
    }

    // MARK: - Name

    @Test("a template starts with the template's title as its name")
    func templateTitleIsDefaultName() {
        let model = makeModel(source: .template(.twoByTwo))

        #expect(model.name == title(.twoByTwo))
        #expect(model.canSave)
    }

    @Test("a saved grid opens under its own name and zones")
    func savedGridKeepsItsName() throws {
        let store = GridStore(storage: InMemoryGridStorage())
        let saved = ZoneGrid(id: UUID(), name: "Work", zones: GridTemplate.mainAndSide.zones)
        try store.save(saved)

        let model = makeModel(source: .saved(saved.id), store: store)

        #expect(model.name == "Work")
        #expect(model.draft.zones == saved.zones)
        #expect(!model.isDirty)
    }

    @Test("an empty or blank name cannot be saved", arguments: ["", "   ", "\n\t"])
    func blankNameBlocksSave(name: String) {
        let storage = InMemoryGridStorage()
        let model = makeModel(store: GridStore(storage: storage))

        model.name = name

        #expect(!model.canSave)
        #expect(!model.save())
        #expect(storage.saveCount == 0)
    }

    @Test("the saved name is trimmed")
    func savedNameIsTrimmed() {
        let store = GridStore(storage: InMemoryGridStorage())
        let model = makeModel(store: store)
        model.name = "  Review  "

        #expect(model.save())

        #expect(store.document.grids.map(\.name) == ["Review"])
    }

    @Test("a name the user typed survives choosing another template")
    func typedNameSurvivesTemplateChange() {
        let model = makeModel(source: .template(.twoColumns))
        model.name = "My layout"

        model.applyTemplate(.twoByTwo)

        #expect(model.name == "My layout")
        #expect(model.draft.zones == GridTemplate.twoByTwo.zones)
    }

    @Test("an untouched template name follows the chosen template")
    func untouchedNameFollowsTemplate() {
        let model = makeModel(source: .template(.twoColumns))

        model.applyTemplate(.mainAndSide)

        #expect(model.name == title(.mainAndSide))
    }

    @Test("a store that cannot write blocks saving")
    func readOnlyStoreBlocksSave() {
        let storage = InMemoryGridStorage(loadError: .newerSchema(99))
        let model = makeModel(store: GridStore(storage: storage))

        #expect(model.isReadOnly)
        #expect(!model.canSave)
        #expect(!model.save())
        #expect(storage.saveCount == 0)
    }

    // MARK: - Save with activation

    @Test("saving with activation writes once and leaves the grid saved and active on the display")
    func saveWithActivationIsOneWrite() {
        let storage = InMemoryGridStorage()
        let store = GridStore(storage: storage)
        let model = makeModel(activatesOnSave: true, store: store)

        #expect(model.save())

        let id = model.draft.id
        #expect(store.document.grids.map(\.id) == [id])
        #expect(store.document.activeRef(for: primaryDisplay.key) == .saved(id: id))
        #expect(storage.document == store.document)
        #expect(storage.saveCount == 1)
    }

    @Test("saving without activation leaves the display's active grid alone")
    func saveWithoutActivationKeepsActive() {
        let store = GridStore(storage: InMemoryGridStorage())
        let model = makeModel(activatesOnSave: false, store: store)

        #expect(model.save())

        #expect(store.document.grids.count == 1)
        #expect(store.document.activeRef(for: primaryDisplay.key) == nil)
    }

    @Test("saving with activation but no connected display only saves the grid")
    func activationWithoutDisplayOnlySaves() {
        let storage = InMemoryGridStorage()
        let store = GridStore(storage: storage)
        let model = makeModel(activatesOnSave: true, display: nil, store: store)

        #expect(model.save())

        #expect(store.document.grids.count == 1)
        #expect(store.document.activeByDisplay.isEmpty)
        #expect(storage.saveCount == 1)
    }

    @Test("a refused write saves nothing, activates nothing and keeps the edits unsaved")
    func refusedWriteChangesNothing() {
        let storage = InMemoryGridStorage()
        let store = GridStore(storage: storage)
        let model = makeModel(source: .template(.twoColumns), activatesOnSave: true, store: store)
        model.split(zone: 0, along: .rows)
        storage.saveError = .writeFailed("disk full")

        #expect(!model.save())

        #expect(store.document == .empty)
        #expect(storage.document == .empty)
        #expect(model.saveError == .writeFailed("disk full"))
        #expect(model.isDirty)
    }

    @Test("a write failing after the first one never leaves a saved grid that is not active")
    func gridAndActivationSucceedOrFailTogether() {
        let storage = FlakyGridStorage(failingWrite: 2)
        let store = GridStore(storage: storage)
        let model = makeModel(activatesOnSave: true, store: store)

        let closed = model.save()

        let id = model.draft.id
        let isSaved = store.document.grids.contains { $0.id == id }
        let isActive = store.document.activeRef(for: primaryDisplay.key) == .saved(id: id)
        #expect(isSaved == isActive)
        #expect(closed == isSaved)
        #expect(closed == (model.saveError == nil))
        #expect(closed == !model.isDirty)
    }

    @Test("a failed save can be retried after the store recovers")
    func retryAfterFailureSucceeds() {
        let storage = InMemoryGridStorage()
        let store = GridStore(storage: storage)
        let model = makeModel(activatesOnSave: true, store: store)
        storage.saveError = .writeFailed("disk full")
        #expect(!model.save())

        storage.saveError = nil

        #expect(model.save())
        #expect(model.saveError == nil)
        #expect(!model.isDirty)
        #expect(store.document.activeRef(for: primaryDisplay.key) == .saved(id: model.draft.id))
    }
}
