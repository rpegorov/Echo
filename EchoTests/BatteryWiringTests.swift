//
//  BatteryWiringTests.swift
//  EchoTests
//
//  Wiring checks for WAVE 3 integration (BW): AppEnvironment composes a real
//  BatteryService without starting it, and MetricTab respects hasBattery.
//

import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Battery — wiring")
struct BatteryWiringTests {
    @Test("AppEnvironment exposes a BatteryService that init does not start")
    func appEnvironmentDoesNotStartBattery() {
        let suiteName = "EchoTests.battery-wiring.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let environment = AppEnvironment(defaults: defaults, system: SystemLanguages(preferred: { [] }))

        #expect(environment.battery.hasBattery == false)
        #expect(environment.battery.history == BatteryHistory())
    }

    @Test("MetricTab.visibleCases includes .battery only when hasBattery is true")
    func visibleCasesRespectsHasBattery() {
        #expect(!MetricTab.visibleCases(hasBattery: false).contains(.battery))
        #expect(MetricTab.visibleCases(hasBattery: true).contains(.battery))
    }
}
