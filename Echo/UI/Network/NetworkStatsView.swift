//
//  NetworkStatsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Сводка сетевой активности: текущая скорость, пики и средние за окно истории.
struct NetworkStatsView: View {
    let current: NetworkMetrics
    let history: [(download: Double, upload: Double)]

    private var peakDown: Double { history.map(\.download).max() ?? 0 }
    private var peakUp:   Double { history.map(\.upload).max() ?? 0 }
    private var avgDown:  Double { history.isEmpty ? 0 : history.map(\.download).reduce(0, +) / Double(history.count) }
    private var avgUp:    Double { history.isEmpty ? 0 : history.map(\.upload).reduce(0, +) / Double(history.count) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(title: "Download", value: current.download, icon: "arrow.down", tint: .blue)
                statCard(title: "Upload",   value: current.upload,   icon: "arrow.up",   tint: .green)
            }

            HStack(spacing: 12) {
                miniCard(title: "Peak ↓",  value: peakDown)
                miniCard(title: "Peak ↑",  value: peakUp)
                miniCard(title: "Avg ↓",   value: avgDown)
                miniCard(title: "Avg ↑",   value: avgUp)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Cards

    private func statCard(title: String, value: Double, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(Self.format(value))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
    }

    private func miniCard(title: String, value: Double) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(Self.format(value))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerSM))
    }

    /// Форматирует скорость (вход в КБ/с) в КБ/с или МБ/с.
    private static func format(_ kbPerSec: Double) -> String {
        if kbPerSec >= 1024 {
            return String(format: "%.2f MB/s", kbPerSec / 1024)
        }
        return String(format: "%.0f KB/s", kbPerSec)
    }
}
