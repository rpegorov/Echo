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

    /// The display the canvas proportions come from; nil when none is connected.
    let display: ConnectedDisplay?
    private let activatesOnSave: Bool
    private let store: GridStore
    private let templateTitle: (GridTemplate) -> String
    private var baseline: ZoneGrid
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
    }

    /// Writes the grid and, when asked, makes it active on the display. True when the editor can close.
    func save() -> Bool {
        guard canSave else { return false }
        var grid = draft
        grid.name = trimmedName
        do {
            try store.save(grid)
            draft = grid
            baseline = grid
            if activatesOnSave, let display {
                try store.setActive(.saved(id: grid.id), for: display.key)
            }
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
