import Foundation

/// Протокол для получения метрик оперативной памяти.
protocol RAMMonitoring: Sendable {
    func info() async -> RAMMetrics
}

// MARK: - Mock для Preview и тестов

struct MockRAMMonitor: RAMMonitoring {
    func info() async -> RAMMetrics {
        RAMMetrics(
            used: 22_548_578_304,
            free:  9_663_676_416,
            total: 34_359_738_368
        )
    }
}
