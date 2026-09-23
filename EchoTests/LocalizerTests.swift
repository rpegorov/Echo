import Combine
import Foundation
import Testing
@testable import Echo

/// T2 — Localizer core, tested against the plan's contract, not the
/// implementation: resolution, publishing discipline, and the en-fallback
/// lookup chain (real bundle for the wiring case, a fixture bundle for the
/// fallback case so the test does not depend on any real key ever going
/// untranslated).
@Suite("Localizer")
struct LocalizerTests {

    // MARK: Positive

    @Test("wiring: the real en and ru bundles produce different Common.quit text")
    @MainActor
    func realBundlesProduceDifferentQuitText() {
        let ru = Localizer(preference: .fixed(.ru))
        let en = Localizer(preference: .fixed(.en))
        #expect(ru.t(CommonKey.quit) != en.t(CommonKey.quit))
    }

    @Test("system preference resolves to Russian when ru-RU is preferred")
    func systemPreferenceResolvesToRussianForRuRU() {
        let resolved = LanguageResolver.resolve(.system, systemPreferred: ["ru-RU"])
        #expect(resolved == .ru)
    }

    @Test("apply publishes exactly once when the resolved language changes")
    @MainActor
    func applyPublishesOnceOnChange() {
        let localizer = Localizer(preference: .fixed(.en))
        var updates = 0
        let cancellable = localizer.$language.dropFirst().sink { _ in updates += 1 }
        localizer.apply(.fixed(.ru))
        #expect(updates == 1)
        #expect(localizer.language == .ru)
        cancellable.cancel()
    }

    @Test("LanguagePreference round-trips through its rawValue")
    func languagePreferenceRawValueRoundTrip() {
        #expect(LanguagePreference(rawValue: "system") == .system)
        #expect(LanguagePreference(rawValue: "ru") == .fixed(.ru))
        #expect(LanguagePreference(rawValue: "en") == .fixed(.en))
        #expect(LanguagePreference.system.rawValue == "system")
        #expect(LanguagePreference.fixed(.ru).rawValue == "ru")
    }

    // MARK: Negative

    @Test("system preference falls back to English when nothing matches")
    func systemPreferenceFallsBackToEnglish() {
        let resolved = LanguageResolver.resolve(.system, systemPreferred: ["de-DE", "fr"])
        #expect(resolved == .en)
    }

    @Test("an unknown rawValue yields no LanguagePreference")
    func unknownRawValueIsNil() {
        #expect(LanguagePreference(rawValue: "xx") == nil)
    }

    @Test("a key missing from the Russian table falls back to the English value")
    @MainActor
    func missingRussianKeyFallsBackToEnglish() {
        let localizer = Localizer(preference: .fixed(.ru), bundle: FixtureLocator.bundle)
        #expect(localizer.t(FixtureKey.onlyEnglish) == "English only value")
    }

    @Test("apply with an already-resolved language publishes nothing")
    @MainActor
    func applyWithSameLanguagePublishesNothing() {
        let localizer = Localizer(preference: .fixed(.en))
        var updates = 0
        let cancellable = localizer.$language.dropFirst().sink { _ in updates += 1 }
        localizer.apply(.fixed(.en))
        #expect(updates == 0)
        cancellable.cancel()
    }
}

/// Key type used only by these tests, backed by EchoTests/Fixtures/*.lproj —
/// never a real, shipped table.
enum FixtureKey: String, LocalizedKey, CaseIterable {
    case greeting
    case onlyEnglish
    static var table: String { "Fixture" }
}

enum FixtureLocator {
    /// Locates EchoTests/Fixtures via #filePath rather than a resource
    /// bundle: the EchoTests target is host-app-hosted (TEST_HOST =
    /// Echo.app), so there is no `Bundle.module` and no guarantee the
    /// synchronized group copies loose fixture files as resources.
    static var bundle: Bundle {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
        guard let bundle = Bundle(url: directory) else {
            fatalError("Fixture bundle not found at \(directory.path)")
        }
        return bundle
    }
}
