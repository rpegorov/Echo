import Foundation

/// Агрегат всех системных метрик — единственный Published объект MetricsService.
struct SystemMetrics: Sendable {
    var cpu = CPUMetrics()
    var ram = RAMMetrics()
    var disk = DiskMetrics()
    var network = NetworkMetrics()
}
