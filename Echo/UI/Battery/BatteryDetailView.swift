//
//  BatteryDetailView.swift
//  Echo
//

import SwiftUI

/// Battery detail tab: a 24h level chart with a draggable selection, and the
/// top-10-by-energy list for whatever moment is selected. Takes plain values
/// — no service, no IOKit — so it can be built and previewed against a fixed
/// ``BatteryHistory`` while the live service is wired in separately.
struct BatteryDetailView: View {
    let history: BatteryHistory
    let lastError: BatteryError?
    @State private var selection: Date?
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let lastError {
                errorBanner(lastError)
            }

            if history.readings.isEmpty {
                emptyState(text: loc.t(BatteryKey.noDataYet))
            } else {
                BatteryChartView(history: history, selection: $selection)
                    .frame(minHeight: 160)

                BatteryEnergyListView(
                    interval: Self.selectedInterval(for: effectiveSelection, in: history.intervals),
                    isChargingAtSelection: Self.isCharging(at: effectiveSelection, in: history.readings)
                )
            }

            Text(loc.t(BatteryKey.currentUserProcessesFootnote))
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func errorBanner(_ error: BatteryError) -> some View {
        switch error {
        case .storage(let message):
            Label(loc.t(BatteryKey.storageError, message), systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Selection derivation

    /// The dragged/clicked moment, or the latest reading when nothing is selected yet.
    private var effectiveSelection: Date? {
        selection ?? history.readings.last?.date
    }

    private static func isCharging(at date: Date?, in readings: [BatteryReading]) -> Bool {
        guard let date, let nearest = nearestReading(to: date, in: readings) else { return false }
        return nearest.isCharging
    }

    private static func nearestReading(to date: Date, in readings: [BatteryReading]) -> BatteryReading? {
        readings.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private static func selectedInterval(for date: Date?, in intervals: [EnergyInterval]) -> EnergyInterval? {
        guard let date else { return nil }
        if let containing = intervals.first(where: { $0.start <= date && date <= $0.end }) {
            return containing
        }
        return intervals.min { abs(midpoint($0).timeIntervalSince(date)) < abs(midpoint($1).timeIntervalSince(date)) }
    }

    private static func midpoint(_ interval: EnergyInterval) -> Date {
        interval.start.addingTimeInterval(interval.end.timeIntervalSince(interval.start) / 2)
    }
}

// MARK: - Preview

#Preview {
    BatteryDetailView(history: .previewSynthetic, lastError: nil)
        .environmentObject(Localizer(preference: .system))
        .frame(width: DS.detailSize.width, height: DS.detailSize.height)
}

private extension BatteryHistory {
    /// 24h of synthetic data: two charging periods and one ~40 min gap
    /// (Echo not running), for previewing chart gaps/bands without a live service.
    static var previewSynthetic: BatteryHistory {
        let now = Date()
        let start = now.addingTimeInterval(-24 * 3600)
        var readings: [BatteryReading] = []
        var intervals: [EnergyInterval] = []

        var cursor = start
        var level = 42
        let step: TimeInterval = 5 * 60

        while cursor < now {
            let elapsed = cursor.timeIntervalSince(start)
            let isCharging = (elapsed > 2 * 3600 && elapsed < 4 * 3600) || (elapsed > 14 * 3600 && elapsed < 16.5 * 3600)
            let inGap = elapsed > 9 * 3600 && elapsed < 9.7 * 3600

            if !inGap {
                level += isCharging ? 1 : (Int.random(in: 0...2) == 0 ? -1 : 0)
                level = min(100, max(1, level))
                readings.append(BatteryReading(date: cursor, level: level, isCharging: isCharging, isOnAC: isCharging))

                if !isCharging, Int(elapsed) % (30 * 60) < Int(step) {
                    let apps = [
                        AppEnergyUsage(id: "1", appName: "Safari", bundleID: "com.apple.Safari", energyNJ: 1_200_000),
                        AppEnergyUsage(id: "2", appName: "Xcode", bundleID: "com.apple.dt.Xcode", energyNJ: 900_000),
                        AppEnergyUsage(id: "3", appName: "Music", bundleID: "com.apple.Music", energyNJ: 300_000),
                    ]
                    intervals.append(EnergyInterval(
                        start: cursor.addingTimeInterval(-30 * 60),
                        end: cursor,
                        totalEnergyNJ: apps.reduce(0) { $0 + $1.energyNJ },
                        top: apps
                    ))
                }
            }
            cursor.addTimeInterval(step)
        }

        return BatteryHistory(readings: readings, intervals: intervals)
    }
}
