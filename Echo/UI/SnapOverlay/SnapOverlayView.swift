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
    /// Bright target rect in window-local SwiftUI coordinates (origin top-left of the display).
    @Published var zone: CGRect = .zero
    /// Every zone of the active grid in the same local coordinates; empty in edge mode.
    @Published var contextFrames: [CGRect] = []
    @Published var layout: WindowLayout?
    /// 1-based numbers of the target zones; empty in edge mode.
    @Published var zoneNumbers: [Int] = []
    @Published var shortcut: KeyboardShortcut?
    /// `visible` drives opacity; `settled` separately drives the appear scale so a hide only fades.
    @Published var visible = false
    @Published var settled = false
}

/// The translucent snap zone drawn inside a full-screen transparent window, with the faint
/// zones of the active grid behind it in grid mode.
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
            gridContext
                .opacity(contextIsVisible(isActive: isActive) ? 1 : 0)
            targetZone
                .opacity(isActive ? 1 : 0)
                .scaleEffect(model.settled && isActive ? 1 : DS.SnapOverlay.appearScale)
                .frame(width: model.zone.width, height: model.zone.height)
                .position(x: model.zone.midX, y: model.zone.midY)
        }
    }

    private func contextIsVisible(isActive: Bool) -> Bool {
        isActive && !model.contextFrames.isEmpty
    }

    private var gridContext: some View {
        ForEach(model.contextFrames.indices, id: \.self) { index in
            RoundedRectangle(cornerRadius: DS.SnapOverlay.contextCornerRadius)
                .fill(DS.accent.opacity(DS.SnapOverlay.contextFillOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.SnapOverlay.contextCornerRadius)
                        .strokeBorder(DS.accent.opacity(DS.SnapOverlay.contextStrokeOpacity), lineWidth: DS.SnapOverlay.contextStrokeWidth)
                )
                .frame(width: model.contextFrames[index].width, height: model.contextFrames[index].height)
                .position(x: model.contextFrames[index].midX, y: model.contextFrames[index].midY)
        }
    }

    private var targetZone: some View {
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
    }

    private var caption: some View {
        Text(captionText)
            .font(.system(size: DS.SnapOverlay.captionFontSize, weight: .medium))
            .lineLimit(DS.SnapOverlay.captionLineLimit)
            .minimumScaleFactor(DS.SnapOverlay.captionMinimumScaleFactor)
    }

    private var captionText: String {
        if let layout = model.layout {
            return commandCaption(for: localizer.t(layout.command.titleKey))
        }
        return gridCaption
    }

    private func commandCaption(for name: String) -> String {
        guard let shortcut = model.shortcut else { return name }
        return name + " " + shortcut.displayString(spaceName: localizer.t(InputKey.keySpace))
    }

    private var gridCaption: String {
        guard model.zoneNumbers.count == 1, let number = model.zoneNumbers.first else {
            return spanCaption
        }
        return commandCaption(for: localizer.t(InputKey.gridZoneNumber, Int64(number)))
    }

    private var spanCaption: String {
        let list = model.zoneNumbers
            .map(String.init)
            .formatted(.list(type: .and).locale(localizer.locale))
        return localizer.t(InputKey.gridZonesSpan, list)
    }
}
