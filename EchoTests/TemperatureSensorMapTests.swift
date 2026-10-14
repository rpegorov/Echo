import XCTest
@testable import Echo

final class TemperatureSensorMapTests: XCTestCase {

    func testAppleSiliconWithTgFamilySplitsCPUAndGPU() {
        // Live key families from a MacBook Pro M4 Max dump: uppercase TG/TP/TB/TA
        // keys exist too but belong to other sensor groups.
        let available: Set<String> = [
            "Tp1i", "Tp2X", "Te05", "Te0S", "Tf04", "Tf46", "Tg0K", "Tg1k",
            "TPD0", "TB0T", "TAOL", "TG0H"
        ]

        XCTAssertEqual(TemperatureSensorMap.gpuKeys(available: available), Set(["Tg0K", "Tg1k"]))
        XCTAssertEqual(
            TemperatureSensorMap.cpuKeys(available: available),
            Set(["Tp1i", "Tp2X", "Te05", "Te0S", "Tf04", "Tf46"])
        )
    }

    func testM3ReportsGPUThroughTfKeys() {
        let available: Set<String> = ["Te05", "Tf04", "Tf14", "Tf18", "Tf1A", "TB0T"]

        XCTAssertEqual(TemperatureSensorMap.gpuKeys(available: available), Set(["Tf14", "Tf18", "Tf1A"]))
        XCTAssertEqual(TemperatureSensorMap.cpuKeys(available: available), Set(["Te05", "Tf04"]))
    }

    func testIntelMacUsesClassicKeys() {
        let available: Set<String> = ["TC0P", "TC0D", "TG0P", "TB0T"]

        XCTAssertEqual(TemperatureSensorMap.gpuKeys(available: available), Set(["TG0P"]))
        XCTAssertEqual(TemperatureSensorMap.cpuKeys(available: available), Set(["TC0P", "TC0D"]))
    }

    func testNoCandidatesYieldsEmptySets() {
        XCTAssertEqual(TemperatureSensorMap.cpuKeys(available: []), [])
        XCTAssertEqual(TemperatureSensorMap.gpuKeys(available: []), [])
    }
}
