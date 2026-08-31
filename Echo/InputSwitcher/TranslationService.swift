//
//  TranslationService.swift
//  MonitorBarApp
//

import NaturalLanguage
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

    private var hostWindow: NSWindow?
    private var pending: CheckedContinuation<String?, Never>?
    private var pendingText: String?

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

        return await withCheckedContinuation { continuation in
            pending = continuation
            pendingText = trimmed
            // Новый объект конфигурации обязателен: у одинакового значения
            // задача не перезапустится и второй перевод подряд не случится.
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    /// Текст, ожидающий перевода. Забирается вью-носителем — сессию перевода
    /// намеренно не выносим сюда: она не Sendable, и любой её переезд между
    /// изоляциями упирается в проверку гонок.
    fileprivate func takePendingText() -> String? {
        defer { pendingText = nil }
        return pendingText
    }

    fileprivate func finish(with translated: String?) {
        pending?.resume(returning: translated)
        pending = nil
        configuration = nil
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
        window.orderFrontRegardless()

        hostWindow = window
    }

    private static func detectLanguage(of text: String) -> Locale.Language? {
        let recognizer = NLLanguageRecognizer()
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
                guard let text = service.takePendingText() else { return }
                let result = try? await session.translate(text)
                service.finish(with: result?.targetText)
            }
    }
}
