//
//  BatteryEnergyListView.swift
//  Echo
//

import SwiftUI

/// Top-10-by-energy list for one selected moment: the ``EnergyInterval`` that
/// contains (or is nearest to) the selected date, or an empty state when
/// there is nothing to show for it.
struct BatteryEnergyListView: View {
    let interval: EnergyInterval?
    /// Whether the device was charging at the selected moment — distinguishes
    /// "no drain data because it was charging" from "no data at all".
    let isChargingAtSelection: Bool
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        Group {
            if let interval {
                content(for: interval)
            } else if isChargingAtSelection {
                emptyState(text: loc.t(BatteryKey.chargingNoDrain))
            } else {
                emptyState(text: loc.t(BatteryKey.noDataYet))
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func content(for interval: EnergyInterval) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(interval.start...interval.end)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(Self.rankedShares(for: interval), id: \.usage.id) { entry in
                        ProcessRowView(rank: entry.rank, name: entry.usage.appName, value: .energyShare(entry.sharePercent), onKill: nil)
                    }
                }
            }
        }
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Derivation

    private static func rankedShares(for interval: EnergyInterval) -> [(rank: Int, usage: AppEnergyUsage, sharePercent: Double)] {
        let total = Double(interval.totalEnergyNJ)
        return interval.top.prefix(10).enumerated().map { index, usage in
            let share = total > 0 ? Double(usage.energyNJ) / total * 100 : 0
            return (index + 1, usage, share)
        }
    }
}
