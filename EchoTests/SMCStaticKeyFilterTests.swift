import XCTest
@testable import Echo

final class SMCStaticKeyFilterTests: XCTestCase {

    func testConstantKeyBecomesStaticAfterTheWindow() {
        var filter = SMCStaticKeyFilter(sampleThreshold: 2)

        XCTAssertFalse(filter.isStatic(key: "Tf46", value: 103.89))
        XCTAssertFalse(filter.isStatic(key: "Tf46", value: 103.89))
        XCTAssertTrue(filter.isStatic(key: "Tf46", value: 103.89))
        XCTAssertTrue(filter.isStatic(key: "Tf46", value: 103.89))
    }

    func testMovingKeyIsNeverStatic() {
        var filter = SMCStaticKeyFilter(sampleThreshold: 2)

        XCTAssertFalse(filter.isStatic(key: "Tf04", value: 69.5))
        XCTAssertFalse(filter.isStatic(key: "Tf04", value: 69.5))
        XCTAssertFalse(filter.isStatic(key: "Tf04", value: 71.25))
        XCTAssertFalse(filter.isStatic(key: "Tf04", value: 71.25))
        XCTAssertFalse(filter.isStatic(key: "Tf04", value: 71.25))
    }

    func testProvenStaticKeyReentersWhenItMoves() {
        var filter = SMCStaticKeyFilter(sampleThreshold: 1)

        XCTAssertFalse(filter.isStatic(key: "Tf06", value: 99.91))
        XCTAssertTrue(filter.isStatic(key: "Tf06", value: 99.91))
        XCTAssertFalse(filter.isStatic(key: "Tf06", value: 88.5))
        XCTAssertFalse(filter.isStatic(key: "Tf06", value: 88.5))
    }

    func testKeysAreTrackedIndependently() {
        var filter = SMCStaticKeyFilter(sampleThreshold: 1)

        XCTAssertFalse(filter.isStatic(key: "Tf06", value: 99.91))
        XCTAssertFalse(filter.isStatic(key: "Tg0K", value: 67.0))
        XCTAssertTrue(filter.isStatic(key: "Tf06", value: 99.91))
        XCTAssertFalse(filter.isStatic(key: "Tg0K", value: 68.5))
    }
}
