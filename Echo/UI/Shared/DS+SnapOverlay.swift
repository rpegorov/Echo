//
//  DS+SnapOverlay.swift
//  Echo
//

import SwiftUI

extension DS {
    /// Tokens for the drag-to-snap overlay: zone fill, caption and motion.
    enum SnapOverlay {

        // MARK: - Zone

        static let cornerRadius: CGFloat = DS.cornerLG
        static let strokeWidth: CGFloat = 2
        static let fillOpacity: Double = 0.22
        static let strokeOpacity: Double = 0.85

        // MARK: - Motion

        static let appearScale: CGFloat = 0.96
        static let appearAnimation = Animation.easeOut(duration: 0.2)
        static let morphAnimation = Animation.spring(response: 0.3, dampingFraction: 0.85)
        static let hideAnimation = Animation.easeOut(duration: 0.15)

        // MARK: - Caption

        static let captionFontSize: CGFloat = 20
        static let captionLineLimit = 1
        static let captionMinimumScaleFactor: CGFloat = 0.5
        static let capsuleFillOpacity: Double = 0.9
        static let capsuleHorizontalPadding: CGFloat = 16
        static let capsuleVerticalPadding: CGFloat = 8
        /// Keeps the caption inside the zone even for a quarter tile on a small display.
        static let captionInset: CGFloat = 12
        static let captionForeground = Color.white
    }
}
