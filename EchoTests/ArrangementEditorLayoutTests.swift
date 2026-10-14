import CoreGraphics
import Foundation
import Testing
@testable import Echo

struct ArrangementCanvasHeightTests {
    private func height(
        _ available: CGSize, _ aspects: [Double],
        spacing: CGFloat = 0, caption: CGFloat = 0, captionSpacing: CGFloat = 0
    ) -> CGFloat {
        ArrangementEditorLayout.canvasHeight(
            available: available, aspects: aspects, spacing: spacing,
            captionHeight: caption, captionSpacing: captionSpacing)
    }

    @Test func singleCanvasIsLimitedByWidthWhenTheAreaIsTall() {
        #expect(abs(height(CGSize(width: 400, height: 900), [2]) - 200) < 1e-9)
    }

    @Test func singleCanvasIsLimitedByHeightLeavingRoomForTheCaption() {
        let result = height(CGSize(width: 900, height: 120), [2], caption: 20, captionSpacing: 4)
        #expect(abs(result - 96) < 1e-9)
    }

    @Test func displaysShareOneRowSoWidthIsDividedByTheSumOfAspects() {
        let result = height(CGSize(width: 420, height: 900), [1.6, 2.4], spacing: 20)
        #expect(abs(result - 100) < 1e-9)
    }

    @Test func rowNeverExceedsTheAvailableWidth() {
        let available = CGSize(width: 700, height: 500)
        let aspects = [1.6, 2.4, 1.0]
        let canvas = height(available, aspects, spacing: 16, caption: 18, captionSpacing: 6)
        let rowWidth = aspects.reduce(0) { $0 + CGFloat($1) * canvas } + 16 * CGFloat(aspects.count - 1)
        #expect(rowWidth <= available.width + 1e-9)
        #expect(canvas + 18 + 6 <= available.height + 1e-9)
    }

    @Test func noDisplaysOrNoUsableAspectGivesZero() {
        #expect(height(CGSize(width: 400, height: 400), []) == 0)
        #expect(height(CGSize(width: 400, height: 400), [0]) == 0)
    }

    @Test func tooSmallAreaClampsToZeroNotNegative() {
        #expect(height(CGSize(width: 10, height: 400), [1.6, 1.6], spacing: 20) == 0)
        #expect(height(CGSize(width: 400, height: 10), [1.6], caption: 20, captionSpacing: 4) == 0)
    }
}

struct ArrangementSlotGroupTests {
    private let zones = GridTemplate.threeColumns.zones

    private func window(_ display: String, _ zone: UnitRect) -> ArrangedWindow {
        fixtureWindow(slot: ZoneSlot(display: display, rect: zone))
    }

    @Test func windowsOfOneSlotShareAGroupInArrivalOrder() {
        let first = window("uuid:AAAA", zones[1])
        let other = window("uuid:AAAA", zones[0])
        let second = window("uuid:AAAA", zones[1])
        let groups = ArrangementEditorLayout.groups(of: [first, other, second], on: "uuid:AAAA", zones: zones)
        #expect(groups.map(\.windowIDs) == [[first.id, second.id], [other.id]])
        #expect(groups.map(\.zoneIndex) == [1, 0])
    }

    @Test func otherDisplaysAreLeftOut() {
        let mine = window("uuid:AAAA", zones[0])
        let theirs = window("uuid:BBBB", zones[0])
        let groups = ArrangementEditorLayout.groups(of: [theirs, mine], on: "uuid:AAAA", zones: zones)
        #expect(groups.flatMap(\.windowIDs) == [mine.id])
    }

