//
//  CPUProcessListView.swift
//  MonitorBarApp
//

import SwiftUI

struct CPUProcessListView: View {
    let searchText: String
    @State private var topProcesses: [MonitoredProcess] = []
    @State private var monitor = ProcessMonitor()

    private var filtered: [MonitoredProcess] {
        searchText.isEmpty ? topProcesses : topProcesses.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if filtered.isEmpty {
                Text(searchText.isEmpty ? "Loading..." : "No matching processes")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, process in
                            ProcessRowView(rank: index + 1, name: process.name, value: process.value, showCPU: true) {
                                Task { _ = await monitor.terminate(pid: process.pid) }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .task {
            while !Task.isCancelled {
                topProcesses = await monitor.topByCPU(limit: 20)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
