//
//  AXWindow.swift
//  MonitorBarApp
//

import AppKit
import ApplicationServices
import os

/// Accessibility reads and writes on window elements; Cocoa coordinates in, AX coordinates on the wire.
@MainActor
enum AXWindow {

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Echo",
        category: "AXWindow"
    )

    /// Not exported by ApplicationServices as a constant.
    private static let fullScreenAttribute = "AXFullScreen"

    /// Upper bound for one AX request to an app, so a hung app cannot stall the main thread for long.
    static let messagingTimeout: Float = 1

    private static var primaryScreenHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    // MARK: - Elements

    /// Application element with the messaging timeout applied.
    static func applicationElement(pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }

    /// Applies the messaging timeout to a window element and returns it.
    @discardableResult
    static func bounded(_ window: AXUIElement) -> AXUIElement {
        AXUIElementSetMessagingTimeout(window, messagingTimeout)
        return window
    }

    // MARK: - Reads

    static func element(from value: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value as AnyObject, to: AXUIElement.self)
    }

    static func role(of element: AXUIElement) -> String? {
        string(kAXRoleAttribute, of: element)
    }

    static func subrole(of element: AXUIElement) -> String? {
        string(kAXSubroleAttribute, of: element)
    }

    static func title(of window: AXUIElement) -> String? {
        string(kAXTitleAttribute, of: window)
    }

    static func isMinimized(_ window: AXUIElement) -> Bool {
        bool(kAXMinimizedAttribute, of: window)
    }

    static func isFullScreen(_ window: AXUIElement) -> Bool {
        bool(fullScreenAttribute, of: window)
    }

    /// AXWindow role, AXStandardWindow subrole, not minimized, not full screen.
    static func isEligible(_ window: AXUIElement) -> Bool {
        role(of: window) == (kAXWindowRole as String)
            && subrole(of: window) == (kAXStandardWindowSubrole as String)
            && !isMinimized(window)
            && !isFullScreen(window)
    }

    /// Current position in AX coordinates (origin top-left).
    static func position(of window: AXUIElement) -> CGPoint? {
        var point = CGPoint.zero
        return readValue(kAXPositionAttribute, of: window, type: .cgPoint, into: &point) ? point : nil
    }

    /// Window frame in Cocoa coordinates (origin bottom-left).
    static func frame(of window: AXUIElement) -> CGRect? {
        var size = CGSize.zero
        guard let origin = position(of: window),
              readValue(kAXSizeAttribute, of: window, type: .cgSize, into: &size)
        else { return nil }
        return ScreenCoordinates.flipped(CGRect(origin: origin, size: size), primaryHeight: primaryScreenHeight)
    }

    /// The app's windows on the current Space, in the order the app reports them (not z-order).
    static func windows(of app: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let raw = value, CFGetTypeID(raw) == CFArrayGetTypeID(),
              let items = raw as? [AnyObject]
        else { return [] }
        return items.compactMap { element(from: $0).map(bounded) }
    }

    static func focusedWindow(of app: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success
        else { return nil }
        return value.flatMap(element(from:))
    }

    // MARK: - Writes

    /// Position, size, then position again: a size change can move the window.
    static func writeFrame(_ frameCocoa: CGRect, to window: AXUIElement) {
        writePosition(frameCocoa.origin, of: frameCocoa.size, to: window)
        writeSize(frameCocoa.size, to: window)
        writePosition(frameCocoa.origin, of: frameCocoa.size, to: window)
    }

    /// `origin` is the bottom-left corner in Cocoa coordinates; `size` is needed to flip it.
    static func writePosition(_ origin: CGPoint, of size: CGSize, to window: AXUIElement) {
        var axOrigin = ScreenCoordinates.flipped(
            CGRect(origin: origin, size: size),
            primaryHeight: primaryScreenHeight
        ).origin
        writeValue(&axOrigin, type: .cgPoint, attribute: kAXPositionAttribute, to: window)
    }

    // MARK: - Private

    private static func writeSize(_ size: CGSize, to window: AXUIElement) {
        var mutable = size
        writeValue(&mutable, type: .cgSize, attribute: kAXSizeAttribute, to: window)
    }

    private static func string(_ attribute: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func bool(_ attribute: String, of element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let raw = value, CFGetTypeID(raw) == CFBooleanGetTypeID()
        else { return false }
        return CFBooleanGetValue(unsafeDowncast(raw as AnyObject, to: CFBoolean.self))
    }

    private static func readValue(
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

    private static func writeValue(
        _ storage: UnsafeRawPointer,
        type: AXValueType,
        attribute: String,
        to window: AXUIElement
    ) {
        guard let axValue = AXValueCreate(type, storage) else { return }
        let result = AXUIElementSetAttributeValue(window, attribute as CFString, axValue)
        if result != .success {
            log.debug("AX write of \(attribute, privacy: .public) failed: \(result.rawValue)")
        }
    }
}
