import Foundation

/// Текущие метрики процессора.
struct CPUMetrics: Sendable {
    /// Суммарная загрузка всех ядер, delta-based, 0–100%.
    var usage: Double = 0
    /// Количество логических ядер.
    var coreCount: Int = ProcessInfo.processInfo.processorCount
    /// Загрузка каждого ядра отдельно, 0–100%.
    var perCore: [Double] = []
}
