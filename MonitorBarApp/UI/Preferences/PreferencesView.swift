//
//  PreferencesView.swift
//  MonitorBarApp
//

import Combine
import SwiftUI

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
        .onAppear {
            hasAXPermission = windowManager.hasPermission()
            systemTilingEnabled = windowManager.isSystemEdgeTilingEnabled()
            hasBothLayouts = ultraSwitch.diagnostics().hasBothLayouts
        }
        .onReceive(permissionTimer) { _ in
            let granted = windowManager.hasPermission()
            if granted != hasAXPermission { hasAXPermission = granted }
            let tiling = windowManager.isSystemEdgeTilingEnabled()
            if tiling != systemTilingEnabled { systemTilingEnabled = tiling }
            let layouts = ultraSwitch.diagnostics().hasBothLayouts
            if layouts != hasBothLayouts { hasBothLayouts = layouts }
        }
    }

    // MARK: - Detail routing

    @ViewBuilder
    private var detailContent: some View {
        switch section ?? .general {
        case .general:       generalSection
        case .monitoring:    monitoringSection
        case .power:         powerSection
        case .appearance:    appearanceSection
        case .menuBar:       MenuBarPrefsView(settings: settings, metrics: metrics)
        case .windowManager: windowManagerSection
        case .ultraSwitch:   ultraSwitchSection
        case .keyboard:      keyboardSection
        case .updates:       UpdatesPrefsView(updater: updater, version: appVersion)
        case .clipboard:     clipboardSection
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("General")

            card {
                Toggle(isOn: $settings.launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at login")
                            .font(.system(size: 13, weight: .medium))
                        Text("Автоматически запускать \(appName) при входе в систему.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            card {
                HStack(spacing: 12) {
                    Image(systemName: "menubar.rectangle")
                        .font(.system(size: 22))
                        .foregroundStyle(DS.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appName)
                            .font(.system(size: 13, weight: .semibold))
                        Text("Версия \(appVersion)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Quit \(appName)") { NSApp.terminate(nil) }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var appName: String {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
            ?? "Echo"
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    // MARK: - System Monitoring

    private var monitoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("System Monitoring")

            card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Update interval")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(intervalLabel(settings.updateInterval))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.updateInterval, in: 0.5...5, step: 0.5)
                        .tint(DS.accent)
                    Text("Как часто опрашиваются CPU, RAM, диск и сеть. Чаще — отзывчивее, но выше нагрузка на процессор и расход батареи.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func intervalLabel(_ seconds: Double) -> String {
        seconds < 1
            ? String(format: "every %.1fs", seconds)
            : String(format: "every %gs", seconds)
    }

    // MARK: - Power Management

    private var powerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Power Management")

            card {
                Toggle(isOn: $settings.pauseWhenHidden) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause when no window is open")
                            .font(.system(size: 13, weight: .medium))
                        Text("Останавливать опрос метрик, когда поповер и все окна закрыты. Главная экономия батареи.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            card {
                Toggle(isOn: $settings.pauseOnSleep) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause during system sleep")
                            .font(.system(size: 13, weight: .medium))
                        Text("Полностью останавливать мониторинг на время сна Mac и возобновлять при пробуждении.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            card {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $settings.lowPowerThrottle) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Throttle in Low Power Mode")
                                .font(.system(size: 13, weight: .medium))
                            Text("Реже опрашивать метрики, когда включён режим энергосбережения macOS.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(DS.accent)

                    if settings.lowPowerThrottle {
                        Divider().opacity(0.12)
                        HStack {
                            Text("Low Power interval")
                                .font(.system(size: 12))
                            Spacer()
                            Text(intervalLabel(settings.lowPowerInterval))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.lowPowerInterval, in: 1...10, step: 1)
                            .tint(DS.accent)
                    }
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Appearance")

            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Theme")
                        .font(.system(size: 13, weight: .medium))
                    Picker("Theme", selection: $settings.appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text("Тема оформления окон \(appName). «System» следует за оформлением macOS.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Window Manager

    private var windowManagerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Window Manager")

            if hasAXPermission {
                card {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Accessibility доступ выдан")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                }
            } else {
                card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Нужен доступ Accessibility")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Включите MonitorBarApp в System Settings → Privacy & Security → Accessibility. Статус обновится здесь автоматически.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        HStack(spacing: 10) {
                            Button("Открыть настройки") {
                                windowManager.openAccessibilitySettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DS.accent)
                            Button("Перезапустить приложение") {
                                windowManager.relaunchApp()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if settings.windowManagerEnabled && systemTilingEnabled {
                card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Конфликт с тайлингом macOS")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Системный тайлинг macOS тоже магнитит окна к краям. Отключите его, чтобы не было конфликта.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        HStack(spacing: 10) {
                            Button("Отключить тайлинг macOS") {
                                windowManager.disableSystemEdgeTiling()
                                systemTilingEnabled = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DS.accent)
                            Button("Открыть настройки") {
                                windowManager.openTilingSettings()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            card {
                Toggle(isOn: $settings.windowManagerEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Window Manager")
                            .font(.system(size: 13, weight: .medium))
                        Text("По умолчанию работает при перетаскивании окна; зажмите Shift, чтобы временно отключить.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }

            card {
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

    // MARK: - Ultra Switch

    private var ultraSwitchSection: some View {
        UltraSwitchPrefsView(
            settings: settings,
            ultraSwitch: ultraSwitch,
            hasBothLayouts: hasBothLayouts
        )
    }

    // MARK: - Keyboard

    private var keyboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Keyboard Shortcuts")

            card {
                VStack(spacing: 0) {
                    ForEach(windowCommands) { command in
                        shortcutRow(command)
                        if command != windowCommands.last { Divider().opacity(0.12) }
                    }
                }
            }

            Text("Clipboard History")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)

            card {
                shortcutRow(.openClipboard)
            }
        }
    }

    private var windowCommands: [WMCommand] {
        WMCommand.allCases.filter { $0.isWindowCommand }
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

    // MARK: - Clipboard

    private var clipboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Clipboard History")

            card {
                Toggle(isOn: $clipboard.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Clipboard History")
                            .font(.system(size: 13, weight: .medium))
                        Text("Хранит последние скопированные тексты, файлы и изображения (в памяти).")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(DS.accent)
            }
        }
    }

    // MARK: - Building blocks

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .padding(.bottom, 4)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
    }
}
