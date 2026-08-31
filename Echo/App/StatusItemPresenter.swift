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
            button.attributedTitle = attributedText(for: metrics, shownMetrics: shownMetrics)
        }
    }

    /// Строка метрик с иконками: голые проценты не говорят, к чему они
    /// относятся, а подписи словами не помещаются в строку меню.
    static func attributedText(for metrics: SystemMetrics, shownMetrics: [MetricTab]) -> NSAttributedString {
        let selected = shownMetrics.isEmpty ? [.cpu] : shownMetrics
        let result = NSMutableAttributedString()

        for tab in selected {
            if result.length > 0 {
                result.append(NSAttributedString(string: "  ", attributes: [.font: font]))
            }
            if let icon = symbol(for: tab) {
                result.append(NSAttributedString(attachment: icon))
                result.append(NSAttributedString(string: " ", attributes: [.font: font]))
            }
            result.append(NSAttributedString(
                string: value(of: tab, in: metrics),
                attributes: [.font: font]
            ))
        }
        return result
    }

    /// Символ метрики как вложение в строку. Базовая линия выравнивается по
    /// шрифту вручную — иначе иконка «висит» выше цифр.
    private static func symbol(for tab: MetricTab) -> NSTextAttachment? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        guard let image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.rawValue)?
            .withSymbolConfiguration(configuration) else { return nil }

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(
            x: 0,
            y: font.descender + 1,
            width: image.size.width,
            height: image.size.height
        )
        return attachment
    }

    /// Строка метрик для строки меню. Пустой выбор — показываем загрузку CPU,
    /// иначе кнопка схлопнется в невидимую точку.
    static func text(for metrics: SystemMetrics, shownMetrics: [MetricTab]) -> String {
        let selected = shownMetrics.isEmpty ? [.cpu] : shownMetrics
        return selected.map { value(of: $0, in: metrics) }.joined(separator: " · ")
    }

    /// Значения дополняются пробелами до постоянной ширины.
    ///
    /// Иначе «9%» и «16%» дают разную ширину иконки, строка меню
    /// переразмеряется, а привязанный к ней поповер прыгает вбок вместе с
    /// содержимым — именно это выглядело как «кольца наползают слева».
    private static func value(of tab: MetricTab, in metrics: SystemMetrics) -> String {
        switch tab {
        case .cpu:
            return percent(metrics.cpu.usage)
        case .memory:
            return percent(metrics.ram.usagePercent)
        case .disk:
            return percent(metrics.disk.usagePercent)
        case .network:
            return "↓" + pad(metrics.network.downloadFormatted, to: 9)
        }
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%3.0f%%", min(max(value, 0), 100))
    }

    private static func pad(_ text: String, to width: Int) -> String {
        text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
    }

    /// Ширина иконки при самых длинных возможных значениях. Задаётся один раз,
    /// чтобы строка меню не меняла размер вообще никогда.
    static func widestWidth(shownMetrics: [MetricTab]) -> CGFloat {
        var sample = SystemMetrics()
        sample.cpu.usage = 100
        sample.ram.used = 100
        sample.ram.total = 100
        sample.disk.used = 100
        sample.disk.total = 100
        sample.network.download = 999 * 1024

        return attributedText(for: sample, shownMetrics: shownMetrics).size().width + 10
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
