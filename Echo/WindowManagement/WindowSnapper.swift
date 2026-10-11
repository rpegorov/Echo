//
//  WindowSnapper.swift
//  MonitorBarApp
//

import AppKit
import ApplicationServices

/// Drag-to-snap: при перетаскивании окна к краю/углу экрана подсвечивает зону
/// и примагничивает окно к соответствующей раскладке. Зажатый Shift отменяет.
@MainActor
final class WindowSnapper {

    private let windowManager: WindowManagerService
    private let settings: AppSettings

    private var downMonitor: Any?
    private var dragMonitor: Any?
    private var upMonitor: Any?
    private var flagsMonitor: Any?

    /// Window movement below this distance is treated as a click, not a drag.
    private static let movementThreshold: CGFloat = 8

    private var downLocation: CGPoint?
    private var dragWindow: AXUIElement?
    private var startPosition: CGPoint?
    private var dragProbe: WindowDragProbe?
    private var dragScreens: [ScreenGeometry] = []
    private var isDraggingWindow = false
    private var shownPreview: SnapPreview?
    private var gridAnchor: GridAnchor?

    private let overlay: any SnapOverlayPresenting
    private let grids: any ActiveGridProviding

    init(
        windowManager: WindowManagerService,
        settings: AppSettings,
        overlay: any SnapOverlayPresenting,
        grids: any ActiveGridProviding
    ) {
        self.windowManager = windowManager
        self.settings = settings
        self.overlay = overlay
        self.grids = grids
    }

    // MARK: - Lifecycle

