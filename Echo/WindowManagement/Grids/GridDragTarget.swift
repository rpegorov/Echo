//
//  GridDragTarget.swift
//  Echo
//

import CoreGraphics

/// Pure grid-mode target of a window drag: which zone (or zone span) the cursor selects and the preview for it.
enum GridDragTarget {
    /// One display's grid, captured once per drag.
    struct Display {
        let screenFrame: CGRect
        let visibleFrame: CGRect
        let zones: [UnitRect]
        /// Every zone as a window frame (gap applied), drawn faintly behind the target.
        let contextFrames: [CGRect]
    }

    struct Resolution: Equatable {
        let preview: SnapPreview
        /// Zone the span grows from; nil outside span mode.
        let anchor: Int?
    }

    /// Nil only when the display has no zones.
    /// `anchor` is the span anchor kept from earlier events on this display; it is adopted when `spanning` starts.
    static func resolve(
        cursor: CGPoint,
        on display: Display,
        spanning: Bool,
        anchor: Int?,
        gap: CGFloat,
        shortcutForZone: (Int) -> KeyboardShortcut?
    ) -> Resolution? {
        let unitPoint = GridSnapResolver.unitPoint(cursor, in: display.visibleFrame)
        guard let index = GridSnapResolver.zoneIndex(at: unitPoint, in: display.zones) else { return nil }
        let nextAnchor = spanning ? (anchor ?? index) : nil
        let span = GridSnapResolver.span(from: nextAnchor ?? index, to: index, in: display.zones)
        let zoneNumbers = span.indices.map { $0 + 1 }
        let shortcut = zoneNumbers.count == 1 ? shortcutForZone(zoneNumbers[0]) : nil
        let preview = SnapPreview(
            target: .grid(GridSnapTarget(zoneNumbers: zoneNumbers, contextFrames: display.contextFrames)),
            frame: span.rect.frame(in: display.visibleFrame, gap: gap),
            screenFrame: display.screenFrame,
            shortcut: shortcut
        )
        return Resolution(preview: preview, anchor: nextAnchor)
    }
}
