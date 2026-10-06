//
//  HotKeyRegistrar.swift
//  MonitorBarApp
//

import AppKit

/// Регистрирует глобальные хоткеи по текущим настройкам.
///
/// Вынесено из `MenuBarController`: контроллер не должен знать, как команда
/// `WMCommand` превращается в вызов конкретного сервиса — только что
/// перерегистрация нужна при изменении настроек.
@MainActor
final class HotKeyRegistrar {

    private let hotKeys = HotKeyManager()
    private let settings: AppSettings
    private let windowManager: WindowManagerService
    private let ultraSwitch: UltraSwitchService
    private let translator: SelectionTranslator
    private let onClipboardCommand: () -> Void

    init(
        settings: AppSettings,
        windowManager: WindowManagerService,
        ultraSwitch: UltraSwitchService,
        translator: SelectionTranslator,
        onClipboardCommand: @escaping () -> Void
    ) {
        self.settings = settings
        self.windowManager = windowManager
        self.ultraSwitch = ultraSwitch
        self.translator = translator
        self.onClipboardCommand = onClipboardCommand
    }

    /// Перерегистрирует все хоткеи по текущим настройкам.
    /// Оконные команды регистрируются только если включён Window Manager,
    /// команды раскладки — только если включён Ultra Switch; clipboard — всегда.
    func registerAll() {
        hotKeys.unregisterAll()
        var layoutShortcuts: [KeyboardShortcut] = []
        defer { ultraSwitch.reserveShortcuts(layoutShortcuts) }
        for command in WMCommand.allCases {
            guard let shortcut = settings.shortcut(for: command) else { continue }
            guard Self.shouldRegister(
                command,
                windowManagerEnabled: settings.windowManagerEnabled,
                ultraSwitchEnabled: settings.ultraSwitchEnabled,
                autoConvertEnabled: settings.autoConvertEnabled
            ) else { continue }

            if let layout = command.layout {
                hotKeys.register(shortcut, label: command.rawValue) { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        self.windowManager.apply(layout, gap: CGFloat(self.settings.windowGap))
                    }
                }
                continue
            }

            switch command {
            case .switchLayout:
                layoutShortcuts.append(shortcut)
                hotKeys.register(shortcut, label: command.rawValue) { [weak self] in
                    MainActor.assumeIsolated { self?.ultraSwitch.switchLayout() }
                }
            case .convertWord:
                layoutShortcuts.append(shortcut)
                hotKeys.register(shortcut, label: command.rawValue) { [weak self] in
                    MainActor.assumeIsolated { self?.ultraSwitch.convertLastWord() }
                }
            case .translateSelection:
                hotKeys.register(shortcut, label: command.rawValue) { [weak self] in
                    MainActor.assumeIsolated { self?.translator.translateSelection() }
                }
            default:
                hotKeys.register(shortcut, label: command.rawValue) { [weak self] in
                    MainActor.assumeIsolated { self?.onClipboardCommand() }
                }
            }
        }
    }

    /// Владелец хоткея команды. Оконным нужен Window Manager, хоткеям раскладки
    /// и переводу — Ultra Switch. Конвертация слова читает буфер набранного,
    /// который наполняет только перехват автоисправления: без неё хоткей всегда
    /// отвечал бы «нечего исправлять», с ней — работает и как отмена автозамены.
    static func shouldRegister(
        _ command: WMCommand,
        windowManagerEnabled: Bool,
        ultraSwitchEnabled: Bool,
        autoConvertEnabled: Bool
    ) -> Bool {
        if command.isWindowCommand { return windowManagerEnabled }
        if command == .convertWord { return autoConvertEnabled }
        if command.isUltraSwitchCommand { return ultraSwitchEnabled }
        return true
    }
}
