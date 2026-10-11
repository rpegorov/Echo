//
//  WindowManagerPrefsView.swift
//  MonitorBarApp
//

import AppKit
import SwiftUI

/// Раздел Preferences: тайлинг окон.
struct WindowManagerPrefsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var windowManager: WindowManagerService
    @EnvironmentObject private var loc: Localizer
    let hasAXPermission: Bool
    @ObservedObject var gridStore: GridStore
    let tilingConflict: TilingConflict
    let onResolveTilingConflict: (TilingConflict) -> Void
    let onOpenGridEditor: (GridEditorRequest) -> Void

    @State private var displays = ZoneMapDisplay.connected()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrefTitle(loc.t(InputKey.windowManagerTitle))

            hasAXPermission ? AnyView(permissionGranted) : AnyView(permissionMissing)
            if settings.windowManagerEnabled && tilingConflict.exists { tilingConflictCard }

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

            PrefCard {
                Toggle(isOn: $settings.layoutCyclingEnabled) {
                    VStack(alignment: .leading, spacing: DS.ZoneMap.zoneTextSpacing) {
                        Text(loc.t(InputKey.layoutCyclingTitle))
                            .font(DS.ZoneMap.titleFont)
                        PrefCaption(loc.t(InputKey.layoutCyclingCaption))
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            PrefCard {
                ZoneMapView(settings: settings, displays: displays)
            }

            GridsPrefsSection(store: gridStore, settings: settings, onOpenEditor: onOpenGridEditor)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displays = ZoneMapDisplay.connected()
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

    private var tilingConflictCard: some View {
        PrefCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t(InputKey.tilingConflictTitle))
                            .font(.system(size: 13, weight: .medium))
                        if tilingConflict.edge { PrefCaption(loc.t(InputKey.tilingConflictCaption)) }
                        if tilingConflict.optionDrag { PrefCaption(loc.t(InputKey.tilingOptionConflictCaption)) }
                    }
                    Spacer()
                }
                HStack(spacing: 10) {
                    Button(loc.t(InputKey.disableSystemTilingButton)) { onResolveTilingConflict(tilingConflict) }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                    Button(loc.t(InputKey.openSettingsButton)) { windowManager.openTilingSettings() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}
