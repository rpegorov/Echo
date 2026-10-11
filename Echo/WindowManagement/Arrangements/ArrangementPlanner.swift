//
//  ArrangementPlanner.swift
//  Echo
//

import CoreGraphics
import Foundation

/// A window to move and the frame to move it to.
struct PlannedMove: Equatable, Sendable {
    let ref: WindowRef
    let frame: CGRect
}

/// What applying an arrangement comes down to before any AX write; the report keeps the invariant
/// `placed + notRunning + noWindow + displayMissing == total`.
struct ArrangementPlan: Equatable, Sendable {
    var report: ArrangementApplyReport
    var moves: [PlannedMove]
}

/// Pure part of applying an arrangement: matching saved entries to running windows and their target frames.
enum ArrangementPlanner {
    static func plan(
        _ arrangement: Arrangement,
        windows: [WindowSnapshot],
        running: Set<String>,
        displays: [DisplaySnapshot],
        gap: CGFloat
    ) -> ArrangementPlan {
        var report = ArrangementApplyReport()
        report.total = arrangement.windows.count
        var planned: [(entryIndex: Int, move: PlannedMove)] = []
        for (bundleID, indices) in groups(of: arrangement) {
            guard running.contains(bundleID) else {
                report.notRunning += indices.count
                let appName = arrangement.windows[indices[0]].appName
                if !report.notRunningApps.contains(appName) { report.notRunningApps.append(appName) }
                continue
            }
            // Entries whose display is gone cannot be placed and must not claim a window in matching.
            let matchable: [(entryIndex: Int, frame: CGRect)] = indices.compactMap { index in
                SlotPlacement
                    .frame(for: arrangement.windows[index].slot, displays: displays, gap: gap)
                    .map { (entryIndex: index, frame: $0) }
            }
            report.displayMissing += indices.count - matchable.count
            let appWindows = windows.filter { $0.bundleID == bundleID }
            let matches = WindowMatcher.match(
                entries: matchable.map { arrangement.windows[$0.entryIndex] },
                windows: appWindows
            )
            report.noWindow += matchable.count - matches.count
            planned.append(contentsOf: matches.map { match in
                let target = matchable[match.entry]
                return (
                    entryIndex: target.entryIndex,
                    move: PlannedMove(ref: appWindows[match.window].ref, frame: target.frame)
                )
            })
        }
        let moves = planned.sorted { $0.entryIndex < $1.entryIndex }.map(\.move)
        report.placed = moves.count
        return ArrangementPlan(report: report, moves: moves)
    }

    /// Entry indices per bundle id, groups in order of first appearance in the arrangement.
    private static func groups(of arrangement: Arrangement) -> [(bundleID: String, indices: [Int])] {
        var order: [String] = []
        var byBundle: [String: [Int]] = [:]
        for (index, entry) in arrangement.windows.enumerated() {
            if byBundle[entry.bundleID] == nil { order.append(entry.bundleID) }
            byBundle[entry.bundleID, default: []].append(index)
        }
        return order.map { (bundleID: $0, indices: byBundle[$0] ?? []) }
    }
}
