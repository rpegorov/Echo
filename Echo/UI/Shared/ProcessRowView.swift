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
            .help("Terminate process")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.cornerSM))
        .confirmationDialog("Terminate \(name)?", isPresented: $showingKillConfirmation, titleVisibility: .visible) {
            Button("Terminate", role: .destructive, action: onKill)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The process will receive SIGTERM and may close unsaved work.")
        }
    }
}
