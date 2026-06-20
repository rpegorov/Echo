//
//  MenuBarController.swift
//  MonitorBarApp
//
//  Created by Ростислав Егоров on 08.12.2025.
//

import Cocoa
import ServiceManagement
import SwiftUI

/// Управляет иконкой в строке меню, поповером и отдельным детальным окном.
/// Держит единственные экземпляры сервисов, общие для поповера и окна.
@MainActor
final class MenuBarController: NSObject, NSWindowDelegate, NSPopoverDelegate {

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    private let metrics = MetricsService()
    private let utilities = SystemUtilitiesService()
    private let clipboard = ClipboardService()
    private let settings = AppSettings()
    private let windowManager = WindowManagerService()
    private let hotKeys = HotKeyManager()
    private lazy var snapper = WindowSnapper(windowManager: windowManager, settings: settings)
    private let detailState = DetailState()

    private var detailWindow: NSWindow?
    private var clipboardWindow: NSWindow?
    private var preferencesWindow: NSWindow?

    /// Система в режиме сна — мониторинг приостановлен.
    private var isAsleep = false

    /// Глобальный монитор кликов вне поповера (для закрытия по клику на экране).
    private var outsideClickMonitor: Any?

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()

        settings.onChange = { [weak self] in
            self?.registerHotKeys()
            self?.updateSnapper()
        }
        settings.onMonitoringChange   = { [weak self] in self?.applyMonitoring() }
        settings.onAppearanceChange   = { [weak self] in self?.applyAppearance() }
        settings.onLaunchAtLoginChange = { [weak self] in self?.applyLaunchAtLogin() }

        observePowerNotifications()
        applyAppearance()
        applyMonitoring()   // задаёт интервал и стартует/останавливает по политике энергосбережения
        registerHotKeys()
        updateSnapper()
    }

    // MARK: - Power & monitoring policy

    /// Подписка на сон/пробуждение и смену режима энергосбережения.
    private func observePowerNotifications() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.settings.pauseOnSleep else { return }
                self.isAsleep = true
                self.updateMonitoringState()
            }
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isAsleep = false
                self.applyMonitoring()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyMonitoring() }
        }
    }

    /// Пересчитывает интервал опроса и решает, должен ли мониторинг работать.
    private func applyMonitoring() {
        let lowPower = settings.lowPowerThrottle && ProcessInfo.processInfo.isLowPowerModeEnabled
        metrics.setInterval(lowPower ? settings.lowPowerInterval : settings.updateInterval)
        updateMonitoringState()
    }

    /// Запускает или останавливает опрос в зависимости от видимости UI и сна.
    private func updateMonitoringState() {
        let uiVisible = popover.isShown || detailWindow != nil || clipboardWindow != nil
        let shouldRun = !isAsleep && (!settings.pauseWhenHidden || uiVisible)
        shouldRun ? metrics.start() : metrics.stop()
    }

    // MARK: - Appearance & login

    private func applyAppearance() {
        NSApp.appearance = settings.appearanceMode.nsAppearance
    }

    /// Регистрирует/снимает агент автозапуска под текущий флаг.
    private func applyLaunchAtLogin() {
        do {
            if settings.launchAtLogin {
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
        settings.windowManagerEnabled ? snapper.start() : snapper.stop()
    }

    // MARK: - Setup

    /// Создаёт иконку в строке меню (шаблонная, наследует цвет системы).
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        if let icon = NSImage(named: "MenuBarIcon") {
            icon.isTemplate = false   // цветная non-template иконка (кольца в тонах воды)
            button.image = icon
        } else {
            button.title = "◈"
        }
        button.target = self
        button.action = #selector(togglePopover)
    }

    /// Настраивает поповер с внедрёнными сервисами и обработчиком выбора метрики.
    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let root = ContentView(
            metrics: metrics,
            utilities: utilities,
            clipboard: clipboard,
            onSelect: { [weak self] tab in self?.openDetail(tab) },
            onOpenClipboard: { [weak self] in self?.openClipboard() },
            onOpenPreferences: { [weak self] in self?.openPreferences() }
        )
        let hosting = NSHostingController(rootView: root)
        hosting.view.wantsLayer = true
        popover.contentViewController = hosting
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Detail window

    /// Открывает (или выводит на передний план) детальное окно для метрики.
    /// Отдельное NSWindow вместо .sheet: поповер `.transient` закрывается при
    /// потере фокуса, поэтому модальная презентация из него невозможна.
    private func openDetail(_ tab: MetricTab) {
        detailState.tab = tab
        popover.performClose(nil)

        if let window = detailWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = MetricsDetailView(state: detailState, metrics: metrics)
        let hosting = NSHostingController(rootView: root)

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
//        window.title = "Monitor Bar"
        window.setContentSize(DS.detailSize)
        window.contentMinSize = NSSize(width: 480, height: 420)
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        detailWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        updateMonitoringState()
    }

    // MARK: - Clipboard window

    /// Открывает (или выводит вперёд) окно истории буфера обмена.
    private func openClipboard() {
        popover.performClose(nil)

        if let window = clipboardWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = ClipboardHistoryView(service: clipboard)
        let hosting = NSHostingController(rootView: root)

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.title = "Clipboard"
        window.setContentSize(NSSize(width: 380, height: 460))
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        clipboardWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        updateMonitoringState()
    }

    // MARK: - Hotkeys

    /// Перерегистрирует глобальные хоткеи по текущим настройкам.
    /// Оконные команды регистрируются только если Window Manager включён;
    /// открытие clipboard — всегда.
    private func registerHotKeys() {
        hotKeys.unregisterAll()
        for command in WMCommand.allCases {
            guard let shortcut = settings.shortcut(for: command) else { continue }
            if command.isWindowCommand && !settings.windowManagerEnabled { continue }

            if let layout = command.layout {
                hotKeys.register(shortcut) { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        self.windowManager.apply(layout, gap: CGFloat(self.settings.windowGap))
                    }
                }
            } else {
                hotKeys.register(shortcut) { [weak self] in
                    MainActor.assumeIsolated { self?.openClipboard() }
                }
            }
        }
    }

    // MARK: - Preferences window

    private func openPreferences() {
        popover.performClose(nil)

        if let window = preferencesWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = PreferencesView(settings: settings, clipboard: clipboard, windowManager: windowManager)
        let hosting = NSHostingController(rootView: root)

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.title = "Preferences"
        window.setContentSize(NSSize(width: 720, height: 520))
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        preferencesWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let closed = notification.object as? NSWindow else { return }
        if closed == detailWindow { detailWindow = nil }
        if closed == clipboardWindow { clipboardWindow = nil }
        if closed == preferencesWindow { preferencesWindow = nil }
        updateMonitoringState()
    }

    // MARK: - NSPopoverDelegate

    func popoverDidShow(_ notification: Notification) {
        updateMonitoringState()
        installOutsideClickMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        updateMonitoringState()
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
