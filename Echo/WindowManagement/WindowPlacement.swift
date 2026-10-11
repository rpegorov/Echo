//
//  WindowPlacement.swift
//  Echo
//

import CoreGraphics

enum WindowPlacement {
    /// Origin keeping a window of `actualSize` as close to `target` as possible while inside `visible`.
    static func clampedOrigin(target: CGRect, actualSize: CGSize, visible: CGRect) -> CGPoint {
        // A window larger than the visible area keeps its top edge visible, the rest may hang below.
        let x = actualSize.width > visible.width
            ? visible.minX
            : min(max(target.minX, visible.minX), visible.maxX - actualSize.width)
        let y = actualSize.height > visible.height
            ? visible.maxY - actualSize.height
            : min(max(target.minY, visible.minY), visible.maxY - actualSize.height)
        return CGPoint(x: x, y: y)
    }
}
