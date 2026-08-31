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
        case character(Character)
        case backspace
        case contextLost
        case tapDisabled
    }

    private func handle(_ signal: Signal) {
        switch signal {
        case .character(let character): onCharacter?(character)
        case .backspace:                onBackspace?()
        case .contextLost:              onContextLost?()
        case .tapDisabled:              reenable()
        }
    }

    /// Разбор события синхронно в колбэке — до перехода на актор.
    private static func signal(for type: CGEventType, event: CGEvent) -> Signal? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            return .tapDisabled

        case .leftMouseDown, .rightMouseDown:
            return .contextLost

        case .keyDown:
            // Своя же вставка не должна попадать в буфер как набор.
            if event.getIntegerValueField(.eventSourceUserData) == TextInjector.eventMarker {
                return nil
            }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == backspaceKeyCode { return .backspace }
            if navigationKeyCodes.contains(keyCode) { return .contextLost }
            // Сочетания с командой или контролом — команды, а не набор текста.
            if event.flags.contains(.maskCommand) || event.flags.contains(.maskControl) {
                return .contextLost
            }

            var length = 0
            var buffer = [UniChar](repeating: 0, count: 4)
            event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &buffer)
            guard length > 0,
                  let character = String(utf16CodeUnits: buffer, count: length).first else { return nil }
            return .character(character)

        default:
            return nil
        }
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
