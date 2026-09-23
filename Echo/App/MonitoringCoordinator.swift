//
//  MonitoringCoordinator.swift
//  MonitorBarApp
//

import AppKit

/// Владеет политикой опроса метрик: сон/пробуждение, режим энергосбережения
/// и решение о том, должен ли опрос сейчас идти.
///
/// Вынесено из `MenuBarController`, который не знает, какие окна сейчас
/// видимы напрямую — эту видимость ему сообщает `isUIVisible`.
@MainActor
final class MonitoringCoordinator {

    private let settings: AppSettings
    private let metrics: MetricsService

    /// Видим ли сейчас поповер или любое из окон приложения.
    /// Задаётся владельцем (`MenuBarController`), который знает про попап и окна.
    var isUIVisible: () -> Bool = { false }

    /// Показывает ли строка меню живые метрики — тоже видимый интерфейс.
    var menuBarShowsMetrics: () -> Bool = { false }

    private var isAsleep = false
    private var sleepToken: NSObjectProtocol?
    private var wakeToken: NSObjectProtocol?
    private var powerToken: NSObjectProtocol?

    init(settings: AppSettings, metrics: MetricsService) {
        self.settings = settings
        self.metrics = metrics
    }

    /// Подписывается на уведомления о сне/пробуждении и стартует опрос.
    func start() {
        observePowerNotifications()
        applyMonitoring()
    }

    /// Отписывается от всех уведомлений и останавливает опрос.
    func stop() {
        let center = NotificationCenter.default
        if let sleepToken { NSWorkspace.shared.notificationCenter.removeObserver(sleepToken) }
        if let wakeToken { NSWorkspace.shared.notificationCenter.removeObserver(wakeToken) }
        if let powerToken { center.removeObserver(powerToken) }
        sleepToken = nil
        wakeToken = nil
        powerToken = nil
        metrics.stop()
    }

    /// Подписка на сон/пробуждение и смену режима энергосбережения.
    private func observePowerNotifications() {
        let workspace = NSWorkspace.shared.notificationCenter
        sleepToken = workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.settings.pauseOnSleep else { return }
                self.isAsleep = true
                self.updateMonitoringState()
            }
        }
        wakeToken = workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isAsleep = false
                self.applyMonitoring()
            }
        }
        powerToken = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyMonitoring() }
        }
    }

    /// Пересчитывает интервал опроса и решает, должен ли мониторинг работать.
    func applyMonitoring() {
        metrics.setInterval(currentInterval)
        updateMonitoringState()
    }

    /// Интервал зависит от того, на что смотрит пользователь.
    ///
    /// Открытый поповер или окно требуют плотного опроса, строка меню — нет:
    /// цифрам в трее секундная точность не нужна, а опрос при закрытом
    /// интерфейсе идёт постоянно, и на батарее это заметно.
    private var currentInterval: Double {
        if settings.lowPowerThrottle && ProcessInfo.processInfo.isLowPowerModeEnabled {
            return settings.lowPowerInterval
        }
        return isUIVisible() ? settings.updateInterval : settings.menuBarInterval
    }

    /// Запускает или останавливает опрос в зависимости от видимости UI и сна.
    ///
    /// Метрики в строке меню — такой же видимый интерфейс, как открытое окно:
    /// без этого при закрытом поповере опрос вставал и в строке меню висели
    /// цифры, замершие с прошлого открытия.
    func updateMonitoringState() {
        let uiVisible = menuBarShowsMetrics() || isUIVisible()
        let shouldRun = !isAsleep && (!settings.pauseWhenHidden || uiVisible)

        // Интервал пересчитываем здесь же: поповер открылся или закрылся —
        // и плотность опроса должна смениться сразу, а не до следующей
        // правки настроек.
        metrics.setInterval(currentInterval)
        shouldRun ? metrics.start() : metrics.stop()
    }
}
