import Foundation

/// Текущие метрики сетевой активности.
struct NetworkMetrics: Sendable {
    /// Скорость входящего трафика, KB/s.
    var download: Double = 0
    /// Скорость исходящего трафика, KB/s.
    var upload: Double = 0

    var downloadFormatted: String { SpeedFormatter.string(forKBPerSec: download) }
    var uploadFormatted: String { SpeedFormatter.string(forKBPerSec: upload) }
}
