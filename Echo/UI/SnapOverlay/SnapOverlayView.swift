//
//  SnapOverlayView.swift
//  Echo
//

import SwiftUI

/// Shared render state of the snap overlay; one instance observed by every display's window.
@MainActor
final class SnapOverlayModel: ObservableObject {
    /// Full frame of the display the zone is currently shown on.
    @Published var activeDisplay: CGRect?
    /// Zone rect in window-local SwiftUI coordinates (origin top-left of the display).
    @Published var zone: CGRect = .zero
    @Published var layout: WindowLayout?
    @Published var shortcut: KeyboardShortcut?
    /// `visible` drives opacity; `settled` separately drives the appear scale so a hide only fades.
    @Published var visible = false
    @Published var settled = false
}

/// The translucent snap zone drawn inside a full-screen transparent window.
/// `display` selects which window this instance paints for; only the active display shows a zone.
struct SnapOverlayView: View {
    @ObservedObject private var model: SnapOverlayModel
    private let display: CGRect

    @EnvironmentObject private var localizer: Localizer

    init(model: SnapOverlayModel, display: CGRect) {
        self.model = model
        self.display = display
    }

    var body: some View {
        let isActive = model.visible && model.activeDisplay == display
        ZStack {
            RoundedRectangle(cornerRadius: DS.SnapOverlay.cornerRadius)
                .fill(DS.accent.opacity(DS.SnapOverlay.fillOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.SnapOverlay.cornerRadius)
                        .strokeBorder(DS.accent.opacity(DS.SnapOverlay.strokeOpacity), lineWidth: DS.SnapOverlay.strokeWidth)
                )
            caption
                .padding(.horizontal, DS.SnapOverlay.capsuleHorizontalPadding)
                .padding(.vertical, DS.SnapOverlay.capsuleVerticalPadding)
                .background(Capsule().fill(DS.accent.opacity(DS.SnapOverlay.capsuleFillOpacity)))
                .foregroundStyle(DS.SnapOverlay.captionForeground)
                .padding(.horizontal, DS.SnapOverlay.captionInset)
        }
        .opacity(isActive ? 1 : 0)
        .scaleEffect(model.settled && isActive ? 1 : DS.SnapOverlay.appearScale)
        .frame(width: model.zone.width, height: model.zone.height)
        .position(x: model.zone.midX, y: model.zone.midY)
    }

    private var caption: some View {
        let name = model.layout.map { localizer.t($0.command.titleKey) } ?? ""
        let full = model.shortcut.map { name + " " + $0.displayString(spaceName: localizer.t(InputKey.keySpace)) }
        return Text(full ?? name)
            .font(.system(size: DS.SnapOverlay.captionFontSize, weight: .medium))
            .lineLimit(DS.SnapOverlay.captionLineLimit)
            .minimumScaleFactor(DS.SnapOverlay.captionMinimumScaleFactor)
    }
}
