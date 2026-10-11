//
//  GridCycler.swift
//  Echo
//

import AppKit
import os

/// The "next grid" command: steps the focused display through `GridCycle` and flashes the grid it lands on.
@MainActor
final class GridCycler {

    private let windowManager: WindowManagerService
    private let store: GridStore
    private let settings: AppSettings
    private let overlay: any SnapOverlayPresenting

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Echo",
        category: "GridCycler"
    )

    init(
        windowManager: WindowManagerService,
        store: GridStore,
        settings: AppSettings,
        overlay: any SnapOverlayPresenting
    ) {
        self.windowManager = windowManager
        self.store = store
        self.settings = settings
        self.overlay = overlay
    }

    /// Cycles the display of the focused window, else the one under the mouse, to its next grid.
    func advance() {
        let screens = NSScreen.screens
        let focused = windowManager.focusedDisplayIndex()
            .flatMap { screens.indices.contains($0) ? screens[$0] : nil }
        guard let screen = focused ?? screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) else { return }
        let visible = screen.visibleFrame
        let aspect = visible.width / visible.height
        let key = DisplayIdentity.key(for: screen)
        guard let key, !store.isReadOnly else {
            flashActiveGrid(on: screen, key: key, aspect: aspect)
            return
        }
        let ref = GridCycle.next(
            after: store.document.activeRef(for: key),
            saved: store.document.grids,
            aspect: aspect
        )
        do {
            try store.setActive(ref, for: key)
        } catch {
            Self.log.error("Activating the next grid failed: \(String(describing: error), privacy: .public)")
            flashActiveGrid(on: screen, key: key, aspect: aspect)
            return
        }
        flashActiveGrid(on: screen, key: key, aspect: aspect)
    }

    /// Flashes the grid active for `key` now — the one just written, or the unchanged one on a failed write.
    private func flashActiveGrid(on screen: NSScreen, key: DisplayKey?, aspect: Double) {
        let visible = screen.visibleFrame
        let gap = CGFloat(settings.windowGap)
        let zoneFrames = store.activeZones(for: key, aspect: aspect).map { $0.frame(in: visible, gap: gap) }
        overlay.flash(GridFlash(
            title: activeTitle(for: key, aspect: aspect),
            screenFrame: screen.frame,
            zoneFrames: zoneFrames,
            zoneShortcuts: zoneFrames.indices.map { WMCommand.zone($0 + 1).flatMap { settings.shortcut(for: $0) } }
        ))
    }

    /// The flash title of the active ref; a display with no usable ref shows the default template.
    private func activeTitle(for key: DisplayKey?, aspect: Double) -> GridFlash.Title {
        let fallback = GridFlash.Title.template(GridTemplate.default(forAspect: aspect))
        guard let key, let ref = store.document.activeRef(for: key) else { return fallback }
        switch ref {
        case .template(kind: let kind): return .template(kind)
        case .saved(id: let id):
            return store.document.grids.first { $0.id == id }.map { .named($0.name) } ?? fallback
        }
    }
}

extension GridCycler: GridCycling {}
