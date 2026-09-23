//
//  BatteryRow.swift
//  Echo
//
//  Popover row for battery state — replaces the former 4th ring
//  (BatteryRingCell) per customer feedback that a ring looked wrong for a
//  binary/linear quantity like charge. Mirrors the Network row's visual
//  style: same material, corner radius, paddings and chevron.
//

import SwiftUI

struct BatteryRow: View {
    let reading: BatteryReading?
    let onSelect: () -> Void
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: symbolName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(tintColor)
                        .accessibilityHidden(true)
                    Text(loc.t(MetricTab.battery.titleKey))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(levelText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text(statusText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                progressBar
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
        .accessibilityElement(children: .combine)
    }

    private var level: Int { reading?.level ?? 0 }
    private var isCharging: Bool { reading?.isCharging ?? false }
    private var isOnAC: Bool { reading?.isOnAC ?? false }

    private var symbolName: String {
        BatteryPresentation.symbolName(isCharging: isCharging, level: level)
    }

    private var tintColor: Color {
        BatteryPresentation.tintColor(isCharging: isCharging, level: level)
    }

    private var statusText: String {
        loc.t(BatteryPresentation.status(isCharging: isCharging, isOnAC: isOnAC, level: level).localizedKey)
    }

    private var levelText: String {
        guard reading != nil else { return "--" } // l10n-exempt: comment, not user-facing — placeholder glyph, not a word
        return "\(level)%" // l10n-exempt: comment, not user-facing — numeric interpolation with a universal % glyph
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(DS.ringTrack)
            GeometryReader { proxy in
                Capsule()
                    .fill(tintColor)
                    .frame(width: proxy.size.width * CGFloat(level) / 100)
            }
        }
        .frame(height: 4)
    }
}
