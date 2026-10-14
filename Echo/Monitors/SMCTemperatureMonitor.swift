//
//  SMCTemperatureMonitor.swift
//  Echo
//

import Foundation
import IOKit

/// Reads CPU/GPU temperatures from the SMC through the AppleSMC user client.
/// Protocol verified on Apple Silicon (M4 Max, macOS 27): method index 2,
/// sub-command in `data8`, key values decoded per their four-char type.
actor SMCTemperatureMonitor: TemperatureMonitoring {

    private enum SMC {
        static let methodIndex: UInt32 = 2
        static let cmdReadBytes: Int8 = 5
        static let cmdKeyByIndex: Int8 = 8
        static let cmdKeyInfo: Int8 = 9
        // Reads outside this range are broken sensors or calibration constants.
        static let plausibleRange: ClosedRange<Double> = 0...130
        static let interestingPrefixes = ["Tp", "Te", "Tf", "Tg", "TC", "TG"]
        static let maxKeyCount: UInt32 = 100_000
    }

    private struct KeyInfo {
        var dataType: String
        var dataSize: Int
    }

    private struct KeyPayload {
        var dataType: String
        var dataSize: Int
        var bytes: [UInt8]
    }

    private var connection: io_connect_t = 0
    private var openAttempted = false
    private var cpuKeys: [String] = []
    private var gpuKeys: [String] = []
    private var keyInfoCache: [String: KeyInfo] = [:]

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    func read() async -> TemperatureSample? {
        guard ensureOpen() else { return nil }
        let sample = TemperatureSample(cpu: maxSensorValue(over: cpuKeys), gpu: maxSensorValue(over: gpuKeys))
        return (sample.cpu != nil || sample.gpu != nil) ? sample : nil
    }

    // MARK: - Connection

    /// Opens the SMC connection on first use and resolves the sensor key sets
    /// once; later reads reuse both. False means this Mac has no readable sensors.
    private func ensureOpen() -> Bool {
        if openAttempted { return !cpuKeys.isEmpty || !gpuKeys.isEmpty }
        openAttempted = true

        var service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        if service == 0 {
            service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMCKeysEndpoint"))
        }
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else {
            connection = 0
            return false
        }
        discoverKeys()
        return !cpuKeys.isEmpty || !gpuKeys.isEmpty
    }

    private func call(_ command: Int8, input: inout SMCKeyData) -> SMCKeyData? {
        input.data8 = command
        var output = SMCKeyData()
        var outputSize = MemoryLayout<SMCKeyData>.size
        let result = IOConnectCallStructMethod(
            connection,
            SMC.methodIndex,
            &input,
            MemoryLayout<SMCKeyData>.size,
            &output,
            &outputSize
        )
        return result == KERN_SUCCESS ? output : nil
    }

    // MARK: - Keys

    private func discoverKeys() {
        guard let count = keyCount() else { return }

        var candidates: Set<String> = []
        for index in UInt32.zero..<count {
            var lookup = SMCKeyData()
            lookup.data32 = index
            guard let output = call(SMC.cmdKeyByIndex, input: &lookup) else { break }
            let name = output.key.smcKeyString
            if SMC.interestingPrefixes.contains(where: { name.hasPrefix($0) }) {
                candidates.insert(name)
            }
        }
        cpuKeys = TemperatureSensorMap.cpuKeys(available: candidates).sorted()
        gpuKeys = TemperatureSensorMap.gpuKeys(available: candidates).sorted()
    }

    private func keyCount() -> UInt32? {
        guard let payload = readPayload("#KEY"), payload.dataSize >= UInt32.smcKeyCodeLength else { return nil }
        let leading = payload.bytes.prefix(UInt32.smcKeyCodeLength)
        let count = leading.reduce(UInt32.zero) { $0 << UInt32.bitsPerByte | UInt32($1) }
        return (count > UInt32.zero && count < SMC.maxKeyCount) ? count : nil
    }

    // MARK: - Values

    private func maxSensorValue(over keys: [String]) -> Double? {
        var peak: Double?
        for key in keys {
            guard let value = readValue(key), SMC.plausibleRange.contains(value) else { continue }
            peak = max(peak ?? value, value)
        }
        return peak
    }

    private func readValue(_ key: String) -> Double? {
        guard let payload = readPayload(key) else { return nil }
        return SMCValueDecoder.value(dataType: payload.dataType, dataSize: payload.dataSize, bytes: payload.bytes)
    }

    /// Raw bytes of a key: info call first (the driver returns nothing without
    /// it), then the read itself with the reported data size.
    private func readPayload(_ key: String) -> KeyPayload? {
        guard let code = UInt32.smcCode(key) else { return nil }

        let info: KeyInfo
        if let cached = keyInfoCache[key] {
            info = cached
        } else {
            var infoInput = SMCKeyData()
            infoInput.key = code
            guard let output = call(SMC.cmdKeyInfo, input: &infoInput), output.keyInfo.dataSize > 0 else { return nil }
            info = KeyInfo(dataType: output.keyInfo.dataType.smcKeyString, dataSize: Int(output.keyInfo.dataSize))
            keyInfoCache[key] = info
        }

        var input = SMCKeyData()
        input.key = code
        input.keyInfo.dataSize = UInt32(info.dataSize)
        guard let output = call(SMC.cmdReadBytes, input: &input) else { return nil }
        let bytes: [UInt8] = withUnsafeBytes(of: output.bytes) { Array($0) }
        return KeyPayload(dataType: info.dataType, dataSize: info.dataSize, bytes: bytes)
    }
}

private extension UInt32 {
    /// Length of a four-char SMC key code ("#KEY", "Tp01", …).
    static let smcKeyCodeLength = 4
    static let bitsPerByte = 8

    /// Four-char SMC code, big-endian.
    static func smcCode(_ name: String) -> UInt32? {
        let bytes = Array(name.utf8)
        guard bytes.count == smcKeyCodeLength else { return nil }
        return bytes.reduce(UInt32.zero) { $0 << bitsPerByte | UInt32($1) }
    }

    var smcKeyString: String {
        var code = self
        var chars = [UInt8]()
        while chars.count < Self.smcKeyCodeLength {
            chars.insert(UInt8(truncatingIfNeeded: code), at: chars.startIndex)
            code >>= Self.bitsPerByte
        }
        return String(bytes: chars, encoding: .ascii) ?? ""
    }
}
