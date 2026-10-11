//
//  WindowLayout.swift
//  MonitorBarApp
//

import CoreGraphics

/// Window layouts. Frames are in Cocoa coordinates (origin bottom-left).
enum WindowLayout: String, CaseIterable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird
    case leftTwoThirds, rightTwoThirds
    case center, maximize

    func frame(in visible: CGRect, gap: CGFloat) -> CGRect {
        unitRect.frame(in: visible, gap: gap)
    }

    var unitRect: UnitRect {
        let half = 0.5
        let third = 1.0 / 3
        let twoThirds = 2 * third
        let centerSide = 0.6
        let centerInset = (1 - centerSide) / 2
        switch self {
        case .leftHalf:       return UnitRect(x: 0, y: 0, width: half, height: 1)
        case .rightHalf:      return UnitRect(x: half, y: 0, width: half, height: 1)
        case .topHalf:        return UnitRect(x: 0, y: half, width: 1, height: half)
        case .bottomHalf:     return UnitRect(x: 0, y: 0, width: 1, height: half)
        case .topLeft:        return UnitRect(x: 0, y: half, width: half, height: half)
        case .topRight:       return UnitRect(x: half, y: half, width: half, height: half)
        case .bottomLeft:     return UnitRect(x: 0, y: 0, width: half, height: half)
        case .bottomRight:    return UnitRect(x: half, y: 0, width: half, height: half)
        case .leftThird:      return UnitRect(x: 0, y: 0, width: third, height: 1)
        case .centerThird:    return UnitRect(x: third, y: 0, width: third, height: 1)
        case .rightThird:     return UnitRect(x: twoThirds, y: 0, width: third, height: 1)
        case .leftTwoThirds:  return UnitRect(x: 0, y: 0, width: twoThirds, height: 1)
        case .rightTwoThirds: return UnitRect(x: third, y: 0, width: twoThirds, height: 1)
        case .center:         return UnitRect(x: centerInset, y: centerInset, width: centerSide, height: centerSide)
        case .maximize:       return UnitRect(x: 0, y: 0, width: 1, height: 1)
        }
    }

    /// The hotkey command that applies this layout.
    var command: WMCommand {
        switch self {
        case .leftHalf:       return .leftHalf
        case .rightHalf:      return .rightHalf
        case .topHalf:        return .topHalf
        case .bottomHalf:     return .bottomHalf
        case .topLeft:        return .topLeft
        case .topRight:       return .topRight
        case .bottomLeft:     return .bottomLeft
        case .bottomRight:    return .bottomRight
        case .leftThird:      return .leftThird
        case .centerThird:    return .centerThird
        case .rightThird:     return .rightThird
        case .leftTwoThirds:  return .leftTwoThirds
        case .rightTwoThirds: return .rightTwoThirds
        case .center:         return .center
        case .maximize:       return .maximize
        }
    }

    var group: LayoutGroup {
        switch self {
        case .leftHalf, .rightHalf:                          return .halves
        case .topHalf, .bottomHalf:                          return .verticalHalves
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return .quarters
        case .leftThird, .centerThird, .rightThird:          return .thirds
        case .leftTwoThirds, .rightTwoThirds:                return .twoThirds
        case .center, .maximize:                             return .centerAndFull
        }
    }
}
