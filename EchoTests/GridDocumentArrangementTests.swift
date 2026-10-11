import CoreGraphics
import Foundation
import Testing
@testable import Echo

private let tolerance = GridEditing.tolerance

private func document(
    arrangements: [Arrangement]? = nil, rules: [AutoRule]? = nil
) -> GridDocument {
    GridDocument(grids: [], activeByDisplay: [:], arrangements: arrangements, autoRules: rules)
}

@Suite("Grid document arrangements and rules")
struct GridDocumentArrangementTests {

    // MARK: Arrangements

    @Test("saving into a version 1 document creates the list")
    func firstArrangementIsAppended() {
        var doc = GridDocument.empty
        let arrangement = fixtureArrangement()

        doc.saveArrangement(arrangement)

        #expect(doc.savedArrangements == [arrangement])
    }

    @Test("saving an arrangement with a known id replaces it in place")
    func sameIdReplacesInPlace() {
        let first = fixtureArrangement(name: "First")
        let second = fixtureArrangement(name: "Second")
        var doc = document(arrangements: [first, second])
        var renamed = first
        renamed.name = "Renamed"

        doc.saveArrangement(renamed)

        #expect(doc.savedArrangements.map(\.name) == ["Renamed", "Second"])
        #expect(doc.savedArrangements.map(\.id) == [first.id, second.id])
    }

    @Test("a new id is appended after the existing arrangements")
    func newIdIsAppended() {
        let first = fixtureArrangement(name: "First")
        var doc = document(arrangements: [first])

        doc.saveArrangement(fixtureArrangement(name: "Second"))

        #expect(doc.savedArrangements.map(\.name) == ["First", "Second"])
    }

    @Test("deleting an arrangement removes only that one")
    func deleteRemovesOnlyThatArrangement() {
        let kept = fixtureArrangement(name: "Kept")
        let gone = fixtureArrangement(name: "Gone")
        var doc = document(arrangements: [gone, kept], rules: [fixtureRule()])

        doc.deleteArrangement(gone.id)

        #expect(doc.savedArrangements == [kept])
        #expect(doc.rules.count == 1)
    }

    @Test("deleting an unknown arrangement changes nothing")
    func deleteUnknownArrangementIsNoOp() {
        let only = fixtureArrangement()
        var doc = document(arrangements: [only])

        doc.deleteArrangement(UUID())

        #expect(doc == document(arrangements: [only]))
    }

    @Test("an arrangement is a snapshot of rects: editing or deleting a grid leaves it as it was")
    func gridChangesDoNotMoveArrangements() {
        let grid = ZoneGrid(id: UUID(), name: "Thirds", zones: GridTemplate.threeColumns.zones)
        let arrangement = fixtureArrangement()
        let rule = fixtureRule()
        var doc = document(arrangements: [arrangement], rules: [rule])
        doc.save(grid)
        doc.setActive(.saved(id: grid.id), for: DisplayKey(rawValue: "uuid:AAAA"))

        var edited = grid
        edited.zones = GridTemplate.twoColumns.zones
        doc.save(edited)
        doc.delete(grid.id)

        #expect(doc.savedArrangements == [arrangement])
        #expect(doc.rules == [rule])
    }

    // MARK: Rules

    @Test("saving a rule appends it")
    func ruleIsAppended() {
        var doc = GridDocument.empty
        let rule = fixtureRule()

        doc.saveRule(rule)

        #expect(doc.rules == [rule])
    }

    @Test("a rule for an app that already has one replaces it, whatever its id")
    func sameBundleReplacesRule() {
        let old = fixtureRule(bundleID: "com.apple.Safari")
        let other = fixtureRule(bundleID: "com.apple.Notes", appName: "Notes")
        var doc = document(rules: [old, other])
        let replacement = fixtureRule(bundleID: "com.apple.Safari", slot: fixtureSlot("uuid:AAAA", 0, 0, 0.5, 1))

        doc.saveRule(replacement)

        #expect(doc.rules.count == 2)
        #expect(doc.rules.contains(replacement))
        #expect(!doc.rules.contains(old))
        #expect(doc.rules.contains(other))
        #expect(doc.rules.filter { $0.bundleID == "com.apple.Safari" }.count == 1)
    }

