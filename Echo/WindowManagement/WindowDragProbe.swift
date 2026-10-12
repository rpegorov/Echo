//
//  WindowDragProbe.swift
//  Echo
//

import CoreGraphics
import Foundation

/// Decides when a mouse drag justifies an Accessibility read of the window position.
/// The window follows the mouse only about 0.23 s and a few hundred points into a drag, so 2.2-rc.1
/// spent its three reads in ~11 ms, never saw the window move, and dragging stopped working.
struct WindowDragProbe: Sendable {
    /// A drag that has not moved its window once the cursor travelled this far and this much time
    /// passed is not a window drag.
    static let giveUpTravel: CGFloat = 400
    static let giveUpTime: TimeInterval = 0.5

    enum Verdict: Sendable {
        case keepWatching
        case windowMoving
        case notAWindowDrag
    }

    private let downLocation: CGPoint
    private let startTime: TimeInterval
    private let threshold: CGFloat
    private var probesTaken = 0
    private(set) var verdict = Verdict.keepWatching

    init(downLocation: CGPoint, startTime: TimeInterval, threshold: CGFloat) {
        self.downLocation = downLocation
        self.startTime = startTime
        self.threshold = threshold
    }

    /// True while the drag is undecided and the cursor has travelled one `threshold` per read taken.
    func shouldProbe(cursor: CGPoint) -> Bool {
        guard verdict == .keepWatching else { return false }
        return travel(cursor) >= threshold * CGFloat(probesTaken + 1)
    }

    /// Records one position read; `moved` is whether the window moved by at least `threshold`.
    mutating func record(moved: Bool, cursor: CGPoint, at time: TimeInterval) -> Verdict {
        guard verdict == .keepWatching else { return verdict }
        probesTaken += 1
        if moved {
            verdict = .windowMoving
        } else if travel(cursor) >= Self.giveUpTravel, time - startTime >= Self.giveUpTime {
            verdict = .notAWindowDrag
        }
        return verdict
    }

    private func travel(_ cursor: CGPoint) -> CGFloat {
        hypot(cursor.x - downLocation.x, cursor.y - downLocation.y)
    }
}
