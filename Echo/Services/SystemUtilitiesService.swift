//
//  SystemUtilitiesService.swift
//  MonitorBarApp
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import IOKit
import IOKit.pwr_mgt
import os

// MARK: - Event tap callback (file scope)

/// Глобальная ссылка на активный тап — нужна, чтобы C-колбэк мог переподключить
/// тап, когда система временно отключает его (timeout / ввод пользователя).
nonisolated(unsafe) private var sharedKeyboardTap: CFMachPort?

/// C-совместимый колбэк тапа. Глотает события клавиатуры (возвращает nil),
/// а на служебные события отключения — снова включает тап и пропускает их.
private func keyboardEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = sharedKeyboardTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    // Блокируем все события клавиатуры: клавиши, модификаторы (Caps Lock) и
    // служебные клавиши. Верхний ряд приходит сюда обычными keyDown, потому что
    // на время очистки переведён в режим F1–F12 (см. suppressFnRow()).
    // События отключения тапа обработаны выше и должны быть пропущены.
    return nil
}

/// Сервис системных утилит: предотвращение сна и блокировка клавиатуры.
@MainActor
final class SystemUtilitiesService: ObservableObject {

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Echo",
        category: "KeyboardCleaning"
    )

    private static let fnStateKey = "com.apple.keyboard.fnState" as CFString
    private static let fnStateRecoveryKey = "KeyboardCleaningRestoresFnState"

    /// Значение `com.apple.keyboard.fnState` до включения очистки.
    private var previousFnState: Bool?

    init() {
        // Приложение могли убить во время очистки — возвращаем настройку,
        // иначе верхний ряд клавиатуры останется в режиме F1–F12.
        if let stored = UserDefaults.standard.object(forKey: Self.fnStateRecoveryKey) as? Bool {
            UserDefaults.standard.removeObject(forKey: Self.fnStateRecoveryKey)
            Self.setFnState(stored)
            Self.log.info("Keyboard cleaning: fn row restored after abnormal exit")
        }
        // Prevent Sleep переживает перезапуск; очистка клавиатуры — намеренно нет,
        // иначе приложение стартовало бы с заблокированной клавиатурой.
        // `didSet` в init не срабатывает, поэтому assertion создаётся явно.
        preventSleepEnabled = UserDefaults.standard.bool(forKey: Self.preventSleepKey)
        if preventSleepEnabled { enablePreventSleep() }
    }

    private static let preventSleepKey = "utilities.preventSleep"

    @Published var preventSleepEnabled: Bool = false {
        didSet {
            guard oldValue != preventSleepEnabled else { return }
            UserDefaults.standard.set(preventSleepEnabled, forKey: Self.preventSleepKey)
            preventSleepEnabled ? enablePreventSleep() : disablePreventSleep()
        }
    }

    @Published var keyboardCleaningEnabled: Bool = false {
        didSet {
            guard oldValue != keyboardCleaningEnabled else { return }
            keyboardCleaningEnabled ? enableKeyboardCleaning() : disableKeyboardCleaning()
        }
    }

    /// True, пока ждём, что пользователь выдаст доступ Accessibility в System Settings.
    @Published var keyboardCleaningNeedsPermission: Bool = false

    nonisolated(unsafe) private var assertionID: IOPMAssertionID = 0
    nonisolated(unsafe) private var eventTap: CFMachPort?
    nonisolated(unsafe) private var runLoopSource: CFRunLoopSource?

    // MARK: - Prevent Sleep

    private func enablePreventSleep() {
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MonitorBarApp: Prevent Sleep" as CFString,
            &assertionID
        )
        if result != kIOReturnSuccess {
            preventSleepEnabled = false
        }
    }

    private func disablePreventSleep() {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }

    // MARK: - Keyboard Cleaning

    private func enableKeyboardCleaning() {
        // 1. Без доступа Accessibility активный тап клавиатуры создать нельзя —
        //    проверяем заранее и при необходимости показываем системный запрос.
        guard AXIsProcessTrusted() else {
            requestAccessibilityPermission()
            keyboardCleaningEnabled = false
            keyboardCleaningNeedsPermission = true
            return
        }

        // NX_SYSDEFINED (тип 14) оставляем в маске: служебные клавиши части
        // клавиатур приходят этим типом. Верхний ряд самого Mac закрывается
        // переводом в режим F1–F12 — см. suppressFnRow().
        let systemDefinedEventType: UInt32 = 14

        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << systemDefinedEventType)
        )

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardEventCallback,
            userInfo: nil
        ) else {
            // Право есть в проверке, но тап не создался (например, доступ выдан
            // другой сборке/пути). Просим выдать заново и откатываем тумблер.
            requestAccessibilityPermission()
            keyboardCleaningEnabled = false
            keyboardCleaningNeedsPermission = true
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        sharedKeyboardTap = tap
        keyboardCleaningNeedsPermission = false
        suppressFnRow()
    }

    private func disableKeyboardCleaning() {
        restoreFnRow()
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        eventTap = nil
        runLoopSource = nil
        sharedKeyboardTap = nil
    }

    // MARK: - Fn row

    /// Верхний ряд (яркость, громкость, F1–F12) система доставляет событиями
    /// NX_SYSDEFINED: их обрабатывают системные демоны до оконного сервера,
    /// поэтому тап на уровне сессии этих событий не видит, а тап уровня HID
    /// доступен только root — `CGEvent.tapCreate` возвращает для него NULL
    /// (CGEventTapLocation). Чтобы очистка закрывала и ряд, переводим его в режим
    /// стандартных функциональных клавиш: тогда нажатия приходят обычными keyDown
    /// и поглощаются тапом. Настройку возвращаем при выключении.
    private func suppressFnRow() {
        let current = Self.fnState()
        guard !current else {
            Self.log.info("Keyboard cleaning: fn row already uses standard function keys")
            return
        }
        previousFnState = current
        UserDefaults.standard.set(current, forKey: Self.fnStateRecoveryKey)
        Self.setFnState(true)
        Self.log.info("Keyboard cleaning: fn row switched to standard function keys")
    }

    private func restoreFnRow() {
        let previous =
            previousFnState
            ?? UserDefaults.standard.object(forKey: Self.fnStateRecoveryKey) as? Bool
        previousFnState = nil
        UserDefaults.standard.removeObject(forKey: Self.fnStateRecoveryKey)
        guard let previous else { return }
        Self.setFnState(previous)
        Self.log.info("Keyboard cleaning: fn row restored")
    }

    /// `com.apple.keyboard.fnState` из глобального домена (аналог `defaults read -g`).
    private static func fnState() -> Bool {
        CFPreferencesCopyValue(
            fnStateKey,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) as? Bool ?? false
    }

    private static func setFnState(_ enabled: Bool) {
        CFPreferencesSetValue(
            fnStateKey,
            enabled ? kCFBooleanTrue : kCFBooleanFalse,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }

    /// Показывает системный диалог «Allow in System Settings» (Accessibility).
    /// Ключ задаём строкой ("AXTrustedCheckOptionPrompt") — это значение
    /// константы kAXTrustedCheckOptionPrompt, так избегаем неоднозначного
    /// импорта Unmanaged<CFString> между версиями SDK.
    private func requestAccessibilityPermission() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Lifecycle

    /// Освобождает все системные ресурсы. Вызывать из @MainActor (applicationWillTerminate).
    func cleanup() {
        disablePreventSleep()
        disableKeyboardCleaning()
    }

    deinit {
        if assertionID != 0 { IOPMAssertionRelease(assertionID) }
        if let tap = eventTap { CFMachPortInvalidate(tap) }
    }
}
