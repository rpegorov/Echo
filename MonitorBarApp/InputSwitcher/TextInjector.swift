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

    /// Метка собственных событий: перехват обязан отличать их от набора
    /// пользователя. Флага «сейчас идёт вставка» недостаточно — и отправка,
    /// и доставка асинхронны, поэтому часть своих же нажатий возвращалась
    /// в буфер уже после снятия флага.
    static let eventMarker: Int64 = 0x4543_484F // 'ECHO'

    private static let backspaceKey: CGKeyCode = 51

    /// В одно событие влезает ограниченное число UTF-16 единиц — режем с запасом.
    private static let chunkSize = 12

    /// Поля не всегда успевают обработать поток событий вплотную.
    private static let settleMicroseconds: useconds_t = 1800

    /// Синтетика идёт отдельной последовательной очередью, а не на главном
    /// потоке: там живёт перехват клавиатуры, и синхронные паузы в нём
    /// затормозили бы доставку ввода во всей системе.
    private static let queue = DispatchQueue(label: "app.echo.text-injector", qos: .userInteractive)

    /// Приватный источник: события не смешиваются с состоянием реальной
    /// клавиатуры, поэтому зажатый в этот момент модификатор их не искажает.
    private static func makeSource() -> CGEventSource? {
        let source = CGEventSource(stateID: .privateState)
        source?.userData = eventMarker
        return source
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
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { return }
        event.flags = []
        event.setIntegerValueField(.eventSourceUserData, value: eventMarker)
        event.post(tap: .cghidEventTap)
    }

    private static func type(_ text: String, source: CGEventSource) -> Bool {
        let units = Array(text.utf16)
        guard !units.isEmpty else { return false }

        var posted = false
        var index = 0
        while index < units.count {
            let chunk = Array(units[index..<min(index + chunkSize, units.count)])
            for isDown in [true, false] {
                posted = postChunk(chunk, keyDown: isDown, source: source) || posted
            }
            index += chunkSize
            usleep(settleMicroseconds / 2)
        }
        return posted
    }

    /// Код клавиши здесь не важен: содержимое задаёт `keyboardSetUnicodeString`.
    /// Важно другое — сбросить флаги, иначе зажатый в этот момент модификатор
    /// превратит печать в сочетание клавиш.
    private static func postChunk(_ chunk: [UniChar], keyDown: Bool, source: CGEventSource) -> Bool {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown) else { return false }
        event.flags = []
        event.setIntegerValueField(.eventSourceUserData, value: eventMarker)
        chunk.withUnsafeBufferPointer { buffer in
            event.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
        }
        event.post(tap: .cghidEventTap)
        return true
    }
}
