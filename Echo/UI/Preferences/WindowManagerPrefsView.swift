//
//  WindowManagerPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: тайлинг окон.
struct WindowManagerPrefsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var windowManager: WindowManagerService
    let hasAXPermission: Bool
    let systemTilingEnabled: Bool
    let onDisableSystemTiling: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle("Window Manager")

            hasAXPermission ? AnyView(permissionGranted) : AnyView(permissionMissing)
            if settings.windowManagerEnabled && systemTilingEnabled { tilingConflict }

            PrefCard {
                Toggle(isOn: $settings.windowManagerEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Window Manager")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("По умолчанию работает при перетаскивании окна; зажмите Shift, чтобы временно отключить.")
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Window spacing")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(Int(settings.windowGap)) px")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.windowGap, in: 0...24, step: 1)
                        .tint(DS.accent)
                }
            }
        }
    }

    // MARK: - Карточки доступа

    private var permissionGranted: some View {
        PrefCard {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("Accessibility доступ выдан")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
        }
    }

    private var permissionMissing: some View {
        PrefCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Нужен доступ Accessibility")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("Включите \(AppInfo.name) в System Settings → Privacy & Security → Accessibility. Статус обновится здесь автоматически.")
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    Button("Открыть настройки") { windowManager.openAccessibilitySettings() }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                    Button("Перезапустить приложение") { windowManager.relaunchApp() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var tilingConflict: some View {
        PrefCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Конфликт с тайлингом macOS")
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption("Системный тайлинг macOS тоже магнитит окна к краям. Отключите его, чтобы не было конфликта.")
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    Button("Отключить тайлинг macOS", action: onDisableSystemTiling)
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                    Button("Открыть настройки") { windowManager.openTilingSettings() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}
