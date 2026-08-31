//
//  SnippetsPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: сниппеты — сокращение разворачивается в текст.
struct SnippetsPrefsView: View {
    @ObservedObject var store: SnippetStore
    @ObservedObject var settings: AppSettings

    @State private var abbreviation = ""
    @State private var expansion = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle("Сниппеты")

            PrefCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Как это работает")
                        .font(.system(size: 13, weight: .medium))
                    PrefCaption("Набираете сокращение, ставите пробел — на его месте оказывается заданный текст. Регистр и раскладка не важны: «ЬЬ» найдёт сниппет «mm».")
                    if !settings.autoConvertEnabled {
                        PrefCaption("Сейчас не работает: сниппеты используют тот же перехват набора, что и автоисправление раскладки. Включите его в разделе Ultra Switch.")
                            .foregroundStyle(.orange)
                    }
                }
            }

            PrefCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Новый сниппет")
                        .font(.system(size: 13, weight: .medium))
                    HStack(spacing: 8) {
                        TextField("сокращение", text: $abbreviation)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        TextField("во что разворачивается", text: $expansion)
                            .textFieldStyle(.roundedBorder)
                        Button("Добавить", action: add)
                            .buttonStyle(.borderedProminent)
                            .tint(DS.accent)
                            .disabled(abbreviation.isEmpty || expansion.isEmpty)
                    }
                }
            }

            if store.snippets.isEmpty {
                PrefCard {
                    PrefCaption("Пока ни одного сниппета. Обычно сюда кладут почту, подпись, номер телефона и заготовки писем.")
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
