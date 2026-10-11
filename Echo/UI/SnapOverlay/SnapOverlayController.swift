//
//  SnapOverlayController.swift
//  Echo
//

import AppKit
import SwiftUI

/// Transparent hint window showing the drag-to-snap target; never takes mouse events.
@MainActor
final class SnapOverlayController: SnapOverlayPresenting {
    private let window: NSWindow

    init(localizer: Localizer) {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: SnapOverlayView().environmentObject(localizer))
    }

    func show(_ preview: SnapPreview) {
        window.setFrame(preview.frame, display: true)
        window.orderFront(nil)
    }

    func hide() {
        window.orderOut(nil)
    }
}

private struct SnapOverlayView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(DS.accent.opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(DS.accent.opacity(0.85), lineWidth: 2)
            )
            .padding(4)
    }
}
