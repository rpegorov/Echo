//
//  AppearancePrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: тема оформления.
struct AppearancePrefsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle("Appearance")

            PrefCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Theme")
                        .font(.system(size: 13, weight: .medium))
                    Picker("Theme", selection: $settings.appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    PrefCaption("Тема оформления окон \(AppInfo.name). «System» следует за оформлением macOS.")
                }
            }
        }
    }
}
