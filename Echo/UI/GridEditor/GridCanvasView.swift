//
//  GridCanvasView.swift
//  Echo
//

import SwiftUI

/// Drawing geometry of the canvas: the same `UnitRect.frame(in:gap:)` a dropped window gets, in top-left coordinates.
enum GridCanvasLayout {
    /// A window gap in points of the display, expressed in points of a canvas `canvasWidth` wide.
    static func scaledGap(_ gap: Double, canvasWidth: CGFloat, displayWidth: CGFloat) -> CGFloat {
        guard displayWidth > 0 else { return 0 }
        return CGFloat(gap) * canvasWidth / displayWidth
    }

    static func frames(for zones: [UnitRect], in size: CGSize, gap: CGFloat) -> [CGRect] {
        let canvas = CGRect(origin: .zero, size: size)
        return zones.map { zone in
            let cocoa = zone.frame(in: canvas, gap: gap)
            // frame(in:gap:) is bottom-left based, SwiftUI draws from the top.
            return CGRect(x: cocoa.minX, y: size.height - cocoa.maxY, width: cocoa.width, height: cocoa.height)
        }
    }
}

/// The display's visible area with the grid's zones drawn at the proportions of that display.
struct GridCanvasView: View {
    let zones: [UnitRect]
    /// Visible size of the display the grid is for; sets the canvas aspect and the gap scale.
    let displaySize: CGSize
    @ObservedObject var settings: AppSettings

    @EnvironmentObject private var loc: Localizer

    var body: some View {
        GeometryReader { proxy in
            let gap = GridCanvasLayout.scaledGap(settings.windowGap, canvasWidth: proxy.size.width, displayWidth: displaySize.width)
            let frames = GridCanvasLayout.frames(for: zones, in: proxy.size, gap: gap)
            ZStack(alignment: .topLeading) {
                // The zone number is its index (reading order), so the index is its identity.
                ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                    zoneView(number: index + 1, size: frame.size)
                        .offset(x: frame.minX, y: frame.minY)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .aspectRatio(displaySize.width / displaySize.height, contentMode: .fit)
        .background {
            RoundedRectangle(cornerRadius: DS.GridEditor.canvasCorner)
                .fill(DS.GridEditor.canvasFill)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.GridEditor.canvasCorner)
                        .strokeBorder(DS.GridEditor.canvasStroke, lineWidth: DS.GridEditor.hairline)
                }
        }
        .accessibilityElement(children: .contain)
    }

    private func zoneView(number: Int, size: CGSize) -> some View {
        let shortcut = shortcutText(forZone: number)
        return ZStack {
            RoundedRectangle(cornerRadius: DS.GridEditor.zoneCorner)
                .fill(DS.GridEditor.zoneFill)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.GridEditor.zoneCorner)
                        .strokeBorder(DS.GridEditor.zoneStroke, lineWidth: DS.GridEditor.zoneStrokeWidth)
                }
            ZoneLabel(number: number, shortcut: shortcut)
                .padding(DS.GridEditor.zoneLabelInset)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: DS.GridEditor.zoneCorner))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName(number: number, shortcut: shortcut))
    }

    /// Zones past the ninth have no command, hence no shortcut.
    private func shortcutText(forZone number: Int) -> String? {
        WMCommand.zone(number)
            .flatMap(settings.shortcut(for:))
            .map { $0.displayString(spaceName: loc.t(InputKey.keySpace)) }
    }

    private func accessibilityName(number: Int, shortcut: String?) -> String {
        let name = loc.t(InputKey.gridZoneNumber, number)
        return shortcut.map { name + " " + $0 } ?? name
    }
}

/// Zone number with its shortcut; drops the shortcut, then shrinks, when the zone is too small for both.
private struct ZoneLabel: View {
    let number: Int
    let shortcut: String?

    var body: some View {
        ViewThatFits {
            if let shortcut {
                VStack(spacing: DS.GridEditor.zoneLabelSpacing) {
                    numberText(font: DS.GridEditor.zoneNumberFont)
                    Text(shortcut)
                        .font(DS.GridEditor.zoneShortcutFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(DS.GridEditor.zoneTextLines)
                }
            }
            numberText(font: DS.GridEditor.zoneNumberFont)
            numberText(font: DS.GridEditor.zoneCompactNumberFont)
                .minimumScaleFactor(DS.GridEditor.zoneTextMinimumScale)
        }
    }

    private func numberText(font: Font) -> some View {
        Text(number, format: .number.grouping(.never))
            .font(font)
            .foregroundStyle(.primary)
            .lineLimit(DS.GridEditor.zoneTextLines)
    }
}
