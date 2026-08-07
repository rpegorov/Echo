//
//  UltraSwitchPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: раскладка клавиатуры (мгновенное переключение и автоисправление).
struct UltraSwitchPrefsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var ultraSwitch: UltraSwitchService
    let hasBothLayouts: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle("Ultra Switch")

            statusCard
            if !hasBothLayouts { singleLayoutCard }

            PrefCard {
                Toggle(isOn: $settings.ultraSwitchEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Ultra Switch")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("Мгновенная смена раскладки по хоткею вместо клавиши 🌐 и конвертация последнего слова.")
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                Toggle(isOn: $settings.autoConvertEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Автоисправление раскладки")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("После пробела слово вроде «ghbdtn» само станет «привет», а раскладка переключится. Решение принимают системные словари ru и en.")
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
                .disabled(!settings.ultraSwitchEnabled)
            }

            PrefCard {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(DS.accent)
                    PrefCaption("Нажатия клавиш не записываются: приложение видит только код клавиши-разделителя, а слово читает из поля ввода в момент проверки. История набора нигде не хранится, поля паролей игнорируются.")
                    Spacer()
                }
            }

            PrefCard {
                VStack(spacing: 0) {
                    shortcutRow(.switchLayout)
                    Divider().opacity(0.12)
                    shortcutRow(.convertWord)
                }
            }

            PrefCaption("Повторная конвертация того же слова возвращает его обратно — это и есть отмена автоисправления.")
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
                    Button("Разрешить", action: ultraSwitch.requestAccess)
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                }
            }
        }
    }

    /// Обновление меняет подпись сборки, и macOS считает её другим приложением:
    /// старая запись в списке остаётся, но уже ничего не разрешает.
    private static let afterUpdateHint =
        "Если Echo уже есть в списке после обновления — удалите его кнопкой «−» и добавьте заново. Статус здесь обновится сам."

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
        case .running:              return "Автозамена активна"
        case .disabled:             return "Автозамена выключена"
        case .needsAccessibility:   return "Нужен доступ Accessibility"
        case .needsInputMonitoring: return "Нужен доступ Input Monitoring"
        }
    }

    private var statusDetail: String {
        switch ultraSwitch.status {
        case .running:
            return "Слово, набранное не в той раскладке, исправляется после пробела."
        case .disabled:
            return "Включите оба тумблера ниже."
        case .needsAccessibility:
            return "Без него нельзя ни прочитать слово в поле ввода, ни заменить его. \(Self.afterUpdateHint)"
        case .needsInputMonitoring:
            return "Без него приложение не узнаёт о нажатии пробела и не понимает, что слово закончено. \(Self.afterUpdateHint)"
        }
    }

    private var singleLayoutCard: some View {
        PrefCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                PrefCaption("В системе включена только одна раскладка — переключать нечего. Добавьте вторую в System Settings → Keyboard → Input Sources.")
                Spacer()
            }
        }
    }

    private func shortcutRow(_ command: WMCommand) -> some View {
        HStack {
            Text(command.title)
                .font(.system(size: 13))
            Spacer()
            ShortcutRecorderView(command: command, settings: settings)
        }
        .padding(.vertical, 7)
    }
}
