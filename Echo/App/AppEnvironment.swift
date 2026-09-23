//
//  AppEnvironment.swift
//  MonitorBarApp
//

import Foundation

/// Композиционный корень приложения: создаёт и владеет всеми сервисами,
/// которые раньше жили прямо в `MenuBarController`.
///
/// Конструируется без побочных эффектов AppKit — никакого статус-айтема, окон
/// или запущенных таймеров — чтобы быть создаваемым в тестах напрямую.
@MainActor
final class AppEnvironment {

    let settings: AppSettings
    let metrics: MetricsService
    let utilities: SystemUtilitiesService
    let clipboard: ClipboardService
    let windowManager: WindowManagerService
    let ultraSwitch: UltraSwitchService
    let translator: SelectionTranslator
    let updater: UpdaterService
    let detailState: DetailState

    lazy var snapper = WindowSnapper(windowManager: windowManager, settings: settings)
    let monitoring: MonitoringCoordinator

    init(defaults: UserDefaults = .standard) {
        settings = AppSettings(defaults: defaults)
        metrics = MetricsService()
        utilities = SystemUtilitiesService()
        clipboard = ClipboardService()
        windowManager = WindowManagerService()
        ultraSwitch = UltraSwitchService()
        translator = SelectionTranslator()
        updater = UpdaterService()
        detailState = DetailState()
        monitoring = MonitoringCoordinator(settings: settings, metrics: metrics)
    }
}
