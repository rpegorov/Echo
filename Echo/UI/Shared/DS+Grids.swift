//
//  DS+Grids.swift
//  Echo
//

import SwiftUI

extension DS {

    enum Grids {

        // MARK: - Thumbnail

        static let thumbnailSize = CGSize(width: 36, height: 22)
        /// Gap drawn between zones so neighbouring cells read as distinct.
        static let thumbnailZoneGap: CGFloat = 1

        // MARK: - Spacing

        static let cardSpacing: CGFloat = 12
        static let groupSpacing: CGFloat = 10
        static let rowSpacing: CGFloat = 10
        static let rowVerticalPadding: CGFloat = 7
        static let nameCountSpacing: CGFloat = 1
        static let dividerOpacity: Double = 0.12

        // MARK: - Type

        static let titleFont = Font.system(size: 13, weight: .medium)
        static let rowFont = Font.system(size: 13)
        static let detailFont = Font.system(size: 11)
        static let actionIconFont = Font.system(size: 12)

        // MARK: - Controls

        static let activeGridPickerWidth: CGFloat = 150
        static let modifierPickerWidth: CGFloat = 180
        static let renameFieldWidth: CGFloat = 220

        static let noticeColor = Color.orange
    }
}
