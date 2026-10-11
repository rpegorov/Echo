//
//  ArrangementEditorModel.swift
//  Echo
//

import CoreGraphics
import Foundation

/// The arrangement being edited, the drag in progress and the save flow; slot rules live in the pure types.
@MainActor
final class ArrangementEditorModel: ObservableObject {

    /// A zone of a canvas, addressed by display key and zone index.
    struct DropTarget: Equatable {
        let display: String
        let zone: Int
    }

    /// An icon being dragged: where the pointer is in the container and the zone under it.
    struct DragState: Equatable {
        let windowID: UUID
        var location: CGPoint
        var target: DropTarget?
    }

    /// Why a save failed, ready for the view to localize.
    enum SaveMessage: Equatable {
        case write(reason: String)
        case unavailable
        case permission
        case noWindows
    }

    /// The working copy. Every edit replaces part of it; nothing else holds the entries.
    @Published private(set) var draft: Arrangement
    @Published private(set) var saveError: ArrangementError?
    @Published private(set) var drag: DragState?

    /// Canvas frames in the container's coordinate space, reported by the canvases.
    var canvasFrames: [String: CGRect] = [:]

    private let store: GridStore
    private let arrangements: any ArrangementManaging
    private let connected: [DisplaySnapshot]
    private var baseline: Arrangement

    init(
        store: GridStore,
        arrangements: any ArrangementManaging,
        arrangement: Arrangement,
        connected: [DisplaySnapshot]
    ) {
        self.store = store
        self.arrangements = arrangements
        self.connected = connected
        draft = arrangement
        baseline = arrangement
    }

    var isDirty: Bool { draft != baseline }

    var isReadOnly: Bool { store.isReadOnly }

    var loadNotice: GridLoadNotice? { store.loadNotice }

    var canSave: Bool { !store.isReadOnly && !trimmedName.isEmpty }

    var name: String {
        get { draft.name }
        set { draft.name = newValue }
    }

    // MARK: - Displays

    /// The displays to draw and the displays a window can move to.
    private var resolvedDisplays: (shown: [ArrangementEditorDisplay], targets: [ArrangementEditorDisplay]) {
        ArrangementEditorDisplay.resolve(
            saved: draft.displays,
            connected: connected,
            disconnectedReferenceWidth: DS.ArrangementEditor.disconnectedReferenceWidth,
            zonesForDisconnected: { [store] key, aspect in
                store.activeZones(for: DisplayKey(rawValue: key), aspect: aspect)
            }
        )
    }

    /// One canvas each: the displays the arrangement refers to.
    var displays: [ArrangementEditorDisplay] { resolvedDisplays.shown }

    /// Where the context menu can send a window: the drawn displays and every other connected one.
    var moveTargets: [ArrangementEditorDisplay] { resolvedDisplays.targets }

    func window(_ id: UUID) -> ArrangedWindow? {
        draft.windows.first { $0.id == id }
    }

    // MARK: - Editing

    /// Puts the window into zone `zone` of the display `display`; a display new to the arrangement joins it.
    func move(window id: UUID, toDisplay display: String, zone: Int) {
        let targets = resolvedDisplays.targets
        guard let index = draft.windows.firstIndex(where: { $0.id == id }),
              let target = targets.first(where: { $0.key == display }),
              target.zones.indices.contains(zone)
        else { return }
        let slot = ZoneSlot(display: display, rect: target.zones[zone])
        guard draft.windows[index].slot != slot else { return }
        draft.windows[index].slot = slot
        if draft.displays[display] == nil { draft.displays[display] = target.saved }
        Self.dropUnreferencedDisplays(from: &draft)
    }

    func remove(window id: UUID) {
        draft.windows.removeAll { $0.id == id }
        Self.dropUnreferencedDisplays(from: &draft)
    }

    // MARK: - Drag

    /// The pointer moved with an icon held; `location` is in the container's coordinate space.
    func dragChanged(window id: UUID, location: CGPoint) {
        drag = DragState(windowID: id, location: location, target: target(at: location))
    }

    /// Drops the icon into the zone under the pointer; outside every canvas nothing changes.
    func dragEnded(window id: UUID, location: CGPoint) {
        drag = nil
        guard let target = target(at: location) else { return }
        move(window: id, toDisplay: target.display, zone: target.zone)
    }

    func cancelDrag() {
        if drag != nil { drag = nil }
    }

    /// The zone under `point`: only inside a canvas, where the nearest zone claims the gaps between zones.
    func target(at point: CGPoint) -> DropTarget? {
        for display in displays {
            guard let frame = canvasFrames[display.key], frame.contains(point) else { continue }
            let local = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
            let unit = GridCanvasLayout.unitPoint(local, in: frame.size)
            guard let zone = GridSnapResolver.zoneIndex(at: unit, in: display.zones) else { return nil }
            return DropTarget(display: display.key, zone: zone)
        }
        return nil
    }

    // MARK: - Save

    /// Writes the arrangement. True when the editor can close; a failure stays in `saveError` and keeps it open.
    func save() -> Bool {
        guard canSave else { return false }
        var arrangement = draft
        arrangement.name = trimmedName
        Self.dropUnreferencedDisplays(from: &arrangement)
        do throws(ArrangementError) {
            try arrangements.save(arrangement)
            draft = arrangement
            baseline = arrangement
            saveError = nil
            return true
        } catch {
            saveError = error
            return false
        }
    }

    /// What to tell the user about the last failed save.
    var saveMessage: SaveMessage? {
        guard let saveError else { return nil }
        switch saveError {
        case .storage(.writeFailed(let reason)), .storage(.readFailed(let reason)):
            return .write(reason: reason)
        case .storage(.invalidSlot):
            return .write(reason: "invalid slot")
        case .notFound:
            return .write(reason: "arrangement not found")
        case .storage:
            return .unavailable
        case .accessibilityDenied:
            return .permission
        case .noWindows:
            return .noWindows
        }
    }

    /// Only displays that a window refers to are kept.
    private static func dropUnreferencedDisplays(from arrangement: inout Arrangement) {
        let referenced = Set(arrangement.windows.map(\.slot.display))
        arrangement.displays = arrangement.displays.filter { referenced.contains($0.key) }
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
