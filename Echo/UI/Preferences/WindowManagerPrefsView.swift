//
//  WindowManagerPrefsView.swift
//  MonitorBarApp
//

import SwiftUI

/// Раздел Preferences: тайлинг окон.
struct WindowManagerPrefsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var windowManager: WindowManagerService
    @EnvironmentObject private var loc: Localizer
    let hasAXPermission: Bool
    let systemTilingEnabled: Bool
    let onDisableSystemTiling: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle(loc.t(InputKey.windowManagerTitle))

            hasAXPermission ? AnyView(permissionGranted) : AnyView(permissionMissing)
            if settings.windowManagerEnabled && systemTilingEnabled { tilingConflict }

            PrefCard {
                Toggle(isOn: $settings.windowManagerEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t(InputKey.windowManagerEnableTitle))
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption(loc.t(InputKey.windowManagerEnableCaption))
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(loc.t(InputKey.windowSpacingTitle))
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(loc.t(InputKey.windowSpacingValue, Int64(settings.windowGap)))
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
                Text(loc.t(InputKey.accessibilityGrantedTitle))
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
                        Text(loc.t(InputKey.accessibilityMissingTitle))
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption(loc.t(InputKey.accessibilityMissingCaption, AppInfo.name))
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    Button(loc.t(InputKey.openSettingsButton)) { windowManager.openAccessibilitySettings() }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                    Button(loc.t(InputKey.relaunchAppButton)) { windowManager.relaunchApp() }
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
                        Text(loc.t(InputKey.tilingConflictTitle))
                            .font(.system(size: 13, weight: .medium))
                        PrefCaption(loc.t(InputKey.tilingConflictCaption))
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    Button(loc.t(InputKey.disableSystemTilingButton), action: onDisableSystemTiling)
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                    Button(loc.t(InputKey.openSettingsButton)) { windowManager.openTilingSettings() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}
