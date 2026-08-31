import Foundation

/// Протокол для получения метрик процессора.
protocol CPUMonitoring: Sendable {
    /// Текущая суммарная загрузка CPU, delta-based, 0–100%.
    func currentUsage() async -> Double
    /// Загрузка каждого ядра отдельно, 0–100%.
    func perCoreUsage() async -> [Double]
}

// MARK: - Mock для Preview и тестов

struct MockCPUMonitor: CPUMonitoring {
    var usage: Double = 34.0
    var perCore: [Double] = [12, 45, 23, 67, 8, 91, 34, 56]

    func currentUsage() async -> Double { usage }
    func perCoreUsage() async -> [Double] { perCore }
}
