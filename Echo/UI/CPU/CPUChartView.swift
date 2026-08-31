//
//  CPUChartView.swift
//  MonitorBarApp
//

import SwiftUI

struct CPUChartView: View {
    let history: [Double]
    let timestamps: [Date]
    let samples: [ResourceSnapshot]
    @State private var hoverIndex: Int?
    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                ZStack {
                    gridLines(size: geometry.size)
                    linePath(values: history, max: 100, size: geometry.size, closed: true)
                        .fill(LinearGradient(colors: [Color.blue.opacity(0.30), .clear], startPoint: .top, endPoint: .bottom))
                    linePath(values: history, max: 100, size: geometry.size, closed: false)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                    yAxisLabels(size: geometry.size)
                    if let hoverIndex, samples.indices.contains(hoverIndex), timestamps.indices.contains(hoverIndex) {
                        ChartTooltip(timestamp: timestamps[hoverIndex], title: samples[hoverIndex].cpuProcessName, details: [String(format: "CPU %.1f%%", samples[hoverIndex].cpuPercent)])
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(8)
                    }
                    Color.clear
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            if case .active(let location) = phase, !history.isEmpty {
                                hoverIndex = min(max(Int(location.x / max(geometry.size.width, 1) * CGFloat(history.count)), 0), history.count - 1)
                            } else { hoverIndex = nil }
                        }
                }
            }
            .frame(maxHeight: .infinity)
            ChartTimeAxis(timestamps: timestamps)
                .frame(height: 22)
        }
        .padding(.bottom, 4)
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


struct ChartTimeAxis: View {
    let timestamps: [Date]

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        let indices = tickIndices
        HStack(spacing: 0) {
            ForEach(indices, id: \.self) { index in
                Text(label(at: index))
                    .frame(maxWidth: .infinity, alignment: index == indices.first ? .leading : index == indices.last ? .trailing : .center)
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 8)
    }

    private var tickIndices: [Int] {
        guard !timestamps.isEmpty else { return [0] }
        return Array(Set([0, timestamps.count / 3, timestamps.count * 2 / 3, timestamps.count - 1])).sorted()
    }

    private func label(at index: Int) -> String {
        guard timestamps.indices.contains(index) else { return "--:--:--" }
        return Self.formatter.string(from: timestamps[index])
    }
}


struct ChartTooltip: View {
    let timestamp: Date
    let title: String
    let details: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(timestamp, format: .dateTime.hour().minute().second())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            ForEach(details, id: \.self) { detail in
                Text(detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.cornerSM))
        .shadow(radius: 3)
    }
}
