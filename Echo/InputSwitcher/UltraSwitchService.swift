//
//  UltraSwitchService.swift
//  MonitorBarApp
//

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import os

/// Ultra Switch — мгновенная смена раскладки и исправление слов,
/// набранных не в той раскладке («ghbdtn» → «привет»).
///
/// Слово берётся из собственного буфера набранного, а не из поля ввода:
/// читать чужой текст через Accessibility можно далеко не везде — Pages не
/// отдаёт его вовсе, а движки на Chromium подтверждают запись и не выполняют
/// её. Замена идёт синтетическим вводом и поэтому работает всюду, где
/// принимают клавиатуру.
///
/// В памяти живёт одно набираемое слово и одно завершённое, не длиннее 64
/// символов; на диск не попадает ничего. Всё, что делает позицию каретки
/// неизвестной, буфер обнуляет.
@MainActor
final class UltraSwitchService: ObservableObject {

    /// Почему автозамена сейчас работает или не работает.
    enum Status: Equatable {
        case disabled
        /// Без Accessibility нельзя отправить исправление в чужое приложение.
        case needsAccessibility
        /// Без Input Monitoring не видно, что набирает пользователь.
        case needsInputMonitoring
        case running

        var isBlocked: Bool { self == .needsAccessibility || self == .needsInputMonitoring }
    }

    /// Приложения, в которых автозамена не работает никогда.
    private static let excludedBundleIDs: Set<String> = [
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "com.apple.loginwindow"
    ]

