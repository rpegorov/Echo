//
//  WindowSnapshot.swift
//  Echo
//

import ApplicationServices
import CoreGraphics

/// A window's identity within one catalog pass: owning process and front-to-back position in its app.
struct WindowRef: Hashable, Sendable {
    let pid: Int32
    let ordinal: Int
}

/// What placement logic needs to know about a window; Cocoa coordinates.
struct WindowSnapshot: Equatable, Sendable {
    let ref: WindowRef
    let bundleID: String
    let appName: String
    let title: String?
    let frame: CGRect
}

/// A catalogued window with its AX element; lives only on the main actor.
struct CatalogWindow {
    let snapshot: WindowSnapshot
    let element: AXUIElement
}
