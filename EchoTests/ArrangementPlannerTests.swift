import CoreGraphics
import Foundation
import Testing
@testable import Echo

private let terminal = "com.apple.Terminal"
private let safari = "com.apple.Safari"
private let notes = "com.apple.Notes"

private let mainDisplay = snapshotDisplay(key: "uuid:AAAA", name: "Studio Display")
private let sideDisplay = snapshotDisplay(
    key: "edid:1-2-3", name: "Laptop", frame: CGRect(x: -1440, y: 120, width: 1440, height: 900))

private func entry(
    _ bundleID: String = terminal, _ appName: String = "Terminal", hint: String? = nil,
    slot: ZoneSlot = fixtureSlot()
) -> ArrangedWindow {
    fixtureWindow(bundleID: bundleID, appName: appName, titleHint: hint, slot: slot)
}

private func plan(
    _ entries: [ArrangedWindow], windows: [WindowSnapshot], running: Set<String>? = nil,
    displays: [DisplaySnapshot] = [mainDisplay], gap: CGFloat = 0
) -> ArrangementPlan {
    ArrangementPlanner.plan(
        fixtureArrangement(windows: entries), windows: windows,
        running: running ?? Set(windows.map(\.bundleID)), displays: displays, gap: gap)
}

@Suite("Arrangement planner")
struct ArrangementPlannerTests {

