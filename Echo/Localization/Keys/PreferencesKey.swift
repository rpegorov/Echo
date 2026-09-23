//
//  PreferencesKey.swift
//  Echo
//

import Foundation

/// Strings for the Preferences window (S2a owns cases and the Preferences table).
enum PreferencesKey: LocalizedKey {
    static var table: String { "Preferences" }

    var rawValue: String {
        switch self {}
    }
    init?(rawValue: String) { nil }
    static var allCases: [PreferencesKey] { [] }
}
