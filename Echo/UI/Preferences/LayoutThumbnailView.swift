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
            zone(layout)
        } else if let direction = command.displayDirection {
            Image(systemName: Self.symbolName(for: direction))
                .font(DS.ZoneMap.thumbnailSymbolFont)
                .foregroundStyle(.secondary)
        }
    }

    private func zone(_ layout: WindowLayout) -> some View {
        let size = display.size(fitting: DS.ZoneMap.thumbnailSize)
        let rect = layout.drawRect(in: size, gap: DS.ZoneMap.thumbnailGap)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: DS.ZoneMap.thumbnailScreenCorner)
                .fill(DS.ZoneMap.screenFill)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.ZoneMap.thumbnailScreenCorner)
                        .strokeBorder(DS.ZoneMap.screenStroke, lineWidth: DS.ZoneMap.hairline)
                }
            RoundedRectangle(cornerRadius: DS.ZoneMap.thumbnailZoneCorner)
                .fill(DS.ZoneMap.zoneStroke)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
        }
        .frame(width: size.width, height: size.height)
    }

    static func symbolName(for direction: DisplayDirection) -> String {
        switch direction {
        case .next:     return "rectangle.righthalf.inset.filled.arrow.right"
        case .previous: return "rectangle.lefthalf.inset.filled.arrow.left"
        }
    }
}
