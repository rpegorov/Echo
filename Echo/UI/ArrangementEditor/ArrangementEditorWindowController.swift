//
//  ArrangementEditorWindowController.swift
//  Echo
//

import AppKit
import SwiftUI

/// Owns the single arrangement editor window. A request while the window holds unsaved changes only brings it forward.
@MainActor
final class ArrangementEditorWindowController: NSObject, NSWindowDelegate {
    private let store: GridStore
    private let arrangements: any ArrangementManaging
    private let settings: AppSettings
    private let localizer: Localizer

    private var window: NSWindow?
    private var model: ArrangementEditorModel?

    init(store: GridStore, arrangements: any ArrangementManaging, settings: AppSettings, localizer: Localizer) {
        self.store = store
        self.arrangements = arrangements
        self.settings = settings
        self.localizer = localizer
    }

    /// Opens the editor for `id`; with unsaved changes already open, only brings that window forward.
    func open(_ id: UUID) {
        if let window, let model, model.isDirty {
            bringForward(window)
            return
        }
        guard let arrangement = store.document.savedArrangements.first(where: { $0.id == id }) else { return }
        let model = ArrangementEditorModel(
            store: store,
            arrangements: arrangements,
            arrangement: arrangement,
            connected: DisplaySnapshot.connected(grids: store)
        )
        let root = ArrangementEditorView(
            model: model,
            settings: settings,
            onClose: { [weak self] in self?.window?.close() }
        )
        let hosting = HostingFactory.make(root, localizer: localizer)
        hosting.sizingOptions = []

        let isNew = window == nil
        let window = window ?? makeWindow()
        window.contentViewController = hosting
        window.setContentSize(Self.initialContentSize(for: model.displays))
        window.title = Self.title(for: arrangement.name, localizer: localizer)
        if isNew { window.center() }

        self.window = window
        self.model = model
        bringForward(window)
    }

    /// Re-titles the open window after the language changed on the fly.
    func applyTitle() {
        guard let model else { return }
        window?.title = Self.title(for: model.name, localizer: localizer)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let closed = notification.object as? NSWindow, closed == window else { return }
        window = nil
        model = nil
    }

    // MARK: - Window

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.contentMinSize = DS.ArrangementEditor.windowMinSize
        window.delegate = self
        return window
    }

    private func bringForward(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private static func title(for name: String, localizer: Localizer) -> String {
        localizer.t(InputKey.arrangementEditorWindowTitle, name)
    }

    /// Canvases start at a fixed height with the displays side by side, capped in width, plus the chrome around them.
    private static func initialContentSize(for displays: [ArrangementEditorDisplay]) -> NSSize {
        let canvasHeight = DS.ArrangementEditor.initialCanvasHeight
        let gaps = DS.ArrangementEditor.canvasSpacing * CGFloat(max(displays.count - 1, 0))
        let rowWidth = displays.reduce(gaps) { $0 + canvasHeight * $1.aspect }
        let padding = DS.ArrangementEditor.contentPadding * 2
        return NSSize(
            width: min(max(rowWidth + padding, DS.ArrangementEditor.windowMinSize.width), DS.ArrangementEditor.initialMaxWidth),
            height: max(canvasHeight + DS.ArrangementEditor.chromeHeight, DS.ArrangementEditor.windowMinSize.height)
        )
    }
}
