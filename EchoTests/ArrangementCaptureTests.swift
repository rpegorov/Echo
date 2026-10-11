import CoreGraphics
import Foundation
import Testing
@testable import Echo

private let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
private let halves = GridTemplate.twoColumns.zones

@Suite("Arrangement capture: nearest zone")
struct NearestZoneTests {

    @Test("a window wholly inside a zone picks that zone")
    func insideOneZone() {
        let window = CGRect(x: 600, y: 100, width: 200, height: 200)
        #expect(ArrangementCapture.nearestZone(of: window, visible: visible, zones: halves) == 1)
    }

    @Test("the zone with the larger overlap wins")
    func largerOverlapWins() {
        let window = CGRect(x: 450, y: 0, width: 300, height: 800)
        #expect(ArrangementCapture.nearestZone(of: window, visible: visible, zones: halves) == 1)
    }

    @Test("an equal overlap on a zone boundary goes to the lower index")
    func tieGoesToLowerIndex() {
        let window = CGRect(x: 400, y: 100, width: 200, height: 200)
        #expect(ArrangementCapture.nearestZone(of: window, visible: visible, zones: halves) == 0)
    }

    @Test("a tie is decided by index, not by position")
    func tieFollowsIndexNotPosition() {
        let window = CGRect(x: 400, y: 100, width: 200, height: 200)
        #expect(ArrangementCapture.nearestZone(of: window, visible: visible, zones: Array(halves.reversed())) == 0)
    }

    @Test("a window larger than the screen picks the biggest zone")
    func windowLargerThanScreen() {
        let window = CGRect(x: -500, y: -500, width: 3000, height: 3000)
        let zones = [
            UnitRect(x: 0, y: 0, width: 0.3, height: 1),
            UnitRect(x: 0.3, y: 0, width: 0.7, height: 1)
        ]
        #expect(ArrangementCapture.nearestZone(of: window, visible: visible, zones: zones) == 1)
    }

    @Test("a window larger than the screen over equal zones picks the first")
    func windowLargerThanScreenTie() {
        let window = CGRect(x: -500, y: -500, width: 3000, height: 3000)
        #expect(ArrangementCapture.nearestZone(of: window, visible: visible, zones: halves) == 0)
    }

    @Test("a window outside the visible area has no zone")
    func outsideVisibleArea() {
        let window = CGRect(x: 2000, y: 100, width: 300, height: 300)
        #expect(ArrangementCapture.nearestZone(of: window, visible: visible, zones: halves) == nil)
    }

    @Test("a window over the menu bar strip only has no zone")
    func insideScreenOutsideVisible() {
        let inset = CGRect(x: 0, y: 0, width: 1000, height: 780)
        let window = CGRect(x: 100, y: 780, width: 300, height: 20)
        #expect(ArrangementCapture.nearestZone(of: window, visible: inset, zones: halves) == nil)
    }

    @Test("a window that only touches the visible edge has no zone")
    func edgeContactIsNoOverlap() {
        let window = CGRect(x: 1000, y: 100, width: 300, height: 300)
        #expect(ArrangementCapture.nearestZone(of: window, visible: visible, zones: halves) == nil)
    }

    @Test("an overlap below the unit tolerance does not count")
    func overlapBelowTolerance() {
        let window = CGRect(x: 995, y: 795, width: 100, height: 100)
        #expect(ArrangementCapture.nearestZone(of: window, visible: visible, zones: halves) == 1)
        let sliver = CGRect(x: 999.9, y: 799.9, width: 100, height: 100)
        #expect(ArrangementCapture.nearestZone(of: sliver, visible: visible, zones: halves) == nil)
    }

    @Test("no zones means no zone")
    func emptyZones() {
        let window = CGRect(x: 100, y: 100, width: 200, height: 200)
        #expect(ArrangementCapture.nearestZone(of: window, visible: visible, zones: []) == nil)
    }

    @Test("zones are laid out on a display with negative origin")
    func negativeCoordinates() {
        let second = CGRect(x: -1440, y: 120, width: 1440, height: 900)
        let right = CGRect(x: -600, y: 200, width: 400, height: 300)
        let left = CGRect(x: -1400, y: 200, width: 400, height: 300)
        #expect(ArrangementCapture.nearestZone(of: right, visible: second, zones: halves) == 1)
        #expect(ArrangementCapture.nearestZone(of: left, visible: second, zones: halves) == 0)
    }

