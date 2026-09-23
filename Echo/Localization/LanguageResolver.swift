//
//  LanguageResolver.swift
//  Echo
//

import Foundation

/// Pure resolution of a `LanguagePreference` into a concrete `AppLanguage`.
enum LanguageResolver {
    static func resolve(_ preference: LanguagePreference, systemPreferred: [String]) -> AppLanguage {
        switch preference {
        case .fixed(let language):
            return language

        case .system:
            let supported = AppLanguage.allCases.map(\.rawValue)
            let matches = Bundle.preferredLocalizations(from: supported, forPreferences: systemPreferred)
            guard let bestMatch = matches.first, let language = AppLanguage(rawValue: bestMatch) else {
                return .en
            }
            return language
        }
    }
}
