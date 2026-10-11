import CoreGraphics
import Foundation
@testable import Echo

// Builders shared by the capture, matcher and planner suites.

/// SplitMix64: a fixed seed gives the same sequence on every machine.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

func snapshotWindow(
    _ bundleID: String = "com.apple.Terminal", appName: String = "Terminal", title: String? = nil,
    pid: Int32 = 1, ordinal: Int = 0, frame: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100)
) -> WindowSnapshot {
    WindowSnapshot(
        ref: WindowRef(pid: pid, ordinal: ordinal), bundleID: bundleID, appName: appName, title: title, frame: frame)
}

func snapshotDisplay(
    key: String? = "uuid:AAAA", name: String = "Studio Display",
    frame: CGRect = CGRect(x: 0, y: 0, width: 1000, height: 800),
    visible: CGRect? = nil, zones: [UnitRect] = GridTemplate.twoColumns.zones
) -> DisplaySnapshot {
    DisplaySnapshot(
        key: key.map { DisplayKey(rawValue: $0) }, name: name, frame: frame,
        visibleFrame: visible ?? frame, zones: zones)
}

/// Ids `A2000000-...-n` in generation order.
final class SequentialIDs {
    private var counter = 0

    func next() -> UUID {
        counter += 1
        return UUID(uuidString: String(format: "A2000000-0000-4000-8000-%012d", counter)) ?? UUID()
    }
}
