import XCTest
@testable import Echo

final class SMCStaticKeyFilterTests: XCTestCase {

    func testUnmovedKeyIsPresumedStaticFromTheFirstRead() {
        var filter = SMCStaticKeyFilter(sampleThreshold: 2)

        XCTAssertTrue(filter.isStatic(key: "Tf16", value: 105.31))
        XCTAssertTrue(filter.isStatic(key: "Tf16", value: 105.31))
        XCTAssertTrue(filter.isStatic(key: "Tf16", value: 105.31))
    }

    func testMovingKeyJoinsTheMaximumAtItsFirstChange() {
        var filter = SMCStaticKeyFilter(sampleThreshold: 2)

        XCTAssertTrue(filter.isStatic(key: "Tf04", value: 69.5))
        XCTAssertFalse(filter.isStatic(key: "Tf04", value: 71.25))
        XCTAssertFalse(filter.isStatic(key: "Tf04", value: 70.5))
        XCTAssertFalse(filter.isStatic(key: "Tf04", value: 70.5))
    }

    func testSettledConstantReentersAsStaticAfterTheWindow() {
        var filter = SMCStaticKeyFilter(sampleThreshold: 2)

        XCTAssertTrue(filter.isStatic(key: "Tf16", value: 105.31))
        XCTAssertFalse(filter.isStatic(key: "Tf16", value: 103.0))
        XCTAssertFalse(filter.isStatic(key: "Tf16", value: 103.0))
        XCTAssertFalse(filter.isStatic(key: "Tf16", value: 103.0))
        XCTAssertTrue(filter.isStatic(key: "Tf16", value: 103.0))
    }

    func testKeysAreTrackedIndependently() {
        var filter = SMCStaticKeyFilter(sampleThreshold: 1)

        XCTAssertTrue(filter.isStatic(key: "Tf06", value: 99.91))
        XCTAssertTrue(filter.isStatic(key: "Tg0K", value: 67.0))
        XCTAssertFalse(filter.isStatic(key: "Tg0K", value: 68.5))
        XCTAssertFalse(filter.isStatic(key: "Tf06", value: 99.0))
        XCTAssertFalse(filter.isStatic(key: "Tg0K", value: 68.5))
    }
}