    @Test func slotOutsideTheGridHasNoZoneIndexButKeepsItsRect() {
        let rect = UnitRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)
        let stray = window("uuid:AAAA", rect)
        let groups = ArrangementEditorLayout.groups(of: [stray], on: "uuid:AAAA", zones: zones)
        #expect(groups == [ArrangementSlotGroup(rect: rect, zoneIndex: nil, windowIDs: [stray.id])])
    }

    @Test func slotsEqualWithinToleranceMergeIntoOneGroup() {
        let zone = zones[2]
        let nudged = UnitRect(x: zone.x + GridEditing.tolerance / 2, y: zone.y, width: zone.width, height: zone.height)
        let first = window("uuid:AAAA", zone)
        let second = window("uuid:AAAA", nudged)
        let groups = ArrangementEditorLayout.groups(of: [first, second], on: "uuid:AAAA", zones: zones)
        #expect(groups.count == 1)
        #expect(groups.first?.windowIDs == [first.id, second.id])
    }

    @Test func slotsDifferingBeyondToleranceStaySeparate() {
        let zone = zones[2]
        let shifted = UnitRect(
            x: zone.x + GridEditing.tolerance * 10, y: zone.y, width: zone.width, height: zone.height)
        let groups = ArrangementEditorLayout.groups(
            of: [window("uuid:AAAA", zone), window("uuid:AAAA", shifted)], on: "uuid:AAAA", zones: zones)
        #expect(groups.count == 2)
    }

    @Test func noWindowsOnTheDisplayGivesNoGroups() {
        #expect(ArrangementEditorLayout.groups(of: [], on: "uuid:AAAA", zones: zones).isEmpty)
    }
}

struct ArrangementIconGridTests {
    private func grid(_ count: Int, _ width: CGFloat, _ height: CGFloat, spacing: CGFloat = 4) -> ArrangementIconGrid {
        ArrangementEditorLayout.iconGrid(
            count: count, in: CGSize(width: width, height: height), spacing: spacing, maxSize: 64, minSize: 16)
    }

    @Test func noIconsDrawNothing() {
        let result = grid(0, 100, 100)
        #expect(result.visible == 0 && result.totalCount == 0)
        #expect(!result.overflow && result.cellCount == 0)
    }

    @Test func aSingleIconIsCappedAtTheMaximumSize() {
        let result = grid(1, 500, 500)
        #expect(result.iconSize == 64)
        #expect(result.columns == 1)
        #expect(!result.overflow)
    }

    @Test func fourIconsInASquareSitInTwoByTwo() {
        let result = grid(4, 100, 100, spacing: 0)
        #expect(result.columns == 2)
        #expect(abs(result.iconSize - 50) < 1e-9)
        #expect(result.visible == 4 && !result.overflow)
    }

    @Test func iconsInAWideStripSitInOneRow() {
        let result = grid(3, 300, 40, spacing: 0)
        #expect(result.columns == 3)
        #expect(abs(result.iconSize - 40) < 1e-9)
    }

    @Test func iconsInATallStripSitInOneColumn() {
        let result = grid(3, 40, 300, spacing: 0)
        #expect(result.columns == 1)
        #expect(abs(result.iconSize - 40) < 1e-9)
    }

    @Test func iconsThatFitExactlyAtTheMinimumSizeAreNotCollapsed() {
        let result = grid(2, 36, 16)
        #expect(result.visible == 2 && !result.overflow)
        #expect(abs(result.iconSize - 16) < 1e-9)
    }

    @Test func tooManyIconsShowWhatFitsAndOnePlusNCell() {
        let result = grid(10, 40, 40)
        #expect(result.iconSize == 16)
        #expect(result.columns == 2)
        #expect(result.visible == 3)
        #expect(result.hidden == 7)
        #expect(result.overflow)
        #expect(result.cellCount == 4)
    }

    @Test func plusNCellStaysInsideTheSlotWheneverTheSlotHoldsAnyCell() {
        for count in [2, 5, 12, 40] {
            for side in [20.0, 40.0, 60.0, 90.0] {
                let result = grid(count, CGFloat(side), CGFloat(side))
                guard result.overflow else { continue }
                let columns = result.columns
                let rows = Int(((CGFloat(side) + 4) / (16 + 4)).rounded(.down))
                #expect(result.cellCount <= columns * rows, "count \(count), side \(side)")
                #expect(result.visible + result.hidden == count)
            }
        }
    }

    @Test func nonOverflowingGridFitsEveryIconInsideTheArea() {
        for count in 1...12 {
            let area = CGSize(width: 150, height: 90)
            let result = ArrangementEditorLayout.iconGrid(count: count, in: area, spacing: 4, maxSize: 64, minSize: 16)
            guard !result.overflow else { continue }
            let rows = (count + result.columns - 1) / result.columns
            let usedWidth = CGFloat(result.columns) * result.iconSize + CGFloat(result.columns - 1) * 4
            let usedHeight = CGFloat(rows) * result.iconSize + CGFloat(rows - 1) * 4
            #expect(usedWidth <= area.width + 1e-9 && usedHeight <= area.height + 1e-9, "count \(count)")
            #expect(result.iconSize >= 16 && result.iconSize <= 64)
        }
    }
}

