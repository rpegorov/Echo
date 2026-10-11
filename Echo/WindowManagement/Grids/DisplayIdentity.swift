//
//  DisplayIdentity.swift
//  Echo
//

import AppKit
import ColorSync

/// A connected display as settings and the editor show it.
struct ConnectedDisplay: Equatable, Identifiable {
    let key: DisplayKey
    /// `NSScreen.localizedName`: data, not a localization key.
    let name: String
    let visibleSize: CGSize

    var id: String { key.rawValue }
    var aspect: Double { visibleSize.width / visibleSize.height }
}

enum DisplayIdentity {
    private static let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

    /// Key of `screen`; nil when AppKit reports no display ID for it.
    static func key(for screen: NSScreen) -> DisplayKey? {
        guard let number = screen.deviceDescription[screenNumberKey] as? NSNumber else { return nil }
        let id = CGDirectDisplayID(number.uint32Value)
        let uuid = CGDisplayCreateUUIDFromDisplayID(id)
            .flatMap { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String? }
        return DisplayKey(
            uuid: uuid,
            vendor: CGDisplayVendorNumber(id),
            model: CGDisplayModelNumber(id),
            serial: CGDisplaySerialNumber(id)
        )
    }

    /// Connected displays that have a key, the menu-bar display first.
    static func connectedDisplays() -> [ConnectedDisplay] {
        NSScreen.screens.compactMap { screen in
            key(for: screen).map {
                ConnectedDisplay(key: $0, name: screen.localizedName, visibleSize: screen.visibleFrame.size)
            }
        }
    }
}
