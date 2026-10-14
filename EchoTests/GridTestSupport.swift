import Foundation
import Testing
@testable import Echo

/// Runs `body` in a fresh directory under the system temporary folder and removes it afterwards.
/// Permissions are restored first so a test may make the directory read-only.
func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("EchoGridTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
            try FileManager.default.removeItem(at: directory)
        } catch {
            Issue.record("could not remove the temporary directory: \(error)")
        }
    }
    return try body(directory)
}

func fileNames(in directory: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
}

/// An independent statement of the zone-grid invariant, so tests of the editing operations
/// do not trust the production `isValid` they are checking.
enum ZoneOracle {
    static let epsilon = 1e-6

    static func top(_ zone: UnitRect) -> Double { zone.y + zone.height }

    static func overlapArea(_ a: UnitRect, _ b: UnitRect) -> Double {
        let width = min(a.x + a.width, b.x + b.width) - max(a.x, b.x)
        let height = min(top(a), top(b)) - max(a.y, b.y)
        return width > 0 && height > 0 ? width * height : 0
    }

    static func isInsideUnitSquare(_ zone: UnitRect) -> Bool {
        zone.width > epsilon && zone.height > epsilon
            && zone.x >= -epsilon && zone.y >= -epsilon
            && zone.x + zone.width <= 1 + epsilon && top(zone) <= 1 + epsilon
    }

    /// Top edge descending, then left edge ascending.
    static func isInReadingOrder(_ zones: [UnitRect]) -> Bool {
        zip(zones, zones.dropFirst()).allSatisfy { first, second in
            if top(first) > top(second) + epsilon { return true }
            return abs(top(first) - top(second)) <= epsilon && first.x <= second.x + epsilon
        }
    }

    static func violation(in zones: [UnitRect]) -> String? {
        guard !zones.isEmpty else { return "no zones" }
        if let outside = zones.first(where: { !isInsideUnitSquare($0) }) { return "outside the unit square: \(outside)" }
        for (index, first) in zones.enumerated() {
            for second in zones[(index + 1)...] where overlapArea(first, second) > epsilon * epsilon {
                return "overlap: \(first) and \(second)"
            }
        }
        let total = zones.reduce(0) { $0 + $1.width * $1.height }
        if abs(total - 1) > epsilon * Double(zones.count) { return "total area \(total) is not 1" }
        if !isInReadingOrder(zones) { return "not in reading order" }
        return nil
    }
}
