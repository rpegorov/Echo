//
//  BatteryHistoryStore.swift
//  Echo
//

import Foundation
import os

/// Persists battery readings and energy intervals as JSON Lines (one record
/// per line) so appends never require rewriting the whole file. Corrupt or
/// unknown-version lines are skipped and logged rather than failing the read.
actor BatteryHistoryStore: BatteryHistoryStoring {

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Echo",
        category: "BatteryHistoryStore"
    )

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL) {
        self.fileURL = fileURL
        let encoder = JSONEncoder()
        // `.iso8601` truncates to whole seconds, so a round trip through this
        // store would silently drop sub-second precision and break equality
        // on the decoded `Date`. `.secondsSince1970`/`.millisecondsSince1970`
        // fare no better: converting to a 1970 epoch adds a subtraction of
        // two large `Double`s (`timeIntervalSinceReferenceDate` minus the
        // ~978M-second 2001 offset) that itself loses precision. `.deferredToDate`
        // encodes `Date`'s own `timeIntervalSinceReferenceDate` verbatim, with
        // no epoch conversion, so the round trip is exact.
        encoder.dateEncodingStrategy = .deferredToDate
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        self.decoder = decoder
    }

    /// Default location: `~/Library/Application Support/<bundle id>/battery-history.jsonl`.
    /// Creates the containing directory if it does not exist.
    static func defaultURL() throws -> URL {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw BatteryError.storage("Application Support directory unavailable")
        }
        let bundleID = Bundle.main.bundleIdentifier ?? "Echo"
        let directory = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("battery-history.jsonl", isDirectory: false)
    }

    func load(since: Date) async throws -> BatteryHistory {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return BatteryHistory()
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw BatteryError.storage("Failed to read battery history: \(error.localizedDescription)")
        }

        var readings: [BatteryReading] = []
        var intervals: [EnergyInterval] = []

        for line in splitLines(of: data) where !line.isEmpty {
            guard let record = decodeRecord(line) else { continue }
            switch record.kind {
            case .reading:
                if let reading = record.reading, reading.date >= since {
                    readings.append(reading)
                }
            case .interval:
                if let interval = record.interval, interval.end >= since {
                    intervals.append(interval)
                }
            }
        }

        return BatteryHistory(readings: readings, intervals: intervals)
    }

    func append(_ reading: BatteryReading) async throws {
        try appendRecord(BatteryHistoryRecord(reading: reading))
    }

    func append(_ interval: EnergyInterval) async throws {
        try appendRecord(BatteryHistoryRecord(interval: interval))
    }

    func compact(keepingSince: Date) async throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        let history = try await load(since: keepingSince)
        var lines: [Data] = []
        lines.reserveCapacity(history.readings.count + history.intervals.count)
        for reading in history.readings {
            lines.append(try encoder.encode(BatteryHistoryRecord(reading: reading)))
        }
        for interval in history.intervals {
            lines.append(try encoder.encode(BatteryHistoryRecord(interval: interval)))
        }

        var contents = Data()
        for line in lines {
            contents.append(line)
            contents.append(0x0A)
        }

        let tempURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(".\(fileURL.lastPathComponent).tmp-\(UUID().uuidString)")

        do {
            try contents.write(to: tempURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw BatteryError.storage("Failed to compact battery history: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func appendRecord(_ record: BatteryHistoryRecord) throws {
        let line: Data
        do {
            line = try encoder.encode(record)
        } catch {
            throw BatteryError.storage("Failed to encode battery history record: \(error.localizedDescription)")
        }

        var payload = line
        payload.append(0x0A)

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: fileURL.path) {
            let directory = fileURL.deletingLastPathComponent()
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                fileManager.createFile(atPath: fileURL.path, contents: nil)
            } catch {
                throw BatteryError.storage("Failed to create battery history file: \(error.localizedDescription)")
            }
        }

        do {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: payload)
        } catch {
            throw BatteryError.storage("Failed to append battery history record: \(error.localizedDescription)")
        }
    }

    private func splitLines(of data: Data) -> [Data] {
        data.split(separator: 0x0A, omittingEmptySubsequences: true).map { Data($0) }
    }

    private func decodeRecord(_ line: Data) -> BatteryHistoryRecord? {
        guard let record = try? decoder.decode(BatteryHistoryRecord.self, from: line) else {
            Self.log.error("Skipping corrupt battery history line (\(line.count) bytes)")
            return nil
        }
        guard record.v == batteryHistoryRecordVersion else {
            Self.log.error("Skipping battery history line with unsupported version \(record.v)")
            return nil
        }
        return record
    }
}
