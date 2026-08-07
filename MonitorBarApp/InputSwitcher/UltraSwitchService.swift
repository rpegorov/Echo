//
//  UltraSwitchService.swift
//  MonitorBarApp
//

import AppKit
import ApplicationServices
import CoreGraphics
import os

/// Ultra Switch — мгновенная смена раскладки и исправление слов,
/// набранных не в той раскладке («ghbdtn» → «привет»).
///
/// Приложение не ведёт журнал нажатий: глобальный монитор смотрит только на
/// код клавиши-разделителя (пробел, Enter, Tab) и никогда — на введённые
/// символы. Само слово читается из поля ввода через Accessibility в момент
/// проверки и живёт до конца обработки.
@MainActor
final class UltraSwitchService: ObservableObject {

    /// Почему автозамена сейчас работает или не работает.
    enum Status: Equatable {
        case disabled
        /// Нет доступа Accessibility — нечем ни прочитать слово, ни заменить его.
        case needsAccessibility
        /// Нет Input Monitoring — глобальный монитор клавиш молчит.
        case needsInputMonitoring
        case running

        var isBlocked: Bool { self == .needsAccessibility || self == .needsInputMonitoring }
    }

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

    /// Как часто перепроверять выданные разрешения, пока автозамена заблокирована.
    private static let permissionPollInterval: TimeInterval = 2

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Echo",
        category: "UltraSwitch"
    )

    @Published private(set) var status: Status = .disabled

    private let inputSource = InputSourceService()
    private let judge = WordJudge()

    private var keyMonitor: Any?
    private var pendingCheck: Task<Void, Never>?
    private var permissionPoll: Timer?

    /// Чего хочет пользователь по настройкам — независимо от того, дали ли права.
    private var wantsAuto = false

    // MARK: - Lifecycle

    /// Единственная точка входа из настроек: пересчитывает состояние под текущие флаги.
    /// Разрешения здесь не запрашиваются: их просит пользователь кнопкой, по одному.
    func apply(autoEnabled: Bool) {
        wantsAuto = autoEnabled
        evaluate()
    }

    /// Доступна ли фича в принципе: нужны и права, и обе раскладки в системе.
    func diagnostics() -> (hasPermission: Bool, hasBothLayouts: Bool) {
        (AXIsProcessTrusted(), inputSource.hasBothScripts())
    }

    // MARK: - Commands

    /// Мгновенное переключение ru ↔ en — замена клавише «глобус».
    func switchLayout() {
        inputSource.toggle()
    }

    /// Безусловно переносит слово перед кареткой в другую раскладку.
    /// Повторный вызов возвращает слово обратно — это же и есть отмена автозамены.
    func convertWordUnderCaret() {
        guard AXIsProcessTrusted() else {
            Self.log.notice("Ручная конвертация: нет доступа Accessibility")
            return
        }
        guard let target = AXTextAccess.wordBeforeCaret(),
              let script = LayoutTranslit.script(of: target.word),
              let converted = LayoutTranslit.convert(target.word, from: script) else { return }

        write(converted, over: target)
        inputSource.select(script.other)
    }

    // MARK: - Permissions

    /// Просит ровно то разрешение, которого не хватает прямо сейчас, и открывает
    /// его вкладку в системных настройках.
    ///
    /// Раньше оба запроса уходили подряд и пользователь получал два системных
    /// окна одновременно. Теперь путь один: сначала Accessibility, и только
    /// когда оно выдано — Input Monitoring.
    func requestAccess() {
        switch status {
        case .needsAccessibility:
            // Запрос нужен не ради диалога, а чтобы приложение вообще попало
            // в список Accessibility — иначе его пришлось бы добавлять вручную.
            AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            open(pane: "Privacy_Accessibility")
        case .needsInputMonitoring:
            // То же самое для Input Monitoring: без вызова приложения нет в списке.
            _ = CGRequestListenEventAccess()
            open(pane: "Privacy_ListenEvent")
        case .running, .disabled:
            break
        }
    }

    private func open(pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Пересчитывает статус и приводит монитор в соответствие с ним.
    private func evaluate() {
        let newStatus: Status
        if !wantsAuto {
            newStatus = .disabled
        } else if !AXIsProcessTrusted() {
            newStatus = .needsAccessibility
        } else if !CGPreflightListenEventAccess() {
            newStatus = .needsInputMonitoring
        } else {
            newStatus = .running
        }

        if newStatus == .running {
            startMonitor()
        } else {
            stopMonitor()
        }

        if newStatus != status {
            status = newStatus
            Self.log.notice("Статус автозамены: \(String(describing: newStatus), privacy: .public)")
        }

        // Разрешение может появиться в любой момент и без перезапуска приложения:
        // пока мы его ждём, опрашиваем состояние сами.
        newStatus.isBlocked ? startPermissionPoll() : stopPermissionPoll()
    }

    private func startMonitor() {
        guard keyMonitor == nil else { return }
        judge.warmUp()
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            MainActor.assumeIsolated { self?.handleKeyDown(event) }
        }
    }

    private func stopMonitor() {
        pendingCheck?.cancel()
        pendingCheck = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func startPermissionPoll() {
        guard permissionPoll == nil else { return }
        permissionPoll = Timer.scheduledTimer(
            withTimeInterval: Self.permissionPollInterval, repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }
    }

    private func stopPermissionPoll() {
        permissionPoll?.invalidate()
        permissionPoll = nil
    }

    // Снятие монитора живёт только в `stopMonitor()`: `NSEvent.removeMonitor`
    // обязан вызываться на главном потоке, а `deinit` не изолирован.
    // Сервис живёт столько же, сколько приложение, — утечь монитору некуда.

    // MARK: - Auto flow

    private func handleKeyDown(_ event: NSEvent) {
        guard Self.boundaryKeyCodes.contains(event.keyCode) else { return }
        guard event.modifierFlags.isDisjoint(with: [.command, .control, .option]) else { return }
        guard !isExcludedApp() else {
            Self.log.debug("Граница слова пропущена: приложение в списке исключений")
            return
        }
        Self.log.debug("Граница слова: keyCode \(event.keyCode, privacy: .public)")

        pendingCheck?.cancel()
        pendingCheck = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            self?.checkLastWord()
        }
    }

    /// Читает слово перед кареткой и исправляет его, если словарь уверен в ошибке.
    private func checkLastWord() {
        guard let target = AXTextAccess.wordBeforeCaret() else {
            Self.log.debug("Поле ввода не отдало текст через Accessibility")
            return
        }
        guard let verdict = judge.verdict(for: target.word) else {
            // Само слово в лог не пишем — только длину: содержимое ввода
            // не должно утекать даже в диагностику.
            Self.log.debug("Слово из \(target.word.count, privacy: .public) букв: замена не нужна")
            return
        }

        Self.log.debug("Исправляю слово из \(target.word.count, privacy: .public) букв")
        write(verdict.converted, over: target)
        inputSource.select(verdict.target)
    }

    /// Пишет исправленное слово: сперва через Accessibility, при отказе —
    /// перенабором клавишами.
    private func write(_ text: String, over target: FocusedWord) {
        if AXTextAccess.replace(target, with: text) { return }

        Self.log.debug("Accessibility не дал заменить текст — перенабираю клавишами")
        SyntheticTyping.replaceBeforeCaret(
            deleteCount: target.caret - target.start,
            with: text + target.trailing
        )
    }

    private func isExcludedApp() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return true }
        if bundleID == Bundle.main.bundleIdentifier { return true }
        return Self.excludedBundleIDs.contains(bundleID)
    }
}
