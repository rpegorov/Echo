//
//  BatteryChartView.swift
//  Echo
//

import SwiftUI
import Charts

/// 24h battery-level chart: one line/area series per gap-separated segment
/// (so a stretch where Echo wasn't running reads as a gap, not a straight
/// line), charging intervals as bands along the bottom, and a rule mark at
/// the current selection. Selecting is a drag/click on the plot area.
struct BatteryChartView: View {
    let history: BatteryHistory
    @Binding var selection: Date?
    @Environment(\.locale) private var locale

    private let windowLength: TimeInterval = 24 * 3600

    private var now: Date { Date() }
    private var windowStart: Date { now.addingTimeInterval(-windowLength) }
    private var segments: [[BatteryReading]] { BatteryTimeline.segments(history.readings) }
    private var chargingIntervals: [ClosedRange<Date>] { BatteryTimeline.chargingIntervals(history.readings) }

    var body: some View {
        Chart {
            levelMarks
            chargingBandMarks
            selectionMark
        }
        .chartXScale(domain: windowStart...now)
        .chartYScale(domain: 0...100)
        .chartXAxis { xAxis }
        .chartYAxis { yAxis }
        .chartXSelection(value: $selection)
        .frame(maxHeight: .infinity)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
    }

    // MARK: - Marks

    @ChartContentBuilder
    private var levelMarks: some ChartContent {
        ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
            ForEach(segment, id: \.date) { reading in
                LineMark(
                    x: .value("Time", reading.date),
                    y: .value("Level", reading.level),
                    series: .value("Segment", index)
                )
                .foregroundStyle(DS.accent)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineJoin: .round))

                AreaMark(
                    x: .value("Time", reading.date),
                    y: .value("Level", reading.level),
                    series: .value("Segment", index)
                )
                .foregroundStyle(LinearGradient(colors: [DS.accent.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            }
        }
    }

    @ChartContentBuilder
    private var chargingBandMarks: some ChartContent {
        ForEach(Array(chargingIntervals.enumerated()), id: \.offset) { _, interval in
            RectangleMark(
                xStart: .value("Start", interval.lowerBound),
                xEnd: .value("End", interval.upperBound),
                yStart: .value("Bottom", 0),
                yEnd: .value("Band top", 4)
            )
            .foregroundStyle(Color.green.opacity(0.55))
        }
    }

    @ChartContentBuilder
    private var selectionMark: some ChartContent {
        if let selection {
            RuleMark(x: .value("Selected", selection))
                .foregroundStyle(.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }

    // MARK: - Axes

    private var xAxis: some AxisContent {
        AxisMarks(values: .stride(by: .hour, count: 4)) { value in
            AxisGridLine()
            AxisTick()
            if let date = value.as(Date.self) {
                AxisValueLabel(date.formatted(.dateTime.hour().locale(locale)))
            }
        }
    }

    private var yAxis: some AxisContent {
        AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
            AxisGridLine()
            if let level = value.as(Int.self) {
                AxisValueLabel("\(level)%") // l10n-exempt: numeric axis tick, no localizable text
            }
        }
    }
}
