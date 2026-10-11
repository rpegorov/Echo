//
//  DS+GridEditor.swift
//  Echo
//

import SwiftUI

extension DS {

    /// Tokens for the grid editor window: sizes, canvas, zone drawing and messages.
    enum GridEditor {

        // MARK: - Window

        /// Widest the canvas starts out, in points.
        static let maxCanvasWidth: CGFloat = 960
        /// Share of the target display's width the canvas starts at.
        static let canvasScreenShare: CGFloat = 0.5
        static let windowMinSize = CGSize(width: 520, height: 420)
        /// Height of the name row, template menu, hint and buttons around the canvas.
        static let chromeHeight: CGFloat = 156
        /// Display proportions used when no display is connected.
        static let fallbackDisplaySize = CGSize(width: 1440, height: 900)

        // MARK: - Spacing

        static let contentPadding: CGFloat = DS.gutter
        static let sectionSpacing: CGFloat = 12
        static let toolbarSpacing: CGFloat = 12
        static let buttonSpacing: CGFloat = 10
        static let nameFieldMaxWidth: CGFloat = 320
        static let messageSpacing: CGFloat = 6

        // MARK: - Canvas

        static let canvasCorner: CGFloat = 8
        static let canvasFill = Color.primary.opacity(0.05)
        static let canvasStroke = Color.primary.opacity(0.18)
        static let hairline: CGFloat = 1

        // MARK: - Zone

        static let zoneCorner: CGFloat = 6
        static let zoneFill = DS.accent.opacity(0.16)
        static let zoneStroke = DS.accent.opacity(0.55)
        static let zoneStrokeWidth: CGFloat = 1.5
        /// Keeps the label clear of the zone edge and of the corner radius.
        static let zoneLabelInset: CGFloat = 6
        static let zoneLabelSpacing: CGFloat = 2

        static let zoneHoverFill = DS.accent.opacity(0.28)

        // MARK: - Border handles

        /// Drawn thickness of an idle border handle.
        static let handleThickness: CGFloat = 4
        /// Drawn thickness while the pointer is over the handle or it is being dragged.
        static let handleThicknessEmphasized: CGFloat = 6
        /// Width of the strip around a border that grabs the pointer.
        static let handleHitWidth: CGFloat = 14
        /// Keeps a handle's ends clear of the canvas edge and of the crossing handles.
        static let handleEndInset: CGFloat = 8
        static let handleFill = Color.primary.opacity(0.5)
        static let handleFillEmphasized = DS.accent
        static let handleOutline = Color.white.opacity(0.85)
        static let handleOutlineWidth: CGFloat = 1
        /// Pointer travel up to which a press on a zone still counts as a click.
        static let clickSlop: CGFloat = 4

        // MARK: - Type

        static let zoneNumberFont = Font.system(size: 28, weight: .semibold, design: .rounded)
        /// The number alone, for a zone too short to hold number and shortcut.
        static let zoneCompactNumberFont = Font.system(size: 14, weight: .semibold, design: .rounded)
        static let zoneShortcutFont = Font.system(size: 12, weight: .medium, design: .rounded)
        static let zoneTextMinimumScale: CGFloat = 0.5
        static let zoneTextLines = 1
        static let messageFont = Font.system(size: 12)
        static let hintFont = Font.system(size: 12)

        // MARK: - Messages

        static let messageIcon = "exclamationmark.triangle.fill"
        static let messageColor = Color.orange
    }
}