    @Test("a rule with a known id replaces that rule, even for another app")
    func sameIdReplacesRule() {
        let old = fixtureRule(bundleID: "com.apple.Safari")
        var doc = document(rules: [old])
        let moved = AutoRule(
            id: old.id, bundleID: "com.apple.Notes", appName: "Notes", slot: old.slot,
            display: old.display, isEnabled: old.isEnabled)

        doc.saveRule(moved)

        #expect(doc.rules == [moved])
    }

    @Test("rules of different apps and ids sit side by side")
    func differentAppsKeepSeparateRules() {
        var doc = GridDocument.empty

        doc.saveRule(fixtureRule(bundleID: "com.apple.Safari"))
        doc.saveRule(fixtureRule(bundleID: "com.apple.Notes", appName: "Notes"))

        #expect(Set(doc.rules.map(\.bundleID)) == ["com.apple.Safari", "com.apple.Notes"])
    }

    @Test("rule(forBundleID:) finds the app's rule and nothing for another app")
    func ruleLookup() {
        let safari = fixtureRule(bundleID: "com.apple.Safari")
        let doc = document(rules: [safari])

        #expect(doc.rule(forBundleID: "com.apple.Safari") == safari)
        #expect(doc.rule(forBundleID: "com.apple.Notes") == nil)
        #expect(GridDocument.empty.rule(forBundleID: "com.apple.Safari") == nil)
    }

    @Test("deleting a rule removes only that rule")
    func deleteRule() {
        let safari = fixtureRule(bundleID: "com.apple.Safari")
        let notes = fixtureRule(bundleID: "com.apple.Notes", appName: "Notes")
        var doc = document(rules: [safari, notes])

        doc.deleteRule(safari.id)
        doc.deleteRule(UUID())

        #expect(doc.rules == [notes])
    }

    @Test("switching a rule changes only its flag")
    func setRuleEnabledChangesOnlyTheFlag() {
        let safari = fixtureRule(bundleID: "com.apple.Safari", isEnabled: true)
        let notes = fixtureRule(bundleID: "com.apple.Notes", appName: "Notes", isEnabled: true)
        var doc = document(rules: [safari, notes])

        doc.setRuleEnabled(safari.id, false)

        #expect(doc.rule(forBundleID: "com.apple.Safari")?.isEnabled == false)
        #expect(doc.rule(forBundleID: "com.apple.Safari")?.slot == safari.slot)
        #expect(doc.rule(forBundleID: "com.apple.Notes") == notes)

        doc.setRuleEnabled(safari.id, true)
        #expect(doc.rule(forBundleID: "com.apple.Safari") == safari)
    }

    @Test("switching an unknown rule changes nothing")
    func setRuleEnabledUnknownIsNoOp() {
        let safari = fixtureRule()
        var doc = document(rules: [safari])

        doc.setRuleEnabled(UUID(), false)

        #expect(doc == document(rules: [safari]))
    }
}

@Suite("Zone slot")
struct ZoneSlotTests {

