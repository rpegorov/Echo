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

/// Сведения о приложении для разделов настроек.
enum AppInfo {
    static var name: String {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
            ?? "Echo"
    }

    static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    /// Подпись интервала опроса — общая для мониторинга и энергосбережения.
    static func intervalLabel(_ seconds: Double) -> String {
        seconds < 1
            ? String(format: "every %.1fs", seconds)
            : String(format: "every %gs", seconds)
    }
}
