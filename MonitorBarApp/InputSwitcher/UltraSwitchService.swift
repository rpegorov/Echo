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
/// Приложение не ведёт журнал нажатий и вообще не читает клавиатуру: о том,
/// что слово закончено, сообщает сам Accessibility — уведомлением об изменении
/// текста в поле. Слово читается из поля в момент проверки и живёт до конца
/// обработки. Поэтому автозамене хватает одного разрешения.
@MainActor
final class UltraSwitchService: ObservableObject {

    /// Почему автозамена сейчас работает или не работает.
    enum Status: Equatable {
        case disabled
        /// Нет доступа Accessibility — единственное, что нужно автозамене.
        case needsAccessibility
        case running

        var isBlocked: Bool { self == .needsAccessibility }
    }

    /// Коды клавиш, завершающих слово, — для дополнительного триггера по клавиатуре.
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
    private let watcher = AXTextWatcher()

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

    /// Открывает вкладку Accessibility — единственное, что нужно автозамене.
    ///
    /// Системный запрос доступа намеренно не вызывается: он показал бы второе
    /// окно поверх этого перехода. В списке Accessibility приложение и так есть,
    /// потому что постоянно обращается к AX.
    func requestAccess() {
        guard status.isBlocked else { return }
        open(pane: "Privacy_Accessibility")
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

    private var isWatching = false
    private var keyMonitor: Any?

    /// Триггеров два, и они дополняют друг друга. Уведомления Accessibility
    /// работают на одном разрешении, но их шлют не все приложения; монитор
    /// клавиш ловит границу слова там, где уведомлений нет, — но требует
    /// Input Monitoring. Ставим оба, какой сработает первым — не важно:
    /// проверка всё равно дебаунсится.
    private func startMonitor() {
        guard !isWatching else { return }
        judge.warmUp()
        watcher.onTextChanged = { [weak self] in self?.scheduleCheck() }
        watcher.start()
        isWatching = true

        if CGPreflightListenEventAccess() {
            keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                MainActor.assumeIsolated {
                    guard Self.boundaryKeyCodes.contains(event.keyCode),
                          event.modifierFlags.isDisjoint(with: [.command, .control, .option]) else { return }
                    self?.scheduleCheck()
                }
            }
            Self.log.notice("Триггеры автозамены: уведомления Accessibility и монитор клавиш")
        } else {
            Self.log.notice("Триггеры автозамены: только уведомления Accessibility")
        }
    }

    private func stopMonitor() {
        pendingCheck?.cancel()
        pendingCheck = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        guard isWatching else { return }
        watcher.stop()
        isWatching = false
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

    /// Текст в поле изменился — проверяем, не закончено ли слово.
    private func scheduleCheck() {
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
        guard let target = AXTextAccess.wordBeforeCaret() else {
            Self.log.debug("Поле ввода не отдало текст через Accessibility")
            return
        }
        // Пустой хвост — каретка стоит сразу за буквой, слово ещё набирается.
        // Правим только когда за словом уже есть разделитель.
        guard !target.trailing.isEmpty else { return }
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
