//
//  ShortcutsPrefsView.swift
//  MonitorBarApp
//

import AppKit
import SwiftUI

/// Раздел Preferences: горячие клавиши оконных команд и буфера обмена.
/// Сочетания раскладки живут в своём разделе, рядом с самой фичей.
struct ShortcutsPrefsView: View {
    @ObservedObject var settings: AppSettings
    @EnvironmentObject private var loc: Localizer

    private var windowCommands: [WMCommand] {
        WMCommand.allCases.filter { $0.isWindowCommand && $0.zoneNumber == nil }
    }

    private var zoneCommands: [WMCommand] {
        WMCommand.allCases.filter { $0.zoneNumber != nil }
    }

    @State private var primaryDisplay = ZoneMapDisplay.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle(loc.t(InputKey.shortcutsTitle))

            commandCard(windowCommands)

            groupTitle(loc.t(InputKey.gridZoneCommandsGroup))
            commandCard(zoneCommands)

            groupTitle(loc.t(InputKey.clipboardHistorySectionTitle))
            PrefCard {
                row(.openClipboard)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            primaryDisplay = ZoneMapDisplay.primary
        }
    }

    private func commandCard(_ commands: [WMCommand]) -> some View {
        PrefCard {
            VStack(spacing: 0) {
                ForEach(commands) { command in
                    row(command)
                    if command != commands.last { Divider().opacity(0.12) }
                }
            }
        }
    }

    private func groupTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.top, 6)
    }

    private func row(_ command: WMCommand) -> some View {
        HStack(spacing: DS.ZoneMap.thumbnailRowSpacing) {
            thumbnail(for: command)
            Text(loc.t(command.titleKey))
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            ShortcutRecorderView(command: command, settings: settings)
        }
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private func thumbnail(for command: WMCommand) -> some View {
        if let number = command.zoneNumber {
            zoneIcon(number, title: loc.t(command.titleKey))
        } else if command.isWindowCommand {
            LayoutThumbnailView(command: command, display: primaryDisplay)
        }
    }

    private func zoneIcon(_ number: Int, title: String) -> some View {
        Image(systemName: "\(number).square")
            .font(DS.ZoneMap.thumbnailSymbolFont)
            .foregroundStyle(.secondary)
            .frame(width: DS.ZoneMap.thumbnailSize.width, height: DS.ZoneMap.thumbnailSize.height)
            .accessibilityLabel(title)
    }
}
