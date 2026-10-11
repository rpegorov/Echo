import CoreGraphics
import Testing
@testable import Echo

private let tolerance: CGFloat = 0.001
private let gap: CGFloat = 8

private let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let rightOfMain = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
private let belowRight = CGRect(x: 1440, y: -1080, width: 1920, height: 1080)
private let leftOfMain = CGRect(x: -1920, y: 120, width: 1920, height: 1080)

private func expectClose(_ actual: CGRect, _ expected: CGRect, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(abs(actual.minX - expected.minX) < tolerance && abs(actual.minY - expected.minY) < tolerance
            && abs(actual.width - expected.width) < tolerance && abs(actual.height - expected.height) < tolerance,
            "\(actual) vs \(expected)", sourceLocation: sourceLocation)
}

@Suite("Unit rect from frame")
struct UnitRectFromFrameTests {

    @Test("the whole visible area is the unit square")
    func fullAreaIsUnit() {
        let visible = CGRect(x: -1000, y: 50, width: 800, height: 400)
        #expect(UnitRect(frame: visible, in: visible) == UnitRect(x: 0, y: 0, width: 1, height: 1))
    }

    @Test("a frame maps to fractions relative to an area with an offset origin")
    func offsetOrigin() {
        let visible = CGRect(x: -1000, y: 50, width: 800, height: 400)
        let unit = UnitRect(frame: CGRect(x: -800, y: 250, width: 400, height: 100), in: visible)
        #expect(abs(unit.x - 0.25) < tolerance && abs(unit.y - 0.5) < tolerance)
        #expect(abs(unit.width - 0.5) < tolerance && abs(unit.height - 0.25) < tolerance)
    }

    @Test("it inverts UnitRect.frame with a zero gap", arguments: WindowLayout.allCases)
    func invertsFrame(layout: WindowLayout) {
        let visible = CGRect(x: 1440, y: -300, width: 2560, height: 1415)
        let unit = UnitRect(frame: layout.frame(in: visible, gap: 0), in: visible)
        let expected = layout.unitRect
        #expect(abs(unit.x - expected.x) < tolerance && abs(unit.y - expected.y) < tolerance)
        #expect(abs(unit.width - expected.width) < tolerance && abs(unit.height - expected.height) < tolerance)
    }
}

@Suite("Display arrangement")
struct DisplayArrangementTests {

    @Test("displays are ordered left to right")
    func horizontalOrder() {
        #expect(DisplayArrangement.spatialOrder([rightOfMain, main]) == [1, 0])
        #expect(DisplayArrangement.spatialOrder([main, rightOfMain, leftOfMain]) == [2, 0, 1])
    }

    @Test("displays sharing a left edge are ordered top to bottom")
    func verticalOrder() {
        let top = CGRect(x: 0, y: 900, width: 1440, height: 900)
        #expect(DisplayArrangement.spatialOrder([main, top]) == [1, 0])
        #expect(DisplayArrangement.spatialOrder([top, main]) == [0, 1])
    }

    @Test("a stacked pair next to another display keeps the left-edge rule")
    func mixedArrangement() {
        #expect(DisplayArrangement.spatialOrder([belowRight, main, rightOfMain]) == [1, 2, 0])
    }

    @Test("a single display and an empty list are handled")
    func degenerateOrders() {
        #expect(DisplayArrangement.spatialOrder([main]) == [0])
        #expect(DisplayArrangement.spatialOrder([]).isEmpty)
    }

    @Test("a window belongs to the display it overlaps most")
    func windowOnOneDisplay() {
        let window = CGRect(x: 100, y: 100, width: 400, height: 300)
        #expect(DisplayArrangement.displayIndex(of: window, in: [rightOfMain, main]) == 1)
    }

    @Test("a window across the seam goes to the display holding more of it")
    func windowOnTheSeam() {
        let mostlyRight = CGRect(x: 1300, y: 100, width: 300, height: 300)
        let mostlyLeft = CGRect(x: 1200, y: 100, width: 300, height: 300)
        #expect(DisplayArrangement.displayIndex(of: mostlyRight, in: [main, rightOfMain]) == 1)
        #expect(DisplayArrangement.displayIndex(of: mostlyLeft, in: [main, rightOfMain]) == 0)
    }

    @Test("a window touching a display only along an edge, or far away, has no display")
    func windowWithoutOverlap() {
        #expect(DisplayArrangement.displayIndex(of: CGRect(x: 1440, y: 0, width: 100, height: 100), in: [main]) == nil)
        #expect(DisplayArrangement.displayIndex(of: CGRect(x: 9000, y: 9000, width: 100, height: 100), in: [main, rightOfMain]) == nil)
        #expect(DisplayArrangement.displayIndex(of: main, in: []) == nil)
    }