    @Test("each window goes to the frame of its slot")
    func movesUseSlotFrames() {
        let entries = [entry(slot: fixtureSlot("uuid:AAAA", 0, 0, 0.5, 1)), entry(slot: fixtureSlot("uuid:AAAA", 0.5, 0, 0.5, 1))]
        let windows = [snapshotWindow(ordinal: 0), snapshotWindow(ordinal: 1)]
        let result = plan(entries, windows: windows)
        #expect(result.moves == [
            PlannedMove(ref: windows[0].ref, frame: CGRect(x: 0, y: 0, width: 500, height: 800)),
            PlannedMove(ref: windows[1].ref, frame: CGRect(x: 500, y: 0, width: 500, height: 800))
        ])
        #expect(result.report == ArrangementApplyReport(placed: 2, total: 2))
    }

    @Test("the move frame is the slot placement frame, gap included")
    func moveFrameIsSlotPlacementFrame() {
        let slot = fixtureSlot("uuid:AAAA", 0.25, 0.5, 0.5, 0.5)
        let result = plan([entry(slot: slot)], windows: [snapshotWindow()], gap: 10)
        #expect(result.moves.map(\.frame) == [SlotPlacement.frame(for: slot, displays: [mainDisplay], gap: 10)])
        #expect(result.moves.map(\.frame) == [CGRect(x: 255, y: 405, width: 490, height: 390)])
    }

    @Test("a slot on a display with negative origin lands there")
    func negativeOriginDisplay() {
        let slot = fixtureSlot("edid:1-2-3", 0.5, 0, 0.5, 1)
        let result = plan([entry(slot: slot)], windows: [snapshotWindow()], displays: [mainDisplay, sideDisplay])
        #expect(result.moves.map(\.frame) == [CGRect(x: -720, y: 120, width: 720, height: 900)])
    }

    @Test("a window titled as the hint is chosen over an earlier one")
    func titleChoosesWindow() {
        let windows = [snapshotWindow(title: "logs", ordinal: 0), snapshotWindow(title: "build", ordinal: 1)]
        let result = plan([entry(hint: "build", slot: fixtureSlot("uuid:AAAA", 0, 0, 0.5, 1))], windows: windows)
        #expect(result.moves.map(\.ref) == [windows[1].ref])
    }

    @Test("an app that is not running skips all its entries and is named once")
    func appNotRunning() {
        let entries = [
            entry(safari, "Safari", slot: fixtureSlot("uuid:AAAA", 0, 0, 0.5, 1)),
            entry(terminal, "Terminal", slot: fixtureSlot("uuid:AAAA", 0.5, 0, 0.5, 1)),
            entry(safari, "Safari", slot: fixtureSlot("uuid:AAAA", 0, 0, 0.5, 0.5))
        ]
        let result = plan(entries, windows: [snapshotWindow()], running: [terminal])
        #expect(result.report == ArrangementApplyReport(placed: 1, total: 3, notRunning: 2, notRunningApps: ["Safari"]))
        #expect(result.moves.count == 1)
    }

    @Test("not running apps are listed in arrangement order")
    func notRunningAppOrder() {
        let entries = [entry(notes, "Notes"), entry(safari, "Safari"), entry(notes, "Notes")]
        let result = plan(entries, windows: [], running: [])
        #expect(result.report.notRunningApps == ["Notes", "Safari"])
        #expect(result.report.notRunning == 3)
        #expect(result.moves.isEmpty)
    }

    @Test("windows of an app absent from the running set are not moved")
    func runningSetDecides() {
        let result = plan([entry()], windows: [snapshotWindow()], running: [])
        #expect(result.moves.isEmpty)
        #expect(result.report == ArrangementApplyReport(placed: 0, total: 1, notRunning: 1, notRunningApps: ["Terminal"]))
    }

    @Test("an entry on a disconnected display is counted and moves nothing")
    func displayMissing() {
        let result = plan([entry(slot: fixtureSlot("uuid:GONE"))], windows: [snapshotWindow()])
        #expect(result.moves.isEmpty)
        #expect(result.report == ArrangementApplyReport(placed: 0, total: 1, displayMissing: 1))
    }

    @Test("an entry on a disconnected display does not take the window another entry needs")
    func missingDisplayEntryDoesNotClaimWindow() {
        let entries = [
            entry(hint: "docs", slot: fixtureSlot("uuid:GONE")),
            entry(slot: fixtureSlot("uuid:AAAA", 0.5, 0, 0.5, 1))
        ]
        let windows = [snapshotWindow(title: "docs")]
        let result = plan(entries, windows: windows)
        #expect(result.moves.map(\.ref) == [windows[0].ref])
        #expect(result.report == ArrangementApplyReport(placed: 1, total: 2, displayMissing: 1))
    }

    @Test("a display without a key never matches a slot")
    func unkeyedDisplayDoesNotMatch() {
        let result = plan([entry()], windows: [snapshotWindow()], displays: [snapshotDisplay(key: nil)])
        #expect(result.report.displayMissing == 1)
    }

    @Test("no connected displays means every running entry has a missing display")
    func noDisplays() {
        let result = plan([entry(), entry()], windows: [snapshotWindow(ordinal: 0), snapshotWindow(ordinal: 1)], displays: [])
        #expect(result.report == ArrangementApplyReport(placed: 0, total: 2, displayMissing: 2))
    }

    @Test("an entry with no window left is counted as noWindow")
    func moreEntriesThanWindows() {
        let result = plan([entry(), entry(), entry()], windows: [snapshotWindow()])
        #expect(result.report == ArrangementApplyReport(placed: 1, total: 3, noWindow: 2))
    }

    @Test("windows without an entry are not moved")
    func moreWindowsThanEntries() {
        let windows = [snapshotWindow(ordinal: 0), snapshotWindow(ordinal: 1), snapshotWindow(ordinal: 2)]
        let result = plan([entry()], windows: windows)
        #expect(result.moves.map(\.ref) == [windows[0].ref])
        #expect(result.report == ArrangementApplyReport(placed: 1, total: 1))
    }

    @Test("windows of another app stay out of the match")
    func otherAppsWindowsIgnored() {
        let foreign = snapshotWindow(safari, appName: "Safari", pid: 2)
        let own = snapshotWindow(terminal, pid: 1)
        let result = plan([entry()], windows: [foreign, own])
        #expect(result.moves.map(\.ref) == [own.ref])
    }

    @Test("moves follow the arrangement order across interleaved apps")
    func movesInEntryOrder() {
        let entries = [
            entry(terminal, "Terminal", slot: fixtureSlot("uuid:AAAA", 0, 0, 0.25, 1)),
            entry(safari, "Safari", slot: fixtureSlot("uuid:AAAA", 0.25, 0, 0.25, 1)),
            entry(terminal, "Terminal", slot: fixtureSlot("uuid:AAAA", 0.5, 0, 0.25, 1))
        ]
        let windows = [
            snapshotWindow(terminal, pid: 1, ordinal: 0),
            snapshotWindow(terminal, pid: 1, ordinal: 1),
            snapshotWindow(safari, appName: "Safari", pid: 2, ordinal: 0)
        ]
        let result = plan(entries, windows: windows)
        #expect(result.moves.map(\.ref) == [windows[0].ref, windows[2].ref, windows[1].ref])
        #expect(result.moves.map(\.frame.minX) == [0, 250, 500])
    }

    @Test("an empty arrangement plans nothing")
    func emptyArrangement() {
        let result = plan([], windows: [snapshotWindow()])
        #expect(result.moves.isEmpty)
        #expect(result.report == ArrangementApplyReport())
    }

    @Test("planning twice gives the same plan")
    func planIsDeterministic() {
        let entries = [entry(hint: "a"), entry(), entry(safari, "Safari")]
        let windows = [snapshotWindow(title: "b", ordinal: 0), snapshotWindow(title: "a", ordinal: 1)]
        #expect(plan(entries, windows: windows) == plan(entries, windows: windows))
    }
}

