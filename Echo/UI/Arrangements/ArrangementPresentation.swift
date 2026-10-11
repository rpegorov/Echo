//
//  ArrangementPresentation.swift
//  Echo
//

import CoreGraphics
import Foundation

/// Pure decisions behind the arrangements screens, kept out of the views.
enum ArrangementPresentation {

    /// Apps of an arrangement as icons: first appearance order, capped, the rest counted.
    struct IconSummary: Equatable {
        let bundleIDs: [String]
        let overflow: Int
    }

    /// How a stored slot reads next to a display's active grid.
    enum SlotLabel: Equatable {
        case zone(Int)
        case customArea
    }

    static func iconSummary(of windows: [ArrangedWindow], limit: Int) -> IconSummary {
        var seen = Set<String>()
        let unique = windows.map(\.bundleID).filter { seen.insert($0).inserted }
        return IconSummary(bundleIDs: Array(unique.prefix(limit)), overflow: max(unique.count - limit, 0))
    }

    /// "Zone N" when `slot` is one of `zones` (numbered from 1 in grid order), else a custom area.
    static func label(for slot: ZoneSlot, zones: [UnitRect]) -> SlotLabel {
        guard let index = zones.firstIndex(where: { matches($0, slot.rect) }) else { return .customArea }
        return .zone(index + 1)
    }

    static func matches(_ first: UnitRect, _ second: UnitRect) -> Bool {
        let tolerance = GridEditing.tolerance
        return abs(first.x - second.x) <= tolerance
            && abs(first.y - second.y) <= tolerance
            && abs(first.width - second.width) <= tolerance
            && abs(first.height - second.height) <= tolerance
    }

    /// The smallest number above the arrangement count that no default name uses yet.
    static func defaultNameNumber(existingNames: [String], count: Int, nameFor: (Int) -> String) -> Int {
        var number = count + 1
        while existingNames.contains(nameFor(number)) { number += 1 }
        return number
    }

    /// The largest size with the display's proportions that fits `bounds`.
    static func fittedSize(visible: CGSize, in bounds: CGSize, fallback: CGSize) -> CGSize {
        let source = visible.width > 0 && visible.height > 0 ? visible : fallback
        let scale = min(bounds.width / source.width, bounds.height / source.height)
        return CGSize(width: source.width * scale, height: source.height * scale)
    }

    /// A name worth saving: trimmed, non-empty.
    static func trimmedName(_ text: String) -> String? {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}
