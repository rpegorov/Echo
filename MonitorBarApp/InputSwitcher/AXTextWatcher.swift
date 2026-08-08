//
//  AXTextWatcher.swift
//  MonitorBarApp
//

import AppKit
import ApplicationServices

/// Сообщает, что в поле ввода активного приложения изменился текст.
///
/// Заменяет глобальный монитор клавиш: Accessibility и так рассказывает об
/// изменениях текста, поэтому отдельное разрешение Input Monitoring для
/// автозамены не нужно. Заодно это надёжнее — приходит факт изменения поля,
/// а не догадка по кодам клавиш.
@MainActor
final class AXTextWatcher {

    /// Вызывается, когда текст в сфокусированном поле изменился.
    var onTextChanged: (() -> Void)?

    private var observer: AXObserver?
    private var observedPID: pid_t?
    private var observedField: AXUIElement?
    private var activationObserver: NSObjectProtocol?

    // MARK: - Lifecycle

    func start() {
        guard activationObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.attachToFrontmostApp() }
        }
        attachToFrontmostApp()
    }

    func stop() {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
        detach()
    }

    // MARK: - Attaching

    /// Переключает наблюдение на приложение, которое стало активным.
    private func attachToFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != observedPID,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }

        detach()

        let pid = app.processIdentifier
        var created: AXObserver?
        guard AXObserverCreate(pid, Self.callback, &created) == .success, let created else { return }

        observer = created
        observedPID = pid

        let appElement = AXUIElementCreateApplication(pid)
        // Просим Chromium построить дерево заранее, при переключении на
        // приложение: к моменту набора оно уже готово, и первое же слово
        // обрабатывается наравне с нативными приложениями.
        AXUIElementSetAttributeValue(appElement, AXTextAccess.manualAccessibilityAttribute as CFString, kCFBooleanTrue)

        let context = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(created, appElement, kAXFocusedUIElementChangedNotification as CFString, context)

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(created),
            .defaultMode
        )

        observeFocusedField()
    }

    /// Подписывается на изменения текста в поле, которое сейчас в фокусе.
    private func observeFocusedField() {
        guard let observer, let observedPID else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()

        if let observedField {
            AXObserverRemoveNotification(observer, observedField, kAXValueChangedNotification as CFString)
        }
        observedField = nil

        let appElement = AXUIElementCreateApplication(observedPID)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement, kAXFocusedUIElementAttribute as CFString, &focused
        ) == .success, let value = focused,
            CFGetTypeID(value) == AXUIElementGetTypeID() else { return }

        let field = unsafeBitCast(value, to: AXUIElement.self)
        guard AXObserverAddNotification(
            observer, field, kAXValueChangedNotification as CFString, context
        ) == .success else { return }

        observedField = field
    }

    private func detach() {
        if let observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        observer = nil
        observedPID = nil
        observedField = nil
    }

    // MARK: - Callback

    /// C-функция обратного вызова: приходит на главный run loop, поэтому
    /// изоляция главного актора здесь фактическая.
    private static let callback: AXObserverCallback = { _, _, notification, context in
        guard let context else { return }
        let watcher = Unmanaged<AXTextWatcher>.fromOpaque(context).takeUnretainedValue()
        let name = notification as String

        MainActor.assumeIsolated {
            if name == kAXFocusedUIElementChangedNotification as String {
                watcher.observeFocusedField()
            } else if name == kAXValueChangedNotification as String {
                watcher.onTextChanged?()
            }
        }
    }
}
