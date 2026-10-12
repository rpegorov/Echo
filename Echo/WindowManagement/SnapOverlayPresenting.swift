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

/// A grid shown on its display for a moment, not a drop target.
struct GridFlash: Equatable, Sendable {
    enum Title: Equatable, Sendable {
        case template(GridTemplate)
        /// A saved grid's name: data, not a localization key.
        case named(String)
    }

    let title: Title
    let screenFrame: CGRect
    /// Every zone as a window frame (global Cocoa coordinates, gap applied), in zone-number order.
    let zoneFrames: [CGRect]
    /// Index-aligned with `zoneFrames`; nil past zone 9 or when unassigned.
    let zoneShortcuts: [KeyboardShortcut?]
}

@MainActor
protocol SnapOverlayPresenting: AnyObject {
    /// Shows the preview, or animates from the current one. Equal consecutive previews are a no-op.
    func show(_ preview: SnapPreview)
    func hide()
    /// Shows `grid` for `DS.SnapOverlay.flashDuration`, then hides it; `show` and `hide` cancel a pending hide.
    func flash(_ grid: GridFlash)
}
