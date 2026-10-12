//
//  GridThumbnailView.swift
//  Echo
//

import SwiftUI

/// Miniature of a grid: the screen with every zone drawn, display proportions preserved.
struct GridThumbnailView: View {
    let zones: [UnitRect]
    /// Visible area giving the thumbnail its proportions; zero size falls back to a default display.
    let visibleSize: CGSize

    var body: some View {
        DS.ZoneMap.ScreenThumbnail(
            visibleSize: visibleSize,
            bounds: DS.Grids.thumbnailSize,
            zones: zones,
            gap: DS.Grids.thumbnailZoneGap,
            zoneCornerRadius: DS.ZoneMap.thumbnailZoneCorner,
            zoneFill: DS.ZoneMap.zoneFill,
            zoneStroke: DS.ZoneMap.zoneStroke
        )
        .accessibilityHidden(true)
    }
}
