//
//  AppSettings.swift
//  MonitorBarApp
//

import AppKit
import Combine
import ServiceManagement

/// Настройки приложения, сохраняемые в UserDefaults.
@MainActor
final class AppSettings: ObservableObject {

    @Published var windowManagerEnabled: Bool {
        didSet { defaults.set(windowManagerEnabled, forKey: Keys.enabled); onChange?() }
    }

    /// Зазор между окнами при тайлинге, px.
    @Published var windowGap: Double {
        didSet { defaults.set(windowGap, forKey: Keys.gap) }
    }

    @Published private(set) var shortcuts: [WMCommand: KeyboardShortcut]

    // MARK: - General

    /// Запускать приложение при входе в систему (через SMAppService).
    @Published var launchAtLogin: Bool {
        didSet { onLaunchAtLoginChange?() }
    }

    // MARK: - Ultra Switch

    /// Хоткеи раскладки: мгновенное переключение и конвертация слова.
    @Published var ultraSwitchEnabled: Bool {
        didSet { defaults.set(ultraSwitchEnabled, forKey: Keys.ultraSwitch); onChange?(); onUltraSwitchChange?() }
    }

    /// Автоматически исправлять слово, набранное не в той раскладке.
    @Published var autoConvertEnabled: Bool {
        didSet { defaults.set(autoConvertEnabled, forKey: Keys.autoConvert); onUltraSwitchChange?() }
    }

    // MARK: - System Monitoring

    /// Базовый интервал опроса метрик, секунды.
    @Published var updateInterval: Double {
        didSet { defaults.set(updateInterval, forKey: Keys.updateInterval); onMonitoringChange?() }
    }

    // MARK: - Power Management

    /// Останавливать опрос метрик, когда не открыто ни одно окно/поповер.
    @Published var pauseWhenHidden: Bool {
        didSet { defaults.set(pauseWhenHidden, forKey: Keys.pauseWhenHidden); onMonitoringChange?() }
    }

    /// Останавливать опрос на время сна системы.
    @Published var pauseOnSleep: Bool {
        didSet { defaults.set(pauseOnSleep, forKey: Keys.pauseOnSleep); onMonitoringChange?() }
    }

    /// Снижать частоту опроса в режиме энергосбережения (Low Power Mode).
    @Published var lowPowerThrottle: Bool {
        didSet { defaults.set(lowPowerThrottle, forKey: Keys.lowPowerThrottle); onMonitoringChange?() }
    }

    /// Интервал опроса в режиме энергосбережения, секунды.
    @Published var lowPowerInterval: Double {
        didSet { defaults.set(lowPowerInterval, forKey: Keys.lowPowerInterval); onMonitoringChange?() }
    }

    // MARK: - Menu Bar

    /// Что показывать в строке меню: иконку, живые метрики или свою картинку.
    @Published var menuBarIconMode: MenuBarIconMode {
        didSet { defaults.set(menuBarIconMode.rawValue, forKey: Keys.menuBarMode); onMenuBarChange?() }
    }

    /// Какие метрики выводить в строке меню (для режима «Метрики»).
    @Published var menuBarMetrics: [MetricTab] {
        didSet {
            defaults.set(menuBarMetrics.map(\.rawValue), forKey: Keys.menuBarMetrics)
            onMenuBarChange?()
        }
    }

    /// Интервал опроса, когда открыта только строка меню, секунды.
    /// Отдельный от основного: цифры в трее не требуют секундной точности,
    /// а опрос при закрытом интерфейсе идёт постоянно и тратит батарею.
    @Published var menuBarInterval: Double {
        didSet { defaults.set(menuBarInterval, forKey: Keys.menuBarInterval); onMonitoringChange?() }
    }

    /// Путь к пользовательской картинке для строки меню.
    @Published var customIconPath: String? {
        didSet { defaults.set(customIconPath, forKey: Keys.menuBarIconPath); onMenuBarChange?() }
    }

    // MARK: - Appearance

