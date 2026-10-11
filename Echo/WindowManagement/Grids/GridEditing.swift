//
//  GridEditing.swift
//  Echo
//

import Foundation

/// Direction of a split cut: `.columns` cuts vertically (left | right), `.rows` horizontally (top / bottom).
enum SplitAxis: Sendable { case columns, rows }

enum GridDirection: CaseIterable, Sendable { case left, right, above, below }

/// A draggable border: the smallest run of shared zone sides on one line that can move without breaking a zone.
struct GridEdge: Hashable, Sendable {
    enum Axis: Hashable, Sendable { case vertical, horizontal }
    /// `.vertical`: the line x = position; `.horizontal`: y = position.
    let axis: Axis
    let position: Double
    /// Extent along the line, unit coordinates.
    let start: Double
    let end: Double
}

/// Pure operations on grids: an ordered flat list of zones covering the unit square without overlap.
enum GridEditing {
    static let tolerance: Double = 1e-6
    static let minimumZoneExtent: Double = 0.1
    static let edgeStep: Double = 0.005

    /// Reading order: top edge descending, then left edge ascending.
    static func canonicalOrder(_ zones: [UnitRect]) -> [UnitRect] {
        zones.sorted { a, b in
            let topA = bucket(a.y + a.height)
            let topB = bucket(b.y + b.height)
            if topA != topB { return topA > topB }
            return bucket(a.x) < bucket(b.x)
        }
    }

    /// Inside the unit square, pairwise non-overlapping, total area 1, in canonical order — all within `tolerance`.
    static func isValid(_ zones: [UnitRect]) -> Bool {
        var totalArea = 0.0
        for (i, zone) in zones.enumerated() {
            guard zone.width > tolerance, zone.height > tolerance,
                  zone.x >= -tolerance, zone.y >= -tolerance,
                  zone.x + zone.width <= 1 + tolerance, zone.y + zone.height <= 1 + tolerance
            else { return false }
            totalArea += zone.width * zone.height
            for other in zones[(i + 1)...] where intersectionArea(zone, other) > tolerance {
                return false
            }
        }
        guard abs(totalArea - 1) <= tolerance else { return false }
        let ordered = canonicalOrder(zones)
        return zip(zones, ordered).allSatisfy(close)
    }

    /// Halves zone `index`; nil when a half would be thinner than `minimumZoneExtent`.
    static func split(_ zones: [UnitRect], at index: Int, along axis: SplitAxis) -> [UnitRect]? {
        guard zones.indices.contains(index) else { return nil }
        let zone = zones[index]
        var halves: [UnitRect]
        switch axis {
        case .columns:
            let half = zone.width / 2
            guard half >= minimumZoneExtent - tolerance else { return nil }
            halves = [
                UnitRect(x: zone.x, y: zone.y, width: half, height: zone.height),
                UnitRect(x: zone.x + half, y: zone.y, width: half, height: zone.height)
            ]
        case .rows:
            let half = zone.height / 2
            guard half >= minimumZoneExtent - tolerance else { return nil }
            halves = [
                UnitRect(x: zone.x, y: zone.y, width: zone.width, height: half),
                UnitRect(x: zone.x, y: zone.y + half, width: zone.width, height: half)
            ]
        }
        var result = zones
        result.replaceSubrange(index...index, with: halves)
        return canonicalOrder(result)
    }

    /// The zone sharing the whole side of zone `index` facing `direction`; nil when there is none.
    static func mergeCandidate(_ zones: [UnitRect], of index: Int, toward direction: GridDirection) -> Int? {
        guard zones.indices.contains(index) else { return nil }
        let zone = zones[index]
        for j in zones.indices where j != index {
            let other = zones[j]
            let sideMatches: Bool
            switch direction {
            case .left:
                sideMatches = abs(other.x + other.width - zone.x) <= tolerance
                    && extentsMatch(other.y, other.y + other.height, zone.y, zone.y + zone.height)
            case .right:
                sideMatches = abs(zone.x + zone.width - other.x) <= tolerance
                    && extentsMatch(other.y, other.y + other.height, zone.y, zone.y + zone.height)
            case .below:
                sideMatches = abs(other.y + other.height - zone.y) <= tolerance
                    && extentsMatch(other.x, other.x + other.width, zone.x, zone.x + zone.width)
            case .above:
                sideMatches = abs(zone.y + zone.height - other.y) <= tolerance
                    && extentsMatch(other.x, other.x + other.width, zone.x, zone.x + zone.width)
            }
            if sideMatches { return j }
        }
        return nil
    }

