//
//  SnapOverlayController.swift
//  Echo
//

import AppKit
import Combine
import SwiftUI

/// Transparent hint windows showing the drag-to-snap target; never takes mouse events.
/// One cached window per display; all windows share a single model so only the active display draws.
@MainActor
final class SnapOverlayController: SnapOverlayPresenting {
    private let localizer: Localizer
    private let model = SnapOverlayModel()
    private var windows: [CGRect: NSWindow] = [:]
    private var activeWindow: NSWindow?
    private var currentPreview: SnapPreview?
    /// Bumped on every show/hide; pending animation completions only act when their generation is current.
    private var generation = 0
    private var screenObserver: AnyCancellable?

    init(localizer: Localizer) {
        self.localizer = localizer
        screenObserver = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.dropAllWindows() }
            }
    }

    func show(_ preview: SnapPreview) {
        guard preview != currentPreview else { return }
        let displayChanged = preview.screenFrame != currentPreview?.screenFrame
        let needsAppear = currentPreview == nil || displayChanged
        currentPreview = preview
        generation += 1

        let window = self.window(for: preview.screenFrame)
        if displayChanged, let previous = activeWindow, previous !== window {
            previous.orderOut(nil)
        }
        activeWindow = window
        if window.frame != preview.screenFrame {
            window.setFrame(preview.screenFrame, display: true)
        }

        if needsAppear {
            // The model is shared by every window: placing the zone must never animate, or it flies in from the last one.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                model.activeDisplay = preview.screenFrame
                model.zone = localZone(of: preview)
                model.layout = zoneLayout(of: preview)
                model.shortcut = preview.shortcut
                model.settled = false
                model.visible = false
            }
            withAnimation(animationsEnabled ? DS.SnapOverlay.appearAnimation : nil) {
                model.visible = true
                model.settled = true
            }
            window.orderFront(nil)
        } else {
            model.layout = zoneLayout(of: preview)
            model.shortcut = preview.shortcut
            withAnimation(animationsEnabled ? DS.SnapOverlay.morphAnimation : nil) {
                model.zone = localZone(of: preview)
            }
        }
    }

    func hide() {
        guard currentPreview != nil else { return }
        currentPreview = nil
        generation += 1
        let current = generation
        let window = activeWindow
        guard animationsEnabled else {
            model.visible = false
            model.settled = false
            window?.orderOut(nil)
            return
        }
        withAnimation(DS.SnapOverlay.hideAnimation) {
            model.visible = false
        } completion: {
            guard current == self.generation else { return }
            // Reset the scale outside any transaction so the next appear animates from the token.
            self.model.settled = false
            window?.orderOut(nil)
        }
    }

    // MARK: - Windows

    private func window(for screenFrame: CGRect) -> NSWindow {
        if let cached = windows[screenFrame] { return cached }
        let window = NSWindow(contentRect: screenFrame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(
            rootView: SnapOverlayView(model: model, display: screenFrame).environmentObject(localizer)
        )
        windows[screenFrame] = window
        return window
    }

    private func dropAllWindows() {
        generation += 1
        currentPreview = nil
        activeWindow = nil
        model.visible = false
        model.settled = false
        model.activeDisplay = nil
        for window in windows.values { window.orderOut(nil) }
        windows.removeAll()
    }

    // MARK: - Geometry

    private var animationsEnabled: Bool {
        !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Window-local SwiftUI coordinates: origin top-left of the display (AX-style flip of the Cocoa frame).
    private func localZone(of preview: SnapPreview) -> CGRect {
        CGRect(
            x: preview.frame.minX - preview.screenFrame.minX,
            y: preview.screenFrame.maxY - preview.frame.maxY,
            width: preview.frame.width,
            height: preview.frame.height
        )
    }

    private func zoneLayout(of preview: SnapPreview) -> WindowLayout? {
        guard case .layout(let layout) = preview.target else { return nil }
        return layout
    }
}
