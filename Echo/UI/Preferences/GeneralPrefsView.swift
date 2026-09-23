//
//  GeneralPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: общие настройки и сведения о приложении.
struct GeneralPrefsView: View {
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle(loc.t(PreferencesKey.sectionGeneral))

            PrefCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.t(PreferencesKey.languageTitle))
                        .font(.system(size: 13, weight: .medium))
                    Picker(loc.t(PreferencesKey.languageTitle), selection: $settings.language) {
                        ForEach(LanguagePreference.allOptions, id: \.self) { option in
                            Text(languageLabel(for: option)).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    PrefCaption(loc.t(PreferencesKey.languageCaption))
                }
            }

            PrefCard {
                Toggle(isOn: $settings.launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t(PreferencesKey.launchAtLoginTitle))
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption(loc.t(PreferencesKey.launchAtLoginCaption, AppInfo.name))
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
                        PrefCaption(loc.t(CommonKey.version, AppInfo.version))
                    }
                    Spacer()
                    Button(loc.t(CommonKey.quitApp, AppInfo.name)) { NSApp.terminate(nil) }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    /// "System" reads from the shared `system` key; a fixed language always shows its own
    /// native name, never translated into the currently active language.
    private func languageLabel(for option: LanguagePreference) -> String {
        switch option {
        case .system:
            return loc.t(CommonKey.system)
        case .fixed(let language):
            return language.nativeName
        }
    }
}
