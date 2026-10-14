import CoreGraphics
import Foundation
import Testing
@testable import Echo

private func windows(_ bundleIDs: [String]) -> [ArrangedWindow] {
    bundleIDs.map { fixtureWindow(bundleID: $0, appName: $0) }
}

struct ArrangementIconSummaryTests {
    @Test func keepsFirstAppearanceOrderAndCollapsesRepeats() {
        let summary = ArrangementPresentation.iconSummary(of: windows(["b", "a", "b", "c", "a"]), limit: 5)
        #expect(summary.bundleIDs == ["b", "a", "c"])
        #expect(summary.overflow == 0)
    }

    @Test func countsOnlyHiddenAppsNotHiddenWindows() {
        let summary = ArrangementPresentation.iconSummary(of: windows(["a", "a", "a", "b", "c", "c", "d"]), limit: 2)
        #expect(summary.bundleIDs == ["a", "b"])
        #expect(summary.overflow == 2)
    }

    @Test func exactlyLimitAppsHaveNoOverflowAndOneMoreHasOne() {
        let atLimit = ArrangementPresentation.iconSummary(of: windows(["a", "b", "c"]), limit: 3)
        #expect(atLimit.overflow == 0)
        let over = ArrangementPresentation.iconSummary(of: windows(["a", "b", "c", "d"]), limit: 3)
        #expect(over.bundleIDs == ["a", "b", "c"])
        #expect(over.overflow == 1)
    }

    @Test func emptyArrangementHasNoIcons() {
        let summary = ArrangementPresentation.iconSummary(of: [], limit: 4)
        #expect(summary == ArrangementPresentation.IconSummary(bundleIDs: [], overflow: 0))
    }

    @Test func zeroLimitHidesEveryApp() {
        let summary = ArrangementPresentation.iconSummary(of: windows(["a", "b"]), limit: 0)
        #expect(summary.bundleIDs.isEmpty)
        #expect(summary.overflow == 2)
    }
}

struct ArrangementSlotLabelTests {
    private let zones = GridTemplate.threeColumns.zones

    @Test func zonesAreNumberedFromOneInGridOrder() {
        for (index, zone) in zones.enumerated() {
            let slot = ZoneSlot(display: "uuid:AAAA", rect: zone)
            #expect(ArrangementPresentation.label(for: slot, zones: zones) == .zone(index + 1))
        }
    }

    @Test func slotWithinToleranceStillReadsAsTheZone() {
        let nudge = GridEditing.tolerance / 2
        let zone = zones[1]
        let rect = UnitRect(
            x: zone.x + nudge, y: zone.y - nudge, width: zone.width - nudge, height: zone.height + nudge
        )
        #expect(ArrangementPresentation.label(for: ZoneSlot(display: "uuid:AAAA", rect: rect), zones: zones)
            == .zone(2))
    }

    @Test func slotBeyondToleranceIsACustomArea() {
        let zone = zones[1]
        let rect = UnitRect(x: zone.x + GridEditing.tolerance * 10, y: zone.y, width: zone.width, height: zone.height)
        #expect(ArrangementPresentation.label(for: ZoneSlot(display: "uuid:AAAA", rect: rect), zones: zones)
            == .customArea)
    }

    @Test func slotMatchingNoZoneOrAnEmptyGridIsACustomArea() {
        let half = ZoneSlot(display: "uuid:AAAA", rect: UnitRect(x: 0, y: 0, width: 0.5, height: 1))
        #expect(ArrangementPresentation.label(for: half, zones: zones) == .customArea)
        #expect(ArrangementPresentation.label(for: half, zones: []) == .customArea)
    }

    @Test func slotDiffersInOneEdgeOnlyIsNotTheZone() {
        let zone = zones[0]
        for rect in [
            UnitRect(x: zone.x, y: zone.y, width: zone.width, height: zone.height / 2),
            UnitRect(x: zone.x, y: zone.y + 0.1, width: zone.width, height: zone.height),
            UnitRect(x: zone.x, y: zone.y, width: zone.width * 2, height: zone.height)
        ] {
            #expect(
                ArrangementPresentation.label(for: ZoneSlot(display: "uuid:AAAA", rect: rect), zones: zones)
                    == .customArea)
        }
    }
}

