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
    private let arrangements: any ArrangementApplying
    private let gridCycler: any GridCycling
    private let onClipboardCommand: () -> Void

    init(
        settings: AppSettings,
        windowManager: WindowManagerService,
        ultraSwitch: UltraSwitchService,
        translator: SelectionTranslator,
        grids: any ActiveGridProviding,
        arrangements: any ArrangementApplying,
        gridCycler: any GridCycling,
        onClipboardCommand: @escaping () -> Void
    ) {
        self.settings = settings
        self.windowManager = windowManager
        self.ultraSwitch = ultraSwitch
        self.translator = translator
        self.grids = grids
        self.arrangements = arrangements
        self.gridCycler = gridCycler
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
        guard !paused else { return }
        registerArrangements()
    }

    private func registerArrangements() {
        let chosen = Self.arrangementHotKeys(
            shortcuts: settings.arrangementShortcuts,
            existing: arrangements.arrangementIDs,
            commandShortcuts: WMCommand.allCases.compactMap { settings.shortcut(for: $0) },
            windowManagerEnabled: settings.windowManagerEnabled
        )
        for (id, shortcut) in chosen {
            hotKeys.register(shortcut, label: ShortcutOwner.arrangement(id).storageKey) { [weak self] in
                MainActor.assumeIsolated { _ = self?.arrangements.apply(id) }
            }
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
                        cycling: self.settings.layoutCyclingEnabled,
                        grids: self.grids
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
        case .nextGrid:
            hotKeys.register(shortcut, label: command.rawValue) { [weak self] in
                MainActor.assumeIsolated { self?.gridCycler.advance() }
            }
        }
    }

    /// Arrangement hotkeys to install, in a stable order. Skipped: a key whose arrangement is gone,
    /// anything while the window manager is off, and a key a command already uses.
    static func arrangementHotKeys(
        shortcuts: [UUID: KeyboardShortcut],
        existing: Set<UUID>,
        commandShortcuts: [KeyboardShortcut],
        windowManagerEnabled: Bool
    ) -> [(UUID, KeyboardShortcut)] {
        guard windowManagerEnabled else { return [] }
        return shortcuts
            .filter { id, shortcut in
                existing.contains(id) && !commandShortcuts.contains { $0.collides(with: shortcut) }
            }
            .sorted { $0.key.uuidString < $1.key.uuidString }
            .map { ($0.key, $0.value) }
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
