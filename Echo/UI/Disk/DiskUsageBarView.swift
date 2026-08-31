//
//  DiskUsageBarView.swift
//  MonitorBarApp
//

import SwiftUI

struct DiskUsageBarView: View {
    let used: Int64
    let total: Int64

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DS.cornerMD)
                    .fill(DS.ringTrack)
                RoundedRectangle(cornerRadius: DS.cornerMD)
                    .fill(barColor.gradient)
                    .frame(width: geometry.size.width * fraction)
                HStack {
                    Spacer()
                    Text(String(format: "%.1f%% used", fraction * 100))
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.cornerMD))
    }

    private var barColor: Color {
        if fraction < 0.7 { return .blue }
        if fraction < 0.9 { return .yellow }
        return .red
    }
}
