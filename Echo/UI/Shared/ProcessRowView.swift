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
    let onKill: () -> Void
    @State private var showingKillConfirmation = false
    @EnvironmentObject private var loc: Localizer

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

            Button {
                showingKillConfirmation = true
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help(loc.t(MetricsKey.terminateProcessHelp))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.cornerSM))
        .confirmationDialog(loc.t(CommonKey.terminateProcessTitle, name), isPresented: $showingKillConfirmation, titleVisibility: .visible) {
            Button(loc.t(CommonKey.terminate), role: .destructive, action: onKill)
            Button(loc.t(CommonKey.cancel), role: .cancel) {}
        } message: {
            Text(loc.t(CommonKey.terminateProcessMessage))
        }
    }
}
