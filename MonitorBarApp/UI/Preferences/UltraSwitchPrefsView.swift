//
//  UltraSwitchPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: раскладка клавиатуры (мгновенное переключение и автоисправление).
struct UltraSwitchPrefsView: View {
    @ObservedObject var settings: AppSettings
    let hasAXPermission: Bool
    let hasBothLayouts: Bool
    let onOpenAccessibility: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle("Ultra Switch")

            if !hasAXPermission { permissionCard }
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

    private var permissionCard: some View {
        PrefCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Нужен доступ Accessibility")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("Без него нельзя ни прочитать слово в поле ввода другого приложения, ни заменить его.")
                    }
                    Spacer()
                }
                Button("Открыть настройки", action: onOpenAccessibility)
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
            }
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
