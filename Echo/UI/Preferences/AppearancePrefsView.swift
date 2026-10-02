//
//  AppearancePrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Preferences section: window theme and the popover metrics style.
struct AppearancePrefsView: View {
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle(loc.t(PreferencesKey.sectionAppearance))

            PrefCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.t(PreferencesKey.themeTitle))
                        .font(.system(size: 13, weight: .medium))
                    Picker(loc.t(PreferencesKey.themeTitle), selection: $settings.appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(loc.t(mode.titleKey)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    PrefCaption(loc.t(PreferencesKey.themeCaption, AppInfo.name))
                }
            }

            PrefCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.t(PreferencesKey.popoverMetricsTitle))
                        .font(.system(size: 13, weight: .medium))
                    Picker(loc.t(PreferencesKey.popoverMetricsTitle), selection: $settings.popoverMetricsStyle) {
                        ForEach(PopoverMetricsStyle.allCases) { style in
                            Text(loc.t(style.titleKey)).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    PrefCaption(loc.t(PreferencesKey.popoverMetricsCaption))
                }
            }
        }
    }
}
