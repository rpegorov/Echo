import CoreGraphics
import Testing
@testable import Echo

private let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)

@Suite("Window placement")
struct WindowPlacementTests {

    @Test("a window that got exactly the requested size keeps the requested origin")
    func exactSizeKeepsOrigin() {
        let target = CGRect(x: 4, y: 4, width: 712, height: 867)
        let origin = WindowPlacement.clampedOrigin(target: target, actualSize: target.size, visible: visible)
        #expect(origin == target.origin)
    }

    @Test("a window wider than a zone at the right edge is pulled left so it stays on screen")
    func widerThanZoneAtRightEdge() {
        let target = CGRect(x: 960, y: 0, width: 480, height: 875)
        let origin = WindowPlacement.clampedOrigin(target: target, actualSize: CGSize(width: 600, height: 875), visible: visible)
        #expect(origin.x == 840)
        #expect(origin.y == 0)
    }

    @Test("a window taller than a zone at the top is pulled down so it stays on screen")
    func tallerThanZoneAtTop() {
        let target = CGRect(x: 0, y: 437.5, width: 1440, height: 437.5)
        let origin = WindowPlacement.clampedOrigin(target: target, actualSize: CGSize(width: 1440, height: 600), visible: visible)
        #expect(origin.y == visible.maxY - 600)
        #expect(origin.x == 0)
    }

    @Test("a smaller window keeps the requested origin")
    func smallerWindowKeepsOrigin() {
        let target = CGRect(x: 960, y: 100, width: 480, height: 600)
        let origin = WindowPlacement.clampedOrigin(target: target, actualSize: CGSize(width: 300, height: 400), visible: visible)
        #expect(origin == target.origin)
    }

    @Test("a target outside the visible area is pulled in on every side",
          arguments: [
            (CGPoint(x: -500, y: 100), CGPoint(x: 0, y: 100)),
            (CGPoint(x: 100, y: -500), CGPoint(x: 100, y: 0)),
            (CGPoint(x: 5000, y: 100), CGPoint(x: 1140, y: 100)),
            (CGPoint(x: 100, y: 5000), CGPoint(x: 100, y: 575))
          ])
    func targetOutsideIsClamped(requested: CGPoint, expected: CGPoint) {
        let target = CGRect(origin: requested, size: CGSize(width: 300, height: 300))
        let origin = WindowPlacement.clampedOrigin(target: target, actualSize: CGSize(width: 300, height: 300), visible: visible)
        #expect(origin == expected)
    }

    @Test("a window larger than the screen is aligned to the left edge with its top edge visible")
    func windowLargerThanScreen() {
        let target = CGRect(x: 500, y: 300, width: 400, height: 300)
        let size = CGSize(width: 2000, height: 1200)
        let origin = WindowPlacement.clampedOrigin(target: target, actualSize: size, visible: visible)
        #expect(origin.x == visible.minX)
        #expect(origin.y == visible.maxY - size.height)
    }

    @Test("a display with a negative origin is clamped against its own bounds")
    func negativeOriginDisplay() {
        let display = CGRect(x: -1920, y: 120, width: 1920, height: 1080)
        let target = CGRect(x: -480, y: 120, width: 480, height: 1080)
        let origin = WindowPlacement.clampedOrigin(target: target, actualSize: CGSize(width: 600, height: 1080), visible: display)
        #expect(origin.x == -600)
        #expect(origin.y == 120)
    }
}
