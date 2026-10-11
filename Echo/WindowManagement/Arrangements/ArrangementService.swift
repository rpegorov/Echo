//
//  ArrangementService.swift
//  Echo
//

import ApplicationServices
import CoreGraphics
import Foundation

/// Saves, applies and deletes arrangements: reads windows through the catalog, moves them through `frames`.
@MainActor
final class ArrangementService: ArrangementManaging {
    private let store: GridStore
    private let settings: AppSettings
    private let catalog: any WindowCataloging
    private let frames: any WindowFrameSetting
    private let displays: @MainActor () -> [DisplaySnapshot]
    private let hasPermission: @MainActor () -> Bool

    init(
        store: GridStore,
        settings: AppSettings,
        catalog: any WindowCataloging,
        frames: any WindowFrameSetting,
        displays: @escaping @MainActor () -> [DisplaySnapshot],
        hasPermission: @escaping @MainActor () -> Bool
    ) {
        self.store = store
        self.settings = settings
        self.catalog = catalog
        self.frames = frames
        self.displays = displays
        self.hasPermission = hasPermission
    }

    var arrangementIDs: Set<UUID> {
        Set(store.document.savedArrangements.map(\.id))
    }

    func captureCurrent(named name: String) throws(ArrangementError) -> Arrangement {
        guard hasPermission() else { throw .accessibilityDenied }
        let captured = ArrangementCapture.capture(
            windows: catalog.windows().map(\.snapshot),
            displays: displays(),
            makeID: UUID.init
        )
        guard !captured.windows.isEmpty else { throw .noWindows }
        let arrangement = Arrangement(
            id: UUID(), name: name, windows: captured.windows, displays: captured.displays)
        try write { () throws(GridStorageError) in try store.saveArrangement(arrangement) }
        return arrangement
    }

    func save(_ arrangement: Arrangement) throws(ArrangementError) {
        guard !store.isReadOnly else { throw .storage(.readOnly) }
        guard arrangementIDs.contains(arrangement.id) else { throw .notFound }
        try write { () throws(GridStorageError) in try store.saveArrangement(arrangement) }
    }

    func delete(_ id: UUID) throws(ArrangementError) {
        try write { () throws(GridStorageError) in try store.deleteArrangement(id) }
        settings.setShortcut(nil, for: .arrangement(id))
    }

    @discardableResult
    func apply(_ id: UUID) -> ArrangementApplyReport {
        guard let arrangement = store.document.savedArrangements.first(where: { $0.id == id }) else {
            return ArrangementApplyReport()
        }
        // Without permission nothing can be read or moved; the plan then reports every running app as windowless.
        let windows = hasPermission() ? catalog.windows() : []
        let plan = ArrangementPlanner.plan(
            arrangement,
            windows: windows.map(\.snapshot),
            running: catalog.runningBundleIDs(),
            displays: displays(),
            gap: CGFloat(settings.windowGap)
        )
        return place(plan, using: windows)
    }

    /// Moves the planned windows; a move whose window is absent from the pass is reported as missing.
    private func place(_ plan: ArrangementPlan, using windows: [CatalogWindow]) -> ArrangementApplyReport {
        let elements = Dictionary(windows.map { ($0.snapshot.ref, $0.element) }, uniquingKeysWith: { first, _ in first })
        var report = plan.report
        for move in plan.moves {
            guard let element = elements[move.ref] else {
                report.placed -= 1
                report.noWindow += 1
                continue
            }
            frames.setFrame(move.frame, for: element)
        }
        return report
    }

    private func write(_ change: () throws(GridStorageError) -> Void) throws(ArrangementError) {
        do {
            try change()
        } catch {
            throw .storage(error)
        }
    }
}
