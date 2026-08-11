//
//  ShortcutsPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: горячие клавиши оконных команд и буфера обмена.
/// Сочетания раскладки живут в своём разделе, рядом с самой фичей.
struct ShortcutsPrefsView: View {
    @ObservedObject var settings: AppSettings

    private var windowCommands: [WMCommand] {
        WMCommand.allCases.filter { $0.isWindowCommand }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle("Keyboard Shortcuts")

            PrefCard {
                VStack(spacing: 0) {
                    ForEach(windowCommands) { command in
                        row(command)
                        if command != windowCommands.last { Divider().opacity(0.12) }
                    }
                }
            }

            Text("Clipboard History")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)

            PrefCard {
                row(.openClipboard)
            }
        }
    }

    private func row(_ command: WMCommand) -> some View {
        HStack {
            Text(command.title)
                .font(.system(size: 13))
            Spacer()
            ShortcutRecorderView(command: command, settings: settings)
        }
        .padding(.vertical, 7)
    }
}
