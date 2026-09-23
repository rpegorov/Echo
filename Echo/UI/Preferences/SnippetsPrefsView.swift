//
//  SnippetsPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: сниппеты — сокращение разворачивается в текст.
struct SnippetsPrefsView: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var settings: AppSettings
    @EnvironmentObject private var loc: Localizer

    @State private var abbreviation = ""
    @State private var expansion = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle(loc.t(InputKey.snippetsTitle))

            PrefCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc.t(InputKey.snippetsHowItWorksTitle))
                        .font(.system(size: 13, weight: .medium))
                    PrefCaption(loc.t(InputKey.snippetsHowItWorksCaption))
                    if !settings.autoConvertEnabled {
                        PrefCaption(loc.t(InputKey.snippetsDisabledWarning))
                            .foregroundStyle(.orange)
                    }
                }
            }

            PrefCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc.t(InputKey.snippetsNewTitle))
                        .font(.system(size: 13, weight: .medium))
                    HStack(spacing: 8) {
                        TextField(loc.t(InputKey.snippetsAbbreviationPlaceholder), text: $abbreviation)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        TextField(loc.t(InputKey.snippetsExpansionPlaceholder), text: $expansion)
                            .textFieldStyle(.roundedBorder)
                        Button(loc.t(InputKey.addButton), action: add)
                            .buttonStyle(.borderedProminent)
                            .tint(DS.accent)
                            .disabled(abbreviation.isEmpty || expansion.isEmpty)
                    }
                }
            }

            if store.snippets.isEmpty {
                PrefCard {
                    PrefCaption(loc.t(InputKey.snippetsEmptyCaption))
                }
            } else {
                PrefCard {
                    VStack(spacing: 0) {
                        ForEach(store.snippets) { snippet in
                            row(snippet)
                            if snippet != store.snippets.last { Divider().opacity(0.12) }
                        }
                    }
                }
            }
        }
    }

    private func row(_ snippet: Snippet) -> some View {
        HStack(spacing: 10) {
            Text(snippet.abbreviation)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(snippet.expansion)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                store.remove(snippet)
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 7)
    }

    private func add() {
        store.add(abbreviation: abbreviation, expansion: expansion)
        abbreviation = ""
        expansion = ""
    }
}