struct ArrangementEditorDisplayResolveTests {
    private let zones = GridTemplate.twoColumns.zones

    private func snapshot(
        _ key: String?, _ name: String, width: Double = 1600, height: Double = 1000
    ) -> DisplaySnapshot {
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        return DisplaySnapshot(
            key: key.map { DisplayKey(rawValue: $0) }, name: name, frame: frame, visibleFrame: frame, zones: zones)
    }

    private func resolve(
        saved: [String: SavedDisplay], connected: [DisplaySnapshot],
        zonesForDisconnected: @escaping (String, Double) -> [UnitRect] = { _, _ in [] }
    ) -> (shown: [ArrangementEditorDisplay], targets: [ArrangementEditorDisplay]) {
        ArrangementEditorDisplay.resolve(
            saved: saved, connected: connected,
            disconnectedReferenceWidth: 1440, zonesForDisconnected: zonesForDisconnected)
    }

    @Test func shownAreTheSavedDisplaysAndTargetsAddEveryKeyedConnectedOne() {
        let result = resolve(
            saved: ["uuid:AAAA": SavedDisplay(name: "Studio", aspect: 1.6)],
            connected: [snapshot("uuid:AAAA", "Studio"), snapshot("uuid:BBBB", "Laptop")])
        #expect(result.shown.map(\.key) == ["uuid:AAAA"])
        #expect(result.targets.map(\.key) == ["uuid:AAAA", "uuid:BBBB"])
    }

    @Test func connectedDisplaysUseLiveDataNotTheSavedCopy() throws {
        let result = resolve(
            saved: ["uuid:AAAA": SavedDisplay(name: "Old name", aspect: 1.0)],
            connected: [snapshot("uuid:AAAA", "Studio", width: 3200, height: 1000)])
        let display = try #require(result.shown.first)
        #expect(display.isConnected)
        #expect(display.name == "Studio")
        #expect(abs(display.aspect - 3.2) < 1e-9)
        #expect(display.referenceWidth == 3200)
        #expect(display.zones == zones)
    }

    @Test func absentDisplayIsDisconnectedWithSavedProportionsAndItsOwnZones() throws {
        var asked: [(String, Double)] = []
        let result = resolve(
            saved: ["uuid:GONE": SavedDisplay(name: "Dell", aspect: 2.4)],
            connected: [snapshot("uuid:AAAA", "Studio")],
            zonesForDisconnected: { key, aspect in
                asked.append((key, aspect))
                return GridTemplate.threeColumns.zones
            })
        let display = try #require(result.shown.first)
        #expect(!display.isConnected)
        #expect(display.name == "Dell")
        #expect(display.aspect == 2.4)
        #expect(display.referenceWidth == 1440)
        #expect(display.zones == GridTemplate.threeColumns.zones)
        #expect(asked.count == 1 && asked[0].0 == "uuid:GONE" && asked[0].1 == 2.4)
        #expect(result.targets.map(\.key) == ["uuid:AAAA", "uuid:GONE"])
    }

    @Test func connectedDisplaysComeFirstInSystemOrderThenAbsentOnesByName() {
        let result = resolve(
            saved: [
                "uuid:Z": SavedDisplay(name: "Alpha", aspect: 1.6),
                "uuid:Y": SavedDisplay(name: "Beta", aspect: 1.6),
                "uuid:X": SavedDisplay(name: "Beta", aspect: 1.6)
            ],
            connected: [snapshot("uuid:B", "Second"), snapshot("uuid:A", "First")])
        #expect(result.targets.map(\.key) == ["uuid:B", "uuid:A", "uuid:Z", "uuid:X", "uuid:Y"])
    }

    @Test func connectedDisplayWithoutAKeyCannotBeATarget() {
        let result = resolve(saved: [:], connected: [snapshot(nil, "Mystery"), snapshot("uuid:AAAA", "Studio")])
        #expect(result.targets.map(\.key) == ["uuid:AAAA"])
        #expect(result.shown.isEmpty)
    }

    @Test func savedDisplayRoundTripsThroughTheEditorDisplay() {
        let display = ArrangementEditorDisplay(
            key: "uuid:AAAA", name: "Studio", aspect: 1.6, referenceWidth: 1600, isConnected: true, zones: zones)
        #expect(display.saved == SavedDisplay(name: "Studio", aspect: 1.6))
        #expect(display.id == "uuid:AAAA")
    }
}
