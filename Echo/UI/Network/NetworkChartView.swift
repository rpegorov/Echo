//
//  NetworkChartView.swift
//  MonitorBarApp
//

import SwiftUI

struct NetworkChartView: View {
    let history: [(download: Double, upload: Double)]

    private var maxValue: Double {
        let maxDl = history.map(\.download).max() ?? 1
        let maxUl = history.map(\.upload).max() ?? 1
        return max(max(maxDl, maxUl), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                gridLines(size: geometry.size)

                // Download — filled area
                linePath(values: history.map(\.download), max: maxValue, size: geometry.size, closed: true)
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.25), .clear],
                        startPoint: .top, endPoint: .bottom))

                // Download — stroke
                linePath(values: history.map(\.download), max: maxValue, size: geometry.size, closed: false)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

                // Upload — filled area
                linePath(values: history.map(\.upload), max: maxValue, size: geometry.size, closed: true)
                    .fill(LinearGradient(
                        colors: [Color.green.opacity(0.20), .clear],
                        startPoint: .top, endPoint: .bottom))

                // Upload — stroke
                linePath(values: history.map(\.upload), max: maxValue, size: geometry.size, closed: false)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

                yAxisLabels(size: geometry.size, maxValue: maxValue)
                xAxisLabels(size: geometry.size)
                legend
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
            // Cubic bezier for smooth curve
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

    private func yAxisLabels(size: CGSize, maxValue: Double) -> some View {
        let step = maxValue / 4
        let items = (0..<5).map { i in
            let value = maxValue - step * Double(i)
            return String(format: "%.0f KB/s", value)
        }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                Text(items[i])
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                if i < items.count - 1 { Spacer() }
            }
        }
        .padding(.leading, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func xAxisLabels(size: CGSize) -> some View {
        HStack {
            Text("60s ago")
            Spacer()
            Text("now")
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 4)
    }

    private func gridLines(size: CGSize) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<5) { i in
                Divider().opacity(0.2)
                if i < 4 { Spacer() }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            legendRow(color: .blue,  label: "↓ Download")
            legendRow(color: .green, label: "↑ Upload")
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerSM))
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func legendRow(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 14, height: 2)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
