//
//  PrefComponents.swift
//  MonitorBarApp
//

import SwiftUI

/// Карточка настроек — единый фон и отступы для всех секций Preferences.
struct PrefCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
    }
}

/// Заголовок секции настроек.
struct PrefTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .padding(.bottom, 4)
    }
}

/// Строка с пояснением под заголовком карточки.
struct PrefCaption: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
