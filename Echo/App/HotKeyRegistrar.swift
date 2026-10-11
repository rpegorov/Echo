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
    private let grids: any ActiveGridProviding
    private let onClipboardCommand: () -> Void

    init(
        settings: AppSettings,
        windowManager: WindowManagerService,
        ultraSwitch: UltraSwitchService,
        translator: SelectionTranslator,
        grids: any ActiveGridProviding,
        onClipboardCommand: @escaping () -> Void
    ) {
        self.settings = settings
        self.windowManager = windowManager
        self.ultraSwitch = ultraSwitch
        self.translator = translator
        self.grids = grids
        self.onClipboardCommand = onClipboardCommand
    }

    /// Re-registers every hotkey from the current settings.
    /// Window commands need the window manager, layout commands need Ultra Switch; clipboard always registers.
    /// While a shortcut is being recorded the Carbon hotkeys are released but the layout reservations stay,
    /// so the combination being recorded never reaches the keystroke buffer.
    func registerAll() {
        hotKeys.unregisterAll()
        var layoutShortcuts: [KeyboardShortcut] = []
        defer { ultraSwitch.reserveShortcuts(layoutShortcuts) }
        let paused = settings.isRecordingShortcut
        for command in WMCommand.allCases {
            guard let shortcut = settings.shortcut(for: command) else { continue }
            guard Self.shouldRegister(
                command,
                windowManagerEnabled: settings.windowManagerEnabled,
                ultraSwitchEnabled: settings.ultraSwitchEnabled,
                autoConvertEnabled: settings.autoConvertEnabled
            ) else { continue }

            if command == .switchLayout || command == .convertWord {
                layoutShortcuts.append(shortcut)
            }
            guard !paused else { continue }
            register(command, shortcut: shortcut)
        }
    }

    private func register(_ command: WMCommand, shortcut: KeyboardShortcut) {
        switch command {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf,
             .topLeft, .topRight, .bottomLeft, .bottomRight,
             .leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds,
             .center, .maximize, .nextDisplay, .previousDisplay,
             .zone1, .zone2, .zone3, .zone4, .zone5, .zone6, .zone7, .zone8, .zone9:
            hotKeys.register(shortcut, label: command.rawValue) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.windowManager.perform(
                        command,
                        gap: CGFloat(self.settings.windowGap),
                        cycling: self.settings.layoutCyclingEnabled
                    )
                }
            }
        case .switchLayout:
            hotKeys.register(shortcut, label: command.rawValue) { [weak self] in
                MainActor.assumeIsolated { self?.ultraSwitch.switchLayout() }
            }
        case .convertWord:
            hotKeys.register(shortcut, label: command.rawValue) { [weak self] in
                MainActor.assumeIsolated { self?.ultraSwitch.convertLastWord() }
            }
        case .translateSelection:
            hotKeys.register(shortcut, label: command.rawValue) { [weak self] in
                MainActor.assumeIsolated { self?.translator.translateSelection() }
            }
        case .openClipboard:
            hotKeys.register(shortcut, label: command.rawValue) { [weak self] in
                MainActor.assumeIsolated { self?.onClipboardCommand() }
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
