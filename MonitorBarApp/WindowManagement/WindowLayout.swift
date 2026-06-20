//
//  WindowLayout.swift
//  MonitorBarApp
//

import CoreGraphics

/// Раскладки окна. Кадры считаются в координатах Cocoa (origin снизу-слева).
enum WindowLayout: String, CaseIterable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case center, maximize

    /// Вычисляет целевой кадр внутри видимой области экрана с учётом зазора.
    func frame(in visible: CGRect, gap: CGFloat) -> CGRect {
        let halfW = visible.width / 2
        let halfH = visible.height / 2
        let raw: CGRect

        switch self {
        case .leftHalf:    raw = CGRect(x: visible.minX,            y: visible.minY,            width: halfW,        height: visible.height)
        case .rightHalf:   raw = CGRect(x: visible.minX + halfW,    y: visible.minY,            width: halfW,        height: visible.height)
        case .topHalf:     raw = CGRect(x: visible.minX,            y: visible.minY + halfH,    width: visible.width, height: halfH)
        case .bottomHalf:  raw = CGRect(x: visible.minX,            y: visible.minY,            width: visible.width, height: halfH)
        case .topLeft:     raw = CGRect(x: visible.minX,            y: visible.minY + halfH,    width: halfW,        height: halfH)
        case .topRight:    raw = CGRect(x: visible.minX + halfW,    y: visible.minY + halfH,    width: halfW,        height: halfH)
        case .bottomLeft:  raw = CGRect(x: visible.minX,            y: visible.minY,            width: halfW,        height: halfH)
        case .bottomRight: raw = CGRect(x: visible.minX + halfW,    y: visible.minY,            width: halfW,        height: halfH)
        case .center:      raw = CGRect(x: visible.midX - visible.width * 0.3,
                                        y: visible.midY - visible.height * 0.3,
                                        width: visible.width * 0.6, height: visible.height * 0.6)
        case .maximize:    raw = visible
        }

        // Зазор: внешние поля gap/2, межоконный зазор ~gap.
        return raw.insetBy(dx: gap / 2, dy: gap / 2)
    }
}
