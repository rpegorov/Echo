//
//  DS+SnapOverlay.swift
//  Echo
//

import SwiftUI

extension DS {
    /// Tokens for the drag-to-snap overlay and the grid flash: zone fill, caption and motion.
    enum SnapOverlay {

        // MARK: - Zone

        static let cornerRadius: CGFloat = DS.cornerLG
        static let strokeWidth: CGFloat = 2
        static let fillOpacity: Double = 0.22
        static let strokeOpacity: Double = 0.85

        // MARK: - Grid context

        /// Faint zones of the active grid drawn behind the bright target; fade only, never scaled.
        /// Smaller radius than the target so context reads as background on small cells.
        static let contextCornerRadius: CGFloat = DS.cornerSM
        static let contextFillOpacity: Double = 0.07
        static let contextStrokeOpacity: Double = 0.28
        static let contextStrokeWidth: CGFloat = 1

        // MARK: - Motion

        static let appearScale: CGFloat = 0.96
        static let appearAnimation = Animation.easeOut(duration: 0.2)
        static let morphAnimation = Animation.spring(response: 0.3, dampingFraction: 0.85)
        static let hideAnimation = Animation.easeOut(duration: 0.15)

        // MARK: - Caption

        static let captionFontSize: CGFloat = 20
        static let captionLineLimit = 1
        /// Floor low enough that "Zone 12 ⌃⌥2" fits a 0.1 x 0.1 zone on a 1280x800 display.
        static let captionMinimumScaleFactor: CGFloat = 0.4
        static let capsuleFillOpacity: Double = 0.9
        static let capsuleHorizontalPadding: CGFloat = 16
        static let capsuleVerticalPadding: CGFloat = 8
        /// Keeps the caption inside the zone even for a quarter tile on a small display.
        static let captionInset: CGFloat = 12
        static let captionForeground = Color.white

        // MARK: - Grid flash

        /// How long the grid stays on screen before it hides itself.
        static let flashDurationMilliseconds = 1400
        static let flashDuration = Duration.milliseconds(flashDurationMilliseconds)
        static let flashFillOpacity: Double = 0.16
        static let flashStrokeOpacity: Double = 0.7
        static let flashStrokeWidth: CGFloat = 2
        static let flashBadgeFillOpacity: Double = 0.9
        static let flashNumberFontSize: CGFloat = 36
        static let flashShortcutFontSize: CGFloat = 16
        static let flashBadgeHorizontalPadding: CGFloat = 14
        static let flashBadgeVerticalPadding: CGFloat = 6
        static let flashContentSpacing: CGFloat = 8
        static let flashRaisedContentShare: CGFloat = 0.3
        static let flashRaisedContentMinHeight: CGFloat = 400
        /// Keeps the badges inside the narrowest zones of a ten-zone grid.
        static let flashBadgeMinimumScaleFactor: CGFloat = 0.4
        static let flashTitleFontSize: CGFloat = 28
        static let flashTitleHorizontalPadding: CGFloat = 28
        static let flashTitleVerticalPadding: CGFloat = 14
        /// Share of the display width the title may take before it shrinks.
        static let flashTitleMaxWidthShare: CGFloat = 0.6
    }
}
