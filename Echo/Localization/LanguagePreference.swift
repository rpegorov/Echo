//
//  LanguagePreference.swift
//  Echo
//

import Foundation

/// User's language choice: follow the system, or a fixed language.
enum LanguagePreference: Hashable, Sendable, RawRepresentable {
    case system
    case fixed(AppLanguage)

    init?(rawValue: String) {
        if rawValue == "system" {
            self = .system
        } else if let language = AppLanguage(rawValue: rawValue) {
            self = .fixed(language)
        } else {
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .system: return "system"
        case .fixed(let language): return language.rawValue
        }
    }

    /// All choices offered in the language picker, in display order.
    static var allOptions: [LanguagePreference] {
        [.system] + AppLanguage.allCases.map(Self.fixed)
    }
}
