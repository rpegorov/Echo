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
    /// A grid flash is on screen; `currentPreview` stays nil for its whole life.
    private var isFlashing = false
    /// The only pending hide; show, hide and a newer flash cancel it.
    private var flashHideTask: Task<Void, Never>?

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
        endFlash()
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
                model.contextFrames = localContextFrames(of: preview)
                model.layout = zoneLayout(of: preview)
                model.zoneNumbers = gridZoneNumbers(of: preview)
                model.shortcut = preview.shortcut
                model.flashZones = []
                model.flashTitle = nil
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
            model.zoneNumbers = gridZoneNumbers(of: preview)
            model.shortcut = preview.shortcut
            withAnimation(animationsEnabled ? DS.SnapOverlay.morphAnimation : nil) {
                model.zone = localZone(of: preview)
                // Entering or leaving grid mode fades the faint zones; within a grid this is a no-op.
                model.contextFrames = localContextFrames(of: preview)
            }
        }
    }

    func flash(_ grid: GridFlash) {
        guard !grid.zoneFrames.isEmpty else { return }
        flashHideTask?.cancel()
        let displayChanged = grid.screenFrame != activeWindow?.frame
        let needsAppear = !isFlashing || displayChanged
        isFlashing = true
        currentPreview = nil
        generation += 1

        let window = self.window(for: grid.screenFrame)
        if displayChanged, let previous = activeWindow, previous !== window {
            previous.orderOut(nil)
        }
        activeWindow = window
        if window.frame != grid.screenFrame {
            window.setFrame(grid.screenFrame, display: true)
        }

        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            model.activeDisplay = grid.screenFrame
            model.flashZones = flashZones(of: grid)
            model.flashTitle = grid.title
            model.contextFrames = []
            model.zoneNumbers = []
            model.layout = nil
            model.shortcut = nil
            if needsAppear {
                model.settled = false
                model.visible = false
            }
        }
        if needsAppear {
            withAnimation(animationsEnabled ? DS.SnapOverlay.appearAnimation : nil) {
                model.visible = true
                model.settled = true
            }
            window.orderFront(nil)
        }
        scheduleFlashHide()
    }

    func hide() {
        guard currentPreview != nil || isFlashing else { return }
        flashHideTask?.cancel()
        isFlashing = false
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

    private func scheduleFlashHide() {
        flashHideTask = Task { [weak self] in
            do {
                try await Task.sleep(for: DS.SnapOverlay.flashDuration)
            } catch {
                // Only cancellation throws: a newer show, hide or flash owns the overlay now.
                return
            }
            self?.hide()
        }
    }

    private func endFlash() {
        flashHideTask?.cancel()
        isFlashing = false
    }

    private func dropAllWindows() {
        endFlash()
        generation += 1
        currentPreview = nil
        activeWindow = nil
        model.visible = false
        model.settled = false
        model.activeDisplay = nil
        model.contextFrames = []
        model.zoneNumbers = []
        model.flashZones = []
        model.flashTitle = nil
        for window in windows.values { window.orderOut(nil) }
        windows.removeAll()
    }

    // MARK: - Geometry

    private var animationsEnabled: Bool {
        !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Window-local SwiftUI coordinates: origin top-left of the display (AX-style flip of the Cocoa frame).
    private func localFrame(_ frame: CGRect, in screenFrame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX - screenFrame.minX,
            y: screenFrame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    private func localZone(of preview: SnapPreview) -> CGRect {
        localFrame(preview.frame, in: preview.screenFrame)
    }

    private func localContextFrames(of preview: SnapPreview) -> [CGRect] {
        guard case .grid(let target) = preview.target else { return [] }
        return target.contextFrames.map { localFrame($0, in: preview.screenFrame) }
    }

    private func flashZones(of grid: GridFlash) -> [GridFlashZone] {
        grid.zoneFrames.enumerated().map { index, frame in
            GridFlashZone(
                frame: localFrame(frame, in: grid.screenFrame),
                number: index + 1,
                shortcut: grid.zoneShortcuts.indices.contains(index) ? grid.zoneShortcuts[index] : nil
            )
        }
    }

    private func zoneLayout(of preview: SnapPreview) -> WindowLayout? {
        guard case .layout(let layout) = preview.target else { return nil }
        return layout
    }

    private func gridZoneNumbers(of preview: SnapPreview) -> [Int] {
        guard case .grid(let target) = preview.target else { return [] }
        return target.zoneNumbers
    }
}
