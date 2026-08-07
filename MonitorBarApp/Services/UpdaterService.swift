//
//  UpdaterService.swift
//  MonitorBarApp
//

import AppKit
import Combine
import Sparkle

/// Автообновление через Sparkle: фид `appcast.xml` в репозитории, подпись EdDSA.
///
/// Приложение — агент (`.accessory`), поэтому окна Sparkle надо явно выводить
/// вперёд: без активации диалог обновления открывается за чужими окнами.
@MainActor
final class UpdaterService: ObservableObject {

    /// Кнопка «Проверить сейчас» недоступна, пока идёт другая проверка.
    @Published private(set) var canCheck = true

    /// Проверять обновления в фоне по расписанию.
    @Published var automaticallyChecks: Bool {
        didSet { updater.automaticallyChecksForUpdates = automaticallyChecks }
    }

    /// Скачивать найденное обновление без вопросов (установка — по подтверждению).
    @Published var automaticallyDownloads: Bool {
        didSet { updater.automaticallyDownloadsUpdates = automaticallyDownloads }
    }

    var lastCheckDate: Date? { updater.lastUpdateCheckDate }

    /// Адрес фида — показываем в настройках, чтобы обновление не выглядело чёрным ящиком.
    var feedURL: String {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? "—"
    }

    private let controller: SPUStandardUpdaterController
    private var updater: SPUUpdater { controller.updater }
    private var cancellable: AnyCancellable?

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        automaticallyDownloads = controller.updater.automaticallyDownloadsUpdates

        cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                MainActor.assumeIsolated { self?.canCheck = value }
            }
    }

    /// Ручная проверка: показывает окно Sparkle даже если обновлений нет.
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        updater.checkForUpdates()
    }
}
