//
//  AppLanguage.swift
//  Echo
//

import Foundation

/// Supported UI languages. Adding a language later is a new case here plus its translations.
enum AppLanguage: String, CaseIterable, Sendable {
    case en
    case ru

    /// Name shown in the language picker, in the language itself — never translated.
    var nativeName: String {
        switch self {
        case .en: return "English" // l10n-exempt: native language name
        case .ru: return "Русский" // l10n-exempt: native language name
        }
    }

    var localeIdentifier: String { rawValue }

    static let fallback: AppLanguage = .en
}
