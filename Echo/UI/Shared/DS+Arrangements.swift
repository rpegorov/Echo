//
//  DS+Arrangements.swift
//  Echo
//

// swiftlint:disable no_magic_numbers
// lint-allow: no_magic_numbers design tokens are the named constants

import SwiftUI

extension DS {

    /// Tokens for the arrangements settings section, its rules block and the rule sheet.
    enum Arrangements {

        // MARK: - Spacing

        static let cardSpacing: CGFloat = 12
        static let groupSpacing: CGFloat = 10
        static let rowSpacing: CGFloat = 10
        static let rowVerticalPadding: CGFloat = 8
        static let textSpacing: CGFloat = 2
        static let reportSpacing: CGFloat = 2
        static let iconSpacing: CGFloat = 3
        static let dividerOpacity: Double = 0.12

        // MARK: - Icons

        /// App icons shown on a row before the rest collapse into "+N".
        static let maxIcons = 6
        static let iconSize: CGFloat = 18
        static let ruleIconSize: CGFloat = 20

        // MARK: - Type

        static let titleFont = Font.system(size: 13, weight: .medium)
        static let rowFont = Font.system(size: 13)
        static let detailFont = Font.system(size: 11)
        static let overflowFont = Font.system(size: 11, weight: .medium)
        static let actionIconFont = Font.system(size: 12)
        static let deleteIcon = "trash"
        static let renameIcon = "pencil"
        static let nameLineLimit = 1
        static let summaryLineLimit = 2

        // MARK: - Controls

        static let renameFieldWidth: CGFloat = 220
        static let noticeColor = Color.orange
        static let messageIcon = "exclamationmark.triangle.fill"

        // MARK: - Sheets

        static let sheetWidth: CGFloat = 400
        static let sheetPadding: CGFloat = 20
        static let sheetSpacing: CGFloat = 14
        static let sheetLabelWidth: CGFloat = 90
        static let sheetButtonSpacing: CGFloat = 8

        // MARK: - Zone picker

        static let pickerBounds = CGSize(width: 240, height: 150)
        static let pickerZoneGap: CGFloat = 2
        static let pickerScreenCorner: CGFloat = 6
        static let pickerZoneCorner: CGFloat = 4
        static let pickerZoneFont = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let pickerStrokeWidth: CGFloat = 1
        static let pickerSelectedStrokeWidth: CGFloat = 2
        static let pickerScreenFill = Color.primary.opacity(0.05)
        static let pickerScreenStroke = Color.primary.opacity(0.18)
        static let pickerZoneFill = DS.accent.opacity(0.12)
        static let pickerZoneFillHover = DS.accent.opacity(0.26)
        static let pickerZoneFillSelected = DS.accent.opacity(0.45)
        static let pickerZoneStroke = DS.accent.opacity(0.5)
        static let pickerZoneStrokeSelected = DS.accent

        // MARK: - Popover menu row

        static let menuRowTitleFont = Font.system(size: 12)
        static let menuRowCountFont = Font.system(size: 11, design: .rounded)
        static let menuRowChevronFont = Font.system(size: 9, weight: .semibold)
        static let menuRowVerticalPadding: CGFloat = 5
        static let menuRowHoverInset: CGFloat = 8
        static let menuReportSpacing: CGFloat = 2
        static let menuReportFont = Font.system(size: 10)
        static let menuReportBottomPadding: CGFloat = 5
        /// How long the outcome of an apply stays under the row.
        static let menuReportDuration = Duration.seconds(10)
    }
}
// swiftlint:enable no_magic_numbers
