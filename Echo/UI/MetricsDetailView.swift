//
//  MetricsDetailView.swift
//  MonitorBarApp
//
//  Детальное окно метрики — направление B (LiquidGlass / фирменный).
//  Открывается как отдельное NSWindow из MenuBarController.
//

import SwiftUI

struct MetricsDetailView: View {
    @ObservedObject var state: DetailState
    @ObservedObject var metrics: MetricsService

    @State private var searchText: String = ""

    /// Поиск процессов нужен только там, где есть список процессов.
    private var showsSearch: Bool {
        state.tab == .cpu || state.tab == .memory
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.top, 20)
                .padding(.bottom, 10)

            chartView
                .frame(height: state.tab == .disk ? 54 : 200)
                .padding(.horizontal, DS.gutter)
                .padding(.vertical, 8)

            if showsSearch {
                searchBar
                    .padding(.horizontal, DS.gutter)
                    .padding(.vertical, 8)
            }

            contentView
                .padding(.horizontal, DS.gutter)
                .padding(.bottom, DS.gutter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: state.tab) { searchText = "" }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        Group {
            HStack(spacing: 4) {
                ForEach(MetricTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { state.tab = tab }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(state.tab == tab ? DS.accent : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background {
                            if state.tab == tab {
                                Color.clear
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerSM))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            TextField("Search process", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerSM))
    }

    // MARK: - Routing

    @ViewBuilder
    private var chartView: some View {
        switch state.tab {
        case .cpu:     CPUChartView(history: metrics.cpuHistory)
        case .memory:  MemoryChartView(history: metrics.ramHistory)
        case .network: NetworkChartView(history: metrics.networkHistory)
        case .disk:    DiskUsageBarView(used: metrics.metrics.disk.used, total: metrics.metrics.disk.total)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch state.tab {
        case .cpu:     CPUProcessListView(searchText: searchText)
        case .memory:  MemoryProcessListView(searchText: searchText)
        case .network: NetworkStatsView(current: metrics.metrics.network, history: metrics.networkHistory)
        case .disk:    DiskDetailView(diskUsed: metrics.metrics.disk.used, diskTotal: metrics.metrics.disk.total)
        }
    }
}
