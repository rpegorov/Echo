//
//  MoleService.swift
//  MonitorBarApp
//

import AppKit
import Foundation

/// Интеграция с CLI Mole через шелл-аут.
/// Mole — интерактивный TUI (меню + запросы sudo/Touch ID), поэтому и превью
/// (`--dry-run`), и реальный запуск выполняем в Terminal: там корректно
/// рисуется интерфейс, а доступы к файлам уже выданы Terminal, а не нам.
@MainActor
final class MoleService: ObservableObject {

    enum Status: Equatable {
        case checking
        case notInstalled
        case ready
    }

    @Published private(set) var status: Status = .checking
    @Published private(set) var binaryPath: String?

    /// Подсказка по установке для UI.
    let installCommand = "brew install tw93/tap/mole"
    let repoURL = URL(string: "https://github.com/tw93/Mole")!

    private let candidatePaths = [
        "/opt/homebrew/bin/mole",
        "/usr/local/bin/mole",
        "/opt/homebrew/bin/mo",
        "/usr/local/bin/mo"
    ]

    // MARK: - Detection

    /// Находит исполняемый файл mole в типичных путях или через login-shell PATH.
    func detect() async {
        status = .checking
        if let path = await Self.locateBinary(candidates: candidatePaths) {
            binaryPath = path
            status = .ready
        } else {
            binaryPath = nil
            status = .notInstalled
        }
    }

    // MARK: - Execute (in Terminal)

    /// Запускает команду в Terminal. `dryRun` добавляет `--dry-run` (только превью).
    func runInTerminal(_ command: MoleCommand, dryRun: Bool = false) {
        guard let path = binaryPath else { return }
        let shellCommand = dryRun
            ? "\(path) \(command.rawValue) --dry-run"
            : "\(path) \(command.rawValue)"
        let script = """
        tell application "Terminal"
            activate
            do script "\(shellCommand)"
        end tell
        """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        try? task.run()
    }

    func openRepo() {
        NSWorkspace.shared.open(repoURL)
    }

    // MARK: - Helpers

    private static func locateBinary(candidates: [String]) async -> String? {
        await Task.detached {
            let fm = FileManager.default
            for path in candidates where fm.isExecutableFile(atPath: path) {
                return path
            }
            // Резерв: спросить у login-shell (учитывает пользовательский PATH).
            let probe = Process()
            probe.executableURL = URL(fileURLWithPath: "/bin/zsh")
            probe.arguments = ["-lc", "command -v mole || command -v mo"]
            let pipe = Pipe()
            probe.standardOutput = pipe
            probe.standardError = FileHandle.nullDevice
            probe.standardInput = FileHandle.nullDevice
            do {
                try probe.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                probe.waitUntilExit()
                let resolved = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let resolved, !resolved.isEmpty, fm.isExecutableFile(atPath: resolved) {
                    return resolved
                }
            } catch {}
            return nil
        }.value
    }
}