    /// Zones `a` and `b` replaced by their union; nil unless the union is a rectangle.
    static func merge(_ zones: [UnitRect], _ a: Int, _ b: Int) -> [UnitRect]? {
        guard a != b, zones.indices.contains(a), zones.indices.contains(b) else { return nil }
        let (first, second) = (zones[a], zones[b])
        let union = UnitRect(
            x: min(first.x, second.x),
            y: min(first.y, second.y),
            width: max(first.x + first.width, second.x + second.width) - min(first.x, second.x),
            height: max(first.y + first.height, second.y + second.height) - min(first.y, second.y)
        )
        let unionArea = union.width * union.height
        let partsArea = first.width * first.height + second.width * second.height
        guard abs(unionArea - partsArea) <= tolerance else { return nil }
        var result = zones
        result.remove(at: max(a, b))
        result.remove(at: min(a, b))
        result.append(union)
        return canonicalOrder(result)
    }

    /// Every draggable border, deduplicated.
    static func edges(of zones: [UnitRect]) -> [GridEdge] {
        var borders: [GridEdge] = []
        for i in zones.indices {
            for j in zones.indices where j > i {
                borders.append(contentsOf: sharedSegments(zones[i], zones[j]).map { extended($0, in: zones) })
            }
        }
        return deduplicated(borders).sorted { a, b in
            if a.axis != b.axis { return a.axis == .vertical }
            if a.position != b.position { return a.position < b.position }
            if a.start != b.start { return a.start < b.start }
            return a.end < b.end
        }
    }

    /// `zones` with `edge` moved to `position`, rounded to `edgeStep`, clamped so no touching zone gets thinner
    /// than `minimumZoneExtent`. Pass the zones from the start of the drag, not the previous frame's result.
    static func move(_ edge: GridEdge, to position: Double, in zones: [UnitRect]) -> [UnitRect] {
        let snapped = (position / edgeStep).rounded() * edgeStep
        // Zones ending on the border sit below/left of it and bound the drag with their near coordinate.
        // With no zone on a side the border still stays inside the unit square.
        let lowerBound: Double
        let upperBound: Double
        switch edge.axis {
        case .vertical:
            lowerBound = zones.filter { endsOnBorder($0, edge) }.map(\.x).max().map { $0 + minimumZoneExtent } ?? 0
            upperBound = zones.filter { startsOnBorder($0, edge) }
                .map { $0.x + $0.width }.min().map { $0 - minimumZoneExtent } ?? 1
        case .horizontal:
            lowerBound = zones.filter { endsOnBorder($0, edge) }.map(\.y).max().map { $0 + minimumZoneExtent } ?? 0
            upperBound = zones.filter { startsOnBorder($0, edge) }
                .map { $0.y + $0.height }.min().map { $0 - minimumZoneExtent } ?? 1
        }
        let target = min(max(snapped, lowerBound), upperBound)
        return canonicalOrder(zones.map { zone -> UnitRect in
            if endsOnBorder(zone, edge) { return withFarSide(zone, at: target, axis: edge.axis) }
            if startsOnBorder(zone, edge) { return withNearSide(zone, at: target, axis: edge.axis) }
            return zone
        })
    }

    // MARK: - Helpers

    /// Sort keys must be discrete: tolerance-based comparators are not a strict weak ordering.
    private static func bucket(_ value: Double) -> Int {
        Int((value / tolerance).rounded())
    }

    private static func close(_ a: UnitRect, _ b: UnitRect) -> Bool {
        abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }

    private static func extentsMatch(_ aStart: Double, _ aEnd: Double, _ bStart: Double, _ bEnd: Double) -> Bool {
        abs(aStart - bStart) <= tolerance && abs(aEnd - bEnd) <= tolerance
    }

    private static func intersectionArea(_ a: UnitRect, _ b: UnitRect) -> Double {
        let width = min(a.x + a.width, b.x + b.width) - max(a.x, b.x)
        let height = min(a.y + a.height, b.y + b.height) - max(a.y, b.y)
        return max(0, width) * max(0, height)
    }

    /// Border segments two neighbouring zones share; empty when they meet only at a corner.
    private static func sharedSegments(_ a: UnitRect, _ b: UnitRect) -> [GridEdge] {
        var segments: [GridEdge] = []
        for (behind, ahead) in [(a, b), (b, a)] {
            if abs(behind.x + behind.width - ahead.x) <= tolerance {
                let start = max(behind.y, ahead.y)
                let end = min(behind.y + behind.height, ahead.y + ahead.height)
                if end - start > tolerance {
                    segments.append(GridEdge(axis: .vertical, position: ahead.x, start: start, end: end))
                }
            }
            if abs(behind.y + behind.height - ahead.y) <= tolerance {
                let start = max(behind.x, ahead.x)
                let end = min(behind.x + behind.width, ahead.x + ahead.width)
                if end - start > tolerance {
                    segments.append(GridEdge(axis: .horizontal, position: ahead.y, start: start, end: end))
                }
            }
        }
        return segments
    }

