//
//  CircularProgressView.swift
//  MonitorBarApp
//

import SwiftUI

/// Кольцо с числовым значением внутри. Используется в ряду метрик поповера.
/// Цвета порогов и дорожки берутся из `DS`, чтобы работать в обеих темах.
struct CircularProgressView: View {
    let progress: Double      // 0–100
    let valueText: String     // текст внутри кольца (напр. "34")
    let unitText: String      // подпись под значением (напр. "%")
    let name: String          // подпись под кольцом (напр. "CPU")
    let subLabel: String      // детали (напр. "8 cores")
    var ringSize: CGFloat = 58
    var action: (() -> Void)? = nil

    private var strokeWidth: CGFloat { ringSize >= 56 ? 5 : 4 }

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(DS.ringTrack, lineWidth: strokeWidth)
                        .frame(width: ringSize, height: ringSize)

                    Circle()
                        .trim(from: 0, to: min(progress / 100, 1))
                        .stroke(
                            DS.load(progress),
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: progress)

                    VStack(spacing: 0) {
                        Text(valueText)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                        if !unitText.isEmpty {
                            Text(unitText)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Text(name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                    .padding(.top, 8)

                Text(subLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // Ширину ячейки задаёт ряд, а не длина подписи: иначе на
                    // каждом обновлении ячейки переразмерялись и кольца ползли
                    // в стороны.
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(MetricCellButtonStyle())
    }
}

// MARK: - Button style

private struct MetricCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: DS.cornerMD)
                    .fill(configuration.isPressed ? DS.pressHighlight : Color.clear)
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Color hex helper

extension Color {
    /// Инициализация из шестнадцатеричной строки RRGGBB.
    init(hex: String) {
        let v = UInt64(hex, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >>  8) & 0xFF) / 255
        let b = Double( v        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
