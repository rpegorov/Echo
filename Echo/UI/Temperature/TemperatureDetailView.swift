//
//  TemperatureDetailView.swift
//  Echo
//

import SwiftUI

struct TemperatureDetailView: View {
    let current: TemperatureSample
    let cpuHistory: [Double]
    let gpuHistory: [Double]
    @EnvironmentObject private var loc: Localizer

    private var peakCPU: Double? { cpuHistory.max() }
    private var peakGPU: Double? { gpuHistory.max() }

    var body: some View {
        VStack(spacing: DS.Temperature.sectionSpacing) {
            HStack(spacing: DS.Temperature.sectionSpacing) {
                statCard(
                    title: loc.t(MetricsKey.temperatureStatCPU),
                    value: current.cpu,
                    icon: "cpu",
                    tint: .orange
                )
                statCard(
                    title: loc.t(MetricsKey.temperatureStatGPU),
                    value: current.gpu,
                    icon: "memorychip",
                    tint: .purple
                )
            }

            HStack(spacing: DS.Temperature.sectionSpacing) {
                miniCard(title: loc.t(MetricsKey.temperatureStatPeakCPU), value: peakCPU)
                miniCard(title: loc.t(MetricsKey.temperatureStatPeakGPU), value: peakGPU)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Cards

    private func degree(_ value: Double) -> String {
        String(format: "%.1f°", value)
    }

    private func statCard(title: String, value: Double?, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Temperature.statSpacing) {
            HStack(spacing: DS.Temperature.statSpacing) {
                Image(systemName: icon)
                    .font(DS.Temperature.statIconFont)
                    .foregroundStyle(tint)
                Text(title)
                    .font(DS.Temperature.statTitleFont)
                    .foregroundStyle(.secondary)
            }
            Text(value.map { degree($0) } ?? "—")
                .font(DS.Temperature.statValueFont)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Temperature.statCardPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
    }

    private func miniCard(title: String, value: Double?) -> some View {
        VStack(spacing: DS.Temperature.miniSpacing) {
            Text(title)
                .font(DS.Temperature.miniTitleFont)
                .foregroundStyle(.tertiary)
            Text(value.map { degree($0) } ?? "—")
                .font(DS.Temperature.miniValueFont)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Temperature.miniVerticalPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerSM))
    }
}
