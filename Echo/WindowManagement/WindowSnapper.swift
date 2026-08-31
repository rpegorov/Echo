//
//  WindowSnapper.swift
//  MonitorBarApp
//

import AppKit
import ApplicationServices
import SwiftUI

/// Drag-to-snap: при перетаскивании окна к краю/углу экрана подсвечивает зону
/// и примагничивает окно к соответствующей раскладке. Зажатый Shift отменяет.
@MainActor
final class WindowSnapper {

    private let windowManager: WindowManagerService
    private let settings: AppSettings

    private var downMonitor: Any?
    private var dragMonitor: Any?
    private var upMonitor: Any?

    private var dragWindow: AXUIElement?
    private var startPosition: CGPoint?
    private var isDraggingWindow = false
    private var activeZone: WindowLayout?

    private lazy var overlay = SnapOverlayWindow()

    init(windowManager: WindowManagerService, settings: AppSettings) {
        self.windowManager = windowManager
        self.settings = settings
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
        let location = NSEvent.mouseLocation
        guard let window = windowManager.window(at: location) else { return }
        dragWindow = window
        startPosition = windowManager.position(of: window)
    }

    private func handleDrag(_ event: NSEvent) {
        guard let window = dragWindow else { return }

        // Shift временно отключает примагничивание.
        if event.modifierFlags.contains(.shift) {
            activeZone = nil
            overlay.hide()
            return
        }

        // Убеждаемся, что окно реально перемещают (а не выделяют текст и т. п.).
        if !isDraggingWindow, let start = startPosition, let current = windowManager.position(of: window) {
            if hypot(current.x - start.x, current.y - start.y) > 8 { isDraggingWindow = true }
        }
        guard isDraggingWindow else { return }

        let location = NSEvent.mouseLocation
        guard let screen = screenContaining(location) else {
            activeZone = nil
            overlay.hide()
            return
        }

        if let zone = zone(for: location, on: screen) {
            activeZone = zone
            overlay.show(frame: zone.frame(in: screen.visibleFrame, gap: CGFloat(settings.windowGap)))
        } else {
            activeZone = nil
            overlay.hide()
        }
    }

    private func handleUp(_ event: NSEvent) {
        defer { reset() }
        guard let window = dragWindow,
              isDraggingWindow,
              let zone = activeZone,
              !event.modifierFlags.contains(.shift)
        else { return }
        windowManager.apply(zone, to: window, gap: CGFloat(settings.windowGap))
    }

    private func reset() {
        dragWindow = nil
        startPosition = nil
        isDraggingWindow = false
        activeZone = nil
        overlay.hide()
    }

    // MARK: - Zone detection

    private func screenContaining(_ point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    /// Зона по позиции курсора (Cocoa-координаты). Углы → четверти, края →
    /// половины, верх по центру → максимизация.
    private func zone(for point: CGPoint, on screen: NSScreen) -> WindowLayout? {
        let frame = screen.frame
        let edge: CGFloat = 4
        let corner: CGFloat = 120

        let nearLeft   = point.x <= frame.minX + edge
        let nearRight  = point.x >= frame.maxX - edge
        let nearTop    = point.y >= frame.maxY - edge
        let nearBottom = point.y <= frame.minY + edge

        let leftSide  = point.x <= frame.minX + corner
        let rightSide = point.x >= frame.maxX - corner
        let topSide   = point.y >= frame.maxY - corner
        let botSide   = point.y <= frame.minY + corner

        if (nearTop && leftSide) || (nearLeft && topSide)    { return .topLeft }
        if (nearTop && rightSide) || (nearRight && topSide)  { return .topRight }
        if (nearBottom && leftSide) || (nearLeft && botSide) { return .bottomLeft }
        if (nearBottom && rightSide) || (nearRight && botSide) { return .bottomRight }
        if nearTop    { return .maximize }
        if nearLeft   { return .leftHalf }
        if nearRight  { return .rightHalf }
        if nearBottom { return .bottomHalf }
        return nil
    }
}

// MARK: - Overlay

/// Прозрачное окно-подсказка, показывающее целевую зону. Не перехватывает мышь.
@MainActor
private final class SnapOverlayWindow {
    private let window: NSWindow

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: SnapOverlayView())
    }

    func show(frame: CGRect) {
        window.setFrame(frame, display: true)
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
