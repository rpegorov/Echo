//
//  SyntheticTyping.swift
//  MonitorBarApp
//

import CoreGraphics
import Foundation

/// Запасной путь замены слова: стереть набранное клавишами Backspace и
/// напечатать исправленный вариант.
///
/// Нужен там, где Accessibility отдаёт текст на чтение, но запрещает запись —
/// в Electron-приложениях и веб-полях это обычное дело. Текст печатается
/// целиком через `keyboardSetUnicodeString`, поэтому результат не зависит
/// от того, какая раскладка активна в момент вставки.
enum SyntheticTyping {

    private static let backspaceKeyCode: CGKeyCode = 51

    /// Стирает `deleteCount` символов перед кареткой и печатает `text`.
    nonisolated static func replaceBeforeCaret(deleteCount: Int, with text: String) {
        guard deleteCount > 0, let source = CGEventSource(stateID: .hidSystemState) else { return }

        for _ in 0..<deleteCount {
            post(key: backspaceKeyCode, source: source, down: true)
            post(key: backspaceKeyCode, source: source, down: false)
        }
        type(text, source: source)
    }

    private nonisolated static func post(key: CGKeyCode, source: CGEventSource, down: Bool) {
        CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)?
            .post(tap: .cghidEventTap)
    }

    private nonisolated static func type(_ text: String, source: CGEventSource) {
        var units = Array(text.utf16)
        guard !units.isEmpty else { return }

        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: isDown) else { continue }
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            event.post(tap: .cghidEventTap)
        }
    }
}