    /// Grows the segment to the full side of every zone touching it on the same line, until that set is stable.
    private static func extended(_ seed: GridEdge, in zones: [UnitRect]) -> GridEdge {
        var start = seed.start
        var end = seed.end
        var grew = true
        while grew {
            grew = false
            for zone in zones {
                guard let side = sideExtent(on: seed.axis, line: seed.position, of: zone),
                      min(side.end, end) - max(side.start, start) > tolerance
                else { continue }
                if side.start < start { start = side.start; grew = true }
                if side.end > end { end = side.end; grew = true }
            }
        }
        return GridEdge(axis: seed.axis, position: seed.position, start: start, end: end)
    }

    /// The zone's side extent along the line, or nil when the zone has no side on that line.
    private static func sideExtent(on axis: GridEdge.Axis, line: Double, of zone: UnitRect)
        -> (start: Double, end: Double)?
    {
        switch axis {
        case .vertical:
            let onLine = abs(zone.x + zone.width - line) <= tolerance || abs(zone.x - line) <= tolerance
            return onLine ? (zone.y, zone.y + zone.height) : nil
        case .horizontal:
            let onLine = abs(zone.y + zone.height - line) <= tolerance || abs(zone.y - line) <= tolerance
            return onLine ? (zone.x, zone.x + zone.width) : nil
        }
    }

    /// The zone's far side lies on the border and shares a stretch of it (a corner touch does not count).
    private static func endsOnBorder(_ zone: UnitRect, _ edge: GridEdge) -> Bool {
        let farCoordinate: Double
        let overlap: Double
        switch edge.axis {
        case .vertical:
            farCoordinate = zone.x + zone.width
            overlap = min(zone.y + zone.height, edge.end) - max(zone.y, edge.start)
        case .horizontal:
            farCoordinate = zone.y + zone.height
            overlap = min(zone.x + zone.width, edge.end) - max(zone.x, edge.start)
        }
        return abs(farCoordinate - edge.position) <= tolerance && overlap > tolerance
    }

    /// The zone's near side lies on the border and shares a stretch of it (a corner touch does not count).
    private static func startsOnBorder(_ zone: UnitRect, _ edge: GridEdge) -> Bool {
        let nearCoordinate: Double
        let overlap: Double
        switch edge.axis {
        case .vertical:
            nearCoordinate = zone.x
            overlap = min(zone.y + zone.height, edge.end) - max(zone.y, edge.start)
        case .horizontal:
            nearCoordinate = zone.y
            overlap = min(zone.x + zone.width, edge.end) - max(zone.x, edge.start)
        }
        return abs(nearCoordinate - edge.position) <= tolerance && overlap > tolerance
    }

    /// The zone with its far (right/top) side moved to `value`.
    private static func withFarSide(_ zone: UnitRect, at value: Double, axis: GridEdge.Axis) -> UnitRect {
        axis == .vertical
            ? UnitRect(x: zone.x, y: zone.y, width: value - zone.x, height: zone.height)
            : UnitRect(x: zone.x, y: zone.y, width: zone.width, height: value - zone.y)
    }

    /// The zone with its near (left/bottom) side moved to `value`.
    private static func withNearSide(_ zone: UnitRect, at value: Double, axis: GridEdge.Axis) -> UnitRect {
        axis == .vertical
            ? UnitRect(x: value, y: zone.y, width: zone.x + zone.width - value, height: zone.height)
            : UnitRect(x: zone.x, y: value, width: zone.width, height: zone.y + zone.height - value)
    }

    /// Two borders are the same when every coordinate agrees within `tolerance`, not by exact equality.
    private static func deduplicated(_ borders: [GridEdge]) -> [GridEdge] {
        var kept: [GridEdge] = []
        for border in borders where !kept.contains(where: { same($0, border) }) {
            kept.append(border)
        }
        return kept
    }

    private static func same(_ a: GridEdge, _ b: GridEdge) -> Bool {
        a.axis == b.axis
            && abs(a.position - b.position) <= tolerance
            && abs(a.start - b.start) <= tolerance
            && abs(a.end - b.end) <= tolerance
    }
}
