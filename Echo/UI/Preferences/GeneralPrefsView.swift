//
//  GeneralPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: общие настройки и сведения о приложении.
struct GeneralPrefsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle("General")

            PrefCard {
                Toggle(isOn: $settings.launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at login")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("Автоматически запускать \(AppInfo.name) при входе в систему.")
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                HStack(spacing: 12) {
                    Image(systemName: "menubar.rectangle")
                        .font(.system(size: 22))
                        .foregroundStyle(DS.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppInfo.name)
                            .font(.system(size: 13, weight: .semibold))
                        PrefCaption("Версия \(AppInfo.version)")
                    }
                    Spacer()
                    Button("Quit \(AppInfo.name)") { NSApp.terminate(nil) }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}
