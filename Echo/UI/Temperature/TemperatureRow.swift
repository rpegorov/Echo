//
//  TemperatureRow.swift
//  Echo
//

import SwiftUI

/// Popover row with current CPU/GPU temperatures, styled after the network row.
struct TemperatureRow: View {
    let cpu: Double?
    let gpu: Double?
    let onSelect: () -> Void
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DS.Temperature.rowSpacing) {
                Image(systemName: "thermometer.medium")
                    .font(DS.Temperature.rowIconFont)
                    .foregroundStyle(DS.accent)
                Text(loc.t(MetricTab.temperature.titleKey))
                    .font(DS.Temperature.rowTitleFont)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: DS.Temperature.rowValueStackSpacing) {
                    valueLine(icon: "cpu", value: cpu, color: .orange)
                    valueLine(icon: "memorychip", value: gpu, color: .purple)
                }
                Image(systemName: "chevron.right")
                    .font(DS.Temperature.rowChevronFont)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.Temperature.rowHorizontalPadding)
            .padding(.vertical, DS.Temperature.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
    }

    /// Value line: component icon plus its reading.
    private func valueLine(icon: String, value: Double?, color: Color) -> some View {
        HStack(spacing: DS.Temperature.rowValueSpacing) {
            Image(systemName: icon)
                .font(DS.Temperature.rowValueIconFont)
                .foregroundStyle(color)
            Text(degreeText(value)) // l10n-exempt: numeric value with a universal ° glyph
                .font(DS.Temperature.rowValueFont)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    private func degreeText(_ value: Double?) -> String {
        value.map { String(format: "%.0f°", $0) } ?? "—"
    }
}