    private func slot(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> ZoneSlot {
        fixtureSlot("uuid:AAAA", x, y, width, height)
    }

    @Test("rects inside the unit square are valid",
          arguments: [(0.0, 0.0, 1.0, 1.0), (0.5, 0.0, 0.5, 1.0), (0.25, 0.25, 0.5, 0.5), (0.0, 0.5, 1.0, 0.5)])
    func insideIsValid(x: Double, y: Double, width: Double, height: Double) {
        #expect(slot(x, y, width, height).isValid)
    }

    @Test("the edges are valid within the tolerance and invalid beyond it")
    func toleranceBoundaries() {
        #expect(slot(-tolerance / 2, 0, 0.5, 1).isValid)
        #expect(slot(0, -tolerance / 2, 0.5, 1).isValid)
        #expect(slot(0.5, 0, 0.5 + tolerance / 2, 1).isValid)
        #expect(slot(0, 0.5, 1, 0.5 + tolerance / 2).isValid)

        #expect(!slot(-2 * tolerance, 0, 0.5, 1).isValid)
        #expect(!slot(0, -2 * tolerance, 0.5, 1).isValid)
        #expect(!slot(0.5, 0, 0.5 + 2 * tolerance, 1).isValid)
        #expect(!slot(0, 0.5, 1, 0.5 + 2 * tolerance).isValid)
    }

    @Test("a rect without area is invalid",
          arguments: [(0.0, 0.0, 0.0, 1.0), (0.0, 0.0, 1.0, 0.0), (0.0, 0.0, tolerance / 2, 1.0), (0.0, 0.0, 1.0, tolerance / 2),
                      (0.5, 0.5, -0.1, 0.2), (0.5, 0.5, 0.2, -0.1)])
    func degenerateIsInvalid(x: Double, y: Double, width: Double, height: Double) {
        #expect(!slot(x, y, width, height).isValid)
    }

    @Test("a rect outside the unit square is invalid",
          arguments: [(1.2, 0.0, 0.5, 1.0), (0.0, 1.2, 0.5, 0.5), (-0.1, 0.0, 0.5, 1.0), (0.6, 0.0, 0.5, 1.0), (0.0, 0.6, 1.0, 0.5)])
    func outsideIsInvalid(x: Double, y: Double, width: Double, height: Double) {
        #expect(!slot(x, y, width, height).isValid)
    }
}

@Suite("Slot placement")
struct SlotPlacementTests {

    private let laptop = DisplaySnapshot(
        key: DisplayKey(rawValue: "edid:1-2-3"), name: "Laptop",
        frame: CGRect(x: 0, y: 0, width: 1500, height: 1000),
        visibleFrame: CGRect(x: 0, y: 0, width: 1500, height: 960), zones: [])
    private let studio = DisplaySnapshot(
        key: DisplayKey(rawValue: "uuid:AAAA"), name: "Studio Display",
        frame: CGRect(x: 1500, y: -100, width: 1600, height: 1000),
        visibleFrame: CGRect(x: 1500, y: -50, width: 1600, height: 900), zones: [])

    @Test("the frame is the slot's rect inside the visible area of the display with that key")
    func frameOnTheNamedDisplay() {
        let slot = fixtureSlot("uuid:AAAA", 0.5, 0, 0.5, 1)

        let frame = SlotPlacement.frame(for: slot, displays: [laptop, studio], gap: 8)

        #expect(frame == CGRect(x: 2304, y: -46, width: 792, height: 892))
    }

    @Test("without a gap the frame is the exact fraction of the visible area")
    func frameWithoutGap() {
        let slot = fixtureSlot("edid:1-2-3", 0, 0.5, 0.5, 0.5)

        #expect(SlotPlacement.frame(for: slot, displays: [laptop, studio], gap: 0)
                == CGRect(x: 0, y: 480, width: 750, height: 480))
    }

    @Test("a slot on a display that is not connected has no frame")
    func disconnectedDisplayHasNoFrame() {
        let slot = fixtureSlot("uuid:GONE", 0, 0, 1, 1)

        #expect(SlotPlacement.frame(for: slot, displays: [laptop, studio], gap: 8) == nil)
        #expect(SlotPlacement.frame(for: slot, displays: [], gap: 8) == nil)
    }

    @Test("a display without a key never matches a slot")
    func displayWithoutKeyIsSkipped() {
        let unkeyed = DisplaySnapshot(
            key: nil, name: "Unknown", frame: laptop.frame, visibleFrame: laptop.visibleFrame, zones: [])

        #expect(SlotPlacement.frame(for: fixtureSlot("uuid:AAAA"), displays: [unkeyed], gap: 0) == nil)
    }
}