    func start() {
        guard downMonitor == nil else { return }
        downMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handleDown(event) }
        }
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            MainActor.assumeIsolated { self?.handleDrag(event) }
        }
        upMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            MainActor.assumeIsolated { self?.handleUp(event) }
        }
    }

    func stop() {
        for monitor in [downMonitor, dragMonitor, upMonitor] {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
        downMonitor = nil
        dragMonitor = nil
        upMonitor = nil
        reset()
    }

    // MARK: - Handlers

    private func handleDown(_ event: NSEvent) {
        reset()
        guard settings.windowManagerEnabled else { return }
        downLocation = NSEvent.mouseLocation
    }

    private func handleDrag(_ event: NSEvent) {
        // The window is resolved lazily on the first drag event, not on every click.
        if let down = downLocation { beginDrag(at: down) }
        guard let window = dragWindow else { return }

        // Shift временно отключает примагничивание.
        if event.modifierFlags.contains(.shift) {
            hideOverlayIfNeeded()
            return
        }

        // Убеждаемся, что окно реально перемещают (а не выделяют текст и т. п.).
        // The probe limits the reads; after it gives up, the rest of the drag is ignored.
        if !isDraggingWindow, let start = startPosition, var probe = dragProbe {
            if probe.shouldProbe(cursor: NSEvent.mouseLocation),
               let current = windowManager.position(of: window) {
                let moved = hypot(current.x - start.x, current.y - start.y) >= Self.movementThreshold
                if probe.record(moved: moved) == .windowMoving {
                    isDraggingWindow = true
                }
                dragProbe = probe
            }
        }
        guard isDraggingWindow else { return }

        installFlagsMonitorIfNeeded()
        updateTarget(flags: event.modifierFlags, at: NSEvent.mouseLocation)
    }

    private func handleUp(_ event: NSEvent) {
        if let window = dragWindow,
           isDraggingWindow,
           let preview = shownPreview,
           !event.modifierFlags.contains(.shift) {
            windowManager.setFrame(preview.frame, for: window)
        }
        reset()
    }

    // MARK: - Target

    /// Picks the target for the current modifiers: free (none), grid, or edge; Shift beats the grid modifier.
    private func updateTarget(flags: NSEvent.ModifierFlags, at location: CGPoint) {
        guard !flags.contains(.shift),
              let screen = dragScreens.first(where: { $0.frame.contains(location) }) else {
            gridAnchor = nil
            hideOverlayIfNeeded()
            return
        }
        if flags.contains(settings.gridModifier.flags) {
            updateGridTarget(on: screen, flags: flags, at: location)
        } else {
            gridAnchor = nil
            updateEdgeTarget(on: screen, at: location)
        }
    }

    private func updateEdgeTarget(on screen: ScreenGeometry, at location: CGPoint) {
        if let layout = EdgeSnapResolver.layout(at: location, in: screen.frame) {
            showOverlayIfNeeded(SnapPreview(
                target: .layout(layout),
                frame: layout.frame(in: screen.visibleFrame, gap: CGFloat(settings.windowGap)),
                screenFrame: screen.frame,
                shortcut: settings.shortcut(for: layout.command)
            ))
        } else {
            hideOverlayIfNeeded()
        }
    }

    private func updateGridTarget(on screen: ScreenGeometry, flags: NSEvent.ModifierFlags, at location: CGPoint) {
        let spanning = flags.contains(GridDragModifier.spanFlags)
        let sameScreenAnchor = gridAnchor?.screenFrame == screen.frame ? gridAnchor?.zone : nil
        let resolution = GridDragTarget.resolve(
            cursor: location,
            on: screen.grid,
            spanning: spanning,
            anchor: sameScreenAnchor,
            gap: CGFloat(settings.windowGap),
            shortcutForZone: { number in WMCommand.zone(number).flatMap { self.settings.shortcut(for: $0) } }
        )
        gridAnchor = resolution?.anchor.map { GridAnchor(screenFrame: screen.frame, zone: $0) }
        if let preview = resolution?.preview {
            showOverlayIfNeeded(preview)
        } else {
            hideOverlayIfNeeded()
        }
    }

    // MARK: - Drag state

    /// Resolves the dragged window and caches screen geometry once per drag.
    private func beginDrag(at down: CGPoint) {
        downLocation = nil
        dragScreens = NSScreen.screens.map(makeScreenGeometry)
        guard let window = windowManager.window(at: down) else { return }
        dragWindow = window
        startPosition = windowManager.position(of: window)
        dragProbe = WindowDragProbe(downLocation: down, threshold: Self.movementThreshold)
    }

    private func makeScreenGeometry(for screen: NSScreen) -> ScreenGeometry {
        let visible = screen.visibleFrame
        let gap = CGFloat(settings.windowGap)
        let zones = grids.activeZones(for: DisplayIdentity.key(for: screen), aspect: visible.width / visible.height)
        return ScreenGeometry(
            frame: screen.frame,
            visibleFrame: visible,
            grid: GridDragTarget.Display(
                screenFrame: screen.frame,
                visibleFrame: visible,
                zones: zones,
                contextFrames: zones.map { $0.frame(in: visible, gap: gap) }
            )
        )
    }

    private func reset() {
        removeFlagsMonitor()
        gridAnchor = nil
        downLocation = nil
        dragWindow = nil
        startPosition = nil
        dragProbe = nil
        dragScreens = []
        isDraggingWindow = false
        hideOverlayIfNeeded()
    }

    // MARK: - Modifier changes

    /// Lets a modifier pressed or released while the mouse is still change the target.
    private func installFlagsMonitorIfNeeded() {
        guard flagsMonitor == nil else { return }
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated { self?.handleFlagsChanged(event) }
        }
    }

    private func removeFlagsMonitor() {
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        flagsMonitor = nil
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard isDraggingWindow else { return }
        updateTarget(flags: event.modifierFlags, at: NSEvent.mouseLocation)
    }

    // MARK: - Overlay

    private func showOverlayIfNeeded(_ preview: SnapPreview) {
        guard preview != shownPreview else { return }
        overlay.show(preview)
        shownPreview = preview
    }

    private func hideOverlayIfNeeded() {
        guard shownPreview != nil else { return }
        overlay.hide()
        shownPreview = nil
    }
}

/// Screen geometry captured once per drag so drag events stay free of NSScreen queries.
private struct ScreenGeometry {
    let frame: CGRect
    let visibleFrame: CGRect
    let grid: GridDragTarget.Display
}

/// Zone a multi-zone span grows from, valid only on the screen it was taken on.
private struct GridAnchor {
    let screenFrame: CGRect
    let zone: Int
}
