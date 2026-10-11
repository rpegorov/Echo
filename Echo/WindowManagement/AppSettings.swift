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

    /// Repeating a half shortcut steps the width ½ → ⅔ → ⅓.
    @Published var layoutCyclingEnabled: Bool {
        didSet { defaults.set(layoutCyclingEnabled, forKey: Keys.cycleLayouts) }
    }

    @Published private(set) var arrangementShortcuts: [UUID: KeyboardShortcut]

    /// The owner whose shortcut a recorder is capturing; Echo's hotkeys stay unregistered meanwhile. Not persisted.
    @Published private(set) var recordingOwner: ShortcutOwner?

    var isRecordingShortcut: Bool { recordingOwner != nil }

    /// New windows of apps with a rule go to their zone.
    @Published var autoRulesEnabled: Bool {
        didSet { defaults.set(autoRulesEnabled, forKey: Keys.autoRules); onChange?() }
    }

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

    /// How CPU, memory and disk load is drawn in the popover.
    @Published var popoverMetricsStyle: PopoverMetricsStyle {
        didSet { defaults.set(popoverMetricsStyle.rawValue, forKey: Keys.popoverMetricsStyle) }
    }

    // MARK: - Grid mode

    /// Modifier that switches a window drag to the display's grid; the snapper reads it at the start of every drag.
    @Published var gridModifier: GridDragModifier {
        didSet { defaults.set(gridModifier.rawValue, forKey: Keys.gridModifier) }
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
        static let cycleLayouts = "wm.cycleLayouts"
        static let shortcuts = "wm.shortcuts"
        static let updateInterval = "monitor.updateInterval"
        static let pauseWhenHidden = "power.pauseWhenHidden"
        static let pauseOnSleep = "power.pauseOnSleep"
        static let lowPowerThrottle = "power.lowPowerThrottle"
        static let lowPowerInterval = "power.lowPowerInterval"
        static let appearance = "appearance.mode"
        static let popoverMetricsStyle = "appearance.popoverMetricsStyle"
        static let ultraSwitch = "ultraSwitch.enabled"
        static let autoConvert = "ultraSwitch.autoConvert"
        static let shortcutsVersion = "wm.shortcuts.version"
        static let menuBarMode = "menuBar.mode"
        static let menuBarMetrics = "menuBar.metrics"
        static let menuBarIconPath = "menuBar.iconPath"
        static let menuBarInterval = "menuBar.interval"
        static let language = "general.language"
        static let gridModifier = "wm.gridModifier"
        static let autoRules = "wm.autoRules.enabled"
    }

    /// Version of the stored shortcut set. When it grows, defaults of newer commands are added
    /// to a stored set by `ShortcutBackfill`.
    private static let shortcutsVersion = 4

    /// Stored entries whose key is neither a `WMCommand` raw value nor an arrangement key; written back unchanged.
    private var unrecognizedShortcutEntries: [String: KeyboardShortcut] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Backfilled defaults must be saved: the version marker is written at the end of init,
        // so without a save the next launch would not add them again.
        var needsShortcutPersist = false

        windowManagerEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        windowGap = defaults.object(forKey: Keys.gap) as? Double ?? 8
        layoutCyclingEnabled = defaults.object(forKey: Keys.cycleLayouts) as? Bool ?? true
        autoRulesEnabled = defaults.object(forKey: Keys.autoRules) as? Bool ?? true

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
        popoverMetricsStyle = (defaults.string(forKey: Keys.popoverMetricsStyle)
            .flatMap(PopoverMetricsStyle.init(rawValue:))) ?? .rings

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

        gridModifier = defaults.string(forKey: Keys.gridModifier).flatMap(GridDragModifier.init(rawValue:)) ?? .option

        let storedVersion = defaults.integer(forKey: Keys.shortcutsVersion)

        // Если есть сохранённый набор — он авторитетный (учитывает удалённые
        // пользователем хоткеи). Иначе — дефолты (первый запуск).
        if let data = defaults.data(forKey: Keys.shortcuts),
           let stored = try? JSONDecoder().decode([String: KeyboardShortcut].self, from: data) {
            var migrated = stored
            if storedVersion < Self.shortcutsVersion {
                migrated = ShortcutBackfill.apply(to: stored, storedVersion: storedVersion)
                needsShortcutPersist = true
            }
            var result: [WMCommand: KeyboardShortcut] = [:]
            var arrangementEntries: [UUID: KeyboardShortcut] = [:]
            var unrecognized: [String: KeyboardShortcut] = [:]
            for (key, value) in migrated {
                switch ShortcutOwner(storageKey: key) {
                case .command(let command)?:      result[command] = value
                case .arrangement(let id)?:       arrangementEntries[id] = value
                case nil:                         unrecognized[key] = value
                }
            }
            unrecognizedShortcutEntries = unrecognized
            arrangementShortcuts = arrangementEntries
            shortcuts = result
        } else {
            var defaultsMap: [WMCommand: KeyboardShortcut] = [:]
            for command in WMCommand.allCases {
                if let shortcut = command.defaultShortcut { defaultsMap[command] = shortcut }
            }
            shortcuts = defaultsMap
            arrangementShortcuts = [:]
        }

        if needsShortcutPersist { persistShortcuts() }
        defaults.set(max(storedVersion, Self.shortcutsVersion), forKey: Keys.shortcutsVersion)
    }

    func shortcut(for owner: ShortcutOwner) -> KeyboardShortcut? {
        switch owner {
        case .command(let command):   return shortcuts[command]
        case .arrangement(let id):    return arrangementShortcuts[id]
        }
    }

    func shortcut(for command: WMCommand) -> KeyboardShortcut? {
        shortcut(for: .command(command))
    }

    /// Starts capturing for `owner`, which cancels any other recorder; nil stops capturing.
    func setRecordingOwner(_ owner: ShortcutOwner?) {
        guard owner != recordingOwner else { return }
        recordingOwner = owner
        onChange?()
    }

    /// The first owner, commands in declaration order and then arrangements by `uuidString`,
    /// bound to a combination that collides with `shortcut`.
    func owner(using shortcut: KeyboardShortcut) -> ShortcutOwner? {
        orderedOwners.first { self.shortcut(for: $0)?.collides(with: shortcut) == true }
    }

    /// Binds `shortcut` to `owner`. Every other owner holding a colliding combination loses it;
    /// the first of them, in `owner(using:)` order, is returned.
    @discardableResult
    func setShortcut(_ shortcut: KeyboardShortcut?, for owner: ShortcutOwner) -> ShortcutOwner? {
        guard let shortcut else {
            store(nil, for: owner)
            persistShortcuts()
            onChange?()
            return nil
        }
        let displaced = orderedOwners.filter {
            $0 != owner && self.shortcut(for: $0)?.collides(with: shortcut) == true
        }
        displaced.forEach { store(nil, for: $0) }
        store(shortcut, for: owner)
        persistShortcuts()
        onChange?()
        return displaced.first
    }

    @discardableResult
    func setShortcut(_ shortcut: KeyboardShortcut?, for command: WMCommand) -> ShortcutOwner? {
        setShortcut(shortcut, for: .command(command))
    }

    private var orderedOwners: [ShortcutOwner] {
        WMCommand.allCases.map(ShortcutOwner.command)
            + arrangementShortcuts.keys.sorted { $0.uuidString < $1.uuidString }.map(ShortcutOwner.arrangement)
    }

    private func store(_ shortcut: KeyboardShortcut?, for owner: ShortcutOwner) {
        switch owner {
        case .command(let command):   shortcuts[command] = shortcut
        case .arrangement(let id):    arrangementShortcuts[id] = shortcut
        }
    }

    private func persistShortcuts() {
        let commandEntries = shortcuts.map { (ShortcutOwner.command($0.key).storageKey, $0.value) }
        let arrangementEntries = arrangementShortcuts.map { (ShortcutOwner.arrangement($0.key).storageKey, $0.value) }
        let recognized = Dictionary(uniqueKeysWithValues: commandEntries + arrangementEntries)
        let stringKeyed = recognized.merging(unrecognizedShortcutEntries, uniquingKeysWith: { current, _ in current })
        if let data = try? JSONEncoder().encode(stringKeyed) {
            defaults.set(data, forKey: Keys.shortcuts)
        }
    }
}
