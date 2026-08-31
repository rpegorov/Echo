import Foundation

/// Текущие метрики оперативной памяти.
struct RAMMetrics: Sendable {
    var used: Int64 = 0
    var free: Int64 = 0
    var total: Int64 = 0

    /// Процент использования, 0–100.
    var usagePercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }

    var usedFormatted: String {
        ByteCountFormatter.string(fromByteCount: used, countStyle: .memory)
    }

    var freeFormatted: String {
        ByteCountFormatter.string(fromByteCount: free, countStyle: .memory)
    }

    var totalFormatted: String {
        ByteCountFormatter.string(fromByteCount: total, countStyle: .memory)
    }
}
