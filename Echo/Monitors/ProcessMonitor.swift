//
//  ProcessMonitor.swift
//  MonitorBarApp

import Darwin
import Foundation

/// Информация о процессе.
struct MonitoredProcess: Identifiable, Sendable {
    var id: Int32 { pid }
    let name: String
    let pid: Int32
    let value: Double
}

/// Информация о файле.
struct FileInfo: Sendable {
    let path: String
    let size: Int64
}

struct ResourceSnapshot: Sendable {
    let cpuProcessName: String
    let cpuPercent: Double
    let ramProcessName: String
    let ramMB: Double
}

/// Монитор процессов и файлов.
/// topFilesBySize кэшируется на 30 секунд — обход домашней директории дорогой.
actor ProcessMonitor: ProcessMonitoring {

    private var filesCache:     [FileInfo] = []
    private var filesCacheDate: Date = .distantPast
    private let filesCacheTTL:  TimeInterval = 60

    // MARK: - ProcessMonitoring

    func topByCPU(limit: Int = 10) async -> [MonitoredProcess] {
        runPS(args: ["-arcwwwxo", "pid,%cpu,comm"], limit: limit) { components in
            guard components.count >= 3,
                  let pid = Int32(components[0]),
                  let val = Double(components[1])
            else { return nil }
            return MonitoredProcess(name: String(components[2]), pid: pid, value: val)
        }
    }

    func topByRAM(limit: Int = 10) async -> [MonitoredProcess] {
        runPS(args: ["-arcwwwxo", "pid,rss,comm"], limit: limit) { components in
            guard components.count >= 3,
                  let pid = Int32(components[0]),
                  let rss = Double(components[1])
            else { return nil }
            return MonitoredProcess(name: String(components[2]), pid: pid, value: rss / 1024)
        }
    }

    func terminate(pid: Int32) async -> Bool {
        guard pid > 1 else { return false }
        return Darwin.kill(pid, SIGTERM) == 0
    }

    func topFilesBySize(limit: Int = 10) async -> [FileInfo] {
        if Date().timeIntervalSince(filesCacheDate) < filesCacheTTL {
            return Array(filesCache.prefix(limit))
        }
        let fresh = await fetchLargeFiles()
        filesCache     = fresh
        filesCacheDate = .now
        return Array(fresh.prefix(limit))
    }

    // MARK: - Private

    /// Запускает /bin/ps и парсит вывод через переданное замыкание.
    private func runPS(
        args: [String],
        limit: Int,
        parse: ([Substring]) -> MonitoredProcess?
    ) -> [MonitoredProcess] {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments  = args
        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            let data   = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var processes: [MonitoredProcess] = output
                .components(separatedBy: .newlines)
                .dropFirst()
                .compactMap { line -> MonitoredProcess? in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return nil }
                    let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                    return parse(parts)
                }
            processes.sort { $0.value > $1.value }
            return Array(processes.prefix(limit))
        } catch {
            return []
        }
    }

    /// Сканирует целевые директории на фоновом потоке (не блокирует actor executor).
    private func fetchLargeFiles() async -> [FileInfo] {
        await Task.detached(priority: .background) {
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            let searchDirs = ["Downloads", "Documents", "Desktop", "Movies", "Music"]
                .map { home.appendingPathComponent($0) }
            let threshold: Int64 = 50 * 1024 * 1024

            var files: [FileInfo] = []

            for dir in searchDirs {
                guard let enumerator = fm.enumerator(
                    at: dir,
                    includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }

                while let url = enumerator.nextObject() as? URL {
                    if Task.isCancelled { break }
                    guard let res = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                          res.isRegularFile == true,
                          let size = res.fileSize.map(Int64.init),
                          size >= threshold
                    else { continue }
                    files.append(FileInfo(path: url.path, size: size))
                }
            }

            files.sort { $0.size > $1.size }
            return Array(files.prefix(50))
        }.value
    }
}
