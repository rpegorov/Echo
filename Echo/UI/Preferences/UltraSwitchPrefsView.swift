//
//  UltraSwitchPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: раскладка клавиатуры (мгновенное переключение и автоисправление).
struct UltraSwitchPrefsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var ultraSwitch: UltraSwitchService
    @EnvironmentObject private var loc: Localizer
    let hasBothLayouts: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle(loc.t(InputKey.ultraSwitchTitle))

            statusCard
            if !hasBothLayouts { singleLayoutCard }

            PrefCard {
                Toggle(isOn: $settings.ultraSwitchEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t(InputKey.ultraSwitchEnableTitle))
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption(loc.t(InputKey.ultraSwitchEnableCaption))
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                Toggle(isOn: $settings.autoConvertEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t(InputKey.autoConvertTitle))
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption(loc.t(InputKey.autoConvertCaption))
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(DS.accent)
                    PrefCaption(loc.t(InputKey.privacyNoteCaption))
                    Spacer()
                }
            }

            PrefCard {
                VStack(spacing: 0) {
                    shortcutRow(.switchLayout)
                    Divider().opacity(0.12)
                    shortcutRow(.convertWord)
                    Divider().opacity(0.12)
                    shortcutRow(.translateSelection)
                }
            }

            PrefCaption(loc.t(InputKey.conversionUndoCaption))
            PrefCaption(loc.t(InputKey.translationCaption))
        }
    }

    // MARK: - Cards

    /// Живой статус автозамены: почему она работает или молчит.
    private var statusCard: some View {
        PrefCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.system(size: 13, weight: .medium))
                    PrefCaption(statusDetail)
                }
                Spacer()
                if ultraSwitch.status.isBlocked {
                    Button(loc.t(InputKey.allowButton), action: ultraSwitch.requestAccess)
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                }
            }
        }
    }

    private var statusIcon: String {
        switch ultraSwitch.status {
        case .running:  return "checkmark.seal.fill"
        case .disabled: return "pause.circle"
        default:        return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch ultraSwitch.status {
        case .running:  return .green
        case .disabled: return .secondary
        default:        return .orange
        }
    }

    private var statusTitle: String {
        switch ultraSwitch.status {
        case .running:              return loc.t(InputKey.statusRunningTitle)
        case .disabled:             return loc.t(InputKey.statusDisabledTitle)
        case .needsAccessibility:   return loc.t(InputKey.accessibilityMissingTitle)
        case .needsInputMonitoring: return loc.t(InputKey.statusNeedsInputMonitoringTitle)
        }
    }

    /// Обновление меняет подпись сборки, и macOS считает её другим приложением:
    /// старая запись в списке остаётся, но уже ничего не разрешает.
    private var statusDetail: String {
        switch ultraSwitch.status {
        case .running:
            return loc.t(InputKey.statusRunningDetail)
        case .disabled:
            return loc.t(InputKey.statusDisabledDetail)
        case .needsAccessibility:
            return "\(loc.t(InputKey.statusNeedsAccessibilityDetail)) \(loc.t(InputKey.afterUpdateHint))"
        case .needsInputMonitoring:
            return "\(loc.t(InputKey.statusNeedsInputMonitoringDetail)) \(loc.t(InputKey.afterUpdateHint))"
        }
    }

    private var singleLayoutCard: some View {
        PrefCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                PrefCaption(loc.t(InputKey.singleLayoutWarning))
                Spacer()
            }
        }
    }

    private func shortcutRow(_ command: WMCommand) -> some View {
        HStack {
            Text(loc.t(command.titleKey))
                .font(.system(size: 13))
            Spacer()
            ShortcutRecorderView(command: command, settings: settings)
        }
        .padding(.vertical, 7)
    }
}
