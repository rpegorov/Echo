//
//  WindowPlacement.swift
//  Echo
//

import CoreGraphics

enum WindowPlacement {
    /// Origin (Cocoa coordinates) for a window of `actualSize` inside `visible`: its left edge follows `target`'s,
    /// its top edge stays at `target`'s top.
    static func clampedOrigin(target: CGRect, actualSize: CGSize, visible: CGRect) -> CGPoint {
        // A window larger than the visible area keeps its top edge visible, the rest may hang below.
        let x = actualSize.width > visible.width
            ? visible.minX
            : min(max(target.minX, visible.minX), visible.maxX - actualSize.width)
        let y = actualSize.height > visible.height
            ? visible.maxY - actualSize.height
            : min(max(target.maxY - actualSize.height, visible.minY), visible.maxY - actualSize.height)
        return CGPoint(x: x, y: y)
    }
}
