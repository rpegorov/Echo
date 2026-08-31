import Foundation

/// Протокол для получения метрик диска.
protocol DiskMonitoring: Sendable {
    func info() async -> DiskMetrics
}

// MARK: - Mock для Preview и тестов

struct MockDiskMonitor: DiskMonitoring {
    func info() async -> DiskMetrics {
        DiskMetrics(used: 321_098_407_936, total: 994_662_584_320)
    }
}
