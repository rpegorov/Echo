//
//  UltraSwitchService.swift
//  MonitorBarApp
//

import AppKit
import ApplicationServices

/// Ultra Switch — мгновенная смена раскладки и исправление слов,
/// набранных не в той раскладке («ghbdtn» → «привет»).
///
/// Приложение не ведёт журнал нажатий: глобальный монитор смотрит только на
/// код клавиши-разделителя (пробел, Enter, Tab) и никогда — на введённые
/// символы. Само слово читается из поля ввода через Accessibility в момент
/// проверки и живёт до конца обработки.
@MainActor
final class UltraSwitchService: ObservableObject {

    /// Коды клавиш, завершающих слово.
    private static let boundaryKeyCodes: Set<UInt16> = [49, 36, 76, 48] // space, return, keypad enter, tab

    /// Приложения, в которых автозамена не работает никогда.
    private static let excludedBundleIDs: Set<String> = [
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "com.apple.loginwindow"
    ]

    /// Пауза перед чтением поля: разделитель должен успеть дойти до приложения.
    private static let settleDelay = Duration.milliseconds(60)

    private let inputSource = InputSourceService()
    private let judge = WordJudge()

    private var keyMonitor: Any?
    private var pendingCheck: Task<Void, Never>?

    /// Работает ли автозамена (монитор установлен).
    private(set) var isAutoRunning = false

    // MARK: - Lifecycle

    /// Включает автозамену. Требует выданного доступа Accessibility.
    func startAuto() {
        guard !isAutoRunning, AXIsProcessTrusted() else { return }
        judge.warmUp()
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            MainActor.assumeIsolated { self?.handleKeyDown(event) }
        }
        isAutoRunning = keyMonitor != nil
    }

    func stopAuto() {
        pendingCheck?.cancel()
        pendingCheck = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        isAutoRunning = false
    }

    // Снятие монитора живёт только в `stopAuto()`: `NSEvent.removeMonitor`
    // обязан вызываться на главном потоке, а `deinit` не изолирован.
    // Сервис живёт столько же, сколько приложение, — утечь монитору некуда.

    // MARK: - Commands

    /// Мгновенное переключение ru ↔ en — замена клавише «глобус».
    func switchLayout() {
        inputSource.toggle()
    }

    /// Безусловно переносит слово перед кареткой в другую раскладку.
    /// Повторный вызов возвращает слово обратно — это же и есть отмена автозамены.
    func convertWordUnderCaret() {
        guard AXIsProcessTrusted(), let target = AXTextAccess.wordBeforeCaret(),
              let script = LayoutTranslit.script(of: target.word),
              let converted = LayoutTranslit.convert(target.word, from: script) else { return }

        if AXTextAccess.replace(target, with: converted) {
            inputSource.select(script.other)
        }
    }

    /// Доступна ли фича в принципе: нужны и права, и обе раскладки в системе.
    func diagnostics() -> (hasPermission: Bool, hasBothLayouts: Bool) {
        (AXIsProcessTrusted(), inputSource.hasBothScripts())
    }

    // MARK: - Auto flow

    private func handleKeyDown(_ event: NSEvent) {
        guard Self.boundaryKeyCodes.contains(event.keyCode) else { return }
        guard event.modifierFlags.isDisjoint(with: [.command, .control, .option]) else { return }
        guard !isExcludedApp() else { return }

        pendingCheck?.cancel()
        pendingCheck = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            self?.checkLastWord()
        }
    }

    /// Читает слово перед кареткой и исправляет его, если словарь уверен в ошибке.
    private func checkLastWord() {
        guard let target = AXTextAccess.wordBeforeCaret(),
              let verdict = judge.verdict(for: target.word) else { return }

        if AXTextAccess.replace(target, with: verdict.converted) {
            inputSource.select(verdict.target)
        }
    }

    private func isExcludedApp() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return true }
        if bundleID == Bundle.main.bundleIdentifier { return true }
        return Self.excludedBundleIDs.contains(bundleID)
    }
}
