//
//  GridFlashView.swift
//  Echo
//

import SwiftUI

/// One zone of a flashed grid in window-local SwiftUI coordinates (origin top-left of the display).
struct GridFlashZone: Equatable {
    let frame: CGRect
    let number: Int
    let shortcut: KeyboardShortcut?
}

/// Every zone of a grid with its number and hotkey, and the grid name in the middle of the display.
struct GridFlashView: View {
    let zones: [GridFlashZone]
    let title: GridFlash.Title?
    let displaySize: CGSize

    @EnvironmentObject private var localizer: Localizer

    /// Divisor that halves a length, so centring geometry carries no bare literal.
    private static let centerDivisor: CGFloat = 2

    var body: some View {
        ZStack {
            ForEach(zones, id: \.number) { zone in
                zoneView(zone)
                    .frame(width: zone.frame.width, height: zone.frame.height)
                    .position(x: zone.frame.midX, y: zone.frame.midY)
            }
            if let titleText {
                badge(titleText, fontSize: DS.SnapOverlay.flashTitleFontSize)
                    .padding(.horizontal, DS.SnapOverlay.flashTitleHorizontalPadding)
                    .padding(.vertical, DS.SnapOverlay.flashTitleVerticalPadding)
                    .background(Capsule().fill(DS.accent.opacity(DS.SnapOverlay.flashBadgeFillOpacity)))
                    .frame(maxWidth: displaySize.width * DS.SnapOverlay.flashTitleMaxWidthShare)
                    .position(x: displaySize.width / Self.centerDivisor, y: displaySize.height / Self.centerDivisor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titleText ?? "")
    }

    private var titleText: String? {
        switch title {
        case .template(let template): localizer.t(template.titleKey)
        case .named(let name): name
        case nil: nil
        }
    }

    private func zoneView(_ zone: GridFlashZone) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.SnapOverlay.cornerRadius)
                .fill(DS.accent.opacity(DS.SnapOverlay.flashFillOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.SnapOverlay.cornerRadius)
                        .strokeBorder(
                            DS.accent.opacity(DS.SnapOverlay.flashStrokeOpacity),
                            lineWidth: DS.SnapOverlay.flashStrokeWidth)
                )
            VStack(spacing: DS.SnapOverlay.flashContentSpacing) {
                numberBadge(zone.number)
                if let shortcut = zone.shortcut {
                    shortcutBadge(shortcut)
                }
            }
            .padding(.horizontal, DS.SnapOverlay.captionInset)
            .position(x: zone.frame.width / Self.centerDivisor, y: contentY(in: zone.frame))
        }
    }

    /// Tall zones carry their badges above the middle so the title in the display centre never covers them.
    private func contentY(in frame: CGRect) -> CGFloat {
        frame.height >= DS.SnapOverlay.flashRaisedContentMinHeight
            ? frame.height * DS.SnapOverlay.flashRaisedContentShare
            : frame.height / Self.centerDivisor
    }

    private func numberBadge(_ number: Int) -> some View {
        badge(number.formatted(.number.locale(localizer.locale)), fontSize: DS.SnapOverlay.flashNumberFontSize)
            .padding(.horizontal, DS.SnapOverlay.flashBadgeHorizontalPadding)
            .padding(.vertical, DS.SnapOverlay.flashBadgeVerticalPadding)
            .background(Capsule().fill(DS.accent.opacity(DS.SnapOverlay.flashBadgeFillOpacity)))
    }

    private func shortcutBadge(_ shortcut: KeyboardShortcut) -> some View {
        badge(
            shortcut.displayString(spaceName: localizer.t(InputKey.keySpace)),
            fontSize: DS.SnapOverlay.flashShortcutFontSize)
            .padding(.horizontal, DS.SnapOverlay.capsuleHorizontalPadding)
            .padding(.vertical, DS.SnapOverlay.flashBadgeVerticalPadding)
            .background(Capsule().fill(DS.accent.opacity(DS.SnapOverlay.flashBadgeFillOpacity)))
    }

    private func badge(_ text: String, fontSize: CGFloat) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold))
            .lineLimit(DS.SnapOverlay.captionLineLimit)
            .minimumScaleFactor(DS.SnapOverlay.flashBadgeMinimumScaleFactor)
            .foregroundStyle(DS.SnapOverlay.captionForeground)
    }
}