    @Test("rows are counted from the bottom edge, as in Cocoa coordinates")
    func rowsGrowUpward() {
        let quarters = GridTemplate.twoByTwo.zones
        let upperRight = CGRect(x: 600, y: 500, width: 300, height: 200)
        let lowerLeft = CGRect(x: 100, y: 100, width: 300, height: 200)
        let upperIndex = ArrangementCapture.nearestZone(of: upperRight, visible: visible, zones: quarters)
        let lowerIndex = ArrangementCapture.nearestZone(of: lowerLeft, visible: visible, zones: quarters)
        #expect(upperIndex.map { quarters[$0] } == UnitRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
        #expect(lowerIndex.map { quarters[$0] } == UnitRect(x: 0, y: 0, width: 0.5, height: 0.5))
    }

    @Test("a window spanning two zones takes the one it covers more")
    func spanningWindowTakesDominantZone() {
        let thirds = GridTemplate.threeColumns.zones
        let window = CGRect(x: 100, y: 0, width: 700, height: 800)
        #expect(ArrangementCapture.nearestZone(of: window, visible: visible, zones: thirds) == 1)
    }
}

@Suite("Arrangement capture: windows to entries")
struct CaptureWindowsTests {

    private let leftHalf = CGRect(x: 50, y: 100, width: 300, height: 300)
    private let rightHalf = CGRect(x: 600, y: 100, width: 300, height: 300)

    private func capture(
        _ windows: [WindowSnapshot], on displays: [DisplaySnapshot] = [snapshotDisplay()]
    ) -> (windows: [ArrangedWindow], displays: [String: SavedDisplay]) {
        let ids = SequentialIDs()
        let captured = ArrangementCapture.capture(windows: windows, displays: displays, makeID: ids.next)
        return (captured.windows, captured.displays)
    }

    @Test("each window becomes an entry with its app, zone rect and display key")
    func entryFields() {
        let result = capture([snapshotWindow("com.apple.Notes", appName: "Notes", title: "Todo", frame: rightHalf)])
        #expect(result.windows.count == 1)
        let entry = result.windows[0]
        #expect(entry.bundleID == "com.apple.Notes")
        #expect(entry.appName == "Notes")
        #expect(entry.titleHint == "Todo")
        #expect(entry.slot == ZoneSlot(display: "uuid:AAAA", rect: halves[1]))
    }

    @Test("the entry keeps the zone rect, not the window frame")
    func slotIsZoneNotFrame() {
        let result = capture([snapshotWindow(frame: leftHalf)])
        #expect(result.windows[0].slot.rect == halves[0])
    }

    @Test("input order is the output order")
    func orderPreserved() {
        let windows = [
            snapshotWindow(title: "c", ordinal: 0, frame: rightHalf),
            snapshotWindow(title: "a", ordinal: 1, frame: leftHalf),
            snapshotWindow(title: "b", ordinal: 2, frame: rightHalf)
        ]
        #expect(capture(windows).windows.map(\.titleHint) == ["c", "a", "b"])
    }

    @Test("ids come from the generator, one per entry")
    func idsFromGenerator() {
        let ids = SequentialIDs()
        let expected = [ids.next(), ids.next()]
        let windows = [snapshotWindow(ordinal: 0, frame: leftHalf), snapshotWindow(ordinal: 1, frame: rightHalf)]
        let result = capture(windows)
        #expect(result.windows.map(\.id) == expected)
    }

    @Test("a window on a display without a key is left out")
    func unkeyedDisplaySkipped() {
        let displays = [snapshotDisplay(key: nil)]
        let result = capture([snapshotWindow(frame: leftHalf)], on: displays)
        #expect(result.windows.isEmpty)
        #expect(result.displays.isEmpty)
    }

    @Test("a window that overlaps no display is left out")
    func offScreenSkipped() {
        let result = capture([snapshotWindow(frame: CGRect(x: 5000, y: 5000, width: 100, height: 100))])
        #expect(result.windows.isEmpty)
    }

    @Test("a window with no zone overlap on its display is left out")
    func noZoneSkipped() {
        let result = capture([snapshotWindow(frame: leftHalf)], on: [snapshotDisplay(zones: [])])
        #expect(result.windows.isEmpty)
        #expect(result.displays.isEmpty)
    }

