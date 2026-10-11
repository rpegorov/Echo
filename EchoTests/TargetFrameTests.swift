import CoreGraphics
import Testing
@testable import Echo

private let gap: CGFloat = 8
private let tolerance: CGFloat = 0.001

private let screens = [
    CGRect(x: 0, y: 0, width: 1440, height: 900),
    CGRect(x: 1440, y: 0, width: 2560, height: 1440)
]
private let visibles = [
    CGRect(x: 0, y: 0, width: 1440, height: 875),
    CGRect(x: 1440, y: 0, width: 2560, height: 1415)
]

private func target(
    _ command: WMCommand, window: CGRect, source: Int = 0, cycling: Bool = true,
    screenFrames: [CGRect] = screens, visibleFrames: [CGRect] = visibles
) -> CGRect? {
    WindowManagerService.targetFrame(
        for: command, windowFrame: window, sourceIndex: source,
        screenFrames: screenFrames, visibleFrames: visibleFrames, gap: gap, cycling: cycling)
}

private func expectClose(_ actual: CGRect?, _ expected: CGRect, sourceLocation: SourceLocation = #_sourceLocation) {
    guard let actual else { Issue.record("expected \(expected), got nil", sourceLocation: sourceLocation); return }
    #expect(abs(actual.minX - expected.minX) < tolerance && abs(actual.minY - expected.minY) < tolerance
            && abs(actual.width - expected.width) < tolerance && abs(actual.height - expected.height) < tolerance,
            "\(actual) vs \(expected)", sourceLocation: sourceLocation)
}

@Suite("Window command target frames")
struct TargetFrameTests {

    @Test("repeating a half shortcut with cycling on steps half, two thirds, third, half")
    func cyclingStepsThroughWidths() {
        var window = WindowLayout.maximize.frame(in: visibles[0], gap: gap)
        var applied: [WindowLayout] = []
        for expected in [WindowLayout.leftHalf, .leftTwoThirds, .leftThird, .leftHalf] {
            let frame = target(.leftHalf, window: window)
            expectClose(frame, expected.frame(in: visibles[0], gap: gap))
            applied.append(expected)
            window = frame ?? window
        }
        #expect(applied.count == 4)
    }

    @Test("with cycling off the command always applies its own layout")
    func cyclingOffAlwaysOwnLayout() {
        let own = WindowLayout.rightHalf.frame(in: visibles[0], gap: gap)
        for _ in 0..<3 {
            expectClose(target(.rightHalf, window: own, cycling: false), own)
        }
        let twoThirds = WindowLayout.rightTwoThirds.frame(in: visibles[0], gap: gap)
        expectClose(target(.rightHalf, window: twoThirds, cycling: false), own)
    }

    @Test("a layout without a cycle is unaffected by the cycling flag", arguments: [true, false])
    func nonCyclingLayoutIgnoresFlag(cycling: Bool) {
        let window = WindowLayout.topHalf.frame(in: visibles[0], gap: gap)
        expectClose(target(.topHalf, window: window, cycling: cycling), window)
        expectClose(target(.leftThird, window: window, cycling: cycling),
                    WindowLayout.leftThird.frame(in: visibles[0], gap: gap))
    }

    @Test("a layout is applied against the visible area of the window's own display")
    func layoutUsesSourceDisplay() {
        let window = WindowLayout.maximize.frame(in: visibles[1], gap: gap)
        expectClose(target(.centerThird, window: window, source: 1),
                    WindowLayout.centerThird.frame(in: visibles[1], gap: gap))
    }

    @Test("moving to the next display keeps the layout the window sits in")
    func nextDisplayKeepsLayout() {
        let window = WindowLayout.leftHalf.frame(in: visibles[0], gap: gap)
        expectClose(target(.nextDisplay, window: window),
                    WindowLayout.leftHalf.frame(in: visibles[1], gap: gap))
    }

    @Test("moving to the previous display from the first one wraps to the last")
    func previousDisplayWraps() {
        let window = WindowLayout.bottomRight.frame(in: visibles[0], gap: gap)
        expectClose(target(.previousDisplay, window: window),
                    WindowLayout.bottomRight.frame(in: visibles[1], gap: gap))
    }

    @Test("a window not in any layout keeps its proportions on the next display")
    func nextDisplayKeepsProportions() {
        let window = CGRect(x: 144, y: 87.5, width: 360, height: 175)
        let moved = target(.nextDisplay, window: window)
        let expected = UnitRect(frame: window, in: visibles[0]).frame(in: visibles[1], gap: 0)
        expectClose(moved, expected)
        if let moved { #expect(visibles[1].contains(moved)) }
    }

    @Test("display commands do nothing with a single display", arguments: [WMCommand.nextDisplay, .previousDisplay])
    func singleDisplayMovesNothing(command: WMCommand) {
        let window = WindowLayout.leftHalf.frame(in: visibles[0], gap: gap)
        #expect(target(command, window: window, screenFrames: [screens[0]], visibleFrames: [visibles[0]]) == nil)
    }

    @Test("commands that are not window commands move nothing",
          arguments: [WMCommand.openClipboard, .switchLayout, .convertWord, .translateSelection])
    func nonWindowCommandsReturnNil(command: WMCommand) {
        #expect(target(command, window: visibles[0]) == nil)
    }

    @Test("inconsistent display data yields no target")
    func invalidDisplayDataReturnsNil() {
        let window = visibles[0]
        #expect(target(.leftHalf, window: window, source: 5) == nil)
        #expect(target(.leftHalf, window: window, screenFrames: [screens[0]]) == nil)
        #expect(target(.nextDisplay, window: window, source: -1) == nil)
    }
}
