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
    // Поглощаем нажатия — клавиатура «не реагирует», можно протирать.
    return nil
}

/// Сервис системных утилит: предотвращение сна и блокировка клавиатуры.
@MainActor
final class SystemUtilitiesService: ObservableObject {

    @Published var preventSleepEnabled: Bool = false {
        didSet {
            guard oldValue != preventSleepEnabled else { return }
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

        // Яркость, громкость и управление воспроизведением приходят не как
        // нажатия клавиш, а системными событиями (NX_SYSDEFINED, тип 14).
        // Без этого бита клавиатура «заблокирована», но верхний ряд работает.
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
    }

    private func disableKeyboardCleaning() {
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

    /// Показывает системный диалог «Allow in System Settings» (Accessibility).
    /// Ключ задаём строкой ("AXTrustedCheckOptionPrompt") — это значение
    /// константы kAXTrustedCheckOptionPrompt, так избегаем неоднозначного
    /// импорта Unmanaged<CFString> между версиями SDK.
    private func requestAccessibilityPermission() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
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
