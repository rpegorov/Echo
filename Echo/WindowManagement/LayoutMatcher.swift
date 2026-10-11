//
//  LayoutMatcher.swift
//  Echo
//

import CoreGraphics

enum LayoutMatcher {
    /// Largest per-edge distance, in points, at which a window still counts as sitting in a layout.
    static let tolerance: CGFloat = 24

    /// The candidate whose frame is nearest to `frame`, if all four edges are within `tolerance`.
    static func match(_ frame: CGRect, among candidates: [WindowLayout], visible: CGRect, gap: CGFloat) -> WindowLayout? {
        var bestLayout: WindowLayout?
        var bestDeviation = CGFloat.greatestFiniteMagnitude
        for candidate in candidates {
            let target = candidate.frame(in: visible, gap: gap)
            let deviation = max(
                abs(frame.minX - target.minX),
                abs(frame.maxX - target.maxX),
                abs(frame.minY - target.minY),
                abs(frame.maxY - target.maxY)
            )
            guard deviation <= tolerance, deviation < bestDeviation else { continue }
            bestLayout = candidate
            bestDeviation = deviation
        }
        return bestLayout
    }
}
