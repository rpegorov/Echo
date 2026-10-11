import CoreGraphics
import Testing
@testable import Echo

private let gap: CGFloat = 8

private let displays: [CGRect] = [
    CGRect(x: 0, y: 0, width: 1280, height: 775),
    CGRect(x: 0, y: 0, width: 3440, height: 1415),
    CGRect(x: -1728, y: 40, width: 1728, height: 1050)
]

/// Presses `layout`'s shortcut `count` times, moving the window to each result.
private func presses(_ layout: WindowLayout, count: Int, startingAt start: CGRect, in visible: CGRect) -> [WindowLayout] {
    var frame = start
    var result: [WindowLayout] = []
    for _ in 0..<count {
        let next = LayoutCycle.next(for: layout, windowFrame: frame, visible: visible, gap: gap)
        result.append(next)
        frame = next.frame(in: visible, gap: gap)
    }
    return result
}

@Suite("Layout cycles")
struct LayoutCycleTests {

    @Test("only the two half layouts cycle, and the first step is the layout itself")
    func cycleDefinitions() {
        #expect(WindowLayout.leftHalf.cycle == [.leftHalf, .leftTwoThirds, .leftThird])
        #expect(WindowLayout.rightHalf.cycle == [.rightHalf, .rightTwoThirds, .rightThird])
        for layout in WindowLayout.allCases where layout != .leftHalf && layout != .rightHalf {
            #expect(layout.cycle == nil, "\(layout)")
        }
    }

    @Test("repeating the left shortcut walks half, two thirds, third and back to half", arguments: displays)
    func leftCycle(visible: CGRect) {
        let start = WindowLayout.maximize.frame(in: visible, gap: gap)
        #expect(presses(.leftHalf, count: 4, startingAt: start, in: visible)
                == [.leftHalf, .leftTwoThirds, .leftThird, .leftHalf])
    }

    @Test("repeating the right shortcut walks half, two thirds, third and back to half", arguments: displays)
    func rightCycle(visible: CGRect) {
        let start = WindowLayout.maximize.frame(in: visible, gap: gap)
        #expect(presses(.rightHalf, count: 4, startingAt: start, in: visible)
                == [.rightHalf, .rightTwoThirds, .rightThird, .rightHalf])
    }

    @Test("a window that is somewhere else starts the cycle from its first step", arguments: displays)
    func unmatchedWindowStartsAtFirstStep(visible: CGRect) {
        let stray = CGRect(x: visible.minX + 100, y: visible.minY + 100, width: 400, height: 300)
        #expect(LayoutCycle.next(for: .leftHalf, windowFrame: stray, visible: visible, gap: gap) == .leftHalf)
        #expect(LayoutCycle.next(for: .rightHalf, windowFrame: stray, visible: visible, gap: gap) == .rightHalf)
    }

    @Test("a window sitting in the other side's cycle starts this one at its first step", arguments: displays)
    func otherSidesStepIsNotMatched(visible: CGRect) {
        let onTheLeft = WindowLayout.leftHalf.frame(in: visible, gap: gap)
        #expect(LayoutCycle.next(for: .rightHalf, windowFrame: onTheLeft, visible: visible, gap: gap) == .rightHalf)
    }

    @Test("small drift from the applied frame still counts as the same step")
    func driftWithinToleranceKeepsTheStep() {
        let visible = displays[0]
        let half = WindowLayout.leftHalf.frame(in: visible, gap: gap).offsetBy(dx: 20, dy: 0)
        #expect(LayoutCycle.next(for: .leftHalf, windowFrame: half, visible: visible, gap: gap) == .leftTwoThirds)
    }

    @Test("a window dragged well away from its step restarts the cycle")
    func largeDriftRestartsTheCycle() {
        let visible = displays[0]
        let half = WindowLayout.leftHalf.frame(in: visible, gap: gap).offsetBy(dx: 30, dy: 0)
        #expect(LayoutCycle.next(for: .leftHalf, windowFrame: half, visible: visible, gap: gap) == .leftHalf)
    }

    @Test("a window that cannot shrink to a third still moves on to half instead of sticking",
          arguments: [CGFloat(440), 500])
    func windowWithLargeMinimumWidthLeavesTheThirdStep(minimumWidth: CGFloat) {
        let visible = displays[0]
        let third = WindowLayout.leftThird.frame(in: visible, gap: gap)
        let stuck = CGRect(x: third.minX, y: third.minY, width: minimumWidth, height: third.height)
        #expect(LayoutCycle.next(for: .leftHalf, windowFrame: stuck, visible: visible, gap: gap) == .leftHalf)
    }

    @Test("layouts without a cycle always return themselves")
    func nonCyclingLayoutsReturnThemselves() {
        let visible = displays[0]
        let anywhere = WindowLayout.leftHalf.frame(in: visible, gap: gap)
        for layout in WindowLayout.allCases where layout.cycle == nil {
            #expect(LayoutCycle.next(for: layout, windowFrame: anywhere, visible: visible, gap: gap) == layout, "\(layout)")
            let own = layout.frame(in: visible, gap: gap)
            #expect(LayoutCycle.next(for: layout, windowFrame: own, visible: visible, gap: gap) == layout, "\(layout)")
        }
    }
}
