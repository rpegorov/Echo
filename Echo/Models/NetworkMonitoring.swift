import Foundation

/// Протокол для получения метрик сетевой активности.
protocol NetworkMonitoring: Sendable {
    /// Текущая скорость входящего и исходящего трафика, KB/s (без loopback).
    func speed() async -> NetworkMetrics
}

// MARK: - Mock для Preview и тестов

struct MockNetworkMonitor: NetworkMonitoring {
    func speed() async -> NetworkMetrics {
        NetworkMetrics(download: 2457.6, upload: 819.2)
    }
}
