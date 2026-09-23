//
//  BatteryRingCell.swift
//  Echo
//

import SwiftUI

/// Popover ring cell for the Battery metric: level in the ring, charging
/// state as the sub-label. `nil` (no reading yet) renders an empty ring.
struct BatteryRingCell: View {
    let reading: BatteryReading?
    var ringSize: CGFloat = 58
    var action: (() -> Void)? = nil
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        CircularProgressView(
            progress: Double(reading?.level ?? 0),
            valueText: valueText,
            unitText: "%", // l10n-exempt: comment, not user-facing — unit glyph, universal across locales
            name: loc.t(MetricsKey.tabBattery),
            subLabel: subLabel,
            ringSize: ringSize,
            action: action
        )
    }

    private var valueText: String {
        guard let reading else { return "--" } // l10n-exempt: comment, not user-facing — placeholder glyph, not a word
        return "\(reading.level)" // l10n-exempt: comment, not user-facing — numeric interpolation only
    }

    private var subLabel: String {
        guard let reading else { return "" }
        return loc.t(reading.isCharging ? BatteryKey.charging : BatteryKey.onBattery)
    }
}
