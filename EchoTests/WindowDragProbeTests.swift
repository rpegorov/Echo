import CoreGraphics
import Testing
@testable import Echo

@Suite("Window drag probe")
struct WindowDragProbeTests {

    private static let threshold: CGFloat = 8
    private static let down = CGPoint(x: 100, y: 100)

    private func cursor(travelX: CGFloat, travelY: CGFloat = 0) -> CGPoint {
        CGPoint(x: Self.down.x + travelX, y: Self.down.y + travelY)
    }

    @Test("no probe before the cursor travels the first threshold")
    func noProbeBeforeFirstThreshold() {
        let probe = WindowDragProbe(downLocation: Self.down, threshold: Self.threshold)
        #expect(!probe.shouldProbe(cursor: Self.down))
        #expect(!probe.shouldProbe(cursor: cursor(travelX: Self.threshold - 1)))
    }

    @Test("probes at 1x, 2x and 3x the threshold, never a fourth")
    func probesAtThresholdMultiples() {
        var probe = WindowDragProbe(downLocation: Self.down, threshold: Self.threshold)
        #expect(probe.shouldProbe(cursor: cursor(travelX: Self.threshold)))
        #expect(probe.record(moved: false) == .keepWatching)

        #expect(!probe.shouldProbe(cursor: cursor(travelX: Self.threshold * 2 - 1)))
        #expect(probe.shouldProbe(cursor: cursor(travelX: Self.threshold * 2)))
        #expect(probe.record(moved: false) == .keepWatching)

        #expect(!probe.shouldProbe(cursor: cursor(travelX: Self.threshold * 3 - 1)))
        #expect(probe.shouldProbe(cursor: cursor(travelX: Self.threshold * 3)))
        #expect(probe.record(moved: false) == .notAWindowDrag)

        #expect(!probe.shouldProbe(cursor: cursor(travelX: Self.threshold * CGFloat(WindowDragProbe.maxProbes + 1))))
    }

    @Test("diagonal travel is measured as euclidean distance from the down point")
    func diagonalTravelIsEuclidean() {
        let probe = WindowDragProbe(downLocation: Self.down, threshold: Self.threshold)
        #expect(!probe.shouldProbe(cursor: cursor(travelX: Self.threshold / 2, travelY: Self.threshold / 2)))
        #expect(probe.shouldProbe(cursor: cursor(travelX: Self.threshold, travelY: Self.threshold)))
    }

    @Test("a moved window is reported as windowMoving")
    func movedWindowIsWindowMoving() {
        var probe = WindowDragProbe(downLocation: Self.down, threshold: Self.threshold)
        #expect(probe.record(moved: true) == .windowMoving)
    }

    @Test("a window that has not moved keeps the drag under watch")
    func notMovedKeepsWatching() {
        var probe = WindowDragProbe(downLocation: Self.down, threshold: Self.threshold)
        #expect(probe.record(moved: false) == .keepWatching)
        #expect(probe.record(moved: false) == .keepWatching)
    }

    @Test("exhausting all probes ends the drag as notAWindowDrag")
    func exhaustedProbesAreNotAWindowDrag() {
        var probe = WindowDragProbe(downLocation: Self.down, threshold: Self.threshold)
        probe.record(moved: false)
        probe.record(moved: false)
        #expect(probe.record(moved: false) == .notAWindowDrag)
    }
}
