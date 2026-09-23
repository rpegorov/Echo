//
//  MenuBarController.swift
//  MonitorBarApp
//
//  Created by Ростислав Егоров on 08.12.2025.
//

import Cocoa
import Combine
import ServiceManagement
import SwiftUI

/// Управляет иконкой в строке меню, поповером и отдельным детальным окном.
/// Держит единственные экземпляры сервисов, общие для поповера и окна.
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    private let environment: AppEnvironment
    private lazy var windows = AppWindows(environment: environment)
    private lazy var hotKeyRegistrar = HotKeyRegistrar(
        settings: environment.settings,
        windowManager: environment.windowManager,
        ultraSwitch: environment.ultraSwitch,
        translator: environment.translator,
        onClipboardCommand: { [weak self] in self?.openClipboard() }
    )

    /// Глобальный монитор кликов вне поповера (для закрытия по клику на экране).
    private var outsideClickMonitor: Any?

    /// Подписка на метрики — только ради строки меню в режиме «Метрики».
    private var metricsObserver: AnyCancellable?

    /// Подписка на смену языка — переприменяет заголовки окон и строку меню без перезапуска.
    private var languageObserver: AnyCancellable?

    init(environment: AppEnvironment) {
        self.environment = environment
        super.init()

        environment.updater.start()
        environment.battery.start()
        setupStatusItem()
        setupPopover()

        windows.onWindowClosed = { [weak self] in self?.environment.monitoring.updateMonitoringState() }
        environment.monitoring.isUIVisible = { [weak self] in self?.isDetailUIVisible ?? false }
        environment.monitoring.menuBarShowsMetrics = { [weak self] in self?.environment.settings.menuBarIconMode == .metrics }

        languageObserver = environment.localizer.$language.dropFirst().sink { [weak self] _ in
            guard let self else { return }
            self.windows.applyTitles(using: self.environment.localizer)
            self.applyStatusItemAppearance()
        }

        let settings = environment.settings
        settings.onChange = { [weak self] in
            self?.hotKeyRegistrar.registerAll()
            self?.updateSnapper()
        }
        settings.onMonitoringChange   = { [weak self] in self?.environment.monitoring.applyMonitoring() }
        settings.onAppearanceChange   = { [weak self] in self?.applyAppearance() }
        settings.onLaunchAtLoginChange = { [weak self] in self?.applyLaunchAtLogin() }
        settings.onUltraSwitchChange  = { [weak self] in self?.applyUltraSwitch() }
        settings.onMenuBarChange      = { [weak self] in
            self?.applyStatusItemAppearance()
            self?.environment.monitoring.updateMonitoringState()
        }

        environment.monitoring.start()
        applyAppearance()
        hotKeyRegistrar.registerAll()
        updateSnapper()
        applyUltraSwitch()
    }

    // MARK: - Monitoring visibility

    /// Открыт ли поповер или одно из окон приложения.
    private var isDetailUIVisible: Bool {
        popover.isShown || windows.isAnyWindowVisible
    }

    // MARK: - Appearance & login

    private func applyAppearance() {
        NSApp.appearance = environment.settings.appearanceMode.nsAppearance
    }

    /// Регистрирует/снимает агент автозапуска под текущий флаг.
    private func applyLaunchAtLogin() {
        do {
            if environment.settings.launchAtLogin {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("Launch at login change failed: \(error.localizedDescription)")
        }
    }

    /// Запускает/останавливает drag-to-snap по флагу Window Manager.
    private func updateSnapper() {
        environment.settings.windowManagerEnabled ? environment.snapper.start() : environment.snapper.stop()
    }

    /// Автозамена раскладки не зависит от хоткеев Ultra Switch.
    private func applyUltraSwitch() {
        environment.ultraSwitch.apply(autoEnabled: environment.settings.autoConvertEnabled)
    }

    // MARK: - Setup

    /// Создаёт иконку в строке меню и подписывается на обновления метрик:
    /// в режиме «Метрики» содержимое перерисовывается на каждом опросе.
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)

        metricsObserver = environment.metrics.$metrics
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.environment.settings.menuBarIconMode == .metrics else { return }
                    self.applyStatusItemAppearance()
                }
            }
        applyStatusItemAppearance()
    }

    /// Приводит строку меню в соответствие с настройками.
    private func applyStatusItemAppearance() {
        guard let button = statusItem.button else { return }
        let settings = environment.settings

        // Ширина иконки фиксируется по самым длинным значениям: меняющаяся
        // ширина двигала бы поповер, привязанный к этой кнопке.
        statusItem.length = settings.menuBarIconMode == .metrics
            ? StatusItemPresenter.widestWidth(shownMetrics: settings.menuBarMetrics, localizer: environment.localizer)
            : NSStatusItem.variableLength
        StatusItemPresenter.apply(
            to: button,
            mode: settings.menuBarIconMode,
            metrics: environment.metrics.metrics,
            shownMetrics: settings.menuBarMetrics,
            customIconPath: settings.customIconPath,
            localizer: environment.localizer
        )
    }

    /// Настраивает поповер с внедрёнными сервисами и обработчиком выбора метрики.
    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let root = ContentView(
            metrics: environment.metrics,
            utilities: environment.utilities,
            clipboard: environment.clipboard,
            settings: environment.settings,
            ultraSwitch: environment.ultraSwitch,
            battery: environment.battery,
            onSelect: { [weak self] tab in self?.openDetail(tab) },
            onOpenClipboard: { [weak self] in self?.openClipboard() },
            onOpenPreferences: { [weak self] in self?.openPreferences() }
        )
        let hosting = HostingFactory.make(root, localizer: environment.localizer)
        hosting.view.wantsLayer = true
        popover.contentViewController = hosting
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            // Приложение-агент не становится активным по клику в строке меню, поэтому
            // окно поповера остаётся не-key и SwiftUI рисует контролы серыми (неактивными).
            // Активируем приложение и делаем окно поповера key — акцентные цвета сразу верные.
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Windows

    private func openDetail(_ tab: MetricTab) {
        popover.performClose(nil)
        windows.openDetail(tab)
        environment.monitoring.updateMonitoringState()
    }

    private func openClipboard() {
        popover.performClose(nil)
        windows.openClipboard()
        environment.monitoring.updateMonitoringState()
    }

    private func openPreferences() {
        popover.performClose(nil)
        windows.openPreferences()
    }

    // MARK: - NSPopoverDelegate

    func popoverDidShow(_ notification: Notification) {
        environment.monitoring.updateMonitoringState()
        installOutsideClickMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        environment.monitoring.updateMonitoringState()
        removeOutsideClickMonitor()
    }

    // MARK: - Outside-click dismissal

    /// Закрывает поповер при клике в любом месте экрана вне его.
    /// Глобальный монитор ловит клики в других приложениях/на рабочем столе;
    /// клики по самому поповеру в него не попадают, по значку — обрабатывает кнопка.
    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.popover.performClose(nil) }
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}
