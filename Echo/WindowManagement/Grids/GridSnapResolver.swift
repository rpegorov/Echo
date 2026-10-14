//
//  GridSnapResolver.swift
//  Echo
//

import CoreGraphics

/// A drag resolved onto a grid: the frame to use plus the zones it covers.
struct GridSpan: Equatable, Sendable {
    /// The window's rect: bounding box of the covered zones.
    let rect: UnitRect
    /// Covered zone indices, ascending.
    let indices: [Int]
}

/// Pure mapping from a cursor position in unit coordinates to grid zones.
enum GridSnapResolver {
    /// Distance in unit space at which a point counts as on a zone edge and a zone as inside a rect.
    static let tolerance: CGFloat = 1e-6

    /// Unit coordinates cover [0, 1] on both axes of the visible area.
    private static let unitRange: ClosedRange<CGFloat> = 0...1

    /// `point` in unit coordinates of `visible`, clamped into [0, 1] on both axes.
    static func unitPoint(_ point: CGPoint, in visible: CGRect) -> CGPoint {
        CGPoint(
            x: clampedToUnit((point.x - visible.minX) / visible.width),
            y: clampedToUnit((point.y - visible.minY) / visible.height)
        )
    }

    /// The zone containing `unitPoint`; on a shared border the lower index wins; nil only for no zones.
    static func zoneIndex(at unitPoint: CGPoint, in zones: [UnitRect]) -> Int? {
        guard let firstIndex = zones.indices.first else { return nil }
        var nearest = firstIndex
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        for index in zones.indices {
            let rect = cgRect(zones[index])
            if contains(rect, unitPoint) {
                return index
            }
            let distance = squaredDistance(from: unitPoint, to: rect)
            if distance < nearestDistance {
                nearest = index
                nearestDistance = distance
            }
        }
        return nearest
    }

    /// Bounding box of zones `anchor` and `current`, grown until every zone it overlaps lies inside it.
    static func span(from anchor: Int, to current: Int, in zones: [UnitRect]) -> GridSpan {
        guard let lastIndex = zones.indices.last else {
            return GridSpan(rect: UnitRect(x: 0, y: 0, width: 0, height: 0), indices: [])
        }
        // Enclosure survives growth, so the loop below runs at most one pass per zone.
        let anchorIndex = min(max(anchor, zones.startIndex), lastIndex)
        let currentIndex = min(max(current, zones.startIndex), lastIndex)
        var rect = cgRect(zones[anchorIndex]).union(cgRect(zones[currentIndex]))
        var grew = true
        while grew {
            grew = false
            for zone in zones {
                let zoneRect = cgRect(zone)
                guard !encloses(rect, zoneRect), intersectionArea(zoneRect, rect) > tolerance else { continue }
                rect = rect.union(zoneRect)
                grew = true
            }
        }
        let indices = zones.indices.filter { encloses(rect, cgRect(zones[$0])) }
        return GridSpan(
            rect: UnitRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height),
            indices: indices
        )
    }

    private static func clampedToUnit(_ value: CGFloat) -> CGFloat {
        min(max(value, unitRange.lowerBound), unitRange.upperBound)
    }

    private static func cgRect(_ rect: UnitRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    private static func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX - tolerance && point.x <= rect.maxX + tolerance
            && point.y >= rect.minY - tolerance && point.y <= rect.maxY + tolerance
    }

    private static func encloses(_ outer: CGRect, _ inner: CGRect) -> Bool {
        inner.minX >= outer.minX - tolerance && inner.maxX <= outer.maxX + tolerance
            && inner.minY >= outer.minY - tolerance && inner.maxY <= outer.maxY + tolerance
    }

    private static func intersectionArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let width = min(a.maxX, b.maxX) - max(a.minX, b.minX)
        let height = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        return max(width, 0) * max(height, 0)
    }

    private static func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, point.x - rect.maxX, 0)
        let dy = max(rect.minY - point.y, point.y - rect.maxY, 0)
        return dx * dx + dy * dy
    }
}
