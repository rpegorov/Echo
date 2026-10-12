//
//  WindowCreationObserver.swift
//  Echo
//

import ApplicationServices
import os

/// What the engine needs from a per-app window watcher; the seam lets tests count watchers without AX.
@MainActor
protocol WindowCreationObserving: AnyObject {
    /// Idempotent.
    func invalidate()
}

/// Watches one app for new windows. Owned by `AutoRuleEngine`, which calls `invalidate()` when the
/// app quits, its rule goes away or the engine is switched off.
@MainActor
final class WindowCreationObserver: WindowCreationObserving {

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Echo",
        category: "WindowCreationObserver"
    )

    private let pid: Int32
    private let appElement: AXUIElement
    private let onWindowCreated: @MainActor (AXUIElement) -> Void
    private var observer: AXObserver?

    /// nil when the AXObserver could not be created or the notification could not be added (logged).
    init?(pid: Int32, onWindowCreated: @escaping @MainActor (AXUIElement) -> Void) {
        self.pid = pid
        self.appElement = AXWindow.applicationElement(pid: pid)
        self.onWindowCreated = onWindowCreated
        guard attach() else { return nil }
    }

    /// Removes the notification and the run-loop source.
    func invalidate() {
        guard let observer else { return }
        self.observer = nil
        let result = AXObserverRemoveNotification(observer, appElement, kAXWindowCreatedNotification as CFString)
        if result != .success {
            Self.log.debug("remove notification pid=\(self.pid) code=\(result.rawValue)")
        }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    isolated deinit {
        invalidate()
    }

    private func attach() -> Bool {
        var created: AXObserver?
        let createResult = AXObserverCreate(pid, windowCreatedCallback, &created)
        guard createResult == .success, let created else {
            Self.log.error("observer create pid=\(self.pid) code=\(createResult.rawValue)")
            return false
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let addResult = AXObserverAddNotification(created, appElement, kAXWindowCreatedNotification as CFString, refcon)
        guard addResult == .success else {
            Self.log.error("add notification pid=\(self.pid) code=\(addResult.rawValue)")
            return false
        }
        // Main run loop: the callback arrives on the main thread, so it may assume main-actor isolation.
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        return true
    }

    fileprivate func deliver(_ window: AXUIElement) {
        onWindowCreated(window)
    }
}

private let windowCreatedCallback: AXObserverCallback = { _, element, _, refcon in
    guard let refcon else { return }
    let watcher = Unmanaged<WindowCreationObserver>.fromOpaque(refcon).takeUnretainedValue()
    // Delivered synchronously on the main thread by the main run-loop source; the element is used only
    // within this call. AXUIElement is not Sendable, so the compiler cannot prove that.
    // swiftlint:disable:next unchecked_sendable
    nonisolated(unsafe) let window = element // lint-allow: sw-nonisolated-unsafe main-thread callback
    MainActor.assumeIsolated { watcher.deliver(window) }
}
