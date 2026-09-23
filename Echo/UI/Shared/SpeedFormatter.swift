//
//  SpeedFormatter.swift
//  MonitorBarApp
//

import Foundation

/// Единственное место форматирования скорости сети — используется и попапом,
/// и строкой меню, и моделью метрик, чтобы значения нигде не расходились.
enum SpeedFormatter {
    static func string(forKBPerSec speed: Double) -> String {
        speed < 1024
            ? String(format: "%.1f KB/s", speed)
            : String(format: "%.2f MB/s", speed / 1024)
    }
}
