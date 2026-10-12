//
//  LayoutCycle.swift
//  Echo
//

import CoreGraphics

extension WindowLayout {
    /// Steps a repeated press walks through, starting with the layout itself; nil when it does not cycle.
    var cycle: [WindowLayout]? {
        switch self {
        case .leftHalf:  return [.leftHalf, .leftTwoThirds, .leftThird]
        case .rightHalf: return [.rightHalf, .rightTwoThirds, .rightThird]
        default:         return nil
        }
    }
}

enum LayoutCycle {
    /// The layout to apply for a press of `layout`'s command on a window currently at `frame`.
    static func next(for layout: WindowLayout, windowFrame frame: CGRect, visible: CGRect, gap: CGFloat) -> WindowLayout {
        guard let steps = layout.cycle else { return layout }
        guard let current = LayoutMatcher.match(frame, among: steps, visible: visible, gap: gap),
              let index = steps.firstIndex(of: current)
        else { return steps[0] }
        return steps[(index + 1) % steps.count]
    }
}
