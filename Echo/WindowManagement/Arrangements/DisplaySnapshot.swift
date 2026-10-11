//
//  DisplaySnapshot.swift
//  Echo
//

import AppKit

/// A connected display with the zones of its active grid.
struct DisplaySnapshot: Equatable, Sendable {
    let key: DisplayKey?
    let name: String
    let frame: CGRect
    let visibleFrame: CGRect
    let zones: [UnitRect]

    var aspect: Double { visibleFrame.width / visibleFrame.height }
}

extension DisplaySnapshot {
    /// Every connected display in `NSScreen.screens` order.
    @MainActor
    static func connected(grids: any ActiveGridProviding) -> [DisplaySnapshot] {
        NSScreen.screens.map { screen in
            let key = DisplayIdentity.key(for: screen)
            let visible = screen.visibleFrame
            return DisplaySnapshot(
                key: key,
                name: screen.localizedName,
                frame: screen.frame,
                visibleFrame: visible,
                zones: grids.activeZones(for: key, aspect: visible.width / visible.height)
            )
        }
    }
}