    /// Режим оформления (System / Light / Dark).
    @Published var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearance); onAppearanceChange?() }
    }

    // MARK: - Language

    /// Выбор языка интерфейса: следовать системе или зафиксированный язык.
    @Published var language: LanguagePreference {
        didSet { defaults.set(language.rawValue, forKey: Keys.language); onLanguageChange?() }
    }

    /// Вызывается при изменении набора хоткеев или флага включения — для перерегистрации.
    var onChange: (@MainActor () -> Void)?
    /// Изменения, влияющие на цикл мониторинга (интервал, паузы, троттлинг).
    var onMonitoringChange: (@MainActor () -> Void)?
    /// Изменение режима оформления.
    var onAppearanceChange: (@MainActor () -> Void)?
    /// Изменение флага «запуск при входе».
    var onLaunchAtLoginChange: (@MainActor () -> Void)?
    /// Включение/выключение Ultra Switch или автозамены.
    var onUltraSwitchChange: (@MainActor () -> Void)?
    /// Изменение оформления строки меню.
    var onMenuBarChange: (@MainActor () -> Void)?
    /// Изменение выбора языка интерфейса.
    var onLanguageChange: (@MainActor () -> Void)?

    private let defaults: UserDefaults

    private enum Keys {
        static let enabled = "wm.enabled"
        static let gap = "wm.gap"
        static let shortcuts = "wm.shortcuts"
        static let updateInterval = "monitor.updateInterval"
        static let pauseWhenHidden = "power.pauseWhenHidden"
        static let pauseOnSleep = "power.pauseOnSleep"
        static let lowPowerThrottle = "power.lowPowerThrottle"
        static let lowPowerInterval = "power.lowPowerInterval"
        static let appearance = "appearance.mode"
        static let ultraSwitch = "ultraSwitch.enabled"
        static let autoConvert = "ultraSwitch.autoConvert"
        static let shortcutsVersion = "wm.shortcuts.version"
        static let menuBarMode = "menuBar.mode"
        static let menuBarMetrics = "menuBar.metrics"
        static let menuBarIconPath = "menuBar.iconPath"
        static let menuBarInterval = "menuBar.interval"
        static let language = "general.language"
    }

    /// Текущая версия набора хоткеев. При росте — в сохранённый набор
    /// доливаются дефолты команд, которых на прошлой версии ещё не было.
    private static let shortcutsVersion = 2

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Долитые дефолты обязаны попасть в хранилище: маркер версии пишется в
        // конце init, и без сохранения следующий запуск остался бы без хоткеев.
        var needsShortcutPersist = false

        windowManagerEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        windowGap = defaults.object(forKey: Keys.gap) as? Double ?? 8

        // General: фактический статус берём у системы, а не из defaults.
        launchAtLogin = (SMAppService.mainApp.status == .enabled)

        // System Monitoring
        updateInterval = defaults.object(forKey: Keys.updateInterval) as? Double ?? 1.0

        // Power Management
        pauseWhenHidden  = defaults.object(forKey: Keys.pauseWhenHidden)  as? Bool   ?? true
        pauseOnSleep     = defaults.object(forKey: Keys.pauseOnSleep)     as? Bool   ?? true
        lowPowerThrottle = defaults.object(forKey: Keys.lowPowerThrottle) as? Bool   ?? true
        lowPowerInterval = defaults.object(forKey: Keys.lowPowerInterval) as? Double ?? 3.0

        // Appearance
        appearanceMode = (defaults.string(forKey: Keys.appearance)
            .flatMap(AppearanceMode.init(rawValue:))) ?? .system

        // Language
        language = (defaults.string(forKey: Keys.language)
            .flatMap(LanguagePreference.init(rawValue:))) ?? .system

        // Menu Bar
        menuBarIconMode = (defaults.string(forKey: Keys.menuBarMode)
            .flatMap(MenuBarIconMode.init(rawValue:))) ?? .appIcon
        menuBarMetrics = (defaults.stringArray(forKey: Keys.menuBarMetrics) ?? ["CPU"])
            .compactMap(MetricTab.init(rawValue:))
            .filter { MetricTab.menuBarSelectable.contains($0) }
        customIconPath = defaults.string(forKey: Keys.menuBarIconPath)
        menuBarInterval = defaults.object(forKey: Keys.menuBarInterval) as? Double ?? 5.0

        // Ultra Switch — обе фичи выключены по умолчанию: автозамена трогает
        // чужой ввод, включать её пользователь должен осознанно.
        ultraSwitchEnabled = defaults.object(forKey: Keys.ultraSwitch) as? Bool ?? false
        autoConvertEnabled = defaults.object(forKey: Keys.autoConvert) as? Bool ?? false

        // Если есть сохранённый набор — он авторитетный (учитывает удалённые
        // пользователем хоткеи). Иначе — дефолты (первый запуск).
        if let data = defaults.data(forKey: Keys.shortcuts),
           let stored = try? JSONDecoder().decode([String: KeyboardShortcut].self, from: data) {
            var result: [WMCommand: KeyboardShortcut] = [:]
            for (key, value) in stored {
                if let command = WMCommand(rawValue: key) { result[command] = value }
            }
            // Доливаем дефолты команд, появившихся после сохранения набора.
            let storedVersion = defaults.integer(forKey: Keys.shortcutsVersion)
            if storedVersion < Self.shortcutsVersion {
                for command in WMCommand.allCases where result[command] == nil && command.isUltraSwitchCommand {
                    result[command] = command.defaultShortcut
                }
                needsShortcutPersist = true
            }
            shortcuts = result
        } else {
            var defaultsMap: [WMCommand: KeyboardShortcut] = [:]
            for command in WMCommand.allCases {
                if let shortcut = command.defaultShortcut { defaultsMap[command] = shortcut }
            }
            shortcuts = defaultsMap
        }

        if needsShortcutPersist { persistShortcuts() }
        defaults.set(Self.shortcutsVersion, forKey: Keys.shortcutsVersion)
    }

    func shortcut(for command: WMCommand) -> KeyboardShortcut? {
        shortcuts[command]
    }

    func setShortcut(_ shortcut: KeyboardShortcut?, for command: WMCommand) {
        if let shortcut {
            shortcuts[command] = shortcut
        } else {
            shortcuts.removeValue(forKey: command)
        }
        persistShortcuts()
        onChange?()
    }

    private func persistShortcuts() {
        let stringKeyed = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(stringKeyed) {
            defaults.set(data, forKey: Keys.shortcuts)
        }
    }
}
