//
//  TranslationService.swift
//  MonitorBarApp
//

import NaturalLanguage
import os
import SwiftUI
@preconcurrency import Translation

/// Перевод текста средствами macOS — на устройстве, без сети.
///
/// Apple отдаёт перевод только через модификатор `translationTask`, то есть из
/// SwiftUI-вью. Приложение живёт в строке меню и своих окон обычно не
/// показывает, поэтому здесь заведено крошечное невидимое окно-носитель: оно
/// существует лишь как точка, к которой можно прицепить задачу перевода.
@MainActor
final class TranslationService: ObservableObject {

    /// Смена конфигурации — это и есть запуск перевода: `translationTask`
    /// перезапускается каждый раз, когда значение меняется.
    @Published fileprivate var configuration: TranslationSession.Configuration?

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Echo",
        category: "Translate"
    )

    /// Сколько ждать ответа сессии перевода, в секундах. Сторож — предохранитель
    /// от зависшей сессии, а не бюджет на скорость: длинный текст и первая
    /// загрузка модели перевода идут заметно дольше секунды. Внутреннее `var`:
    /// тесты укорачивают интервал.
    ///
    /// Без сторожа потерянная сессия навсегда вешает ожидающий continuation:
    /// `isBusy` переводчика остаётся поднятым, и хоткей молча умирает до
    /// перезапуска приложения.
    var sessionTimeout: TimeInterval = 30

    private var hostWindow: NSWindow?
    /// Номер запроса: экшен прошлой конфигурации может завершиться уже после
    /// старта нового — его результат не должен достаться чужому continuation.
    private var nextRequestID = 0
    private var pending: CheckedContinuation<String?, Never>?
    private var pendingRequestID = 0
    private var pendingText: String?
    private var timeoutTask: Task<Void, Never>?

    /// Переводит текст на язык, противоположный распознанному:
    /// русский уходит в английский, всё остальное — в русский.
    func translate(_ text: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        installHostIfNeeded()

        let source = Self.detectLanguage(of: trimmed)
        let target: Locale.Language = source?.languageCode == "ru"
            ? Locale.Language(identifier: "en")
            : Locale.Language(identifier: "ru")
        let sourceCode = source?.languageCode?.identifier ?? "auto"
        let targetCode = target.languageCode?.identifier ?? "?"
        let pair = "\(sourceCode) → \(targetCode)"
        Self.log.notice("Перевод: \(pair, privacy: .public)") // l10n-exempt: log, not user-facing

        // Модели пары живут на устройстве. Неподдержанную пару отсекаем
        // сразу: сессия для неё всё равно не готовится. Пару без установленной
        // модели ждём как есть — система докачивает её при первом обращении,
        // и это занимает заметное время.
        if let source {
            let availability = LanguageAvailability()
            let pairStatus = await availability.status(from: source, to: target)
            if pairStatus == .unsupported {
                Self.log.notice("Пары \(pair, privacy: .public) нет в системе") // l10n-exempt: log, not user-facing
                return nil
            }
            if pairStatus == .supported {
                Self.log.notice("Модель пары докачивается, перевод ждёт") // l10n-exempt: log, not user-facing
            }
        }

        return await withCheckedContinuation { continuation in
            // Прошлый запрос, чью сессию так и не дождались, резюмируем с nil:
            // его задача не должна висеть вечно.
            pending?.resume(returning: nil)
            nextRequestID += 1
            pendingRequestID = nextRequestID
            pending = continuation
            pendingText = trimmed
            scheduleTimeout()
            // Новый объект конфигурации обязателен: у одинакового значения
            // задача не перезапустится и второй перевод подряд не случится.
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    /// Текст, ожидающий перевода, и номер его запроса. Забирается вью-носителем
    /// — сессию перевода намеренно не выносим сюда: она не Sendable, и любой её
    /// переезд между изоляциями упирается в проверку гонок.
    fileprivate func takePendingText() -> (text: String, requestID: Int)? {
        guard let text = pendingText else { return nil }
        pendingText = nil
        return (text, pendingRequestID)
    }

    /// Экшен translationTask вошёл: сессия подготовлена системой. Молчание
    /// после этой записи — медленный или зависший перевод; отсутствие записи —
    /// носитель не отрисовался и сессия вообще не начиналась.
    fileprivate func sessionStarted(_ requestID: Int) {
        guard requestID == pendingRequestID else { return }
        Self.log.debug("Сессия перевода готова") // l10n-exempt: log, not user-facing
    }

    /// Завершение перевода из вью-носителя. Результат принимается только от
    /// актуального запроса: запоздавший экшен прошлой конфигурации не должен
    /// возобновить текущего с чужим ответом.
    fileprivate func finish(_ requestID: Int, with translated: String?, failure: (any Error)? = nil) {
        guard requestID == pendingRequestID, pending != nil else { return }
        if let failure {
            if failure is CancellationError {
                // Смена конфигурации отменяет бегущий перевод — это штатно.
                Self.log.debug("Перевод отменён") // l10n-exempt: log, not user-facing
            } else {
                let detail = String(describing: failure)
                Self.log.notice("Перевод не удался: \(detail, privacy: .public)") // l10n-exempt: log, not user-facing
            }
        }
        closePending(with: translated)
    }

    /// Возобновляет ожидающего, гасит конфигурацию и сторож таймаута.
    private func closePending(with translated: String?) {
        pending?.resume(returning: translated)
        pending = nil
        configuration = nil
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    private func scheduleTimeout() {
        timeoutTask?.cancel()
        let timeout = sessionTimeout
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(timeout))
            } catch {
                // Отмена — штатный путь: перевод завершился раньше сторожа.
                return
            }
            self?.sessionTimedOut()
        }
    }

    /// Сессия не ответила: снимаем ожидание с результатом «нет перевода»,
    /// иначе `isBusy` переводчика останется поднятым навсегда.
    private func sessionTimedOut() {
        let timeout = sessionTimeout
        Self.log.notice("Сессия перевода не ответила за \(timeout) с") // l10n-exempt: log, not user-facing
        closePending(with: nil)
    }

    // MARK: - Носитель

    /// Окно размером в точку и практически прозрачное.
    ///
    /// Держать его за пределами экрана нельзя: SwiftUI не запускает задачи для
    /// вью, которое никогда не отрисовывалось, и перевод молча не начинается.
    /// Поэтому окно живёт в углу экрана, размером в пиксель и почти невидимое.
    private func installHostIfNeeded() {
        guard hostWindow == nil else { return }

        let corner = NSScreen.main?.visibleFrame.origin ?? .zero
        let window = NSWindow(
            contentRect: NSRect(x: corner.x, y: corner.y, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.alphaValue = 0.01
        window.contentViewController = NSHostingController(rootView: TranslationHost(service: self))
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.level = .floating
        // Носитель обязан рендериться в любом Space, иначе SwiftUI не запустит
        // translationTask и перевод молча не начнётся: полноэкранное приложение
        // (типичный Mail) живёт в отдельном Space. Визуально это по-прежнему
        // невидимый пиксель.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.orderFrontRegardless()

        hostWindow = window
    }

    /// Внутреннее — тесты проверяют детерминированность выборки.
    static func detectLanguage(of text: String) -> Locale.Language? {
        let recognizer = NLLanguageRecognizer()
        // Фича переводит только между русским и английским, а на кириллице
        // распознаватель нередко даёт болгарский или украинский. Пара вида
        // «bg → ru» системой не поддерживается, экшен translationTask тогда
        // не вызывается вовсе, и перевод молча не начинается. Ограничение
        // парой ru/en делает выборку детерминированной и заведомо рабочей.
        recognizer.languageConstraints = [.russian, .english]
        recognizer.processString(text)
        guard let code = recognizer.dominantLanguage?.rawValue else { return nil }
        return Locale.Language(identifier: code)
    }
}

/// Невидимое вью, к которому прицеплена задача перевода.
private struct TranslationHost: View {
    @ObservedObject var service: TranslationService

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(service.configuration) { session in
                guard let request = service.takePendingText() else { return }
                service.sessionStarted(request.requestID)
                do {
                    let response = try await session.translate(request.text)
                    service.finish(request.requestID, with: response.targetText)
                } catch {
                    service.finish(request.requestID, with: nil, failure: error)
                }
            }
    }
}
