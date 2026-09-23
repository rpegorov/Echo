//
//  BatteryPresentationTests.swift
//  EchoTests
//
//  Pure BatteryPresentation mapping only (symbol / tint / status). No view
//  rendering — see BatteryRow for the SwiftUI wiring.
//

import Testing
@testable import Echo
import SwiftUI

@Suite("BatteryPresentation")
struct BatteryPresentationTests {

    // MARK: Positive

    @Test("100% on AC power without charging maps to .charged, not .onBattery")
    func fullyChargedOnACIsCharged() {
        let status = BatteryPresentation.status(isCharging: false, isOnAC: true, level: 100)
        #expect(status == .charged)
    }

    @Test("On AC power below 100% without charging maps to .onPowerAdapter")
    func partiallyChargedOnACIsOnPowerAdapter() {
        let status = BatteryPresentation.status(isCharging: false, isOnAC: true, level: 80)
        #expect(status == .onPowerAdapter)
    }

    @Test("Charging always tints green and shows the bolt symbol, regardless of level")
    func chargingIsAlwaysGreenWithBoltSymbol() {
        #expect(BatteryPresentation.tintColor(isCharging: true, level: 5) == .green)
        #expect(BatteryPresentation.symbolName(isCharging: true, level: 5) == "battery.100.bolt")
    }

    @Test("Not on AC and not charging maps to .onBattery")
    func notOnACAndNotChargingIsOnBattery() {
        let status = BatteryPresentation.status(isCharging: false, isOnAC: false, level: 50)
        #expect(status == .onBattery)
    }

    // MARK: Negative / boundary

    @Test("15% while unplugged tints orange")
    func fifteenPercentTintsOrange() {
        #expect(BatteryPresentation.tintColor(isCharging: false, level: 15) == .orange)
    }

    @Test("5% while unplugged tints red")
    func fivePercentTintsRed() {
        #expect(BatteryPresentation.tintColor(isCharging: false, level: 5) == .red)
    }

    @Test("Charging overrides .onBattery even at a critically low level")
    func chargingOverridesOnBatteryStatus() {
        let status = BatteryPresentation.status(isCharging: true, isOnAC: false, level: 1)
        #expect(status == .charging)
    }

    @Test("Symbol steps down from battery.100 at the 88% boundary")
    func symbolStepsAtEightyEightPercentBoundary() {
        #expect(BatteryPresentation.symbolName(isCharging: false, level: 88) == "battery.100")
        #expect(BatteryPresentation.symbolName(isCharging: false, level: 87) == "battery.75")
    }
}
