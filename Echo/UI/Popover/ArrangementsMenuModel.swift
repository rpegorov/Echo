//
//  ArrangementsMenuModel.swift
//  Echo
//

import Foundation

/// One entry of the popover's arrangements menu.
struct ArrangementsMenuItem: Equatable, Identifiable {
    let id: UUID
    let name: String
    let shortcut: KeyboardShortcut?
}

/// What the popover shows after an arrangement was applied.
struct ArrangementApplyOutcome: Equatable, Identifiable {
    let id = UUID()
    let report: ArrangementApplyReport
}

/// Menu content and apply-report text for the popover row; the view only iterates the results.
enum ArrangementsMenuModel {
    /// Document order, so the menu matches the list in Preferences.
    static func items(arrangements: [Arrangement], shortcuts: [UUID: KeyboardShortcut]) -> [ArrangementsMenuItem] {
        arrangements.map { ArrangementsMenuItem(id: $0.id, name: $0.name, shortcut: shortcuts[$0.id]) }
    }

    /// The placed count first, then one line per kind of skip that happened.
    @MainActor
    static func reportLines(_ report: ArrangementApplyReport, using loc: Localizer) -> [String] {
        var lines = [loc.t(InputKey.arrangementApplyResult, Int64(report.placed), Int64(report.total))]
        if report.notRunning > 0, !report.notRunningApps.isEmpty {
            let apps = report.notRunningApps.formatted(.list(type: .and).locale(loc.locale))
            lines.append(loc.t(InputKey.arrangementNotRunning, apps))
        }
        if report.noWindow > 0 {
            lines.append(loc.t(InputKey.arrangementNoWindowCount, Int64(report.noWindow)))
        }
        if report.displayMissing > 0 {
            lines.append(loc.t(InputKey.arrangementDisplayMissingCount, Int64(report.displayMissing)))
        }
        return lines
    }
}
