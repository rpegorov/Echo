//
//  DS+Temperature.swift
//  Echo
//

// swiftlint:disable no_magic_numbers
// lint-allow: no_magic_numbers design tokens are the named constants

import SwiftUI

extension DS {

    /// Tokens for the temperature tab: chart lines, legend and stat cards.
    enum Temperature {

        // MARK: - Chart

        static let chartStackSpacing: CGFloat = 2
        static let chartBottomPadding: CGFloat = 4
        static let timeAxisHeight: CGFloat = 22
        static let tooltipPadding: CGFloat = 8
        static let seriesStrokeWidth: CGFloat = 1.5
        static let cpuFillOpacity = 0.25
        static let gpuFillOpacity = 0.20
        static let curveSmoothingRatio: CGFloat = 0.5
        static let minimumSeriesPoints = 2

        // MARK: - Axis

        static let axisStepCount = 4
        static let axisFloorCelsius: Double = 60
        static let axisRoundingCelsius: Double = 20
        static let axisFont = Font.system(size: 10, design: .monospaced)
        static let axisLeadingPadding: CGFloat = 6
        static let axisVerticalPadding: CGFloat = 4
        static let gridOpacity = 0.2
        static let gridHorizontalPadding: CGFloat = 4

        // MARK: - Legend

        static let legendRowSpacing: CGFloat = 4
        static let legendPadding: CGFloat = 8
        static let legendItemSpacing: CGFloat = 6
        static let legendSwatchRadius: CGFloat = 1
        static let legendSwatchWidth: CGFloat = 14
        static let legendSwatchHeight: CGFloat = 2
        static let legendFont = Font.system(size: 10, design: .monospaced)

        // MARK: - Stat cards

        static let sectionSpacing: CGFloat = 12
        static let statSpacing: CGFloat = 6
        static let statCardPadding: CGFloat = 14
        static let statIconFont = Font.system(size: 12, weight: .bold)
        static let statTitleFont = Font.system(size: 11, weight: .medium)
        static let statValueFont = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let miniSpacing: CGFloat = 4
        static let miniVerticalPadding: CGFloat = 10
        static let miniTitleFont = Font.system(size: 10, weight: .medium)
        static let miniValueFont = Font.system(size: 13, weight: .medium, design: .rounded)
    }
}

// swiftlint:enable no_magic_numbers
