//
//  SlotPlacement.swift
//  Echo
//

import CoreGraphics

enum SlotPlacement {
    /// Window frame for `slot` on the connected display with that key; nil when it is not connected.
    static func frame(for slot: ZoneSlot, displays: [DisplaySnapshot], gap: CGFloat) -> CGRect? {
        guard let display = displays.first(where: { $0.key?.rawValue == slot.display }) else { return nil }
        return slot.rect.frame(in: display.visibleFrame, gap: gap)
    }
}
