//
//  GridEditorModel.swift
//  Echo
//

import Foundation

/// The grid being edited and the save flow; grid rules live in the pure grid types, not here.
@MainActor
final class GridEditorModel: ObservableObject {
    /// The working copy. Every edit replaces `draft.zones`; nothing else holds zones.
    @Published private(set) var draft: ZoneGrid
    /// Why the last save failed; nil until a save fails and after one succeeds.
    @Published private(set) var saveError: GridStorageError?
    /// Borders of the draft that can be dragged; follows every change of `draft.zones`.
    @Published private(set) var edges: [GridEdge] = []
    @Published private(set) var hoveredZone: Int?
    @Published private(set) var hoveredEdge: GridEdge?
    /// The border being dragged, as it sits in the current draft; nil outside a drag.
    @Published private(set) var activeEdge: GridEdge?

    /// The display the canvas proportions come from; nil when none is connected.
    let display: ConnectedDisplay?
    private let activatesOnSave: Bool
    private let store: GridStore
    private let templateTitle: (GridTemplate) -> String
    private var baseline: ZoneGrid
    private var dragSnapshot: DragSnapshot?

    /// The zones and border at the start of a drag; every frame of the drag is computed from these.
    private struct DragSnapshot {
        let edge: GridEdge
        let zones: [UnitRect]
        /// Edge position minus pointer position at the start, so the border does not jump under the pointer.
        let grabOffset: Double
    }
    /// The template `draft.name` was taken from while the user has not typed a name of their own.
    private var namingTemplate: GridTemplate?

    init(
        store: GridStore,
        request: GridEditorRequest,
        display: ConnectedDisplay?,
        templateTitle: @escaping (GridTemplate) -> String
    ) {
        self.store = store
        self.display = display
        self.activatesOnSave = request.activatesOnSave
        self.templateTitle = templateTitle

        let aspect = display?.aspect ?? DS.GridEditor.fallbackDisplaySize.width / DS.GridEditor.fallbackDisplaySize.height
        let start = Self.startingGrid(for: request.source, in: store, aspect: aspect, templateTitle: templateTitle)
        draft = start.grid
        baseline = start.grid
        namingTemplate = start.namingTemplate
        edges = GridEditing.edges(of: start.grid.zones)
    }

    var isDirty: Bool { draft != baseline }

    var isReadOnly: Bool { store.isReadOnly }

    var loadNotice: GridLoadNotice? { store.loadNotice }

    var canSave: Bool { !store.isReadOnly && !trimmedName.isEmpty }

    var name: String {
        get { draft.name }
        set { draft.name = newValue }
    }

    /// Replaces the zones with the template's; the name follows the template only while it still is a template title.
    func applyTemplate(_ template: GridTemplate) {
        if let previous = namingTemplate, draft.name == templateTitle(previous) {
            draft.name = templateTitle(template)
            namingTemplate = template
        }
        replaceZones(template.zones)
    }

    /// The single point through which the zones change.
    func replaceZones(_ zones: [UnitRect]) {
        draft.zones = zones
        edges = GridEditing.edges(of: zones)
        hoveredEdge = nil
    }

    // MARK: - Split and merge

    func canSplit(zone index: Int, along axis: SplitAxis) -> Bool {
        GridEditing.split(draft.zones, at: index, along: axis) != nil
    }

    /// Does nothing when the zone is too small to halve along `axis`.
    func split(zone index: Int, along axis: SplitAxis) {
        guard let zones = GridEditing.split(draft.zones, at: index, along: axis) else { return }
        replaceZones(zones)
    }

    /// The zone that `index` can merge into on the `direction` side; nil when the union would not be a rectangle.
    func mergeTarget(zone index: Int, toward direction: GridDirection) -> Int? {
        guard let other = GridEditing.mergeCandidate(draft.zones, of: index, toward: direction),
              GridEditing.merge(draft.zones, index, other) != nil
        else { return nil }
        return other
    }

    func merge(zone index: Int, toward direction: GridDirection) {
        guard let other = mergeTarget(zone: index, toward: direction),
              let zones = GridEditing.merge(draft.zones, index, other)
        else { return }
        replaceZones(zones)
    }

    // MARK: - Hover

    func setHover(zone: Int?, edge: GridEdge?) {
        if hoveredZone != zone { hoveredZone = zone }
        if hoveredEdge != edge { hoveredEdge = edge }
    }

    // MARK: - Border drag

    var isDragging: Bool { dragSnapshot != nil }

    /// The axis of the border grabbed at the start of the drag; fixed for the whole gesture.
    var dragAxis: GridEdge.Axis? { dragSnapshot?.edge.axis }

    /// `pointerPosition` is the pointer's coordinate across the border, in unit space.
    func beginDrag(of edge: GridEdge, pointerPosition: Double) {
        dragSnapshot = DragSnapshot(edge: edge, zones: draft.zones, grabOffset: edge.position - pointerPosition)
        activeEdge = edge
    }

    func drag(toPointerPosition pointerPosition: Double) {
        guard let snapshot = dragSnapshot else { return }
        let target = pointerPosition + snapshot.grabOffset
        // At the press point the border stays exactly where it was, unsnapped to the grid step.
        let atStart = abs(target - snapshot.edge.position) <= GridEditing.tolerance
        let zones = atStart ? snapshot.zones : GridEditing.move(snapshot.edge, to: target, in: snapshot.zones)
        guard zones != draft.zones else { return }
        draft.zones = zones
        edges = GridEditing.edges(of: zones)
        activeEdge = edges
            .filter { $0.axis == snapshot.edge.axis && Self.covers($0, snapshot.edge) }
            .min { abs($0.position - target) < abs($1.position - target) }
    }

    func endDrag() {
        dragSnapshot = nil
        activeEdge = nil
    }

    /// A border may grow when the move lines it up with another one, so the highlight follows any border that covers the grabbed run.
    private static func covers(_ edge: GridEdge, _ grabbed: GridEdge) -> Bool {
        edge.start <= grabbed.start + GridEditing.tolerance && edge.end >= grabbed.end - GridEditing.tolerance
    }

    /// Writes the grid and, when asked, makes it active on the display. True when the editor can close.
    func save() -> Bool {
        guard canSave else { return false }
        var grid = draft
        grid.name = trimmedName
        do {
            try store.save(grid, activatingOn: activatesOnSave ? display?.key : nil)
            draft = grid
            baseline = grid
            saveError = nil
            return true
        } catch {
            saveError = error
            return false
        }
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func startingGrid(
        for source: GridEditorRequest.Source,
        in store: GridStore,
        aspect: Double,
        templateTitle: (GridTemplate) -> String
    ) -> (grid: ZoneGrid, namingTemplate: GridTemplate?) {
        switch source {
        case .template(let template):
            return (template.makeGrid(named: templateTitle(template)), template)
        case .saved(let id):
            if let saved = store.document.grids.first(where: { $0.id == id }) {
                guard saved.zones.isEmpty else { return (saved, nil) }
                var repaired = saved
                repaired.zones = GridTemplate.default(forAspect: aspect).zones
                return (repaired, nil)
            }
            let fallback = GridTemplate.default(forAspect: aspect)
            return (fallback.makeGrid(named: templateTitle(fallback)), fallback)
        }
    }
}
