//
//  ArrangementCapture.swift
//  Echo
//

import CoreGraphics
import Foundation

/// Turns the windows open now into arrangement entries: the zone each window overlaps most, per display.
enum ArrangementCapture {
    /// Index of the zone `window` overlaps most, scored in fractions of `visible`; nil when nothing overlaps.
    static func nearestZone(of window: CGRect, visible: CGRect, zones: [UnitRect]) -> Int? {
        let unitArea = Double(visible.width) * Double(visible.height)
        // A zero-area visible rect has no unit area to score against.
        guard unitArea > 0 else { return nil }
        var bestIndex: Int?
        var bestScore = 0.0
        for (index, zone) in zones.enumerated() {
            let overlap = window.intersection(zone.frame(in: visible, gap: 0))
            guard !overlap.isNull, !overlap.isEmpty else { continue }
            let score = Double(overlap.width * overlap.height) / unitArea
            // Scores within the tolerance count as equal; the earlier, lower index keeps the win.
            guard score > bestScore + GridEditing.tolerance else { continue }
            bestIndex = index
            bestScore = score
        }
        return bestIndex
    }

    /// Entries for the current windows and the displays they use; the caller builds the arrangement.
    static func capture(
        windows: [WindowSnapshot],
        displays: [DisplaySnapshot],
        makeID: () -> UUID
    ) -> (windows: [ArrangedWindow], displays: [String: SavedDisplay]) {
        var savedDisplays: [String: SavedDisplay] = [:]
        var entries: [ArrangedWindow] = []
        for window in windows {
            guard let displayIndex = DisplayArrangement.displayIndex(of: window.frame, in: displays.map(\.frame)),
                  let key = displays[displayIndex].key,
                  let zone = nearestZone(
                      of: window.frame,
                      visible: displays[displayIndex].visibleFrame,
                      zones: displays[displayIndex].zones
                  )
            else { continue }
            let isBlank = window.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
            entries.append(
                ArrangedWindow(
                    id: makeID(),
                    bundleID: window.bundleID,
                    appName: window.appName,
                    titleHint: isBlank ? nil : window.title,
                    slot: ZoneSlot(display: key.rawValue, rect: displays[displayIndex].zones[zone])
                )
            )
            savedDisplays[key.rawValue] = SavedDisplay(
                name: displays[displayIndex].name,
                aspect: displays[displayIndex].aspect
            )
        }
        return (entries, savedDisplays)
    }
}
