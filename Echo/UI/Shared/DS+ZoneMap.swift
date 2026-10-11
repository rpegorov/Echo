//
//  DS+ZoneMap.swift
//  Echo
//

import SwiftUI

extension DS {

    /// Tokens for the zone map, layout thumbnails and the shortcut recorder.
    enum ZoneMap {

        // MARK: - Map size

        /// Bounding box of a map that shows several zones at once.
        static let singleMapBounds = CGSize(width: 320, height: 200)
        /// Bounding box of each map in the side-by-side groups.
        static let pairMapBounds = CGSize(width: 200, height: 125)
        /// Display proportions used when no screen is available.
        static let fallbackDisplaySize = CGSize(width: 1440, height: 900)

        // MARK: - Spacing

        static let mapSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 10
        static let chipSpacing: CGFloat = 6
        static let zoneInset: CGFloat = 4
        static let zoneTextSpacing: CGFloat = 2

        // MARK: - Corners and strokes

        static let screenCorner: CGFloat = 6
        static let zoneCorner: CGFloat = 4
        static let chipCorner: CGFloat = 8
        static let hairline: CGFloat = 1
        static let focusStroke: CGFloat = 2

        // MARK: - Chips

        static let chipVerticalPadding: CGFloat = 6
        static let chipHorizontalPadding: CGFloat = 6
        static let chipColumns = 3
        static let chipTitleLines = 2

        // MARK: - Color

        static let screenFill = Color.primary.opacity(0.05)
        static let screenStroke = Color.primary.opacity(0.18)

        static let zoneFill = DS.accent.opacity(0.16)
        static let zoneFillHover = DS.accent.opacity(0.28)
        static let zoneFillPressed = DS.accent.opacity(0.40)
        static let zoneFillRecording = DS.accent.opacity(0.34)
        static let zoneStroke = DS.accent.opacity(0.55)
        static let zoneStrokeRecording = DS.accent

        static let chipFill = Color.primary.opacity(0.06)
        static let chipFillHover = Color.primary.opacity(0.11)
        static let chipFillSelected = DS.accent.opacity(0.22)
        static let chipStrokeSelected = DS.accent.opacity(0.65)

        // MARK: - Type

        static let titleFont = Font.system(size: 13, weight: .medium)
        static let chipFont = Font.system(size: 11, weight: .medium)
        static let zoneTitleFont = Font.system(size: 10)
        static let zoneShortcutFont = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let zoneMinimumTextScale: CGFloat = 0.8
        static let zoneTitleLines = 2

        // MARK: - Thumbnail

        static let thumbnailSize = CGSize(width: 28, height: 18)
        static let thumbnailScreenCorner: CGFloat = 2.5
        static let thumbnailZoneCorner: CGFloat = 1
        static let thumbnailSymbolFont = Font.system(size: 14, weight: .regular)
        static let thumbnailGap: CGFloat = 0
        static let thumbnailRowSpacing: CGFloat = 10

        // MARK: - Shortcut recorder

        enum Recorder {
            static let minWidth: CGFloat = 70
            static let horizontalPadding: CGFloat = 10
            static let verticalPadding: CGFloat = 5
            static let spacing: CGFloat = 6
            static let conflictSpacing: CGFloat = 6
            static let conflictIconSpacing: CGFloat = 4
            static let conflictMaxWidth: CGFloat = 240
            static let font = Font.system(size: 12, weight: .medium, design: .rounded)
            static let clearIconFont = Font.system(size: 11)
            static let conflictFont = Font.system(size: 11)
            static let conflictIconColor = Color.orange
            static let fill = Color.primary.opacity(0.06)
            static let fillHover = Color.primary.opacity(0.11)
            static let fillRecording = DS.accent.opacity(0.18)
            static let strokeRecording = DS.accent.opacity(0.65)
        }
    }
}

extension UnitRect {

    /// The zone in a top-left-origin drawing `size` wide; the geometry itself comes from `frame(in:gap:)`.
    func drawRect(in size: CGSize, gap: CGFloat) -> CGRect {
        let cocoa = frame(in: CGRect(origin: .zero, size: size), gap: gap)
        // frame(in:gap:) is bottom-left based, SwiftUI draws from the top.
        return CGRect(x: cocoa.minX, y: size.height - cocoa.maxY, width: cocoa.width, height: cocoa.height)
    }
}

extension DS.ZoneMap {

    /// Display miniature with zone rectangles on it. Layout and grid thumbnails draw through this
    /// so the geometry (`UnitRect.frame(in:gap:)` plus the top-left flip) lives in one place.
    struct ScreenThumbnail: View {
        /// Visible area giving the thumbnail its proportions; zero size falls back to a default display.
        let visibleSize: CGSize
        /// Bounding box the thumbnail fits into.
        let bounds: CGSize
        let zones: [UnitRect]
        let gap: CGFloat
        let zoneCornerRadius: CGFloat
        let zoneFill: Color
        /// Drawn as a hairline border around every zone; nil draws no border.
        let zoneStroke: Color?

        var body: some View {
            let size = Self.fittedSize(visible: visibleSize, in: bounds)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: DS.ZoneMap.thumbnailScreenCorner)
                    .fill(DS.ZoneMap.screenFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.ZoneMap.thumbnailScreenCorner)
                            .strokeBorder(DS.ZoneMap.screenStroke, lineWidth: DS.ZoneMap.hairline)
                    }
                ForEach(zones.indices, id: \.self) { index in
                    let rect = zones[index].drawRect(in: size, gap: gap)
                    RoundedRectangle(cornerRadius: zoneCornerRadius)
                        .fill(zoneFill)
                        .overlay {
                            if let zoneStroke {
                                RoundedRectangle(cornerRadius: zoneCornerRadius)
                                    .strokeBorder(zoneStroke, lineWidth: DS.ZoneMap.hairline)
                            }
                        }
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .frame(width: size.width, height: size.height)
        }

        /// The largest size with the display's proportions that fits `bounds`.
        private static func fittedSize(visible: CGSize, in bounds: CGSize) -> CGSize {
            let source = visible.width > 0 && visible.height > 0 ? visible : DS.ZoneMap.fallbackDisplaySize
            let scale = min(bounds.width / source.width, bounds.height / source.height)
            return CGSize(width: source.width * scale, height: source.height * scale)
        }
    }
}
