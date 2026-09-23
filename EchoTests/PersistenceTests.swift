//
//  PersistenceTests.swift
//  EchoTests
//
//  Wave-1 review finding: ClipboardService(defaults:) and
//  SystemUtilitiesService(defaults:) must restore isEnabled /
//  preventSleepEnabled from UserDefaults and persist changes back to it.
//  keyboardCleaningEnabled is explicitly NOT restored across launches.
//  Each test uses its own ephemeral UserDefaults(suiteName:) so runs never
//  see another test's or the developer's real state.
//

import Testing
@testable import Echo
import Foundation

@MainActor
private func ephemeralDefaults() -> UserDefaults {
    let suiteName = "EchoTests.Persistence.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    return defaults
}

@MainActor
@Suite("Clipboard/Utilities persistence — wave-1 review finding")
struct PersistenceTests {

    // MARK: Positive

    @Test("[wiring] ClipboardService restores isEnabled from a previously stored true value")
    func clipboardRestoresEnabledTrue() {
        let defaults = ephemeralDefaults()
        defaults.set(true, forKey: "clipboard.enabled")

        let service = ClipboardService(defaults: defaults)

        #expect(service.isEnabled == true)
    }

    @Test("ClipboardService persists isEnabled changes back to UserDefaults")
    func clipboardPersistsEnabledChange() {
        let defaults = ephemeralDefaults()
        let service = ClipboardService(defaults: defaults)

        service.isEnabled = true

        #expect(defaults.bool(forKey: "clipboard.enabled") == true)
    }

    @Test("SystemUtilitiesService restores preventSleepEnabled but never keyboardCleaningEnabled")
    func utilitiesRestoresPreventSleepOnlyNotKeyboardCleaning() {
        let defaults = ephemeralDefaults()
        defaults.set(true, forKey: "utilities.preventSleep")

        let service = SystemUtilitiesService(defaults: defaults)

        #expect(service.preventSleepEnabled == true)
        #expect(service.keyboardCleaningEnabled == false)
    }

    @Test("SystemUtilitiesService persists preventSleepEnabled changes back to UserDefaults")
    func utilitiesPersistsPreventSleepChange() {
        let defaults = ephemeralDefaults()
        let service = SystemUtilitiesService(defaults: defaults)

        service.preventSleepEnabled = true

        #expect(defaults.bool(forKey: "utilities.preventSleep") == true)
    }

    // MARK: Negative

    @Test("ClipboardService defaults to disabled when the key is absent")
    func clipboardDefaultsToDisabledWhenKeyMissing() {
        let defaults = ephemeralDefaults()

        let service = ClipboardService(defaults: defaults)

        #expect(service.isEnabled == false)
    }

    @Test("ClipboardService tolerates a wrong-type stored value without crashing")
    func clipboardToleratesWrongTypeStoredValue() {
        let defaults = ephemeralDefaults()
        defaults.set("not-a-bool", forKey: "clipboard.enabled")

        let service = ClipboardService(defaults: defaults)

        #expect(service.isEnabled == false)
    }

    @Test("SystemUtilitiesService defaults preventSleepEnabled to false when the key is absent")
    func utilitiesDefaultsPreventSleepToFalseWhenKeyMissing() {
        let defaults = ephemeralDefaults()

        let service = SystemUtilitiesService(defaults: defaults)

        #expect(service.preventSleepEnabled == false)
    }

    @Test("SystemUtilitiesService tolerates a wrong-type stored preventSleep value without crashing")
    func utilitiesToleratesWrongTypeStoredValue() {
        let defaults = ephemeralDefaults()
        defaults.set("not-a-bool", forKey: "utilities.preventSleep")

        let service = SystemUtilitiesService(defaults: defaults)

        #expect(service.preventSleepEnabled == false)
    }
}
