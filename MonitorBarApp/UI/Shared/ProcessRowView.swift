//
//  ProcessRowView.swift
//  MonitorBarApp
//

import SwiftUI

struct ProcessRowView: View {
    let rank: Int
    let name: String
    let value: Double
    let showCPU: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)

            Text(name)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if showCPU {
                Text(String(format: "%.1f%%", value))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)
            } else {
                Text(String(format: "%.0f MB", value))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.cornerSM))
    }
}
