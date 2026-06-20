//
//  CPUChartView.swift
//  MonitorBarApp
//

import SwiftUI

struct CPUChartView: View {
    let history: [Double]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                gridLines(size: geometry.size)

                linePath(values: history, max: 100, size: geometry.size, closed: true)
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.30), .clear],
                        startPoint: .top, endPoint: .bottom))

                linePath(values: history, max: 100, size: geometry.size, closed: false)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

                yAxisLabels(size: geometry.size)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
    }

    // MARK: - Paths

    private func linePath(values: [Double], max maxVal: Double, size: CGSize, closed: Bool) -> Path {
        guard values.count > 1 else { return Path() }
        let step = size.width / CGFloat(values.count - 1)

        func pt(_ i: Int) -> CGPoint {
            let x = CGFloat(i) * step
            let y = size.height * CGFloat(1 - values[i] / maxVal)
            return CGPoint(x: x, y: max(0, min(size.height, y)))
        }

        var path = Path()
        path.move(to: pt(0))
        for i in 1..<values.count {
            let prev = pt(i - 1)
            let curr = pt(i)
            let cp1 = CGPoint(x: prev.x + step * 0.5, y: prev.y)
            let cp2 = CGPoint(x: curr.x - step * 0.5, y: curr.y)
            path.addCurve(to: curr, control1: cp1, control2: cp2)
        }

        if closed {
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
        return path
    }

    private func gridLines(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let fractions: [CGFloat] = [0.25, 0.50, 0.75, 1.0]
            for f in fractions {
                let y = canvasSize.height * f
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                context.stroke(path,
                               with: .color(.secondary.opacity(0.15)),
                               style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
    }

    private func yAxisLabels(size: CGSize) -> some View {
        let items: [(label: String, fraction: CGFloat)] = [
            ("100%", 0.25),
            ("75%",  0.50),
            ("50%",  0.75),
            ("25%",  1.00),
        ]
        return ZStack(alignment: .topLeading) {
            ForEach(items.indices, id: \.self) { i in
                Text(items[i].label)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .offset(x: 6, y: size.height * items[i].fraction - 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
