//
//  SnapOverlayPresenting.swift
//  Echo
//

import CoreGraphics

/// What a drop would snap the window into.
enum SnapTarget: Equatable, Sendable {
    case layout(WindowLayout)
    case grid(GridSnapTarget)
}

/// A drop into one zone of the display's active grid, or into the union of several.
struct GridSnapTarget: Equatable, Sendable {
    /// 1-based numbers of the zones the window will cover, ascending; one entry outside span mode.
    let zoneNumbers: [Int]
    /// Every zone of the active grid as a window frame (global Cocoa coordinates, gap applied), drawn faintly.
    let contextFrames: [CGRect]
}

/// `frame` is exactly the window frame on drop (global Cocoa coordinates, gap applied); `screenFrame` picks the display.
struct SnapPreview: Equatable, Sendable {
    let target: SnapTarget
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
