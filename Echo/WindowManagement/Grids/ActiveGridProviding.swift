//
//  ActiveGridProviding.swift
//  Echo
//

/// Read seam for the snapper and the zone hotkeys.
@MainActor
protocol ActiveGridProviding: AnyObject {
    /// Zones of the grid active on `display`, in reading order, never empty.
    /// A display without a key gets the default template for `aspect`.
    func activeZones(for display: DisplayKey?, aspect: Double) -> [UnitRect]
}
