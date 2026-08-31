import Darwin
import Foundation

/// Протокол для получения списков процессов и файлов.
protocol ProcessMonitoring: Sendable {
    func topByCPU(limit: Int) async -> [MonitoredProcess]
    func topByRAM(limit: Int) async -> [MonitoredProcess]
    func terminate(pid: Int32) async -> Bool
    /// Топ файлов по размеру. Результат кэшируется реализацией.
    func topFilesBySize(limit: Int) async -> [FileInfo]
}

// MARK: - Mock для Preview и тестов

struct MockProcessMonitor: ProcessMonitoring {
    func topByCPU(limit: Int) async -> [MonitoredProcess] {
        [
            MonitoredProcess(name: "kernel_task",     pid: 0,   value: 12.4),
            MonitoredProcess(name: "Google Chrome",   pid: 1234, value: 8.2),
            MonitoredProcess(name: "Xcode",           pid: 2345, value: 6.7),
            MonitoredProcess(name: "Spotify",         pid: 3456, value: 3.1),
            MonitoredProcess(name: "Finder",          pid: 4567, value: 1.8),
        ].prefix(limit).map { $0 }
    }

    func topByRAM(limit: Int) async -> [MonitoredProcess] {
        [
            MonitoredProcess(name: "Xcode",           pid: 2345, value: 2048),
            MonitoredProcess(name: "Google Chrome",   pid: 1234, value: 1843),
            MonitoredProcess(name: "com.apple.WebKit",pid: 5678, value: 921),
            MonitoredProcess(name: "Simulator",       pid: 6789, value: 768),
            MonitoredProcess(name: "Slack",           pid: 7890, value: 512),
        ].prefix(limit).map { $0 }
    }

    func terminate(pid: Int32) async -> Bool { true }

    func topFilesBySize(limit: Int) async -> [FileInfo] {
        [
            FileInfo(path: "/Users/roos/Movies/Screen Recording.mov", size: 4_831_838_208),
            FileInfo(path: "/Users/roos/Library/Developer/Xcode/iOS DeviceSupport/archive.dmg", size: 3_221_225_472),
            FileInfo(path: "/Users/roos/Downloads/macOS Sonoma.dmg", size: 2_684_354_560),
        ].prefix(limit).map { $0 }
    }
}
