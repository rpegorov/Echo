//
//  ZonePlacement.swift
//  Echo
//

import CoreGraphics

enum ZonePlacement {
    /// Window frame for 1-based zone `number` inside `visible`; nil when the grid has fewer zones.
    static func frame(forZone number: Int, of zones: [UnitRect], visible: CGRect, gap: CGFloat) -> CGRect? {
        guard zones.indices.contains(number - 1) else { return nil }
        return zones[number - 1].frame(in: visible, gap: gap)
    }
}
