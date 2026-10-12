//
//  DisplayKey.swift
//  Echo
//

/// Identity of a display that survives reboots and reconnects; `rawValue` is the storage key.
struct DisplayKey: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The display UUID when the system has one, else vendor, model and serial from the EDID.
    init(uuid: String?, vendor: UInt32, model: UInt32, serial: UInt32) {
        if let uuid {
            rawValue = Self.uuidPrefix + uuid
        } else {
            rawValue = Self.edidPrefix + "\(vendor)-\(model)-\(serial)"
        }
    }

    private static let uuidPrefix = "uuid:"
    private static let edidPrefix = "edid:"
}
