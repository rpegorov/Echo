//
//  ArrangementNameSheet.swift
//  Echo
//

import SwiftUI

/// Asks for the name of the arrangement about to be remembered.
struct ArrangementNameSheet: View {
    /// Saves under the trimmed name; returns the message to show when it could not be saved, nil on success.
    let onSave: (String) -> String?

    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var failure: String?
    @FocusState private var nameFocused: Bool

    private typealias Tokens = DS.Arrangements

    init(defaultName: String, onSave: @escaping (String) -> String?) {
        self.onSave = onSave
        _name = State(initialValue: defaultName)
    }

    private var trimmedName: String? { ArrangementPresentation.trimmedName(name) }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.sheetSpacing) {
            Text(loc.t(InputKey.arrangementNameLabel)).font(Tokens.titleFont)
            TextField(loc.t(InputKey.arrangementNameLabel), text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onSubmit(save)
                .accessibilityLabel(loc.t(InputKey.arrangementNameLabel))
            if let failure { ArrangementMessageLine(text: failure) }
            HStack(spacing: Tokens.sheetButtonSpacing) {
                Spacer(minLength: 0)
                Button(loc.t(CommonKey.cancel)) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(loc.t(InputKey.gridEditorSave), action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName == nil)
            }
        }
        .padding(Tokens.sheetPadding)
        .frame(width: Tokens.sheetWidth)
        .onAppear { nameFocused = true }
    }

    private func save() {
        guard let trimmedName else { return }
        failure = onSave(trimmedName)
        if failure == nil { dismiss() }
    }
}
