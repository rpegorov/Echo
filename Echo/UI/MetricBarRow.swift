//
//  MetricBarRow.swift
//  Echo
//

import SwiftUI

/// Popover row for a load metric drawn as a bar — the alternative to
/// `CircularProgressView`, styled like `BatteryRow` so the rows stack evenly.
struct MetricBarRow: View {
    let progress: Double      // 0–100
    let icon: String
    let name: String
    let valueText: String
    let subLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.accent)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(valueText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text(subLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                bar
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
        .accessibilityElement(children: .combine)
    }

    private var bar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(DS.ringTrack)
            GeometryReader { proxy in
                Capsule()
                    .fill(DS.load(progress))
                    .frame(width: proxy.size.width * min(progress / 100, 1))
                    .animation(.easeInOut(duration: 0.6), value: progress)
            }
        }
        .frame(height: 4)
    }
}
