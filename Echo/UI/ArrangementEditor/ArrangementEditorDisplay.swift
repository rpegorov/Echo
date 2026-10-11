//
//  ArrangementEditorDisplay.swift
//  Echo
//

import CoreGraphics

/// A display the editor can draw: one the arrangement refers to, or a connected one windows can be moved to.
struct ArrangementEditorDisplay: Identifiable, Equatable {
    /// `DisplayKey.rawValue`.
    let key: String
    let name: String
    /// Visible width over height.
    let aspect: Double
    /// Visible width in points; scales the window gap onto the canvas.
    let referenceWidth: CGFloat
    let isConnected: Bool
    /// Zones of the grid active on this display, in reading order.
    let zones: [UnitRect]

    var id: String { key }

    var saved: SavedDisplay { SavedDisplay(name: name, aspect: aspect) }
}

extension ArrangementEditorDisplay {
    /// Displays to draw (keys of `saved`) and displays a window can move to (those plus every keyed connected one).
    /// Connected displays come first in system order, then the others by name.
    static func resolve(
        saved: [String: SavedDisplay],
        connected: [DisplaySnapshot],
        disconnectedReferenceWidth: CGFloat,
        zonesForDisconnected: (String, Double) -> [UnitRect]
    ) -> (shown: [ArrangementEditorDisplay], targets: [ArrangementEditorDisplay]) {
        let live: [ArrangementEditorDisplay] = connected.compactMap { snapshot in
            guard let key = snapshot.key?.rawValue else { return nil }
            return ArrangementEditorDisplay(
                key: key,
                name: snapshot.name,
                aspect: snapshot.aspect,
                referenceWidth: snapshot.visibleFrame.width,
                isConnected: true,
                zones: snapshot.zones
            )
        }
        let liveKeys = Set(live.map(\.key))
        let absent = saved
            .filter { !liveKeys.contains($0.key) }
            .map { key, display in
                ArrangementEditorDisplay(
                    key: key,
                    name: display.name,
                    aspect: display.aspect,
                    referenceWidth: disconnectedReferenceWidth,
                    isConnected: false,
                    zones: zonesForDisconnected(key, display.aspect)
                )
            }
            .sorted { ($0.name, $0.key) < ($1.name, $1.key) }
        let targets = live + absent
        return (targets.filter { saved[$0.key] != nil }, targets)
    }
}
