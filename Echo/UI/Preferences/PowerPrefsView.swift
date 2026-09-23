//
//  PowerPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: когда мониторинг можно приостановить.
struct PowerPrefsView: View {
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle(loc.t(PreferencesKey.sectionPower))

            PrefCard {
                Toggle(isOn: $settings.pauseWhenHidden) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t(PreferencesKey.pauseWhenHiddenTitle))
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption(loc.t(PreferencesKey.pauseWhenHiddenCaption))
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                Toggle(isOn: $settings.pauseOnSleep) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t(PreferencesKey.pauseOnSleepTitle))
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption(loc.t(PreferencesKey.pauseOnSleepCaption))
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $settings.lowPowerThrottle) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.t(PreferencesKey.lowPowerThrottleTitle))
                                .font(.system(size: 13, weight: .medium))
                            PrefCaption(loc.t(PreferencesKey.lowPowerThrottleCaption))
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(DS.accent)

                    if settings.lowPowerThrottle {
                        Divider().opacity(0.12)
                        HStack {
                            Text(loc.t(PreferencesKey.lowPowerIntervalTitle))
                                .font(.system(size: 12))
                            Spacer()
                            Text(AppInfo.intervalLabel(settings.lowPowerInterval, loc: loc))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.lowPowerInterval, in: 1...10, step: 1)
                            .tint(DS.accent)
                    }
                }
            }
        }
    }
}
