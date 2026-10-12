//
//  GridEditorView.swift
//  Echo
//

import SwiftUI

/// The editor window's content: name and template above the canvas, messages and buttons below.
struct GridEditorView: View {
    @ObservedObject var model: GridEditorModel
    @ObservedObject var settings: AppSettings
    let onClose: () -> Void

    @EnvironmentObject private var loc: Localizer

    var body: some View {
        VStack(alignment: .leading, spacing: DS.GridEditor.sectionSpacing) {
            toolbar
            GridCanvasView(
                model: model,
                displaySize: model.display?.visibleSize ?? DS.GridEditor.fallbackDisplaySize,
                settings: settings
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(loc.t(InputKey.gridEditorHint))
                .font(DS.GridEditor.hintFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            messages
            buttons
        }
        .padding(DS.GridEditor.contentPadding)
    }

    private var toolbar: some View {
        HStack(spacing: DS.GridEditor.toolbarSpacing) {
            Text(loc.t(InputKey.gridEditorNameLabel))
            TextField(text: $model.name) {
                Text(loc.t(InputKey.gridEditorNameLabel))
            }
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: DS.GridEditor.nameFieldMaxWidth)
            Menu {
                ForEach(GridTemplate.allCases, id: \.self) { template in
                    Button(loc.t(template.titleKey)) { model.applyTemplate(template) }
                }
            } label: {
                Text(loc.t(InputKey.gridEditorTemplateMenu))
            }
            .fixedSize()
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var messages: some View {
        if model.isReadOnly {
            message(model.loadNotice.map { loc.t($0.messageKey) } ?? loc.t(InputKey.gridUnavailableMessage))
        }
        if let error = model.saveError {
            message(text(for: error))
        }
    }

    private func message(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.GridEditor.messageSpacing) {
            Image(systemName: DS.GridEditor.messageIcon)
                .foregroundStyle(DS.GridEditor.messageColor)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.GridEditor.messageFont)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var buttons: some View {
        HStack(spacing: DS.GridEditor.buttonSpacing) {
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

    /// Only a failed write carries a reason of its own; every other error means grids are unavailable.
    private func text(for error: GridStorageError) -> String {
        switch error {
        case .writeFailed(let reason), .readFailed(let reason):
            return loc.t(InputKey.gridSaveFailedMessage, reason)
        case .invalidGrid:
            return loc.t(InputKey.gridInvalidMessage)
        case .locationUnavailable, .unreadable, .newerSchema, .readOnly, .invalidSlot:
            return loc.t(InputKey.gridUnavailableMessage)
        }
    }
}
