//
//  SelectionTranslator.swift
//  MonitorBarApp
//

import AppKit
import os

/// Перевод выделенного текста прямо на месте.
///
/// Выделение забирается копированием, а не через Accessibility: читать чужой
/// текст там получается далеко не везде (см. `UltraSwitchService`), а
/// копирование понимают все. Буфер обмена при этом восстанавливается — им
/// пользуется сам пользователь, и подменять его молча нельзя.
@MainActor
final class SelectionTranslator {

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Echo",
        category: "Translate"
    )

    /// Сколько ждать, пока приложение положит выделение в буфер обмена.
    private static let copyDelay = Duration.milliseconds(150)

    private let translator = TranslationService()
    private var isBusy = false

    /// Переводит выделение и печатает перевод поверх него.
    func translateSelection() {
        guard !isBusy else { return }
        isBusy = true

        Task { [weak self] in
            defer { self?.isBusy = false }
            await self?.run()
        }
    }

    private func run() async {
        Self.log.debug("Перевод: забираю выделение")
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)
        let changeCountBefore = pasteboard.changeCount

        TextInjector.copySelection()
        try? await Task.sleep(for: Self.copyDelay)

        guard pasteboard.changeCount != changeCountBefore,
              let selected = pasteboard.string(forType: .string),
              !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Self.log.notice("Переводить нечего: выделение пустое или не скопировалось")
            restore(saved, to: pasteboard)
            return
        }

        Self.log.debug("Выделено \(selected.count, privacy: .public) символов, перевожу")
        guard let translated = await translator.translate(selected) else {
            Self.log.notice("Перевод не выполнен")
            restore(saved, to: pasteboard)
            return
        }

        // Выделение после копирования остаётся на месте, поэтому печать
        // просто заменяет его переводом.
        Self.log.debug("Перевод готов, \(translated.count, privacy: .public) символов")
        TextInjector.type(translated)
        restore(saved, to: pasteboard)
    }

    /// Возвращает буфер обмена в прежнее состояние. Делается с задержкой:
    /// вставка ещё может дочитывать буфер, и подмена на лету её испортит.
    private func restore(_ text: String?, to pasteboard: NSPasteboard) {
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            pasteboard.clearContents()
            if let text { pasteboard.setString(text, forType: .string) }
        }
    }
}
