import Foundation

/// Текущие метрики использования диска.
struct DiskMetrics: Sendable {
    var used: Int64 = 0
    var total: Int64 = 0

    var free: Int64 { total - used }

    /// Процент использования, 0–100.
    var usagePercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }

    var usedFormatted: String {
        ByteCountFormatter.string(fromByteCount: used, countStyle: .file)
    }

    var freeFormatted: String {
        ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
    }

    var totalFormatted: String {
        ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
}
