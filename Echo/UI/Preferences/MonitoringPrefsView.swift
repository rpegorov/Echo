//
//  MonitoringPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: частота опроса метрик.
struct MonitoringPrefsView: View {
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle(loc.t(PreferencesKey.sectionMonitoring))

            PrefCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(loc.t(PreferencesKey.updateIntervalTitle))
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(AppInfo.intervalLabel(settings.updateInterval, loc: loc))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.updateInterval, in: 0.5...5, step: 0.5)
                        .tint(DS.accent)
                    PrefCaption(loc.t(PreferencesKey.updateIntervalCaption))
                }
            }
        }
    }
}
