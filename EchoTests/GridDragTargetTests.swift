import AppKit
import CoreGraphics
import Testing
@testable import Echo

private func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> UnitRect {
    UnitRect(x: x, y: y, width: width, height: height)
}

private func shortcut(forZone number: Int) -> KeyboardShortcut {
    KeyboardShortcut(keyCode: UInt32(number), flags: [.control, .option])
}

/// Mirrors the real bindings: only zones 1...9 have a hotkey.
private func hotkeyForSingleDigitZones(_ number: Int) -> KeyboardShortcut? {
    (1...9).contains(number) ? shortcut(forZone: number) : nil
}

private func zoneNumbers(of resolution: GridDragTarget.Resolution?) -> [Int]? {
    guard case .grid(let target)? = resolution?.preview.target else { return nil }
    return target.zoneNumbers
}

/// A display left of the primary one (negative origin); the menu bar makes the visible area shorter than the screen.
private let screenFrame = CGRect(x: -1920, y: 0, width: 1920, height: 1200)
private let visibleFrame = CGRect(x: -1920, y: 100, width: 1920, height: 1080)

private func display(_ zones: [UnitRect], gap: CGFloat = 0) -> GridDragTarget.Display {
    GridDragTarget.Display(
        screenFrame: screenFrame,
        visibleFrame: visibleFrame,
        zones: zones,
        contextFrames: zones.map { $0.frame(in: visibleFrame, gap: gap) }
    )
}

/// Cocoa point at the given fraction of the visible area; y grows upwards.
private func cursor(_ unitX: CGFloat, _ unitY: CGFloat) -> CGPoint {
    CGPoint(x: visibleFrame.minX + visibleFrame.width * unitX, y: visibleFrame.minY + visibleFrame.height * unitY)
}

private func resolve(
    _ point: CGPoint,
    on display: GridDragTarget.Display,
    spanning: Bool = false,
    anchor: Int? = nil,
    gap: CGFloat = 0,
    shortcutForZone: (Int) -> KeyboardShortcut? = { shortcut(forZone: $0) }
) -> GridDragTarget.Resolution? {
    GridDragTarget.resolve(
        cursor: point, on: display, spanning: spanning, anchor: anchor, gap: gap, shortcutForZone: shortcutForZone
    )
}

private let twoColumns = [rect(0, 0, 0.5, 1), rect(0.5, 0, 0.5, 1)]
/// Reading order: top-left, top-right, bottom-left, bottom-right.
private let quarters = [rect(0, 0.5, 0.5, 0.5), rect(0.5, 0.5, 0.5, 0.5), rect(0, 0, 0.5, 0.5), rect(0.5, 0, 0.5, 0.5)]
/// A tall main zone on the left, two stacked side zones on the right.
private let mainAndTwoSides = [rect(0, 0, 0.5, 1), rect(0.5, 0.5, 0.5, 0.5), rect(0.5, 0, 0.5, 0.5)]

@Suite("Grid drag target: single zone")
struct GridDragTargetSingleZoneTests {

    @Test("the cursor in the left or right half selects zone 1 or zone 2")
    func zoneUnderCursor() {
        let grid = display(twoColumns)
        #expect(zoneNumbers(of: resolve(cursor(0.25, 0.5), on: grid)) == [1])
        #expect(zoneNumbers(of: resolve(cursor(0.75, 0.5), on: grid)) == [2])
    }

    @Test("on the shared border the lower zone wins")
    func sharedBorder() {
        let grid = display(twoColumns)
        #expect(zoneNumbers(of: resolve(cursor(0.5, 0.5), on: grid)) == [1])
    }

    @Test("a cursor outside the visible area is clamped to the nearest edge")
    func cursorOutsideVisibleArea() {
        let grid = display(quarters)
        // Left of the display and above the menu-bar-free area: top-left quarter.
        #expect(zoneNumbers(of: resolve(CGPoint(x: -5000, y: 1190), on: grid)) == [1])
        // Over the menu bar strip (inside the screen, above the visible area) at the right edge.
        #expect(zoneNumbers(of: resolve(CGPoint(x: -10, y: 1195), on: grid)) == [2])
        // Below the visible area, right of the display.
        #expect(zoneNumbers(of: resolve(CGPoint(x: 400, y: 20), on: grid)) == [4])
    }

