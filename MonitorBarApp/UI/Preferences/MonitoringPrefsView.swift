//
//  MonitoringPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: частота опроса метрик.
struct MonitoringPrefsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle("System Monitoring")

            PrefCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Update interval")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(AppInfo.intervalLabel(settings.updateInterval))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.updateInterval, in: 0.5...5, step: 0.5)
                        .tint(DS.accent)
                    PrefCaption("Как часто опрашиваются CPU, RAM, диск и сеть. Чаще — отзывчивее, но выше нагрузка на процессор и расход батареи.")
                }
            }
        }
    }
}
