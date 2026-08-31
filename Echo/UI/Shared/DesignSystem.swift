//
//  DesignSystem.swift
//  MonitorBarApp
//

import SwiftUI

/// Единая дизайн-система приложения — направление B (LiquidGlass / фирменный).
/// Размеры, радиусы, цвета и пороги метрик живут здесь, чтобы поповер и
/// детальное окно говорили на одном визуальном языке.
enum DS {

    // MARK: - Layout

    /// Ширина поповера.
    static let popoverWidth: CGFloat = 264
    /// Размер детального окна по умолчанию.
    static let detailSize = CGSize(width: 560, height: 500)

    // MARK: - Corners

    static let cornerLG: CGFloat = 20
    static let cornerMD: CGFloat = 14
    static let cornerSM: CGFloat = 10

    // MARK: - Spacing

    static let gutter: CGFloat = 16

    // MARK: - Color

    /// Фирменный акцент.
    static let accent = Color(red: 0.26, green: 0.56, blue: 1.0)

    /// Полупрозрачная дорожка кольца — адаптивна к светлой и тёмной теме.
    static let ringTrack = Color.primary.opacity(0.10)

    /// Лёгкая подсветка нажатия — адаптивна к теме.
    static let pressHighlight = Color.primary.opacity(0.06)

    /// Цвет метрики по порогу загрузки (0–100): зелёный / оранжевый / красный.
    static func load(_ percent: Double) -> Color {
        switch percent {
        case ..<50:  return .green
        case ..<80:  return .orange
        default:     return .red
        }
    }
}
