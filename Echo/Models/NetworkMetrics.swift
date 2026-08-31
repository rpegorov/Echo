import Foundation

/// Текущие метрики сетевой активности.
struct NetworkMetrics: Sendable {
    /// Скорость входящего трафика, KB/s.
    var download: Double = 0
    /// Скорость исходящего трафика, KB/s.
    var upload: Double = 0

    var downloadFormatted: String { formatSpeed(download) }
    var uploadFormatted: String { formatSpeed(upload) }

    private func formatSpeed(_ speed: Double) -> String {
        speed < 1024
            ? String(format: "%.1f KB/s", speed)
            : String(format: "%.2f MB/s", speed / 1024)
    }
}
