//
//  ScreenCoordinates.swift
//  Echo
//

import CoreGraphics

enum ScreenCoordinates {
    /// Converts a frame between Cocoa (origin bottom-left) and Accessibility (origin top-left) coordinates.
    /// Both directions use the same formula, so applying it twice returns the original frame.
    static func flipped(_ frame: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: frame.minX,
            y: primaryHeight - frame.minY - frame.height,
            width: frame.width,
            height: frame.height
        )
    }
}
