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

    /// Включён ли системный тайлинг перетаскиванием к краям (конфликтует с нашим).
    func isSystemEdgeTilingEnabled() -> Bool {
        systemTiling.isEnabled
    }

    /// Отключает системный тайлинг к краям и перезапускает WindowManager,
    /// чтобы изменение вступило в силу.
    func disableSystemEdgeTiling() {
        systemTiling.disable()
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
    func perform(_ command: WMCommand, gap: CGFloat, cycling: Bool) {
        guard hasPermission(), let window = focusedWindow(), let current = frame(of: window) else { return }
        let screens = NSScreen.screens
        guard let sourceIndex = displayIndex(containing: current) else { return }
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

        if role(of: el) == (kAXWindowRole as String) { return el }
        var windowValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(el, kAXWindowAttribute as CFString, &windowValue) == .success,
           let window = windowValue.flatMap(Self.element(from:)) {
            return window
        }
        return focusedWindow()
    }

    /// Текущая позиция окна (AX-координаты, origin сверху-слева).
    func position(of window: AXUIElement) -> CGPoint? {
        var point = CGPoint.zero
        return readValue(kAXPositionAttribute, of: window, type: .cgPoint, into: &point) ? point : nil
    }

    /// Window frame in Cocoa coordinates (origin bottom-left).
    func frame(of window: AXUIElement) -> CGRect? {
        var size = CGSize.zero
        guard let origin = position(of: window),
              readValue(kAXSizeAttribute, of: window, type: .cgSize, into: &size)
        else { return nil }
        return ScreenCoordinates.flipped(CGRect(origin: origin, size: size), primaryHeight: primaryScreenHeight)
    }

    /// Applies a Cocoa-coordinate frame. A window whose minimum size exceeds the target
    /// is moved back inside the visible area of the target's screen.
    func setFrame(_ frameCocoa: CGRect, for window: AXUIElement) {
        guard hasPermission() else { return }
        writePosition(of: frameCocoa, to: window)
        writeSize(frameCocoa.size, to: window)
        writePosition(of: frameCocoa, to: window)

        guard let actual = frame(of: window), !Self.sizesMatch(actual.size, frameCocoa.size),
              let visible = displayIndex(containing: frameCocoa).map({ NSScreen.screens[$0].visibleFrame })
        else { return }
        let origin = WindowPlacement.clampedOrigin(target: frameCocoa, actualSize: actual.size, visible: visible)
        writePosition(of: CGRect(origin: origin, size: actual.size), to: window)
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

    private func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) == .success
        else { return nil }
        return value.flatMap(Self.element(from:))
    }

    private static func element(from value: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value as AnyObject, to: AXUIElement.self)
    }

    private func readValue(
        _ attribute: String,
        of element: AXUIElement,
        type: AXValueType,
        into storage: UnsafeMutableRawPointer
    ) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let raw = value, CFGetTypeID(raw) == AXValueGetTypeID()
        else { return false }
        return AXValueGetValue(unsafeDowncast(raw as AnyObject, to: AXValue.self), type, storage)
    }

    private func writePosition(of frameCocoa: CGRect, to window: AXUIElement) {
        var origin = ScreenCoordinates.flipped(frameCocoa, primaryHeight: primaryScreenHeight).origin
        writeValue(&origin, type: .cgPoint, attribute: kAXPositionAttribute, to: window)
    }

    private func writeSize(_ size: CGSize, to window: AXUIElement) {
        var mutable = size
        writeValue(&mutable, type: .cgSize, attribute: kAXSizeAttribute, to: window)
    }

    private func writeValue(
        _ storage: UnsafeRawPointer,
        type: AXValueType,
        attribute: String,
        to window: AXUIElement
    ) {
        guard let axValue = AXValueCreate(type, storage) else { return }
        let result = AXUIElementSetAttributeValue(window, attribute as CFString, axValue)
        if result != .success {
            Self.log.debug("AX write of \(attribute, privacy: .public) failed: \(result.rawValue)")
        }
    }
}
