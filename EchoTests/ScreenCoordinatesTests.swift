import CoreGraphics
import Testing
@testable import Echo

private let primaryHeight: CGFloat = 900

@Suite("Cocoa to AX screen coordinates")
struct ScreenCoordinatesTests {

    @Test("a frame on the primary screen flips against the primary height")
    func primaryScreenFrameFlips() {
        let cocoa = CGRect(x: 100, y: 50, width: 400, height: 300)
        let ax = ScreenCoordinates.flipped(cocoa, primaryHeight: primaryHeight)
        #expect(ax == CGRect(x: 100, y: 550, width: 400, height: 300))
    }

    @Test("the full primary screen maps onto the AX origin")
    func primaryScreenMapsToOrigin() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        #expect(ScreenCoordinates.flipped(screen, primaryHeight: primaryHeight) == screen)
    }

    @Test("a display above the primary one gets a negative AX y")
    func displayAbovePrimaryHasNegativeY() {
        let above = CGRect(x: 0, y: 900, width: 2560, height: 1440)
        let ax = ScreenCoordinates.flipped(above, primaryHeight: primaryHeight)
        #expect(ax.origin.y == -1440)
        #expect(ax.origin.x == 0)
        #expect(ax.size == above.size)
    }

    @Test("a display to the left keeps its negative x")
    func displayToTheLeftKeepsX() {
        let left = CGRect(x: -1920, y: 120, width: 1920, height: 1080)
        let ax = ScreenCoordinates.flipped(left, primaryHeight: primaryHeight)
        #expect(ax.origin.x == -1920)
        #expect(ax.origin.y == primaryHeight - 120 - 1080)
        #expect(ax.size == left.size)
    }

    @Test("a display below the primary one gets a positive AX y")
    func displayBelowPrimaryHasPositiveY() {
        let below = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        let ax = ScreenCoordinates.flipped(below, primaryHeight: primaryHeight)
        #expect(ax.origin.y == primaryHeight)
    }

    @Test("flipping twice returns the original frame",
          arguments: [
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 0, y: 900, width: 2560, height: 1440),
            CGRect(x: -1920, y: 120, width: 1920, height: 1080),
            CGRect(x: 37.5, y: -12.25, width: 640, height: 480.5)
          ])
    func flippingTwiceIsIdentity(frame: CGRect) {
        let once = ScreenCoordinates.flipped(frame, primaryHeight: primaryHeight)
        #expect(ScreenCoordinates.flipped(once, primaryHeight: primaryHeight) == frame)
    }
}
