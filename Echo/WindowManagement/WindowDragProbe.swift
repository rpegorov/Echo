//
//  WindowDragProbe.swift
//  Echo
//

import CoreGraphics

/// Decides when a mouse drag justifies an Accessibility read of the window position.
/// Drags that never move the window (text selection, sliders, canvas scrolling)
/// are capped at `maxProbes` reads, so a long selection drag costs at most three.
struct WindowDragProbe: Sendable {
    static let maxProbes = 3

    private let downLocation: CGPoint
    private let threshold: CGFloat
    private var probesTaken = 0

    init(downLocation: CGPoint, threshold: CGFloat) {
        self.downLocation = downLocation
        self.threshold = threshold
    }

    /// True when the cursor has travelled far enough since the down point to justify the next position read:
    /// distance >= threshold * (probesTaken + 1) and probesTaken < maxProbes.
    func shouldProbe(cursor: CGPoint) -> Bool {
        let distance = hypot(cursor.x - downLocation.x, cursor.y - downLocation.y)
        return probesTaken < Self.maxProbes && distance >= threshold * CGFloat(probesTaken + 1)
    }

    /// Records one position read; `moved` is whether the window moved by at least `threshold` from its start.
    mutating func record(moved: Bool) -> Outcome {
        probesTaken += 1
        if moved { return .windowMoving }
        return probesTaken >= Self.maxProbes ? .notAWindowDrag : .keepWatching
    }

    enum Outcome: Sendable {
        case windowMoving
        case keepWatching
        case notAWindowDrag
    }
}