    /// Как часто перепроверять разрешения, пока автозамена заблокирована.
    private static let permissionPollInterval: TimeInterval = 2

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Echo",
        category: "UltraSwitch"
    )

    @Published private(set) var status: Status = .disabled

    private let inputSource = InputSourceService()
    private let judge = LayoutJudge()
    private let buffer = KeystrokeBuffer()
    let snippets = SnippetStore()
    private let tap = KeyboardTap()

    private var permissionPoll: Timer?
    private var wantsAuto = false

    /// Пока идёт синтетический ввод, собственные события игнорируются —
    /// иначе замена попала бы в буфер как пользовательский набор.
    private var isInjecting = false

    /// Сколько нажатий пользователя пришлось на время вставки. Они попали в
    /// документ, но мимо буфера — значит, буфер больше не описывает текст,
    /// и следующая замена стёрла бы не то. Такой буфер обнуляем.
    private var keystrokesDuringInjection = 0

    init() {
        tap.onCharacter = { [weak self] character in self?.handle(character) }
        tap.onBackspace = { [weak self] in self?.handleBackspace() }
        tap.onContextLost = { [weak self] in self?.buffer.clear() }

        // Словари читаются с диска около ста миллисекунд — заранее и в фоне.
        Task.detached(priority: .utility) { LanguageData.shared.load() }
    }

    // MARK: - Lifecycle

    /// Единственная точка входа из настроек.
    func apply(autoEnabled: Bool) {
        wantsAuto = autoEnabled
        evaluate()
    }

    /// Доступна ли фича в принципе: нужны и права, и обе раскладки в системе.
    func diagnostics() -> (hasPermission: Bool, hasBothLayouts: Bool) {
        (AXIsProcessTrusted(), inputSource.hasBothScripts())
    }

    // MARK: - Команды

    /// Мгновенное переключение ru ↔ en — замена клавише «глобус».
    func switchLayout() {
        inputSource.toggle()
    }

    /// Безусловно переносит последнее слово в другую раскладку.
    /// Повторный вызов возвращает его обратно — это и есть отмена автозамены.
    func convertLastWord() {
        guard let candidate = buffer.wordForManualConversion(),
              let script = LayoutTranslit.script(of: candidate.word),
              let converted = LayoutTranslit.convert(candidate.word, from: script) else {
            Self.log.notice("Ручная конвертация: нечего исправлять")
            return
        }
        replace(candidate.word, with: converted, tail: candidate.tail,
                deleteCount: candidate.deleteCount, target: script.other)
    }

    /// Открывает вкладку с недостающим разрешением. Системные запросы доступа
    /// не вызываются: они открыли бы второе окно поверх этого перехода.
    func requestAccess() {
        switch status {
        case .needsAccessibility:   open(pane: "Privacy_Accessibility")
        case .needsInputMonitoring: open(pane: "Privacy_ListenEvent")
        case .running, .disabled:   break
        }
    }

    private func open(pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Состояние

    private func evaluate() {
        let newStatus: Status
        if !wantsAuto {
            newStatus = .disabled
        } else if !AXIsProcessTrusted() {
            newStatus = .needsAccessibility
        } else if !CGPreflightListenEventAccess() {
            newStatus = .needsInputMonitoring
        } else {
            newStatus = tap.start() ? .running : .needsInputMonitoring
        }

        if newStatus != .running {
            tap.stop()
            buffer.clear()
        }

        if newStatus != status {
            status = newStatus
            Self.log.notice("Статус автозамены: \(String(describing: newStatus), privacy: .public)")
        }
        newStatus.isBlocked ? startPermissionPoll() : stopPermissionPoll()
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

    // MARK: - Набор

    private func handle(_ character: Character) {
        guard !isInjecting else {
            keystrokesDuringInjection += 1
            return
        }
        guard !isExcludedApp() else {
            buffer.clear()
            return
        }

        let completesWord = !character.isLetter
        buffer.append(character)
        if completesWord { checkCompletedWord() }
    }

    private func handleBackspace() {
        guard !isInjecting else {
            keystrokesDuringInjection += 1
            return
        }
        buffer.backspace()
    }

    /// Слово завершено разделителем — самое время его проверить.
    /// Сниппеты идут первыми: сокращение задано пользователем явно, и оно
    /// важнее догадки словаря о раскладке.
    private func checkCompletedWord() {
        if let token = buffer.completedToken(),
           let expansion = snippets.expansion(for: token.token) {
            Self.log.debug("Разворачиваю сниппет")
            expand(expansion, tail: token.tail, deleteCount: token.deleteCount)
            return
        }

        guard let candidate = buffer.completedForConversion(),
              let verdict = judge.verdict(for: candidate.word) else { return }

        replace(candidate.word, with: verdict.converted, tail: candidate.tail,
                deleteCount: candidate.deleteCount, target: verdict.target)
    }

    /// Подставляет сниппет. Раскладку при этом не трогаем: текст вставляется
    /// как есть, и переключать язык пользователю тут незачем.
    private func expand(_ expansion: String, tail: String, deleteCount: Int) {
        isInjecting = true
        keystrokesDuringInjection = 0

        TextInjector.replaceBeforeCaret(deleteCount: deleteCount, with: expansion + tail) { _ in
            Task { @MainActor [weak self] in
                self?.isInjecting = false
                self?.buffer.clear()
            }
        }
    }

    /// Стирает набранное и печатает исправленный вариант.
    /// Раскладка переключается только после подтверждённой отправки.
    private func replace(_ word: String, with converted: String, tail: String,
                         deleteCount: Int, target: KeyScript) {
        Self.log.debug("Исправляю слово из \(word.count, privacy: .public) букв")
        isInjecting = true
        keystrokesDuringInjection = 0

        TextInjector.replaceBeforeCaret(deleteCount: deleteCount, with: converted + tail) { success in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isInjecting = false
                guard success else {
                    Self.log.notice("Отправить исправление не удалось — раскладку не трогаю")
                    self.buffer.clear()
                    return
                }
                if self.keystrokesDuringInjection > 0 {
                    Self.log.debug("Во время вставки набирали дальше — сбрасываю буфер")
                    self.buffer.clear()
                } else {
                    self.buffer.replaceCompleted(with: converted)
                }
                self.inputSource.select(target)
            }
        }
    }

    private func isExcludedApp() -> Bool {
        // При защищённом вводе система не отдаёт нажатия никому, но проверяем
        // явно, чтобы не полагаться только на это.
        if IsSecureEventInputEnabled() { return true }
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return true }
        if bundleID == Bundle.main.bundleIdentifier { return true }
        return Self.excludedBundleIDs.contains(bundleID)
    }
}
