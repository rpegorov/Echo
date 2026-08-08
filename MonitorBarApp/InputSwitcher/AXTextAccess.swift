//
//  AXTextAccess.swift
//  MonitorBarApp
//

import ApplicationServices
import Foundation

/// Слово перед кареткой в поле ввода активного приложения.
struct FocusedWord: Sendable {
    let word: String
    /// Диапазон слова в тексте поля (UTF-16).
    let start: Int
    let length: Int
    /// Позиция каретки на момент чтения — восстанавливается после замены.
    let caret: Int
    /// Разделители между словом и кареткой (пробел, точка) — нужны фолбэку,
    /// который перенабирает текст клавишами и обязан их вернуть на место.
    let trailing: String
}

/// Чтение и замена текста в чужом приложении через Accessibility API.
///
/// Приложение не ведёт собственный буфер набранного: слово каждый раз читается
/// из самого поля ввода и живёт ровно до конца обработки. Ничего не копится
/// и никуда не сохраняется.
enum AXTextAccess {

    /// Секретные поля не читаем ни при каких условиях.
    private static let secureRole = "AXSecureTextField"
    /// Ответ AX-сервера ждём недолго: зависший клиент не должен тормозить набор.
    private static let messagingTimeout: Float = 0.25
    /// Сколько разделителей перед кареткой можно пропустить (пробел, точка).
    private static let maxTrailingSeparators = 2

    /// Читает слово перед кареткой в сфокусированном поле.
    /// `appPID` — процесс активного приложения: у части приложений фокус
    /// доступен только через их собственный элемент (см. `focusedElement`).
    nonisolated static func wordBeforeCaret(appPID: pid_t? = nil) -> FocusedWord? {
        guard let element = focusedElement(appPID: appPID), !isSecure(element) else { return nil }

        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let text = valueRef as? String, !text.isEmpty else { return nil }

        guard let selection = selectedRange(of: element), selection.length == 0 else { return nil }

        let source = text as NSString
        var index = min(selection.location, source.length)

        var skipped = 0
        while index > 0, skipped < maxTrailingSeparators, !isWordCharacter(source.character(at: index - 1)) {
            index -= 1
            skipped += 1
        }
        let end = index
        while index > 0, isWordCharacter(source.character(at: index - 1)) {
            index -= 1
        }
        guard end > index else { return nil }

        let caret = min(selection.location, source.length)
        return FocusedWord(
            word: source.substring(with: NSRange(location: index, length: end - index)),
            start: index,
            length: end - index,
            caret: caret,
            trailing: source.substring(with: NSRange(location: end, length: caret - end))
        )
    }

    /// Заменяет слово на `text` и возвращает каретку на прежнее место.
    /// Перенос символ-в-символ не меняет длину строки в UTF-16, поэтому позиция каретки остаётся валидной.
    @discardableResult
    nonisolated static func replace(_ target: FocusedWord, with text: String, appPID: pid_t? = nil) -> Bool {
        guard let element = focusedElement(appPID: appPID), !isSecure(element) else { return false }
        guard let current = wordBeforeCaret(appPID: appPID), current.word == target.word,
              current.start == target.start else { return false }

        guard setRange(element, location: target.start, length: target.length) else { return false }
        guard AXUIElementSetAttributeValue(
            element, kAXSelectedTextAttribute as CFString, text as CFString
        ) == .success else { return false }

        _ = setRange(element, location: target.caret, length: 0)
        return true
    }

    // MARK: - Private

    /// Сначала спрашиваем у самого приложения, потом — систему.
    ///
    /// Порядок именно такой: у Electron-приложений системный запрос фокуса не
    /// возвращает ничего, а запрос к элементу приложения — возвращает поле ввода.
    private nonisolated static func focusedElement(appPID: pid_t?) -> AXUIElement? {
        if let appPID {
            let appElement = AXUIElementCreateApplication(appPID)
            AXUIElementSetMessagingTimeout(appElement, messagingTimeout)
            if let element = copyFocused(from: appElement) { return element }

            // Chromium строит дерево доступности лениво и только по запросу.
            // Без этого поле ввода в Electron-приложении невидимо целиком.
            AXUIElementSetAttributeValue(appElement, manualAccessibilityAttribute as CFString, kCFBooleanTrue)
            if let element = copyFocused(from: appElement) { return element }
        }

        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, messagingTimeout)
        return copyFocused(from: system)
    }

    /// Просит дерево доступности построиться — для приложений на Chromium.
    static let manualAccessibilityAttribute = "AXManualAccessibility"

    private nonisolated static func copyFocused(from parent: AXUIElement) -> AXUIElement? {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            parent, kAXFocusedUIElementAttribute as CFString, &focused
        ) == .success, let value = focused,
            CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }

        let element = unsafeBitCast(value, to: AXUIElement.self)
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }

    private nonisolated static func isSecure(_ element: AXUIElement) -> Bool {
        stringAttribute(element, kAXRoleAttribute) == secureRole
            || stringAttribute(element, kAXSubroleAttribute) == secureRole
    }

    private nonisolated static func stringAttribute(_ element: AXUIElement, _ key: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private nonisolated static func selectedRange(of element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &value
        ) == .success, let raw = value, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }

        var range = CFRange()
        guard AXValueGetValue(unsafeBitCast(raw, to: AXValue.self), .cfRange, &range) else { return nil }
        return range
    }

    private nonisolated static func setRange(_ element: AXUIElement, location: Int, length: Int) -> Bool {
        var range = CFRange(location: location, length: length)
        guard let value = AXValueCreate(.cfRange, &range) else { return false }
        return AXUIElementSetAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, value
        ) == .success
    }

    /// Буквы (и только они) образуют слово: цифры и знаки — границы.
    private nonisolated static func isWordCharacter(_ unit: unichar) -> Bool {
        guard let scalar = UnicodeScalar(unit) else { return false }
        return CharacterSet.letters.contains(scalar)
    }
}
