//
//  StatusItemPresenter.swift
//  MonitorBarApp
//

import AppKit

/// Что показывать в строке меню.
enum MenuBarIconMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case appIcon
    case metrics
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appIcon: return "Иконка"
        case .metrics: return "Метрики"
        case .custom:  return "Своя картинка"
        }
    }
}

/// Оформление иконки в строке меню: статичная картинка, живые метрики
/// или пользовательское изображение.
///
/// Вынесено из контроллера отдельно, потому что при режиме метрик содержимое
/// перерисовывается на каждом обновлении опроса, а всё остальное в строке меню
/// живёт своей жизнью.
@MainActor
struct StatusItemPresenter {

    /// Высота картинки в строке меню — как у системных иконок.
    private static let iconHeight: CGFloat = 18

    /// Метрики выводятся моноширинными цифрами: иначе строка дёргается по
    /// ширине на каждом обновлении и соседние иконки прыгают.
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)

    static func apply(
        to button: NSStatusBarButton,
        mode: MenuBarIconMode,
        metrics: SystemMetrics,
        shownMetrics: [MetricTab],
        customIconPath: String?
    ) {
        switch mode {
        case .appIcon:
            button.attributedTitle = NSAttributedString(string: "")
            button.image = defaultIcon()

        case .custom:
            button.attributedTitle = NSAttributedString(string: "")
            button.image = customIcon(at: customIconPath) ?? defaultIcon()

        case .metrics:
            button.image = nil
            button.attributedTitle = NSAttributedString(
                string: text(for: metrics, shownMetrics: shownMetrics),
                attributes: [.font: font]
            )
        }
    }

    /// Строка метрик для строки меню. Пустой выбор — показываем загрузку CPU,
    /// иначе кнопка схлопнется в невидимую точку.
    static func text(for metrics: SystemMetrics, shownMetrics: [MetricTab]) -> String {
        let selected = shownMetrics.isEmpty ? [.cpu] : shownMetrics
        return selected.map { value(of: $0, in: metrics) }.joined(separator: " · ")
    }

    private static func value(of tab: MetricTab, in metrics: SystemMetrics) -> String {
        switch tab {
        case .cpu:
            return String(format: "%.0f%%", metrics.cpu.usage)
        case .memory:
            return String(format: "%.0f%%", metrics.ram.usagePercent)
        case .disk:
            return String(format: "%.0f%%", metrics.disk.usagePercent)
        case .network:
            return "↓\(metrics.network.downloadFormatted)"
        }
    }

    // MARK: - Картинки

    private static func defaultIcon() -> NSImage? {
        guard let icon = NSImage(named: "MenuBarIcon") else { return nil }
        icon.isTemplate = false   // цветная non-template иконка (кольца в тонах воды)
        return icon
    }

    /// Пользовательская картинка масштабируется под строку меню и рисуется
    /// шаблоном: так она подхватывает цвет системы и не выглядит инородной.
    private static func customIcon(at path: String?) -> NSImage? {
        guard let path, let source = NSImage(contentsOfFile: path) else { return nil }

        let ratio = source.size.height > 0 ? source.size.width / source.size.height : 1
        let size = NSSize(width: iconHeight * ratio, height: iconHeight)

        let scaled = NSImage(size: size, flipped: false) { rect in
            source.draw(in: rect)
            return true
        }
        scaled.isTemplate = true
        return scaled
    }
}
