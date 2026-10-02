//
//  ClipboardPanel.swift
//  Echo
//

import AppKit

/// Borderless floating panel for the clipboard history. It takes keyboard
/// focus without activating Echo, so the app the user was typing in stays
/// active and a paste lands there as soon as the panel closes.
final class ClipboardPanel: NSPanel {

    /// Esc: routed to the owner so it closes the panel the same way a pick does.
    var onCancel: (() -> Void)?

    init(contentViewController: NSViewController) {
        super.init(
            contentRect: NSRect(origin: .zero, size: DS.clipboardSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        self.contentViewController = contentViewController
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        setContentSize(DS.clipboardSize)
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
