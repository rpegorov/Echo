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
    let localizer: Localizer
    let battery: BatteryService
    let gridStore: GridStore

    lazy var snapper = WindowSnapper(
        windowManager: windowManager,
        settings: settings,
        overlay: SnapOverlayController(localizer: localizer),
        grids: gridStore
    )
    let monitoring: MonitoringCoordinator

    /// `gridStorage` has no default: the live file store is built only at the app entry point,
    /// so a test host can never read or move the user's grid file.
    init(defaults: UserDefaults = .standard, system: SystemLanguages = .live, gridStorage: any GridDocumentStoring) {
        settings = AppSettings(defaults: defaults)
        metrics = MetricsService()
        utilities = SystemUtilitiesService(defaults: defaults)
        clipboard = ClipboardService(defaults: defaults)
        windowManager = WindowManagerService()
        ultraSwitch = UltraSwitchService()
        translator = SelectionTranslator()
        updater = UpdaterService()
        detailState = DetailState()
        localizer = Localizer(preference: settings.language, system: system)
        monitoring = MonitoringCoordinator(settings: settings, metrics: metrics)
        battery = Self.makeBatteryService()
        gridStore = GridStore(storage: gridStorage)

        settings.onLanguageChange = { [weak self] in
            guard let self else { return }
            self.localizer.apply(self.settings.language)
        }
    }

    /// Grid file in Application Support; without that folder grids stay unavailable and the store reports why.
    static func liveGridStorage() -> any GridDocumentStoring {
        do {
            return GridFileStorage(fileURL: try GridFileStorage.defaultURL())
        } catch {
            return UnavailableGridStorage(error: error)
        }
    }

    /// Builds `BatteryService` with real dependencies. When the on-disk
    /// history location can't be determined, the service is still built —
    /// with a store that reports that error into `lastError` on first use —
    /// so composition never crashes and never silently drops the failure.
    private static func makeBatteryService() -> BatteryService {
        let store: BatteryHistoryStoring
        do {
            store = try BatteryHistoryStore(fileURL: BatteryHistoryStore.defaultURL())
        } catch {
            store = FailingBatteryHistoryStore(error: (error as? BatteryError) ?? .storage(error.localizedDescription))
        }
        return BatteryService(
            power: PowerSourceMonitor(),
            observer: PowerSourceChangeObserver(),
            energy: ProcessEnergySampler(),
            store: store,
            sleeper: ContinuousTickSleeper()
        )
    }
}
