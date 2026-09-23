import Foundation
import Testing
@testable import Echo

/// T3 (AppSettings / AppEnvironment / SpeedFormatter) — composition and
/// persistence tested against injected UserDefaults, never `.standard`, so
/// runs never leak state into the developer's real defaults domain.
@Suite("AppEnvironment and settings wiring")
struct AppEnvironmentTests {

    private func ephemeralDefaults(_ suffix: String) -> UserDefaults {
        let suiteName = "EchoTests.\(suffix).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: Positive

    @Test("wiring: changing AppSettings.language reaches AppEnvironment's Localizer")
    @MainActor
    func settingsLanguageChangeReachesLocalizer() {
        let defaults = ephemeralDefaults("environment")
        let environment = AppEnvironment(defaults: defaults, system: SystemLanguages(preferred: { [] }))

        environment.settings.language = .fixed(.ru)
        #expect(environment.localizer.language == .ru)

        environment.settings.language = .fixed(.en)
        #expect(environment.localizer.language == .en)
    }

    @Test("AppSettings persists the chosen language and reloads it from the same defaults")
    func appSettingsPersistsLanguageAcrossInstances() {
        let defaults = ephemeralDefaults("settings")
        let first = AppSettings(defaults: defaults)
        first.language = .fixed(.ru)

        let second = AppSettings(defaults: defaults)
        #expect(second.language == .fixed(.ru))
    }

    @Test("SpeedFormatter switches from KB/s to MB/s at the 1024 KB/s boundary")
    @MainActor
    func speedFormatterSwitchesUnitAt1024() {
        let localizer = Localizer(preference: .fixed(.en))
        let below = SpeedFormatter.format(kbPerSec: 1023, using: localizer)
        let atBoundary = SpeedFormatter.format(kbPerSec: 1024, using: localizer)

        #expect(below.contains("KB"))
        #expect(!below.contains("MB"))
        #expect(atBoundary.contains("MB"))
    }

    // MARK: Negative

    @Test("AppSettings falls back to System when the stored language value is unknown")
    func appSettingsFallsBackToSystemForUnknownStoredValue() {
        let defaults = ephemeralDefaults("unknown-language")
        defaults.set("xx-not-a-language", forKey: AppSettings.Keys.language)

        let settings = AppSettings(defaults: defaults)
        #expect(settings.language == .system)
    }

    @Test("AppSettings falls back to System when no language has ever been stored")
    func appSettingsFallsBackToSystemWhenMissing() {
        let defaults = ephemeralDefaults("missing-language")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.language == .system)
    }
}
