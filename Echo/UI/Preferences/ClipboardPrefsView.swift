//
//  ClipboardPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: история буфера обмена.
struct ClipboardPrefsView: View {
    @EnvironmentObject private var loc: Localizer
    @ObservedObject var clipboard: ClipboardService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle(loc.t(PreferencesKey.sectionClipboard))

            PrefCard {
                Toggle(isOn: $clipboard.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t(PreferencesKey.clipboardEnableTitle))
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption(loc.t(PreferencesKey.clipboardEnableCaption))
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }
        }
    }
}