struct ArrangementDefaultNameTests {
    private func name(_ number: Int) -> String { "Arrangement \(number)" }

    @Test func firstArrangementGetsNumberOne() {
        #expect(ArrangementPresentation.defaultNameNumber(existingNames: [], count: 0, nameFor: name) == 1)
    }

    @Test func numberFollowsTheCount() {
        let names = [name(1), name(2)]
        #expect(ArrangementPresentation.defaultNameNumber(existingNames: names, count: 2, nameFor: name) == 3)
    }

    @Test func skipsNumbersAlreadyUsedAfterTheCount() {
        let names = ["Work", name(2), name(3)]
        #expect(ArrangementPresentation.defaultNameNumber(existingNames: names, count: 1, nameFor: name) == 4)
    }

    @Test func aFreeGapBelowTheCountIsNotReused() {
        let names = [name(2), "Work", "Review"]
        #expect(ArrangementPresentation.defaultNameNumber(existingNames: names, count: 3, nameFor: name) == 4)
    }

    @Test func userNamesNeverBlockTheNumber() {
        let names = ["Work", "Review"]
        #expect(ArrangementPresentation.defaultNameNumber(existingNames: names, count: 2, nameFor: name) == 3)
    }
}

struct ArrangementThumbnailSizeTests {
    private let fallback = CGSize(width: 16, height: 10)

    @Test func wideDisplayFillsTheWidth() {
        let size = ArrangementPresentation.fittedSize(
            visible: CGSize(width: 1600, height: 900), in: CGSize(width: 160, height: 160), fallback: fallback)
        #expect(abs(size.width - 160) < 1e-9)
        #expect(abs(size.height - 90) < 1e-9)
    }

    @Test func tallDisplayFillsTheHeight() {
        let size = ArrangementPresentation.fittedSize(
            visible: CGSize(width: 900, height: 1600), in: CGSize(width: 160, height: 160), fallback: fallback)
        #expect(abs(size.width - 90) < 1e-9)
        #expect(abs(size.height - 160) < 1e-9)
    }

    @Test func smallDisplayIsScaledUpToTheBounds() {
        let size = ArrangementPresentation.fittedSize(
            visible: CGSize(width: 100, height: 50), in: CGSize(width: 400, height: 400), fallback: fallback)
        #expect(abs(size.width - 400) < 1e-9)
        #expect(abs(size.height - 200) < 1e-9)
    }

    @Test func degenerateVisibleAreaUsesTheFallbackProportions() {
        for visible in [CGSize.zero, CGSize(width: 0, height: 900), CGSize(width: 1600, height: 0)] {
            let size = ArrangementPresentation.fittedSize(
                visible: visible, in: CGSize(width: 160, height: 160), fallback: fallback)
            #expect(abs(size.width - 160) < 1e-9)
            #expect(abs(size.height - 100) < 1e-9)
        }
    }

    @Test func resultFitsTheBoundsAndKeepsTheProportions() {
        let bounds = CGSize(width: 120, height: 80)
        for visible in [
            CGSize(width: 1440, height: 900), CGSize(width: 3440, height: 1440), CGSize(width: 800, height: 1200)
        ] {
            let size = ArrangementPresentation.fittedSize(visible: visible, in: bounds, fallback: fallback)
            #expect(size.width <= bounds.width + 1e-9 && size.height <= bounds.height + 1e-9)
            #expect(abs(size.width / size.height - visible.width / visible.height) < 1e-9)
            #expect(abs(size.width - bounds.width) < 1e-9 || abs(size.height - bounds.height) < 1e-9)
        }
    }
}

struct ArrangementNameInputTests {
    @Test func blankNamesAreRejected() {
        #expect(ArrangementPresentation.trimmedName("") == nil)
        #expect(ArrangementPresentation.trimmedName("  \n\t ") == nil)
    }

    @Test func surroundingWhitespaceIsTrimmedAndInnerKept() {
        #expect(ArrangementPresentation.trimmedName("  Deep  work \n") == "Deep  work")
    }
}
