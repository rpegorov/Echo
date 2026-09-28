//
//  KeyboardTap.swift
//  MonitorBarApp
//

import AppKit
import CoreGraphics

/// Перехват клавиатуры для отслеживания набираемого слова.
///
/// Только слушает, ничего не блокирует и не изменяет. Всё, что делает позицию
/// каретки неизвестной — клик мышью, стрелки, сочетание с модификатором —
/// приходит отдельным сигналом, чтобы буфер успел обнулиться.
@MainActor
final class KeyboardTap {

    /// Напечатан обычный символ.
    var onCharacter: ((Character) -> Void)?
    /// Нажат Backspace.
    var onBackspace: (() -> Void)?
    /// Позиция каретки стала неизвестной — буфер пора сбросить.
    var onContextLost: (() -> Void)?

    /// Хоткеи раскладки. Carbon забирает их себе, и в поле ввода они ничего
    /// не печатают, но перехват всё равно их видит. Без этого списка ⌥Space
    /// попадал бы в буфер неразрывным пробелом (и следующая замена стёрла бы
    /// лишний символ), а хоткей с ⌃ или ⌘ обнулял бы буфер раньше, чем
    /// успевает сработать сам.
    var reservedShortcuts: [KeyboardShortcut] = []

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private static let backspaceKeyCode: Int64 = 51
    /// Стрелки, Home/End, PageUp/PageDown — каретка уезжает неизвестно куда.
    private static let navigationKeyCodes: Set<Int64> = [123, 124, 125, 126, 115, 119, 116, 121, 53]

    var isRunning: Bool { tap != nil }

    // MARK: - Lifecycle

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: Self.handler,
            userInfo: context
        ) else { return false }

        tap = created
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        return true
    }

    func stop() {
        if let created = tap { CGEvent.tapEnable(tap: created, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        tap = nil
    }

    /// Система отключает перехват, если он однажды задумался. Без этого
    /// восстановления фича тихо умирает через несколько часов работы.
    fileprivate func reenable() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - Обработка

    /// Что удалось вынуть из события. Через границу изоляции передаются только
    /// такие значения: сам `CGEvent` не Sendable.
    private enum Signal: Sendable {
        case key(KeyPress)
        case contextLost
        case tapDisabled
    }

    private struct KeyPress: Sendable {
        let keyCode: Int64
        let flags: NSEvent.ModifierFlags
        let character: Character?
    }

    private func handle(_ signal: Signal) {
        switch signal {
        case .key(let press):  handle(press)
        case .contextLost:     onContextLost?()
        case .tapDisabled:     reenable()
        }
    }

    private func handle(_ press: KeyPress) {
        let isReserved = reservedShortcuts.contains {
            $0.matches(keyCode: UInt32(press.keyCode), flags: press.flags)
        }
        if isReserved { return }
        if press.keyCode == Self.backspaceKeyCode { onBackspace?(); return }
        if Self.navigationKeyCodes.contains(press.keyCode) { onContextLost?(); return }
        // Сочетания с командой или контролом — команды, а не набор текста.
        if press.flags.contains(.command) || press.flags.contains(.control) {
            onContextLost?()
            return
        }
        if let character = press.character { onCharacter?(character) }
    }

    /// Разбор события синхронно в колбэке — до перехода на актор.
    private static func signal(for type: CGEventType, event: CGEvent) -> Signal? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            return .tapDisabled

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return .contextLost

        case .keyDown:
            // Своя же вставка не должна попадать в буфер как набор.
            if event.getIntegerValueField(.eventSourceUserData) == TextInjector.eventMarker {
                return nil
            }
            // Биты модификаторов CGEventFlags и NSEvent.ModifierFlags совпадают.
            return .key(KeyPress(
                keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                flags: NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)),
                character: character(of: event)
            ))

        default:
            return nil
        }
    }

    private static func character(of event: CGEvent) -> Character? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: buffer, count: length).first
    }

    /// Колбэк перехвата: приходит на главный run loop, поэтому изоляция
    /// главного актора здесь фактическая.
    private static let handler: CGEventTapCallBack = { _, type, event, context in
        guard let context, let signal = signal(for: type, event: event) else {
            return Unmanaged.passUnretained(event)
        }
        let tap = Unmanaged<KeyboardTap>.fromOpaque(context).takeUnretainedValue()
        MainActor.assumeIsolated { tap.handle(signal) }
        return Unmanaged.passUnretained(event)
    }
}
