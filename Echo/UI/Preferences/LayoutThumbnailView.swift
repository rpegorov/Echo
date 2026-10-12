//
//  LayoutThumbnailView.swift
//  Echo
//

import SwiftUI

/// Miniature of a window command: the display with the command's zone highlighted,
/// or a two-screens glyph for the move-to-display commands.
struct LayoutThumbnailView: View {
    let command: WMCommand
    let display: ZoneMapDisplay

    var body: some View {
        content
            .frame(width: DS.ZoneMap.thumbnailSize.width, height: DS.ZoneMap.thumbnailSize.height)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let layout = command.layout {
            DS.ZoneMap.ScreenThumbnail(
                visibleSize: display.visible.size,
                bounds: DS.ZoneMap.thumbnailSize,
                zones: [layout.unitRect],
                gap: DS.ZoneMap.thumbnailGap,
                zoneCornerRadius: DS.ZoneMap.thumbnailZoneCorner,
                zoneFill: DS.ZoneMap.zoneStroke,
                zoneStroke: nil
            )
        } else if let direction = command.displayDirection {
            Image(systemName: Self.symbolName(for: direction))
                .font(DS.ZoneMap.thumbnailSymbolFont)
                .foregroundStyle(.secondary)
        }
    }

    static func symbolName(for direction: DisplayDirection) -> String {
        switch direction {
        case .next:     return "rectangle.righthalf.inset.filled.arrow.right"
        case .previous: return "rectangle.lefthalf.inset.filled.arrow.left"
        }
    }
}
