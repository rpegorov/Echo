//
//  TemperatureChartView.swift
//  Echo
//

import SwiftUI

struct TemperatureChartView: View {
    let cpuHistory: [Double]
    let gpuHistory: [Double]
    let timestamps: [Date]
    @State private var hoverIndex: Int?
    @EnvironmentObject private var loc: Localizer

    /// Axis top: the higher series rounded up to a multiple of 20 °C.
    private var axisMax: Double {
        let peaks = [cpuHistory.max(), gpuHistory.max()].compactMap { $0 }
        let rounded = ((peaks.max() ?? DS.Temperature.axisFloorCelsius) / DS.Temperature.axisRoundingCelsius)
            .rounded(.up) * DS.Temperature.axisRoundingCelsius
        return max(rounded, DS.Temperature.axisFloorCelsius)
    }

    /// Y-axis label values, top to bottom.
    private var axisLabelValues: [Double] {
        let step = (axisMax - DS.Temperature.axisFloorCelsius) / Double(DS.Temperature.axisStepCount)
        return Array(stride(from: axisMax, through: DS.Temperature.axisFloorCelsius, by: -step))
    }

    var body: some View {
        VStack(spacing: DS.Temperature.chartStackSpacing) {
            GeometryReader { geometry in
                ZStack {
                    gridLines
                    series(
                        values: gpuHistory,
                        size: geometry.size,
                        strokeColor: .purple,
                        fillOpacity: DS.Temperature.gpuFillOpacity
                    )
                    series(
                        values: cpuHistory,
                        size: geometry.size,
                        strokeColor: .orange,
                        fillOpacity: DS.Temperature.cpuFillOpacity
                    )
                    yAxisLabels
                    legend
                    tooltip
                    Color.clear
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            hoverIndex = hoverIndex(for: phase, in: geometry.size)
                        }
                }
            }
            .frame(maxHeight: .infinity)
            ChartTimeAxis(timestamps: timestamps)
                .frame(height: DS.Temperature.timeAxisHeight)
        }
        .padding(.bottom, DS.Temperature.chartBottomPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
    }

    // MARK: - Series

    private func series(values: [Double], size: CGSize, strokeColor: Color, fillOpacity: Double) -> some View {
        Group {
            linePath(values: values, size: size, closed: true)
                .fill(LinearGradient(
                    colors: [strokeColor.opacity(fillOpacity), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            linePath(values: values, size: size, closed: false)
                .stroke(strokeColor, style: StrokeStyle(lineWidth: DS.Temperature.seriesStrokeWidth, lineJoin: .round))
        }
    }

    private func linePath(values: [Double], size: CGSize, closed: Bool) -> Path {
        guard values.count >= DS.Temperature.minimumSeriesPoints else { return Path() }
        let last = values.index(before: values.endIndex)
        let step = size.width / CGFloat(last)

        func point(at index: Int) -> CGPoint {
            let inverted = (axisMax - values[index]) / axisMax
            let coordY = size.height * CGFloat(inverted)
            return CGPoint(x: CGFloat(index) * step, y: min(max(coordY, .zero), size.height))
        }

        var path = Path()
        path.move(to: point(at: values.startIndex))
        for index in values.indices.dropFirst() {
            let previous = point(at: values.index(before: index))
            let current = point(at: index)
            let controlLead = CGPoint(x: previous.x + step * DS.Temperature.curveSmoothingRatio, y: previous.y)
            let controlTrail = CGPoint(x: current.x - step * DS.Temperature.curveSmoothingRatio, y: current.y)
            path.addCurve(to: current, control1: controlLead, control2: controlTrail)
        }

        if closed {
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: .zero, y: size.height))
            path.closeSubpath()
        }
        return path
    }

    // MARK: - Axis and grid

    private var gridLines: some View {
        VStack(spacing: .zero) {
            ForEach(axisLabelValues.indices, id: \.self) { index in
                Divider().opacity(DS.Temperature.gridOpacity)
                if index != axisLabelValues.indices.last {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DS.Temperature.gridHorizontalPadding)
    }

    private var yAxisLabels: some View {
        VStack(alignment: .leading, spacing: .zero) {
            ForEach(axisLabelValues.indices, id: \.self) { index in
                Text(loc.t(MetricsKey.temperatureAxisValue, Int(axisLabelValues[index])))
                    .font(DS.Temperature.axisFont)
                    .foregroundStyle(.tertiary)
                if index != axisLabelValues.indices.last {
                    Spacer()
                }
            }
        }
        .padding(.leading, DS.Temperature.axisLeadingPadding)
        .padding(.vertical, DS.Temperature.axisVerticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Legend and tooltip

    private var legend: some View {
        VStack(alignment: .leading, spacing: DS.Temperature.legendRowSpacing) {
            legendRow(color: .orange, label: loc.t(MetricsKey.temperatureLegendCPU))
            legendRow(color: .purple, label: loc.t(MetricsKey.temperatureLegendGPU))
        }
        .padding(DS.Temperature.legendPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerSM))
        .padding(DS.Temperature.legendPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func legendRow(color: Color, label: String) -> some View {
        HStack(spacing: DS.Temperature.legendItemSpacing) {
            RoundedRectangle(cornerRadius: DS.Temperature.legendSwatchRadius)
                .fill(color)
                .frame(width: DS.Temperature.legendSwatchWidth, height: DS.Temperature.legendSwatchHeight)
            Text(label)
                .font(DS.Temperature.legendFont)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var tooltip: some View {
        if let hoverIndex,
           timestamps.indices.contains(hoverIndex),
           cpuHistory.indices.contains(hoverIndex),
           gpuHistory.indices.contains(hoverIndex) {
            ChartTooltip(
                timestamp: timestamps[hoverIndex],
                title: loc.t(MetricsKey.temperatureTooltipTitle),
                details: [
                    loc.t(MetricsKey.temperatureValueCPU, cpuHistory[hoverIndex]),
                    loc.t(MetricsKey.temperatureValueGPU, gpuHistory[hoverIndex])
                ]
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(DS.Temperature.tooltipPadding)
        }
    }

    private func hoverIndex(for phase: HoverPhase, in size: CGSize) -> Int? {
        guard case .active(let location) = phase, !cpuHistory.isEmpty, size.width > 0 else { return nil }
        let fraction = location.x / size.width
        let raw = Int((fraction * CGFloat(cpuHistory.count)).rounded(.down))
        return min(max(raw, cpuHistory.startIndex), cpuHistory.index(before: cpuHistory.endIndex))
    }
}
