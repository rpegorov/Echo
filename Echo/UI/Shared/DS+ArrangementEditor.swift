//
//  DS+ArrangementEditor.swift
//  Echo
//
// swiftlint:disable no_magic_numbers
// lint-allow: no_magic_numbers design tokens are the named constants

import SwiftUI

extension DS {

    enum ArrangementEditor {

        static let windowMinSize = CGSize(width: 520, height: 420)
        static let initialMaxWidth: CGFloat = 1100
        static let initialCanvasHeight: CGFloat = 280
        static let chromeHeight: CGFloat = 190

        static let contentPadding: CGFloat = DS.gutter
        /// Padding applies on both sides of the row of canvases.
        static let contentPaddingBothSides: CGFloat = contentPadding * 2
        static let sectionSpacing: CGFloat = 12
        static let toolbarSpacing: CGFloat = 12
        static let buttonSpacing: CGFloat = 10
        static let nameFieldMaxWidth: CGFloat = 320
        static let messageSpacing: CGFloat = 6
        static let canvasSpacing: CGFloat = 16
        static let captionSpacing: CGFloat = 6
        static let captionHeight: CGFloat = 18

        static let canvasCorner: CGFloat = 8
        static let canvasFill = Color.primary.opacity(0.05)
        static let canvasStroke = Color.primary.opacity(0.18)
        static let hairline: CGFloat = 1
        static let disconnectedOpacity: Double = 0.55
        /// Visible width assumed for a display that is not connected, to scale the window gap.
        static let disconnectedReferenceWidth: CGFloat = 1440

        static let zoneCorner: CGFloat = 6
        static let zoneFill = DS.accent.opacity(0.16)
        static let zoneStroke = DS.accent.opacity(0.55)
        static let zoneStrokeWidth: CGFloat = 1.5
        static let zoneDropFill = DS.accent.opacity(0.34)
        static let zoneLabelInset: CGFloat = 6

        static let customStroke = Color.primary.opacity(0.55)
        static let customStrokeWidth: CGFloat = 1.5
        static let customDash: [CGFloat] = [5, 4]
        static let customFill = Color.primary.opacity(0.06)
        static let customLabelHeight: CGFloat = 16

        static let iconMaxSize: CGFloat = 40
        /// Below this an icon is too small to recognise; the rest of the slot collapses into a "+N" cell.
        /// Below this the rest of a slot collapses into a "+N" cell.
        static let iconMinSize: CGFloat = 20
        static let iconSpacing: CGFloat = 4
        static let iconInset: CGFloat = 8
        /// A small slot shrinks the inset to this share of its shorter side.
        static let iconInsetShare: CGFloat = 0.15
        static let dragIconSize: CGFloat = 40
        static let draggedSourceOpacity: Double = 0.3
        static let dragGhostShadowRadius: CGFloat = 6
        static let dragGhostShadow = Color.black.opacity(0.35)
        static let overflowFill = Color.primary.opacity(0.12)
        static let overflowCorner: CGFloat = 6

        /// Pointer travel before a press on an icon becomes a drag; above zero so a plain click changes nothing.
        /// Above zero so a plain click on an icon changes nothing.
        static let dragThreshold: CGFloat = 4

        static let captionFont = Font.system(size: 12, weight: .medium)
        static let zoneNumberFont = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let customLabelFont = Font.system(size: 11, weight: .medium)
        static let overflowFont = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let hintFont = Font.system(size: 12)
        static let messageFont = Font.system(size: 12)
        static let textMinimumScale: CGFloat = 0.6

        static let messageIcon = "exclamationmark.triangle.fill"
        static let messageColor = Color.orange
    }
}
// swiftlint:enable no_magic_numbers
