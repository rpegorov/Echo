//
//  SMCValueDecoder.swift
//  Echo
//

import Foundation

/// Decodes SMC key payloads by their four-char data type. The fixed-point
/// formats come from the classic SMC tooling family (smcFanControl, smctemp);
/// Apple Silicon temperature keys use "flt " — a little-endian float32.
enum SMCValueDecoder {

    private static let floatType = "flt "
    private static let floatSize = 4
    private static let wordSize = 2
    private static let byteSize = 1
    private static let bitsPerByte = 8

    // swiftlint:disable no_magic_numbers
    // lint-allow: no_magic_numbers SMC fixed-point divisors are the wire-format definitions, named by key
    private static let unsignedDivisors: [String: Double] = [
        "fpe2": 4, "fp5b": 2048, "fp6a": 1024, "fp88": 256, "fpa6": 64, "fpc4": 16
    ]
    private static let signedDivisors: [String: Double] = [
        "sp5a": 1024, "sp78": 256, "sp87": 128, "sp96": 64, "spb4": 16
    ]
    // swiftlint:enable no_magic_numbers

    /// Numeric value of a key payload, or nil for an unknown type/size.
    static func value(dataType: String, dataSize: Int, bytes: [UInt8]) -> Double? {
        let word = firstWord(bytes)
        switch (dataType, dataSize) {
        case (floatType, floatSize):
            return floatValue(bytes)
        case ("ui16", wordSize):
            return word.map(Double.init)
        case ("si16", wordSize):
            return word.map { Double(Int16(bitPattern: $0)) }
        case ("ui8 ", byteSize):
            return bytes.first.map(Double.init)
        case ("si8 ", byteSize):
            return bytes.first.map { Double(Int8(bitPattern: $0)) }
        case (_, wordSize):
            if let divisor = unsignedDivisors[dataType] {
                return word.map { Double($0) / divisor }
            }
            if let divisor = signedDivisors[dataType] {
                return word.map { Double(signed($0)) / divisor }
            }
            return nil
        default:
            return nil
        }
    }

    private static func firstWord(_ bytes: [UInt8]) -> UInt16? {
        guard bytes.count >= wordSize else { return nil }
        return bytes.prefix(wordSize).reduce(UInt16.zero) { ($0 << UInt16(bitsPerByte)) | UInt16($1) }
    }

    private static func floatValue(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= floatSize else { return nil }
        return Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
    }

    private static func signed(_ value: UInt16) -> Int16 {
        Int16(bitPattern: value)
    }
}
