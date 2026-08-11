//
//  PowerPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: когда мониторинг можно приостановить.
struct PowerPrefsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle("Power Management")

            PrefCard {
                Toggle(isOn: $settings.pauseWhenHidden) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause when no window is open")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("Останавливать опрос метрик, когда поповер и все окна закрыты. Главная экономия батареи.")
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                Toggle(isOn: $settings.pauseOnSleep) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause during system sleep")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("Полностью останавливать мониторинг на время сна Mac и возобновлять при пробуждении.")
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $settings.lowPowerThrottle) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Throttle in Low Power Mode")
                                .font(.system(size: 13, weight: .medium))
                            PrefCaption("Реже опрашивать метрики, когда включён режим энергосбережения macOS.")
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(DS.accent)

                    if settings.lowPowerThrottle {
                        Divider().opacity(0.12)
                        HStack {
                            Text("Low Power interval")
                                .font(.system(size: 12))
                            Spacer()
                            Text(AppInfo.intervalLabel(settings.lowPowerInterval))
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
