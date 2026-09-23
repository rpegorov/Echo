//
//  RingMetricFormatter.swift
//  Echo
//
//  Localized formatting for the CPU / Memory / Disk ring sub-labels in
//  ContentView. Kept out of the view body per the "view doesn't think" rule —
//  mirrors the SpeedFormatter pattern already used for the network row.
//

import Foundation

enum RingMetricFormatter {

    private static let bytesPerGB: Double = 1_073_741_824
    private static let decimalBytesPerGB: Double = 1_000_000_000
    private static let decimalBytesPerTB: Double = 1_000_000_000_000

    /// "14 cores" / "14 ядер" — correct plural category per language via the
    /// Metrics catalog's plural variations.
    @MainActor
    static func cpuCores(_ count: Int, using loc: Localizer) -> String {
        loc.t(MetricsKey.cpuCoresCount, count)
    }

    /// "24/36 GB" / "24/36 ГБ" — RAM is always sub-TB, so a flat whole-GB
    /// format is enough.
    @MainActor
    static func memoryUsage(usedBytes: Int64, totalBytes: Int64, using loc: Localizer) -> String {
        let used = Double(usedBytes) / bytesPerGB
        let total = Double(totalBytes) / bytesPerGB
        return loc.t(MetricsKey.memoryUsageGB, used, total)
    }

    /// Whole-GB rounded compact form ("580/994 ГБ"); switches to one-decimal
    /// TB once the total crosses the TB threshold ("1,2/2 ТБ"), formatting
    /// each value with its own decimal-or-not so a whole number never shows
    /// a trailing ".0".
    @MainActor
    static func diskUsage(usedBytes: Int64, totalBytes: Int64, using loc: Localizer) -> String {
        if Double(totalBytes) >= decimalBytesPerTB {
            let used = compactNumber(Double(usedBytes) / decimalBytesPerTB, locale: loc.locale)
            let total = compactNumber(Double(totalBytes) / decimalBytesPerTB, locale: loc.locale)
            return loc.t(MetricsKey.diskUsageTB, used, total)
        }
        let used = Double(usedBytes) / decimalBytesPerGB
        let total = Double(totalBytes) / decimalBytesPerGB
        return loc.t(MetricsKey.diskUsageGB, used, total)
    }

    /// Up to one fraction digit, dropped entirely when the value is whole
    /// (2.0 -> "2", 1.2 -> "1,2" in ru).
    private static func compactNumber(_ value: Double, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}
