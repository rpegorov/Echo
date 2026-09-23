//
//  BatteryHistoryStoreTests.swift
//  EchoTests
//
//  Tests written against the WAVE 3 plan contract for BatteryHistoryStore
//  (task B3): JSONL in a file, one record per line, corrupt lines skipped,
//  compact drops old records, missing file loads empty. We only rely on the
//  public BatteryHistoryStoring API plus raw line manipulation for corruption,
//  never on the exact JSON schema (that is B3's own implementation detail).
//

import Testing
@testable import Echo
import Foundation

@Suite("BatteryHistoryStore — requirement B3")
struct BatteryHistoryStoreTests {

    private func makeTempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoTests-battery-\(UUID().uuidString)")
            .appendingPathComponent("battery-history.jsonl")
    }

    private func sampleReading(_ offsetSeconds: TimeInterval, date base: Date = .now) -> BatteryReading {
        BatteryReading(date: base.addingTimeInterval(offsetSeconds), level: 42, isCharging: false, isOnAC: false)
    }

    private func sampleInterval(_ start: Date, _ end: Date) -> EnergyInterval {
        EnergyInterval(
            start: start,
            end: end,
            totalEnergyNJ: 1_000,
            top: [AppEnergyUsage(id: "app.sample", appName: "Sample App", bundleID: "app.sample", energyNJ: 1_000)]
        )
    }

    // MARK: Positive

    @Test("[wiring] Appended readings and intervals round-trip through load")
    func appendLoadRoundTrip() async throws {
        let url = makeTempFileURL()
        let store = BatteryHistoryStore(fileURL: url)

        let reading = sampleReading(0)
        let interval = sampleInterval(.now.addingTimeInterval(-300), .now)
        try await store.append(reading)
        try await store.append(interval)

        let history = try await store.load(since: .distantPast)

        #expect(history.readings.contains(reading))
        #expect(history.intervals.contains(interval))
    }

    @Test("compact(keepingSince:) drops records older than the cutoff and keeps newer ones")
    func compactDropsOldRecords() async throws {
        let url = makeTempFileURL()
        let store = BatteryHistoryStore(fileURL: url)
        let now = Date.now
        let old = sampleReading(0, date: now.addingTimeInterval(-48 * 3600))
        let recent = sampleReading(0, date: now)
        try await store.append(old)
        try await store.append(recent)

        try await store.compact(keepingSince: now.addingTimeInterval(-24 * 3600))
        let history = try await store.load(since: .distantPast)

        #expect(!history.readings.contains(old))
        #expect(history.readings.contains(recent))
    }

    @Test("A corrupt line in the middle of the file is skipped; surrounding valid lines still load")
    func corruptMiddleLineIsSkipped() async throws {
        let url = makeTempFileURL()
        let store = BatteryHistoryStore(fileURL: url)
        let first = sampleReading(0)
        let second = sampleReading(600)
        try await store.append(first)
        try await store.append(second)

        // Splice a garbage line between the two valid ones written above.
        var lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        #expect(lines.count == 2)
        lines.insert("{not-even-json", at: 1)
        try lines.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)

        let history = try await store.load(since: .distantPast)

        #expect(history.readings.contains(first))
        #expect(history.readings.contains(second))
        #expect(history.readings.count == 2)
    }

    @Test("load(since:) filters out records older than the given date")
    func loadFiltersBySince() async throws {
        let url = makeTempFileURL()
        let store = BatteryHistoryStore(fileURL: url)
        let now = Date.now
        let old = sampleReading(0, date: now.addingTimeInterval(-3600))
        let recent = sampleReading(0, date: now)
        try await store.append(old)
        try await store.append(recent)

        let history = try await store.load(since: now.addingTimeInterval(-60))

        #expect(!history.readings.contains(old))
        #expect(history.readings.contains(recent))
    }

    // MARK: Negative

    @Test("Loading from a missing file returns an empty history without throwing")
    func missingFileLoadsEmptyHistory() async throws {
        let url = makeTempFileURL()
        let store = BatteryHistoryStore(fileURL: url)

        let history = try await store.load(since: .distantPast)

        #expect(history.readings.isEmpty)
        #expect(history.intervals.isEmpty)
    }

    @Test("A file containing only corrupt lines loads as empty history, not a thrown error")
    func onlyCorruptLinesLoadsEmpty() async throws {
        let url = makeTempFileURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try "garbage line one\nnot json either\n".write(to: url, atomically: true, encoding: .utf8)
        let store = BatteryHistoryStore(fileURL: url)

        let history = try await store.load(since: .distantPast)

        #expect(history.readings.isEmpty)
        #expect(history.intervals.isEmpty)
    }

    @Test("compact on a missing file does not throw")
    func compactOnMissingFileDoesNotThrow() async throws {
        let url = makeTempFileURL()
        let store = BatteryHistoryStore(fileURL: url)

        try await store.compact(keepingSince: .now)
    }

    @Test("Appending when the parent directory cannot be created surfaces a storage error")
    func appendToUnwritableLocationThrows() async throws {
        // A regular file in place of the parent directory: no directory can be
        // created there, so writing the JSONL file underneath must fail.
        let blockerParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoTests-battery-blocker-\(UUID().uuidString)")
        try Data().write(to: blockerParent)
        defer { try? FileManager.default.removeItem(at: blockerParent) }
        let url = blockerParent.appendingPathComponent("battery-history.jsonl")
        let store = BatteryHistoryStore(fileURL: url)

        await #expect(throws: Error.self) {
            try await store.append(sampleReading(0))
        }
    }
}
