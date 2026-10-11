//
//  ArrangementEditorView.swift
//  Echo
//

import SwiftUI

/// The editor window's content: the name above one canvas per display, messages and buttons below.
struct ArrangementEditorView: View {
    @ObservedObject var model: ArrangementEditorModel
    @ObservedObject var settings: AppSettings
    let onClose: () -> Void

    @EnvironmentObject private var loc: Localizer

    private static let space = NamedCoordinateSpace.named("arrangementEditorCanvases")

    var body: some View {
        VStack(alignment: .leading, spacing: DS.ArrangementEditor.sectionSpacing) {
            toolbar
            canvases
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(loc.t(InputKey.arrangementEditorHint))
                .font(DS.ArrangementEditor.hintFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            messages
            buttons
        }
        .padding(DS.ArrangementEditor.contentPadding)
    }

    private var toolbar: some View {
        HStack(spacing: DS.ArrangementEditor.toolbarSpacing) {
            Text(loc.t(InputKey.arrangementNameLabel))
            TextField(text: $model.name) {
                Text(loc.t(InputKey.arrangementNameLabel))
            }
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: DS.ArrangementEditor.nameFieldMaxWidth)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Canvases

    private var canvases: some View {
        GeometryReader { proxy in
            let displays = model.displays
            let targets = model.moveTargets
            let height = ArrangementEditorLayout.canvasHeight(
                available: proxy.size,
                aspects: displays.map(\.aspect),
                spacing: DS.ArrangementEditor.canvasSpacing,
                captionHeight: DS.ArrangementEditor.captionHeight,
                captionSpacing: DS.ArrangementEditor.captionSpacing
            )
            HStack(alignment: .top, spacing: DS.ArrangementEditor.canvasSpacing) {
                ForEach(displays) { display in
                    let width = height * display.aspect
                    VStack(alignment: .leading, spacing: DS.ArrangementEditor.captionSpacing) {
                        caption(display)
                            .frame(width: width, height: DS.ArrangementEditor.captionHeight, alignment: .leading)
                        ArrangementCanvasView(
                            model: model,
                            display: display,
                            windowGap: settings.windowGap,
                            targets: targets,
                            space: Self.space
                        )
                        .frame(width: width, height: height)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .overlay { dragGhost }
        }
        .coordinateSpace(Self.space)
    }

    private func caption(_ display: ArrangementEditorDisplay) -> some View {
        Text(display.isConnected ? display.name : loc.t(InputKey.arrangementDisplayDisconnected, display.name))
            .font(DS.ArrangementEditor.captionFont)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    /// The dragged icon follows the pointer above every canvas, so it can cross from one display to another.
    @ViewBuilder
    private var dragGhost: some View {
        if let drag = model.drag, let window = model.window(drag.windowID) {
            AppIconView(bundleID: window.bundleID, size: DS.ArrangementEditor.dragIconSize)
                .shadow(
                    color: DS.ArrangementEditor.dragGhostShadow,
                    radius: DS.ArrangementEditor.dragGhostShadowRadius
                )
                .position(drag.location)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Messages and buttons

    @ViewBuilder
    private var messages: some View {
        if model.isReadOnly {
            message(model.loadNotice.map { loc.t($0.messageKey) } ?? loc.t(InputKey.gridUnavailableMessage))
        }
        if let saveMessage = model.saveMessage {
            message(text(for: saveMessage))
        }
    }

    private func message(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.ArrangementEditor.messageSpacing) {
            Image(systemName: DS.ArrangementEditor.messageIcon)
                .foregroundStyle(DS.ArrangementEditor.messageColor)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.ArrangementEditor.messageFont)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var buttons: some View {
        HStack(spacing: DS.ArrangementEditor.buttonSpacing) {
            Spacer(minLength: 0)
            Button(loc.t(CommonKey.cancel), action: onClose)
                .keyboardShortcut(.cancelAction)
            Button(loc.t(InputKey.gridEditorSave)) {
                if model.save() { onClose() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canSave)
        }
    }

    private func text(for message: ArrangementEditorModel.SaveMessage) -> String {
        switch message {
        case .write(let reason): return loc.t(InputKey.gridSaveFailedMessage, reason)
        case .unavailable: return loc.t(InputKey.gridUnavailableMessage)
        case .permission: return loc.t(InputKey.arrangementPermissionMessage)
        case .noWindows: return loc.t(InputKey.arrangementNoWindowsMessage)
        }
    }
}
