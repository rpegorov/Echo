//
//  UpdatesPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: автообновление.
struct UpdatesPrefsView: View {
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var updater: UpdaterService
    let version: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle(loc.t(PreferencesKey.sectionUpdates))

            PrefCard {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(DS.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t(PreferencesKey.updatesInstalledVersion, version))
                            .font(.system(size: 13, weight: .semibold))
                        PrefCaption(lastCheckLabel)
                    }
                    Spacer()
                    Button(loc.t(PreferencesKey.updatesCheckNowButton)) { updater.checkForUpdates() }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                        .disabled(!updater.canCheck)
                }
            }

            PrefCard {
                Toggle(isOn: $updater.automaticallyChecks) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t(PreferencesKey.updatesAutoCheckTitle))
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption(loc.t(PreferencesKey.updatesAutoCheckCaption))
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                Toggle(isOn: $updater.automaticallyDownloads) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t(PreferencesKey.updatesAutoDownloadTitle))
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption(loc.t(PreferencesKey.updatesAutoDownloadCaption))
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
                .disabled(!updater.automaticallyChecks)
            }

            PrefCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc.t(PreferencesKey.updatesFeedTitle))
                        .font(.system(size: 13, weight: .medium))
                    PrefCaption(updater.feedURL)
                    PrefCaption(loc.t(PreferencesKey.updatesFeedCaption))
                }
            }
        }
    }

    private var lastCheckLabel: String {
        guard let date = updater.lastCheckDate else { return loc.t(PreferencesKey.updatesNeverChecked) }
        let formatter = DateFormatter()
        formatter.locale = loc.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return loc.t(PreferencesKey.updatesLastCheck, formatter.string(from: date))
    }
}