    @Test("without spanning there is no anchor, even when one is passed in")
    func noAnchorWithoutSpanning() {
        let grid = display(quarters)
        #expect(resolve(cursor(0.75, 0.25), on: grid)?.anchor == nil)
        let stale = resolve(cursor(0.75, 0.25), on: grid, spanning: false, anchor: 0)
        #expect(stale?.anchor == nil)
        #expect(zoneNumbers(of: stale) == [4])
    }

    @Test("the preview frame is the zone's frame, as the zone hotkey places it")
    func previewFrameMatchesHotkeyPlacement() throws {
        let gap: CGFloat = 12
        let grid = display(quarters, gap: gap)
        let resolution = try #require(resolve(cursor(0.75, 0.25), on: grid, gap: gap))
        let hotkeyFrame = try #require(ZonePlacement.frame(forZone: 4, of: quarters, visible: visibleFrame, gap: gap))
        #expect(resolution.preview.frame == hotkeyFrame)
    }

    @Test("a non-zero gap insets the preview by half the gap on every side")
    func gapInset() throws {
        let grid = display(twoColumns, gap: 10)
        let resolution = try #require(resolve(cursor(0.25, 0.5), on: grid, gap: 10))
        #expect(resolution.preview.frame == CGRect(x: -1915, y: 105, width: 950, height: 1070))
    }

    @Test("the frame lies on the display with the negative origin")
    func negativeOriginFrame() throws {
        let grid = display(twoColumns)
        let resolution = try #require(resolve(cursor(0.75, 0.5), on: grid))
        #expect(resolution.preview.frame == CGRect(x: -960, y: 100, width: 960, height: 1080))
    }

    @Test("the screen frame and the context frames reach the preview unchanged")
    func passThrough() throws {
        let grid = display(quarters, gap: 8)
        let resolution = try #require(resolve(cursor(0.25, 0.75), on: grid, gap: 8))
        guard case .grid(let target) = resolution.preview.target else {
            Issue.record("expected a grid target")
            return
        }
        #expect(resolution.preview.screenFrame == screenFrame)
        #expect(target.contextFrames == grid.contextFrames)
        #expect(target.contextFrames.count == quarters.count)
    }

    @Test("an empty grid resolves to nothing")
    func emptyGrid() {
        #expect(resolve(cursor(0.5, 0.5), on: display([])) == nil)
        #expect(resolve(cursor(0.5, 0.5), on: display([]), spanning: true, anchor: 0) == nil)
    }
}

@Suite("Grid drag target: shortcut")
struct GridDragTargetShortcutTests {

    @Test("a single zone carries the shortcut the closure returns for its 1-based number")
    func singleZoneShortcut() {
        let grid = display(twoColumns)
        #expect(resolve(cursor(0.25, 0.5), on: grid)?.preview.shortcut == shortcut(forZone: 1))
        #expect(resolve(cursor(0.75, 0.5), on: grid)?.preview.shortcut == shortcut(forZone: 2))
    }

    @Test("a zone without a hotkey gives a preview without a shortcut")
    func zoneTenHasNoShortcut() {
        let columns = (0..<12).map { rect(Double($0) / 12, 0, 1.0 / 12, 1) }
        let grid = display(columns)
        // Zone 10 is the tenth column: its centre is at 9.5 / 12.
        let resolution = resolve(cursor(9.5 / 12, 0.5), on: grid, shortcutForZone: hotkeyForSingleDigitZones)
        #expect(zoneNumbers(of: resolution) == [10])
        #expect(resolution?.preview.shortcut == nil)
        let ninth = resolve(cursor(8.5 / 12, 0.5), on: grid, shortcutForZone: hotkeyForSingleDigitZones)
        #expect(ninth?.preview.shortcut == shortcut(forZone: 9))
    }

    @Test("several zones never carry a shortcut, whatever the closure returns")
    func spanHasNoShortcut() {
        let grid = display(quarters)
        let resolution = resolve(cursor(0.75, 0.25), on: grid, spanning: true, anchor: 0)
        #expect(zoneNumbers(of: resolution) == [1, 2, 3, 4])
        #expect(resolution?.preview.shortcut == nil)
    }

