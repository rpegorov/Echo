//
//  TextInjector.swift
//  MonitorBarApp
//

import CoreGraphics
import Foundation

/// Замена текста синтетическим вводом: стереть набранное и напечатать заново.
///
/// Работает везде, где принимают клавиатуру, — в отличие от записи через
/// Accessibility, которой Pages не поддерживает, а Chromium подтверждает, но
/// не выполняет.
enum TextInjector {

    private static let backspaceKey: CGKeyCode = 51

    /// Неназначенная клавиша: сама по себе не печатает ничего, поэтому в поле
    /// попадает ровно то, что задано `keyboardSetUnicodeString`. С обычным
    /// кодом (например 0 — это «a») проигнорированная строка обернулась бы
    /// лишней буквой в чужом тексте.
    private static let unassignedKey: CGKeyCode = 255

    /// Поля не всегда успевают обработать поток событий вплотную.
    private static let settleMicroseconds: useconds_t = 1800

    /// Синтетика идёт отдельной последовательной очередью, а не на главном
    /// потоке: там живёт перехват клавиатуры, и синхронные паузы в нём
    /// затормозили бы доставку ввода во всей системе.
    private static let queue = DispatchQueue(label: "app.echo.text-injector", qos: .userInteractive)

    /// Приватный источник: события не смешиваются с состоянием реальной
    /// клавиатуры, поэтому зажатый в этот момент модификатор их не искажает.
    private static func makeSource() -> CGEventSource? {
        CGEventSource(stateID: .privateState)
    }

    /// Стирает `deleteCount` символов перед кареткой и печатает `text`.
    /// Вызывающий получает управление сразу — работа идёт в фоне.
    static func replaceBeforeCaret(deleteCount: Int, with text: String, completion: (@Sendable (Bool) -> Void)? = nil) {
        guard deleteCount > 0, !text.isEmpty else {
            completion?(false)
            return
        }

        queue.async {
            guard let source = makeSource() else {
                completion?(false)
                return
            }

            for _ in 0..<deleteCount {
                post(key: backspaceKey, source: source, down: true)
                post(key: backspaceKey, source: source, down: false)
                usleep(settleMicroseconds / 3)
            }

            usleep(settleMicroseconds)
            let typed = type(text, source: source)
            completion?(typed)
        }
    }

    // MARK: - Private

    private static func post(key: CGKeyCode, source: CGEventSource, down: Bool) {
        CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)?
            .post(tap: .cghidEventTap)
    }

    private static func type(_ text: String, source: CGEventSource) -> Bool {
        let units = Array(text.utf16)
        guard !units.isEmpty else { return false }

        var posted = false
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: unassignedKey, keyDown: isDown) else {
                continue
            }
            units.withUnsafeBufferPointer { buffer in
                event.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            }
            event.post(tap: .cghidEventTap)
            posted = true
            usleep(settleMicroseconds / 4)
        }
        return posted
    }
}
