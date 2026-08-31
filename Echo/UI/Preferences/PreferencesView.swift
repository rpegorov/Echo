//
//  PreferencesView.swift
//  MonitorBarApp
//

import Combine
import SwiftUI

/// Окно настроек: список разделов слева, содержимое справа.
///
/// Сами разделы живут в отдельных файлах — здесь только навигация и то
/// состояние, которое нужно нескольким разделам сразу (статусы доступа,
/// опрашиваемые по таймеру).
struct PreferencesView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var clipboard: ClipboardService
    @ObservedObject var windowManager: WindowManagerService
    let ultraSwitch: UltraSwitchService
    @ObservedObject var updater: UpdaterService
    @ObservedObject var metrics: MetricsService

    @State private var section: PrefSection? = .general
    @State private var hasAXPermission = false
    @State private var systemTilingEnabled = false
    @State private var hasBothLayouts = true

    /// Живой опрос статуса доступа — UI сам переключится, когда выдашь право.
    private let permissionTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    enum PrefSection: String, CaseIterable, Identifiable, Hashable {
        case general = "General"
        case monitoring = "System Monitoring"
        case power = "Power Management"
        case appearance = "Appearance"
        case menuBar = "Menu Bar"
        case windowManager = "Window Manager"
        case ultraSwitch = "Ultra Switch"
        case snippets = "Сниппеты"
        case keyboard = "Keyboard Shortcuts"
        case updates = "Updates"
        case clipboard = "Clipboard History"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general:       return "gearshape"
            case .monitoring:    return "gauge.with.dots.needle.67percent"
            case .power:         return "battery.100.bolt"
            case .appearance:    return "paintbrush"
            case .menuBar:       return "menubar.rectangle"
            case .windowManager: return "macwindow.on.rectangle"
            case .ultraSwitch:   return "globe"
            case .snippets:      return "text.badge.plus"
            case .keyboard:      return "keyboard"
            case .updates:       return "arrow.down.circle"
            case .clipboard:     return "doc.on.clipboard"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(PrefSection.allCases, selection: $section) { item in
                Label(item.rawValue, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(210)
        } detail: {
            ScrollView {
                detailContent
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 720, height: 520)
        .onAppear(perform: refreshStatuses)
        .onReceive(permissionTimer) { _ in refreshStatuses() }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch section ?? .general {
        case .general:
            GeneralPrefsView(settings: settings)
        case .monitoring:
            MonitoringPrefsView(settings: settings)
        case .power:
            PowerPrefsView(settings: settings)
        case .appearance:
            AppearancePrefsView(settings: settings)
        case .menuBar:
            MenuBarPrefsView(settings: settings, metrics: metrics)
        case .windowManager:
            WindowManagerPrefsView(
                settings: settings,
                windowManager: windowManager,
                hasAXPermission: hasAXPermission,
                systemTilingEnabled: systemTilingEnabled,
                onDisableSystemTiling: {
                    windowManager.disableSystemEdgeTiling()
                    systemTilingEnabled = false
                }
            )
        case .ultraSwitch:
            UltraSwitchPrefsView(
                settings: settings,
                ultraSwitch: ultraSwitch,
                hasBothLayouts: hasBothLayouts
            )
        case .snippets:
            SnippetsPrefsView(store: ultraSwitch.snippets, settings: settings)
        case .keyboard:
            ShortcutsPrefsView(settings: settings)
        case .updates:
            UpdatesPrefsView(updater: updater, version: AppInfo.version)
        case .clipboard:
            ClipboardPrefsView(clipboard: clipboard)
        }
    }

    /// Статусы доступа и раскладок опрашиваются, а не приходят событиями:
    /// система не уведомляет о выдаче права, а раздел должен переключиться сам.
    private func refreshStatuses() {
        let granted = windowManager.hasPermission()
        if granted != hasAXPermission { hasAXPermission = granted }

        let tiling = windowManager.isSystemEdgeTilingEnabled()
        if tiling != systemTilingEnabled { systemTilingEnabled = tiling }

        let layouts = ultraSwitch.diagnostics().hasBothLayouts
        if layouts != hasBothLayouts { hasBothLayouts = layouts }
    }
}