    @Test("a span that grows from one zone to a single zone keeps that zone's shortcut")
    func spanningOverOneZoneKeepsShortcut() {
        let grid = display(quarters)
        let resolution = resolve(cursor(0.25, 0.25), on: grid, spanning: true, anchor: 2)
        #expect(zoneNumbers(of: resolution) == [3])
        #expect(resolution?.preview.shortcut == shortcut(forZone: 3))
    }
}

@Suite("Grid drag target: span")
struct GridDragTargetSpanTests {

    @Test("spanning without a kept anchor starts at the zone under the cursor")
    func anchorAdoptedFromCursor() {
        let grid = display(twoColumns)
        let resolution = resolve(cursor(0.75, 0.5), on: grid, spanning: true, anchor: nil)
        #expect(resolution?.anchor == 1)
        #expect(zoneNumbers(of: resolution) == [2])
    }

    @Test("the kept anchor survives while the cursor moves to another zone")
    func anchorKept() throws {
        let grid = display(twoColumns)
        let resolution = try #require(resolve(cursor(0.75, 0.5), on: grid, spanning: true, anchor: 0))
        #expect(resolution.anchor == 0)
        #expect(zoneNumbers(of: resolution) == [1, 2])
        #expect(resolution.preview.frame == visibleFrame)
    }

    @Test("anchor 1 with the cursor in zone 4 covers all four quarters")
    func quartersCorner() throws {
        let grid = display(quarters)
        let resolution = try #require(resolve(cursor(0.75, 0.25), on: grid, spanning: true, anchor: 0))
        #expect(zoneNumbers(of: resolution) == [1, 2, 3, 4])
        #expect(resolution.preview.frame == visibleFrame)
    }

    @Test("anchor 1 with the cursor in zone 2 covers the top row only")
    func quartersTopRow() throws {
        let grid = display(quarters)
        let resolution = try #require(resolve(cursor(0.75, 0.75), on: grid, spanning: true, anchor: 0))
        #expect(zoneNumbers(of: resolution) == [1, 2])
        #expect(resolution.preview.frame == CGRect(x: -1920, y: 640, width: 1920, height: 540))
    }

    @Test("the span does not depend on which end is the anchor")
    func anchorOrderDoesNotMatter() {
        let grid = display(quarters)
        let forward = resolve(cursor(0.75, 0.25), on: grid, spanning: true, anchor: 0)
        let backward = resolve(cursor(0.25, 0.75), on: grid, spanning: true, anchor: 3)
        #expect(zoneNumbers(of: forward) == zoneNumbers(of: backward))
        #expect(forward?.preview.frame == backward?.preview.frame)
    }

    @Test("on an uneven grid the span grows to whole zones")
    func unevenGridGrowsToWholeZones() throws {
        let grid = display(mainAndTwoSides)
        // Main zone to the upper side zone: the bounding box is the whole display, so the lower side zone joins.
        let resolution = try #require(resolve(cursor(0.75, 0.75), on: grid, spanning: true, anchor: 0))
        #expect(zoneNumbers(of: resolution) == [1, 2, 3])
        #expect(resolution.preview.frame == visibleFrame)
    }

    @Test("on an uneven grid two stacked side zones span only the right half")
    func unevenGridSideZones() throws {
        let grid = display(mainAndTwoSides)
        let resolution = try #require(resolve(cursor(0.75, 0.25), on: grid, spanning: true, anchor: 1))
        #expect(zoneNumbers(of: resolution) == [2, 3])
        #expect(resolution.preview.frame == CGRect(x: -960, y: 100, width: 960, height: 1080))
    }

    @Test("a span frame honours the gap and the display origin")
    func spanFrameWithGap() throws {
        let gap: CGFloat = 16
        let grid = display(quarters, gap: gap)
        let resolution = try #require(resolve(cursor(0.75, 0.25), on: grid, spanning: true, anchor: 2, gap: gap))
        #expect(zoneNumbers(of: resolution) == [3, 4])
        #expect(resolution.preview.frame == CGRect(x: -1912, y: 108, width: 1904, height: 524))
    }

    @Test("the context frames of a span are still every zone of the grid")
    func spanKeepsContextFrames() throws {
        let grid = display(quarters, gap: 4)
        let resolution = try #require(resolve(cursor(0.75, 0.25), on: grid, spanning: true, anchor: 0, gap: 4))
        guard case .grid(let target) = resolution.preview.target else {
            Issue.record("expected a grid target")
            return
        }
        #expect(target.contextFrames == grid.contextFrames)
    }
}
