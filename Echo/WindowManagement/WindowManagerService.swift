//
//  WindowManagerService.swift
//  MonitorBarApp
//

import AppKit
import ApplicationServices

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

    private let systemWindowManagerDomain = "com.apple.WindowManager"

    /// Включён ли системный тайлинг перетаскиванием к краям (конфликтует с нашим).
    /// На macOS 15+ по умолчанию включён, поэтому отсутствие ключа = true.
    func isSystemEdgeTilingEnabled() -> Bool {
        guard let defaults = UserDefaults(suiteName: systemWindowManagerDomain) else { return false }
        if defaults.object(forKey: "EnableTilingByEdgeDrag") == nil { return true }
        return defaults.bool(forKey: "EnableTilingByEdgeDrag")
    }

    /// Отключает системный тайлинг к краям и перезапускает WindowManager,
    /// чтобы изменение вступило в силу.
    func disableSystemEdgeTiling() {
        guard let defaults = UserDefaults(suiteName: systemWindowManagerDomain) else { return }
        defaults.set(false, forKey: "EnableTilingByEdgeDrag")
        defaults.set(false, forKey: "EnableTopTilingByEdgeDrag")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["WindowManager"]
        try? task.run()
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

    /// Применяет раскладку к активному окну переднего приложения.
    func apply(_ layout: WindowLayout, gap: CGFloat) {
        guard let window = focusedWindow() else { return }
        apply(layout, to: window, gap: gap)
    }

    /// Применяет раскладку к конкретному окну (для drag-to-snap).
    func apply(_ layout: WindowLayout, to window: AXUIElement, gap: CGFloat) {
        guard hasPermission() else { return }
        let screen = screen(for: window) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        setFrame(layout.frame(in: visible, gap: gap), for: window)
    }

    /// Окно под точкой экрана (Cocoa-координаты, origin снизу-слева).
    func window(at screenPoint: CGPoint) -> AXUIElement? {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let system = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            system,
            Float(screenPoint.x),
            Float(primaryHeight - screenPoint.y),
            &element
        )
        guard result == .success, let el = element else { return nil }

        if role(of: el) == (kAXWindowRole as String) { return el }
        var windowValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(el, kAXWindowAttribute as CFString, &windowValue) == .success,
           let raw = windowValue {
            return (raw as! AXUIElement)
        }
        return focusedWindow()
    }

    /// Текущая позиция окна (AX-координаты, origin сверху-слева).
    func position(of window: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success,
              let raw = value
        else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(raw as! AXValue, .cgPoint, &point)
        return point
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
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let raw = value
        else { return nil }
        return (raw as! AXUIElement)
    }

    /// Конвертирует кадр из Cocoa (origin снизу-слева) в AX (origin сверху-слева) и применяет.
    private func setFrame(_ frameCocoa: CGRect, for window: AXUIElement) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let axY = primaryHeight - frameCocoa.origin.y - frameCocoa.height
        var origin = CGPoint(x: frameCocoa.origin.x, y: axY)
        var size = frameCocoa.size

        if let positionValue = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    /// Экран, на котором сейчас находится окно (по его позиции).
    private func screen(for window: AXUIElement) -> NSScreen? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success,
              let raw = value
        else { return nil }

        var axPoint = CGPoint.zero
        AXValueGetValue(raw as! AXValue, .cgPoint, &axPoint)

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let cocoaPoint = CGPoint(x: axPoint.x, y: primaryHeight - axPoint.y)
        return NSScreen.screens.first { $0.frame.contains(cocoaPoint) }
    }
}