    @Test("next and previous follow the spatial order and wrap around")
    func neighbourWraps() {
        let frames = [rightOfMain, main, leftOfMain]
        // spatial order: leftOfMain (2), main (1), rightOfMain (0)
        #expect(DisplayArrangement.neighbour(of: 2, direction: .next, in: frames) == 1)
        #expect(DisplayArrangement.neighbour(of: 1, direction: .next, in: frames) == 0)
        #expect(DisplayArrangement.neighbour(of: 0, direction: .next, in: frames) == 2)
        #expect(DisplayArrangement.neighbour(of: 0, direction: .previous, in: frames) == 1)
        #expect(DisplayArrangement.neighbour(of: 1, direction: .previous, in: frames) == 2)
        #expect(DisplayArrangement.neighbour(of: 2, direction: .previous, in: frames) == 0)
    }

    @Test("with stacked displays next goes downwards")
    func neighbourOnVerticalArrangement() {
        let top = CGRect(x: 0, y: 900, width: 1440, height: 900)
        #expect(DisplayArrangement.neighbour(of: 1, direction: .next, in: [main, top]) == 0)
        #expect(DisplayArrangement.neighbour(of: 0, direction: .next, in: [main, top]) == 1)
    }

    @Test("with one display both directions stay on it")
    func singleDisplayNeighbour() {
        #expect(DisplayArrangement.neighbour(of: 0, direction: .next, in: [main]) == 0)
        #expect(DisplayArrangement.neighbour(of: 0, direction: .previous, in: [main]) == 0)
    }
}

@Suite("Moving a window between displays")
struct MovedFrameTests {

    private let source = CGRect(x: 0, y: 0, width: 1440, height: 875)
    private let target = CGRect(x: 1440, y: -300, width: 2560, height: 1415)

    @Test("a window sitting in a layout lands in the same layout on the target", arguments: WindowLayout.allCases)
    func layoutIsPreserved(layout: WindowLayout) {
        let frame = layout.frame(in: source, gap: gap)
        expectClose(DisplayArrangement.movedFrame(frame, from: source, to: target, gap: gap),
                    layout.frame(in: target, gap: gap))
    }

    @Test("a window slightly off its layout is still treated as in that layout")
    func nearLayoutIsSnapped() {
        let frame = WindowLayout.rightHalf.frame(in: source, gap: gap).offsetBy(dx: -15, dy: 10)
        expectClose(DisplayArrangement.movedFrame(frame, from: source, to: target, gap: gap),
                    WindowLayout.rightHalf.frame(in: target, gap: gap))
    }

    @Test("any other window keeps its proportions relative to the display")
    func proportionsArePreserved() {
        let frame = CGRect(x: 144, y: 87.5, width: 360, height: 175)
        let moved = DisplayArrangement.movedFrame(frame, from: source, to: target, gap: 0)
        expectClose(moved, CGRect(x: target.minX + target.width * 0.1, y: target.minY + target.height * 0.1,
                                  width: target.width * 0.25, height: target.height * 0.2))
    }

    @Test("the result always fits inside the target, even for windows hanging off the source",
          arguments: [
            CGRect(x: 1300, y: 0, width: 400, height: 300),
            CGRect(x: -100, y: -50, width: 600, height: 400),
            CGRect(x: 200, y: 600, width: 500, height: 500),
            CGRect(x: 0, y: 0, width: 3000, height: 2000)
          ],
          [CGRect(x: 0, y: 0, width: 1024, height: 600), CGRect(x: -1920, y: 120, width: 1920, height: 1080)])
    func resultStaysInsideTarget(frame: CGRect, target: CGRect) {
        let moved = DisplayArrangement.movedFrame(frame, from: source, to: target, gap: gap)
        #expect(moved.minX >= target.minX - tolerance && moved.maxX <= target.maxX + tolerance, "\(moved)")
        #expect(moved.minY >= target.minY - tolerance && moved.maxY <= target.maxY + tolerance, "\(moved)")
        #expect(moved.width > 0 && moved.height > 0)
    }

    @Test("moving within the same display changes nothing")
    func sameDisplayIsIdentity() {
        let layoutFrame = WindowLayout.topLeft.frame(in: source, gap: gap)
        expectClose(DisplayArrangement.movedFrame(layoutFrame, from: source, to: source, gap: gap), layoutFrame)
        let free = CGRect(x: 200, y: 100, width: 500, height: 300)
        expectClose(DisplayArrangement.movedFrame(free, from: source, to: source, gap: 0), free)
    }
}
