//
//  ClipboardPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: история буфера обмена.
struct ClipboardPrefsView: View {
    @ObservedObject var clipboard: ClipboardService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle("Clipboard History")

            PrefCard {
                Toggle(isOn: $clipboard.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Clipboard History")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("Хранит последние скопированные тексты, файлы и изображения (в памяти).")
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }
        }
    }
}
