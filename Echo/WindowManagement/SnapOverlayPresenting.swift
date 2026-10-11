//
//  SnapOverlayPresenting.swift
//  Echo
//

import CoreGraphics

/// `frame` is exactly the window frame on drop (global Cocoa coordinates, gap applied); `screenFrame` picks the display.
struct SnapPreview: Equatable, Sendable {
    let layout: WindowLayout
    let frame: CGRect
    let screenFrame: CGRect
    let shortcut: KeyboardShortcut?
}

@MainActor
protocol SnapOverlayPresenting: AnyObject {
    /// Shows the preview, or animates from the current one. Equal consecutive previews are a no-op.
    func show(_ preview: SnapPreview)
    func hide()
}
