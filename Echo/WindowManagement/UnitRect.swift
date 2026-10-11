//
//  UnitRect.swift
//  Echo
//

import CoreGraphics

/// A rectangle in fractions of a screen's visible area, origin bottom-left like Cocoa.
struct UnitRect: Equatable, Hashable, Sendable, Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    /// The window frame for this rect inside `visible`, inset by half the gap on every side
    /// so neighbouring windows end up one gap apart.
    func frame(in visible: CGRect, gap: CGFloat) -> CGRect {
        CGRect(
            x: visible.minX + visible.width * x,
            y: visible.minY + visible.height * y,
            width: visible.width * width,
            height: visible.height * height
        ).insetBy(dx: gap / 2, dy: gap / 2)
    }
}
