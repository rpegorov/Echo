//
//  Localizer.swift
//  Echo
//

import Foundation
import os.log

/// Resolves `LocalizedKey`s to strings for the current language and publishes language changes
/// so SwiftUI views and AppKit code can react without a restart.
@MainActor
final class Localizer: ObservableObject {
    @Published private(set) var language: AppLanguage

    private let system: SystemLanguages
    private let bundle: Bundle
    private var lprojBundles: [AppLanguage: Bundle] = [:]

    private static let logger = Logger(subsystem: "com.echo.app", category: "Localization")
    private static let missingSentinel = "\u{1}echo.missing.sentinel\u{1}"

    var locale: Locale { Locale(identifier: language.localeIdentifier) }

    init(preference: LanguagePreference, system: SystemLanguages = .live, bundle: Bundle = .main) {
        self.system = system
        self.bundle = bundle
        self.language = LanguageResolver.resolve(preference, systemPreferred: system.preferred())
    }

    /// Re-resolves the language for a new preference. Publishes only if it actually changed.
    func apply(_ preference: LanguagePreference) {
        let resolved = LanguageResolver.resolve(preference, systemPreferred: system.preferred())
        guard resolved != language else { return }
        language = resolved
    }

    func t<K: LocalizedKey>(_ key: K) -> String {
        lookup(key)
    }

    func t<K: LocalizedKey>(_ key: K, _ args: any CVarArg...) -> String {
        let format = lookup(key)
        return String(format: format, locale: locale, arguments: args)
    }

    private func lookup<K: LocalizedKey>(_ key: K) -> String {
        let rawKey = key.rawValue

        if let value = string(forKey: rawKey, table: K.table, language: language) {
            return value
        }
        if language != .en, let value = string(forKey: rawKey, table: K.table, language: .en) {
            return value
        }
        Self.logger.fault("Missing localization for key \(rawKey, privacy: .public) in table \(K.table, privacy: .public)")
        return rawKey
    }

    private func string(forKey key: String, table: String, language: AppLanguage) -> String? {
        guard let lprojBundle = lprojBundle(for: language) else { return nil }
        let value = lprojBundle.localizedString(forKey: key, value: Self.missingSentinel, table: table)
        return value == Self.missingSentinel ? nil : value
    }

    private func lprojBundle(for language: AppLanguage) -> Bundle? {
        if let cached = lprojBundles[language] { return cached }
        guard let path = bundle.path(forResource: language.localeIdentifier, ofType: "lproj"),
              let lprojBundle = Bundle(path: path) else {
            return nil
        }
        lprojBundles[language] = lprojBundle
        return lprojBundle
    }
}
