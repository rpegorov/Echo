// Each test owns a defaults suite, so the developer's real settings are never touched.

import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Popover metrics style")
struct PopoverMetricsStyleTests {

    @Test("defaults to rings and persists a switch to bars across launches")
    func persistsAcrossLaunches() {
        let defaults = UserDefaults(suiteName: "EchoTests.MetricsStyle.\(UUID().uuidString)")!

        let first = AppSettings(defaults: defaults)
        #expect(first.popoverMetricsStyle == .rings)
        first.popoverMetricsStyle = .bars

        #expect(AppSettings(defaults: defaults).popoverMetricsStyle == .bars)
    }
}
