//
//  AppWindows.swift
//  MonitorBarApp
//

import AppKit
import SwiftUI

/// Владеет созданием и показом всех вспомогательных окон приложения
/// (детали метрики, буфер обмена, настройки).
///
/// Вынесено из `MenuBarController`: контроллер отвечает за строку меню и
/// поповер, а не за то, как выглядит каждое отдельное окно.
@MainActor
final class AppWindows: NSObject, NSWindowDelegate {

    private let environment: AppEnvironment

    private(set) var detailWindow: NSWindow?
    private(set) var clipboardWindow: NSWindow?
    private(set) var preferencesWindow: NSWindow?

    /// Вызывается при закрытии любого из окон — владелец пересчитывает
    /// политику мониторинга по новому набору видимых окон.
    var onWindowClosed: (() -> Void)?

    /// Открыто ли хотя бы одно из окон, за которые отвечает этот тип.
    var isAnyWindowVisible: Bool {
        detailWindow != nil || clipboardWindow != nil
    }

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    // MARK: - Detail window

    /// Открывает (или выводит на передний план) детальное окно для метрики.
    /// Отдельное NSWindow вместо .sheet: поповер `.transient` закрывается при
    /// потере фокуса, поэтому модальная презентация из него невозможна.
    func openDetail(_ tab: MetricTab) {
        environment.detailState.tab = tab

        if let window = detailWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = MetricsDetailView(state: environment.detailState, metrics: environment.metrics)
        let hosting = HostingFactory.make(root, localizer: environment.localizer)

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = environment.localizer.t(SystemKey.windowTitleDetail)
        window.isMovableByWindowBackground = true
        window.setContentSize(DS.detailSize)
        window.contentMinSize = NSSize(width: 480, height: 420)
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        detailWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Clipboard window

    /// Открывает (или выводит вперёд) окно истории буфера обмена.
    func openClipboard() {
        if let window = clipboardWindow {
            NSApp.activate(ignoringOtherApps: true)
            positionNearMouse(window)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = ClipboardHistoryView(service: environment.clipboard)
        let hosting = HostingFactory.make(root, localizer: environment.localizer)

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.title = environment.localizer.t(SystemKey.windowTitleClipboard)
        window.setContentSize(NSSize(width: 380, height: 460))
        window.isReleasedWhenClosed = false
        positionNearMouse(window)
        window.delegate = self
        clipboardWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Ставит окно под курсор мыши, а не в центр экрана: историю буфера
    /// открывают, чтобы тут же выбрать запись, и тянуться к центру неудобно.
    private func positionNearMouse(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let size = window.frame.size
        // Окно вешаем чуть ниже и правее курсора — так он оказывается у его
        // верхнего края, у первой записи списка.
        var origin = CGPoint(x: mouse.x - 24, y: mouse.y - size.height + 24)

        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        window.setFrameOrigin(origin)
    }

    // MARK: - Preferences window

    func openPreferences() {
        if let window = preferencesWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = PreferencesView(
            settings: environment.settings,
            clipboard: environment.clipboard,
            windowManager: environment.windowManager,
            ultraSwitch: environment.ultraSwitch,
            updater: environment.updater,
            metrics: environment.metrics
        )
        let hosting = HostingFactory.make(root, localizer: environment.localizer)

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.title = environment.localizer.t(SystemKey.windowTitlePreferences)
        window.setContentSize(NSSize(width: 720, height: 520))
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        preferencesWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Language change

    /// Re-titles already open windows after the language changed on the fly.
    func applyTitles(using localizer: Localizer) {
        detailWindow?.title = localizer.t(SystemKey.windowTitleDetail)
        clipboardWindow?.title = localizer.t(SystemKey.windowTitleClipboard)
        preferencesWindow?.title = localizer.t(SystemKey.windowTitlePreferences)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let closed = notification.object as? NSWindow else { return }
        if closed == detailWindow { detailWindow = nil }
        if closed == clipboardWindow { clipboardWindow = nil }
        if closed == preferencesWindow { preferencesWindow = nil }
        onWindowClosed?()
    }
}