@Suite("Arrangement planner: report invariant")
struct ArrangementPlannerInvariantTests {
    private let bundles = ["b0", "b1", "b2", "b3"]
    private let keys = ["k0", "k1", "k2", "gone"]

    private func connectedDisplays(using generator: inout SeededGenerator) -> [DisplaySnapshot] {
        let origins: [CGFloat] = [0, -1440, 2000]
        return zip(keys, origins).compactMap { key, originX in
            guard Bool.random(using: &generator) else { return nil }
            let frame = CGRect(x: originX, y: originX < 0 ? 100 : 0, width: 1200 + originX / 10, height: 800)
            return snapshotDisplay(key: key, name: key, frame: frame)
        }
    }

    @Test("over 500 seeded arrangements the report adds up and every move sits on its entry's frame")
    func reportAddsUp() {
        var generator = SeededGenerator(seed: 0x6A7)
        let titles: [String?] = [nil, "a", "b", "c"]
        for round in 0..<500 {
            let entries = (0..<Int.random(in: 0...8, using: &generator)).map { index in
                entry(
                    bundles.randomElement(using: &generator) ?? "", "App", hint: titles.randomElement(using: &generator) ?? nil,
                    slot: fixtureSlot(keys.randomElement(using: &generator) ?? "", Double(index) / 16, 0, 1.0 / 16, 1))
            }
            let windows = (0..<Int.random(in: 0...8, using: &generator)).map { ordinal in
                let bundleIndex = Int.random(in: 0..<bundles.count, using: &generator)
                return snapshotWindow(
                    bundles[bundleIndex], title: titles.randomElement(using: &generator) ?? nil,
                    pid: Int32(bundleIndex + 1), ordinal: ordinal)
            }
            let running = Set(bundles.filter { _ in Bool.random(using: &generator) })
            let displays = connectedDisplays(using: &generator)
            let gap: CGFloat = Bool.random(using: &generator) ? 0 : 8

            let result = ArrangementPlanner.plan(
                fixtureArrangement(windows: entries), windows: windows, running: running, displays: displays, gap: gap)
            check(result, entries: entries, windows: windows, running: running, displays: displays, gap: gap, round: round)
        }
    }

    private func check(
        _ result: ArrangementPlan, entries: [ArrangedWindow], windows: [WindowSnapshot], running: Set<String>,
        displays: [DisplaySnapshot], gap: CGFloat, round: Int
    ) {
        let report = result.report
        let sum = report.placed + report.notRunning + report.noWindow + report.displayMissing
        #expect(sum == report.total, "round \(round)")
        #expect(report.total == entries.count, "round \(round)")
        #expect(report.placed == result.moves.count, "round \(round)")

        let frames = entries.map { SlotPlacement.frame(for: $0.slot, displays: displays, gap: gap) }
        let idle = entries.filter { !running.contains($0.bundleID) }
        #expect(report.notRunning == idle.count, "round \(round)")
        #expect(report.notRunningApps.count == Set(report.notRunningApps).count, "round \(round)")

        var expectedPlaced = 0
        var expectedMissing = 0
        var expectedNoWindow = 0
        for bundle in bundles where running.contains(bundle) {
            let indices = entries.indices.filter { entries[$0].bundleID == bundle }
            let matchable = indices.filter { frames[$0] != nil }.count
            let available = windows.filter { $0.bundleID == bundle }.count
            expectedMissing += indices.count - matchable
            expectedPlaced += min(matchable, available)
            expectedNoWindow += matchable - min(matchable, available)
        }
        #expect(report.displayMissing == expectedMissing, "round \(round)")
        #expect(report.placed == expectedPlaced, "round \(round)")
        #expect(report.noWindow == expectedNoWindow, "round \(round)")

        checkMoves(result.moves, entries: entries, frames: frames, windows: windows, round: round)
    }

    private func checkMoves(
        _ moves: [PlannedMove], entries: [ArrangedWindow], frames: [CGRect?], windows: [WindowSnapshot], round: Int
    ) {
        #expect(Set(moves.map(\.ref)).count == moves.count, "round \(round)")
        var previousEntry = -1
        for move in moves {
            let owner = entries.indices.first { frames[$0] == move.frame }
            #expect(owner != nil, "round \(round)")
            guard let owner else { continue }
            #expect(owner > previousEntry, "round \(round)")
            previousEntry = owner
            let window = windows.first { $0.ref == move.ref }
            #expect(window?.bundleID == entries[owner].bundleID, "round \(round)")
        }
    }
}