    @Test("a window over the menu bar only is left out")
    func windowOutsideVisibleFrameSkipped() {
        let display = snapshotDisplay(visible: CGRect(x: 0, y: 0, width: 1000, height: 780))
        let result = capture([snapshotWindow(frame: CGRect(x: 100, y: 780, width: 300, height: 20))], on: [display])
        #expect(result.windows.isEmpty)
    }

    @Test("an empty or blank title gives no hint", arguments: [nil, "", "   ", "\t\n"])
    func blankTitleHasNoHint(title: String?) {
        let result = capture([snapshotWindow(title: title, frame: leftHalf)])
        #expect(result.windows.count == 1)
        #expect(result.windows[0].titleHint == nil)
    }

    @Test("a title with text is kept as the window reported it")
    func titleKeptVerbatim() {
        let result = capture([snapshotWindow(title: " build ", frame: leftHalf)])
        #expect(result.windows[0].titleHint == " build ")
    }

    @Test("displays holds only the displays that received a window")
    func onlyUsedDisplays() {
        let main = snapshotDisplay(key: "uuid:AAAA", name: "Studio Display")
        let side = snapshotDisplay(
            key: "edid:1-2-3", name: "Laptop", frame: CGRect(x: -1440, y: 0, width: 1440, height: 900))
        let result = capture(
            [snapshotWindow(frame: leftHalf), snapshotWindow(ordinal: 1, frame: rightHalf)], on: [main, side])
        #expect(Set(result.displays.keys) == ["uuid:AAAA"])
        #expect(result.displays["uuid:AAAA"] == SavedDisplay(name: "Studio Display", aspect: 1000.0 / 800.0))
    }

    @Test("windows on two displays reference both, named and proportioned from the snapshot")
    func bothDisplaysReferenced() {
        let main = snapshotDisplay(key: "uuid:AAAA", name: "Studio Display")
        let laptopFrame = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        let side = snapshotDisplay(key: "edid:1-2-3", name: "Laptop", frame: laptopFrame)
        let onLaptop = CGRect(x: -700, y: 100, width: 300, height: 300)
        let result = capture(
            [snapshotWindow(frame: leftHalf), snapshotWindow(ordinal: 1, frame: onLaptop)], on: [main, side])
        #expect(result.windows.map(\.slot.display) == ["uuid:AAAA", "edid:1-2-3"])
        #expect(result.windows[1].slot.rect == halves[1])
        #expect(result.displays == [
            "uuid:AAAA": SavedDisplay(name: "Studio Display", aspect: 1.25),
            "edid:1-2-3": SavedDisplay(name: "Laptop", aspect: 1.6)
        ])
    }

    @Test("a window between two displays belongs to the one it overlaps most")
    func straddlingWindowTakesLargerDisplay() {
        let main = snapshotDisplay(key: "uuid:AAAA")
        let side = snapshotDisplay(
            key: "edid:1-2-3", name: "Laptop", frame: CGRect(x: -1000, y: 0, width: 1000, height: 800))
        let window = snapshotWindow(frame: CGRect(x: -100, y: 100, width: 400, height: 300))
        let result = capture([window], on: [main, side])
        #expect(result.windows.map(\.slot.display) == ["uuid:AAAA"])
    }

    @Test("the visible frame, not the full frame, positions the zones")
    func zonesUseVisibleFrame() {
        let display = snapshotDisplay(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800), visible: CGRect(x: 400, y: 0, width: 600, height: 800))
        let window = snapshotWindow(frame: CGRect(x: 420, y: 100, width: 100, height: 100))
        let result = capture([window], on: [display])
        #expect(result.windows.map(\.slot.rect) == [halves[0]])
        #expect(result.displays["uuid:AAAA"]?.aspect == 600.0 / 800.0)
    }

    @Test("nothing to capture gives an empty result")
    func emptyInput() {
        let result = capture([])
        #expect(result.windows.isEmpty)
        #expect(result.displays.isEmpty)
    }

    @Test("a captured slot is a valid slot")
    func capturedSlotsAreValid() {
        let result = capture([snapshotWindow(frame: leftHalf), snapshotWindow(ordinal: 1, frame: rightHalf)])
        #expect(result.windows.allSatisfy { $0.slot.isValid })
    }
}
