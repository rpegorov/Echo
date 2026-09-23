//
//  BatteryTimelineTests.swift
//  EchoTests
//
//  Tests written against the WAVE 3 plan contract for BatteryTimeline (task B5):
//  "maxGap 12 min; segments(_:); chargingIntervals(_:)". Pure, no fakes needed.
//

import Testing
@testable import Echo
import Foundation

private let base = Date(timeIntervalSince1970: 1_700_000_000)

private func reading(_ offsetMinutes: Double, charging: Bool = false, onAC: Bool = false) -> BatteryReading {
    BatteryReading(
        date: base.addingTimeInterval(offsetMinutes * 60),
        level: 50,
        isCharging: charging,
        isOnAC: onAC
    )
}

@Suite("BatteryTimeline — requirement B5")
struct BatteryTimelineTests {

    // MARK: Positive

    @Test("[wiring] A gap larger than maxGap (12 min) splits readings into separate segments")
    func gapLargerThanMaxGapSplitsSegments() {
        let readings = [reading(0), reading(5), reading(5 + 13)]

        let segments = BatteryTimeline.segments(readings)

        #expect(segments.count == 2)
        #expect(segments[0] == [readings[0], readings[1]])
        #expect(segments[1] == [readings[2]])
    }

    @Test("Readings with gaps under maxGap stay in a single segment")
    func contiguousReadingsStayInOneSegment() {
        let readings = [reading(0), reading(5), reading(10), reading(15)]

        let segments = BatteryTimeline.segments(readings)

        #expect(segments.count == 1)
        #expect(segments.first?.count == 4)
    }

    @Test("Consecutive charging readings merge into a single charging interval")
    func consecutiveChargingReadingsMerge() {
        let readings = [
            reading(0, charging: true),
            reading(5, charging: true),
            reading(10, charging: true),
            reading(15, charging: false),
        ]

        let intervals = BatteryTimeline.chargingIntervals(readings)

        #expect(intervals.count == 1)
        #expect(intervals.first?.lowerBound == readings[0].date)
        #expect(intervals.first?.upperBound == readings[2].date)
    }

    @Test("Multiple gaps larger than maxGap produce one segment per contiguous run")
    func multipleGapsProduceMultipleSegments() {
        let readings = [
            reading(0), reading(5),
            reading(5 + 20), reading(5 + 20 + 5),
            reading(5 + 20 + 5 + 20),
        ]

        let segments = BatteryTimeline.segments(readings)

        #expect(segments.count == 3)
        #expect(segments.flatMap { $0 }.count == readings.count)
    }

    // MARK: Negative

    @Test("Empty input produces no segments and no charging intervals")
    func emptyInputProducesNothing() {
        #expect(BatteryTimeline.segments([]).isEmpty)
        #expect(BatteryTimeline.chargingIntervals([]).isEmpty)
    }

    @Test("No charging readings at all produces an empty list of charging intervals")
    func noChargingProducesEmptyIntervals() {
        let readings = [reading(0), reading(5), reading(10)]

        #expect(BatteryTimeline.chargingIntervals(readings).isEmpty)
    }

    @Test("A single reading forms its own one-element segment")
    func singleReadingFormsOneSegment() {
        let only = reading(0)

        let segments = BatteryTimeline.segments([only])

        #expect(segments.count == 1)
        #expect(segments.first == [only])
    }

    @Test("A non-charging reading interrupts what would otherwise be one merged charging interval")
    func nonChargingReadingInterruptsChargingRun() {
        let readings = [
            reading(0, charging: true),
            reading(5, charging: false),
            reading(10, charging: true),
        ]

        let intervals = BatteryTimeline.chargingIntervals(readings)

        #expect(intervals.count == 2)
    }
}
