//
//  SystemLanguages.swift
//  Echo
//

import Foundation

/// Reads the user's preferred system languages. Injectable so `LanguageResolver` can be tested
/// without depending on the real system preferences.
struct SystemLanguages: Sendable {
    var preferred: @Sendable () -> [String]

    static let live = SystemLanguages(
        preferred: {
            if let value = CFPreferencesCopyValue(
                "AppleLanguages" as CFString,
                kCFPreferencesAnyApplication,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            ) as? [String], !value.isEmpty {
                return value
            }
            return Locale.preferredLanguages
        }
    )
}
