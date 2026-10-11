//
//  WindowManagerService.swift
//  MonitorBarApp
//

import AppKit
import ApplicationServices
import os

/// Тайлинг активного окна через Accessibility API.
/// Требует разрешения Accessibility (как и блокировка клавиатуры — см. TCC-нюанс).
@MainActor
final class WindowManagerService: ObservableObject {

    func hasPermission() -> Bool { AXIsProcessTrusted() }

    /// Показывает системный запрос (срабатывает один раз на идентичность приложения).
    func requestPermission() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Открывает раздел Accessibility в System Settings — надёжнее запроса,
    /// когда приложение уже есть в списке, но выключено или подпись сменилась.
    func openAccessibilitySettings() {
        requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Системный тайлинг macOS

    private static let systemWindowManagerDomain = "com.apple.WindowManager"

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Echo",
        category: "WindowManager"
    )

    private var systemTiling: SystemTiling {
        SystemTiling(defaults: UserDefaults(suiteName: Self.systemWindowManagerDomain))
    }

    /// Which macOS drag-tiling switches collide with Echo's grid drag mode.
    func systemTilingConflict(gridModifier: GridDragModifier) -> TilingConflict {
        systemTiling.conflict(gridModifier: gridModifier)
    }

    /// Writes false to the conflicting switches, then restarts WindowManager once
    /// so both changes take effect together.
    func resolveSystemTilingConflict(_ conflict: TilingConflict) {
        if conflict.edge { systemTiling.disable() }
        if conflict.optionDrag { systemTiling.disableOptionDrag() }
        guard conflict.exists else { return }
        restartSystemWindowManager()
    }

    /// WindowManager caches the switches at launch, so it must be relaunched after a write.
    private func restartSystemWindowManager() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["WindowManager"]
        do {
            try task.run()
        } catch {
            Self.log.error("Failed to restart WindowManager: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Открывает System Settings → Desktop & Dock (там переключатели тайлинга).
    func openTilingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Перезапускает приложение (иногда нужно, чтобы новая выдача прав вступила в силу).
    func relaunchApp() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }

    /// Executes a window command on the focused window of the frontmost app.
    func perform(_ command: WMCommand, gap: CGFloat, cycling: Bool, grids: any ActiveGridProviding) {
        guard hasPermission(), let window = focusedWindow(), let current = frame(of: window) else { return }
        let screens = NSScreen.screens
        guard let sourceIndex = displayIndex(containing: current) else { return }
        if let number = command.zoneNumber {
            let screen = screens[sourceIndex]
            let visible = screen.visibleFrame
            let zones = grids.activeZones(
                for: DisplayIdentity.key(for: screen),
                aspect: visible.width / visible.height
            )
            guard let target = ZonePlacement.frame(forZone: number, of: zones, visible: visible, gap: gap) else { return }
            setFrame(target, for: window)
            return
        }
        guard let target = Self.targetFrame(
            for: command,
            windowFrame: current,
            sourceIndex: sourceIndex,
            screenFrames: screens.map(\.frame),
            visibleFrames: screens.map(\.visibleFrame),
            gap: gap,
            cycling: cycling
        ) else { return }
        setFrame(target, for: window)
    }

    /// The frame `command` moves a window at `windowFrame` to, all in Cocoa coordinates;
    /// nil when the command does not move it. `sourceIndex` is the window's display.
    nonisolated static func targetFrame(
        for command: WMCommand,
        windowFrame: CGRect,
        sourceIndex: Int,
        screenFrames: [CGRect],
        visibleFrames: [CGRect],
        gap: CGFloat,
        cycling: Bool
    ) -> CGRect? {
        guard screenFrames.count == visibleFrames.count, visibleFrames.indices.contains(sourceIndex) else { return nil }
        let visible = visibleFrames[sourceIndex]
        if let layout = command.layout {
            let step = cycling
                ? LayoutCycle.next(for: layout, windowFrame: windowFrame, visible: visible, gap: gap)
                : layout
            return step.frame(in: visible, gap: gap)
        }
        guard let direction = command.displayDirection else { return nil }
        let destination = DisplayArrangement.neighbour(of: sourceIndex, direction: direction, in: screenFrames)
        guard destination != sourceIndex else { return nil }
        return DisplayArrangement.movedFrame(windowFrame, from: visible, to: visibleFrames[destination], gap: gap)
    }

    /// Окно под точкой экрана (Cocoa-координаты, origin снизу-слева).
    func window(at screenPoint: CGPoint) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let axPoint = ScreenCoordinates.flipped(
            CGRect(origin: screenPoint, size: .zero),
            primaryHeight: primaryScreenHeight
        ).origin
        let result = AXUIElementCopyElementAtPosition(system, Float(axPoint.x), Float(axPoint.y), &element)
        guard result == .success, let el = element else { return nil }

        if AXWindow.role(of: el) == (kAXWindowRole as String) { return el }
        var windowValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(el, kAXWindowAttribute as CFString, &windowValue) == .success,
           let window = windowValue.flatMap(AXWindow.element(from:)) {
            return window
        }
        return focusedWindow()
    }

    /// Текущая позиция окна (AX-координаты, origin сверху-слева).
    func position(of window: AXUIElement) -> CGPoint? {
        AXWindow.position(of: window)
    }

    /// Window frame in Cocoa coordinates (origin bottom-left).
    func frame(of window: AXUIElement) -> CGRect? {
        AXWindow.frame(of: window)
    }

    /// Applies a Cocoa-coordinate frame. A window whose minimum size exceeds the target
    /// is moved back inside the visible area of the target's screen.
    func setFrame(_ frameCocoa: CGRect, for window: AXUIElement) {
        guard hasPermission() else { return }
        AXWindow.writeFrame(frameCocoa, to: window)

        guard let actual = frame(of: window), !Self.sizesMatch(actual.size, frameCocoa.size),
              let visible = displayIndex(containing: frameCocoa).map({ NSScreen.screens[$0].visibleFrame })
        else { return }
        let origin = WindowPlacement.clampedOrigin(target: frameCocoa, actualSize: actual.size, visible: visible)
        AXWindow.writePosition(origin, of: actual.size, to: window)
    }

    // MARK: - Screens

    /// Largest size difference, in points, still treated as the requested size.
    private static let sizeMatchTolerance: CGFloat = 1

    private static func sizesMatch(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
        abs(lhs.width - rhs.width) <= sizeMatchTolerance && abs(lhs.height - rhs.height) <= sizeMatchTolerance
    }

    private var primaryScreenHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    /// Index in `NSScreen.screens` of the display `frame` overlaps most, else of the main display.
    private func displayIndex(containing frame: CGRect) -> Int? {
        let screens = NSScreen.screens
        if let index = DisplayArrangement.displayIndex(of: frame, in: screens.map(\.frame)) { return index }
        guard let main = NSScreen.main else { return nil }
        return screens.firstIndex(of: main)
    }

    // MARK: - AX helpers

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return AXWindow.focusedWindow(of: AXUIElementCreateApplication(app.processIdentifier))
    }
}
