//
//  GridEditorWindowController.swift
//  Echo
//

import AppKit
import SwiftUI

/// Owns the single grid editor window. A request while the window holds unsaved changes only brings it forward.
@MainActor
final class GridEditorWindowController: NSObject, NSWindowDelegate {
    private let store: GridStore
    private let settings: AppSettings
    private let localizer: Localizer

    private var window: NSWindow?
    private var model: GridEditorModel?

    init(store: GridStore, settings: AppSettings, localizer: Localizer) {
        self.store = store
        self.settings = settings
        self.localizer = localizer
    }

    func open(_ request: GridEditorRequest) {
        if let window, let model, model.isDirty {
            bringForward(window)
            return
        }
        let display = Self.display(for: request.display)
        let localizer = localizer
        let model = GridEditorModel(
            store: store,
            request: request,
            display: display,
            templateTitle: { localizer.t($0.titleKey) }
        )
        let root = GridEditorView(
            model: model,
            settings: settings,
            onClose: { [weak self] in self?.window?.close() }
        )
        let hosting = HostingFactory.make(root, localizer: localizer)
        hosting.sizingOptions = []

        let isNew = window == nil
        let window = window ?? makeWindow()
        window.contentViewController = hosting
        window.setContentSize(Self.initialContentSize(for: display))
        window.title = Self.title(for: display, localizer: localizer)
        if isNew { window.center() }

        self.window = window
        self.model = model
        bringForward(window)
    }

    /// Re-titles the open window after the language changed on the fly.
    func applyTitle() {
        window?.title = Self.title(for: model?.display, localizer: localizer)
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
        window.contentMinSize = DS.GridEditor.windowMinSize
        window.delegate = self
        return window
    }

    private func bringForward(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Display and size

    /// The requested display when connected, else the first (menu-bar) display; nil when none is connected.
    private static func display(for key: DisplayKey?) -> ConnectedDisplay? {
        let displays = DisplayIdentity.connectedDisplays()
        return displays.first { $0.key == key } ?? displays.first
    }

    private static func title(for display: ConnectedDisplay?, localizer: Localizer) -> String {
        localizer.t(InputKey.gridEditorWindowTitle, display?.name ?? "")
    }

    /// Canvas starts at a share of the display's width, capped, plus the chrome around it.
    private static func initialContentSize(for display: ConnectedDisplay?) -> NSSize {
        let displaySize = display?.visibleSize ?? DS.GridEditor.fallbackDisplaySize
        let canvasWidth = min(DS.GridEditor.maxCanvasWidth, displaySize.width * DS.GridEditor.canvasScreenShare)
        let canvasHeight = canvasWidth * displaySize.height / displaySize.width
        let padding = DS.GridEditor.contentPadding * 2
        return NSSize(
            width: max(canvasWidth + padding, DS.GridEditor.windowMinSize.width),
            height: max(canvasHeight + DS.GridEditor.chromeHeight, DS.GridEditor.windowMinSize.height)
        )
    }
}
