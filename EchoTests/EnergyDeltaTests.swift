//
//  EnergyDeltaTests.swift
//  EchoTests
//
//  Tests written against the WAVE 3 plan contract for EnergyDelta (task B2),
//  not against its implementation. EnergyDelta.topApps is pure: no OS calls,
//  no fakes needed beyond constructing ProcessEnergySnapshot values by hand.
//

import Testing
@testable import Echo
import Foundation

private func snapshot(
    machTime: UInt64,
    _ entries: [(pid: Int32, start: UInt64, energyNJ: UInt64, name: String, path: String?)]
) -> ProcessEnergySnapshot {
    var map: [ProcessKey: ProcessEnergyEntry] = [:]
    for e in entries {
        map[ProcessKey(pid: e.pid, startAbstime: e.start)] =
            ProcessEnergyEntry(energyNJ: e.energyNJ, executablePath: e.path, name: e.name)
    }
    return ProcessEnergySnapshot(date: .now, machTime: machTime, entries: map)
}

@Suite("EnergyDelta.topApps — requirement B2")
struct EnergyDeltaTests {

    // MARK: Positive

    @Test("Same process key: delta is current minus previous energy")
    func sameKeyDelta() {
        let previous = snapshot(machTime: 1_000, [(100, 1, 100, "App A", nil)])
        let current = snapshot(machTime: 2_000, [(100, 1, 150, "App A", nil)])

        let result = EnergyDelta.topApps(previous: previous, current: current, limit: 10)

        #expect(result.total == 50)
        #expect(result.top.count == 1)
        #expect(result.top.first?.appName == "App A")
        #expect(result.top.first?.energyNJ == 50)
    }

    @Test("Reused pid with a new start time after the previous baseline counts as a full counter")
    func newInstanceCountedFromZero() {
        // pid 200 existed before, under a different (older) start time; the OS
        // reused the pid for a brand-new process that started after we last sampled.
        let previous = snapshot(machTime: 5_000, [(200, 1_000, 500, "App B (old instance)", nil)])
        let current = snapshot(machTime: 6_000, [(200, 6_000, 80, "App B", nil)])

        let result = EnergyDelta.topApps(previous: previous, current: current, limit: 10)

        #expect(result.total == 80)
        #expect(result.top.first?.appName == "App B")
        #expect(result.top.first?.energyNJ == 80)
    }

    @Test("Helper processes under a parent .app bundle aggregate into the parent app's name")
    func helperProcessesAggregateIntoParentApp() {
        let helperPath =
            "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework"
            + "/Versions/1/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper"
        let rendererPath =
            "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework"
            + "/Versions/1/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)"

        let previous = snapshot(machTime: 0, [
            (10, 1, 200, "Google Chrome Helper", helperPath),
            (11, 1, 300, "Google Chrome Helper (Renderer)", rendererPath),
        ])
        let current = snapshot(machTime: 1_000, [
            (10, 1, 250, "Google Chrome Helper", helperPath),
            (11, 1, 340, "Google Chrome Helper (Renderer)", rendererPath),
        ])

        let result = EnergyDelta.topApps(previous: previous, current: current, limit: 10)

        #expect(result.total == 90)
        #expect(result.top.count == 1)
        #expect(result.top.first?.appName == "Google Chrome")
        #expect(result.top.first?.energyNJ == 90)
    }

    @Test("Limit caps the returned list and sorts it descending, but total sums every positive delta")
    func limitSortAndGrandTotalInvariant() {
        var entries: [(pid: Int32, start: UInt64, energyNJ: UInt64, name: String, path: String?)] = []
        for i in 1...15 {
            entries.append((Int32(i), UInt64(i), 0, "App \(i)", nil))
        }
        let previous = snapshot(machTime: 0, entries)
        let current = snapshot(
            machTime: 1_000,
            entries.map { ($0.pid, $0.start, UInt64($0.pid), $0.name, $0.path) }
        )

        let result = EnergyDelta.topApps(previous: previous, current: current, limit: 10)

        #expect(result.top.count == 10)
        #expect(result.top == result.top.sorted { $0.energyNJ > $1.energyNJ })
        #expect(result.top.first?.energyNJ == 15)
        #expect(result.total == (1...15).reduce(0, +))
    }

    // MARK: Negative

    @Test("A negative delta (counter went backwards) is skipped, not reported as negative energy")
    func negativeDeltaIsSkipped() {
        let previous = snapshot(machTime: 0, [(300, 1, 200, "App C", nil)])
        let current = snapshot(machTime: 1_000, [(300, 1, 150, "App C", nil)])

        let result = EnergyDelta.topApps(previous: previous, current: current, limit: 10)

        #expect(result.top.isEmpty)
        #expect(result.total == 0)
    }

    @Test("A new key whose start time predates the previous sample's machTime is skipped")
    func staleNewKeyIsSkipped() {
        // startAbstime (4000) is before previous.machTime (5000): this process
        // already existed when we last sampled but under an unseen key — its
        // full counter cannot be trusted as "new since baseline".
        let previous = snapshot(machTime: 5_000, [])
        let current = snapshot(machTime: 6_000, [(400, 4_000, 999, "App D", nil)])

        let result = EnergyDelta.topApps(previous: previous, current: current, limit: 10)

        #expect(result.top.isEmpty)
        #expect(result.total == 0)
    }

    @Test("An exited process is simply absent from the result, not treated as an error")
    func exitedProcessIsLost() {
        let previous = snapshot(machTime: 0, [
            (500, 1, 100, "App E", nil),
            (501, 1, 100, "App F", nil),
        ])
        // App F (pid 501) exited; only App E is present in the new sample.
        let current = snapshot(machTime: 1_000, [(500, 1, 140, "App E", nil)])

        let result = EnergyDelta.topApps(previous: previous, current: current, limit: 10)

        #expect(result.top.count == 1)
        #expect(result.top.first?.appName == "App E")
        #expect(result.total == 40)
    }

    @Test("A limit of zero returns no apps, but the grand total is still every positive delta")
    func zeroLimitStillReportsGrandTotal() {
        let previous = snapshot(machTime: 0, [(600, 1, 10, "App G", nil)])
        let current = snapshot(machTime: 1_000, [(600, 1, 52, "App G", nil)])

        let result = EnergyDelta.topApps(previous: previous, current: current, limit: 0)

        #expect(result.top.isEmpty)
        #expect(result.total == 42)
    }
}
