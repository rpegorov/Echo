import XCTest
@testable import Echo

final class SMCValueDecoderTests: XCTestCase {

    func testFloatTypeDecodesLittleEndianFloat32() throws {
        // 33.4 °C read live from key TB0T on a MacBook Pro M4 Max
        let value = try XCTUnwrap(SMCValueDecoder.value(dataType: "flt ", dataSize: 4, bytes: [0x98, 0x99, 0x05, 0x42]))
        XCTAssertEqual(value, 33.4, accuracy: 0.01)
    }

    func testFpe2DividesByFour() {
        // 0x0144 = 324 → 81.0
        XCTAssertEqual(SMCValueDecoder.value(dataType: "fpe2", dataSize: 2, bytes: [0x01, 0x44]), 81.0)
    }

    func testSp78HandlesSignedValues() throws {
        // 0xFF38 = -200 → -200/256
        let value = try XCTUnwrap(SMCValueDecoder.value(dataType: "sp78", dataSize: 2, bytes: [0xFF, 0x38]))
        XCTAssertEqual(value, -0.78, accuracy: 0.01)
    }

    func testUnknownTypeReturnsNil() {
        XCTAssertNil(SMCValueDecoder.value(dataType: "ioft", dataSize: 8, bytes: [0x00, 0x00, 0x21, 0x00, 0, 0, 0, 0]))
    }

    func testShortPayloadReturnsNil() {
        XCTAssertNil(SMCValueDecoder.value(dataType: "flt ", dataSize: 4, bytes: [0x01, 0x02]))
    }
}
