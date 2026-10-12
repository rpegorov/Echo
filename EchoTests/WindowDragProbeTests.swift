import CoreGraphics
import Foundation
import Testing
@testable import Echo

@Suite("Window drag probe")
struct WindowDragProbeTests {
    private static let threshold: CGFloat = 8
    private static let down = CGPoint(x: 100, y: 100)

    private func makeProbe(startTime: TimeInterval = 0) -> WindowDragProbe {
        WindowDragProbe(downLocation: Self.down, startTime: startTime, threshold: Self.threshold)
    }

    private func cursor(travelX: CGFloat, travelY: CGFloat = 0) -> CGPoint {
        CGPoint(x: Self.down.x + travelX, y: Self.down.y + travelY)
    }

    @Test("no probe before the cursor travels the first threshold")
    func noProbeBeforeFirstThreshold() {
        let probe = makeProbe()
        #expect(!probe.shouldProbe(cursor: Self.down))
        #expect(!probe.shouldProbe(cursor: cursor(travelX: Self.threshold - 1)))
    }

    @Test("one probe per threshold travelled")
    func oneProbePerThresholdTravelled() {
        var probe = makeProbe()
        #expect(probe.shouldProbe(cursor: cursor(travelX: Self.threshold)))
        #expect(probe.record(moved: false, cursor: cursor(travelX: Self.threshold), at: 0.02) == .keepWatching)

        #expect(!probe.shouldProbe(cursor: cursor(travelX: Self.threshold * 2 - 1)))
        #expect(probe.shouldProbe(cursor: cursor(travelX: Self.threshold * 2)))
        #expect(probe.record(moved: false, cursor: cursor(travelX: Self.threshold * 2), at: 0.04) == .keepWatching)
    }

    /// Regression guard for 2.2-rc.1: the probe gave up after three reads, taken in about 11 ms and
    /// under a hundred points of cursor travel, while the window only follows the mouse about 0.23 s
    /// and several hundred points of travel after the drag has begun — so a real drag was rejected as
    /// "not a window drag" and snapping never appeared.
    @Test("a window that only starts moving after several reads is still detected")
    func lateWindowMovementIsDetected() {
        var probe = makeProbe()
        for index in 1...10 {
            let travelled = Self.threshold * CGFloat(index)
            #expect(probe.shouldProbe(cursor: cursor(travelX: travelled)))
            #expect(
                probe.record(moved: false, cursor: cursor(travelX: travelled), at: Double(index) * 0.02)
                    == .keepWatching
            )
        }

        let travelled = Self.threshold * 11
        #expect(probe.shouldProbe(cursor: cursor(travelX: travelled)))
        #expect(probe.record(moved: true, cursor: cursor(travelX: travelled), at: 0.22) == .windowMoving)
    }

    /// A drag is often held before it is moved; the watch starts with the first drag event, not with
    /// the press, so seconds spent holding the button must not end it.
    @Test("a drag held still for seconds before it starts moving is still detected")
    func slowStartIsDetected() {
        var probe = makeProbe()
        #expect(probe.record(moved: false, cursor: cursor(travelX: Self.threshold * 3), at: 3) == .keepWatching)
        #expect(probe.record(moved: false, cursor: cursor(travelX: Self.threshold * 4), at: 3.2) == .keepWatching)
        #expect(probe.record(moved: true, cursor: cursor(travelX: Self.threshold * 5), at: 3.4) == .windowMoving)
    }

    @Test("diagonal travel is measured as euclidean distance from the down point")
    func diagonalTravelIsEuclidean() {
        let probe = makeProbe()
        #expect(!probe.shouldProbe(cursor: cursor(travelX: Self.threshold / 2, travelY: Self.threshold / 2)))
        #expect(probe.shouldProbe(cursor: cursor(travelX: Self.threshold, travelY: Self.threshold)))
    }

    @Test("a moved window is reported as windowMoving")
    func movedWindowIsWindowMoving() {
        var probe = makeProbe()
        #expect(probe.record(moved: true, cursor: cursor(travelX: Self.threshold), at: 0.05) == .windowMoving)
    }

    @Test("one signal alone does not write a motionless drag off")
    func oneSignalAloneKeepsWatching() {
        var farAndBrief = makeProbe()
        #expect(
            farAndBrief.record(moved: false, cursor: cursor(travelX: WindowDragProbe.giveUpTravel), at: 0.1)
                == .keepWatching
        )

        var slowAndNear = makeProbe()
        #expect(
            slowAndNear.record(
                moved: false,
                cursor: cursor(travelX: WindowDragProbe.giveUpTravel - 1),
                at: WindowDragProbe.giveUpTime * 10
            ) == .keepWatching
        )
    }

    @Test("a drag far and long enough without moving its window is written off")
    func motionlessDragIsWrittenOff() {
        var probe = makeProbe()
        #expect(
            probe.record(moved: false, cursor: cursor(travelX: Self.threshold), at: WindowDragProbe.giveUpTime - 0.1)
                == .keepWatching
        )
        #expect(
            probe.record(
                moved: false,
                cursor: cursor(travelX: WindowDragProbe.giveUpTravel),
                at: WindowDragProbe.giveUpTime + 0.01
            ) == .notAWindowDrag
        )
    }

    @Test("a closed drag takes no further reads and keeps its verdict")
    func closedDragStaysClosed() {
        var probe = makeProbe()
        #expect(
            probe.record(
                moved: false,
                cursor: cursor(travelX: WindowDragProbe.giveUpTravel),
                at: WindowDragProbe.giveUpTime + 0.01
            ) == .notAWindowDrag
        )
        #expect(!probe.shouldProbe(cursor: cursor(travelX: 2_000)))
        #expect(probe.record(moved: true, cursor: cursor(travelX: 2_000), at: 10) == .notAWindowDrag)
    }
}
