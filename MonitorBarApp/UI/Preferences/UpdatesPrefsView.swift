//
//  UpdatesPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: автообновление.
struct UpdatesPrefsView: View {
    @ObservedObject var updater: UpdaterService
    let version: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle("Updates")

            PrefCard {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(DS.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Установлена версия \(version)")
                            .font(.system(size: 13, weight: .semibold))
                        PrefCaption(lastCheckLabel)
                    }
                    Spacer()
                    Button("Проверить сейчас") { updater.checkForUpdates() }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                        .disabled(!updater.canCheck)
                }
            }

            PrefCard {
                Toggle(isOn: $updater.automaticallyChecks) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Проверять обновления автоматически")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("Раз в сутки в фоне. Приложение спросит перед установкой.")
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                Toggle(isOn: $updater.automaticallyDownloads) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Скачивать обновления заранее")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("Новая версия скачается в фоне, установка — по вашему подтверждению.")
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
                .disabled(!updater.automaticallyChecks)
            }

            PrefCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Источник обновлений")
                        .font(.system(size: 13, weight: .medium))
                    PrefCaption(updater.feedURL)
                    PrefCaption("Каждая сборка подписана ключом EdDSA — обновление с чужого адреса приложение не примет.")
                }
            }
        }
    }

    private var lastCheckLabel: String {
        guard let date = updater.lastCheckDate else { return "Обновления ещё не проверялись" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Последняя проверка: \(formatter.string(from: date))"
    }
}
