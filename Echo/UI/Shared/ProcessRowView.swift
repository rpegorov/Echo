//
//  ProcessRowView.swift
//  MonitorBarApp
//

import SwiftUI

/// What a process row's value column shows, and how it's formatted.
enum ProcessRowValue {
    case cpuPercent(Double)
    case megabytes(Double)
    case energyShare(Double)
}

struct ProcessRowView: View {
    let rank: Int
    let name: String
    let value: ProcessRowValue
    /// `nil` hides the terminate button — used for read-only rows (e.g. battery's energy list).
    let onKill: (() -> Void)?
    @State private var showingKillConfirmation = false
    @EnvironmentObject private var loc: Localizer

    private var valueText: String {
        switch value {
        case .cpuPercent(let percent):    loc.t(MetricsKey.processValueCPU, percent)
        case .megabytes(let megabytes):   loc.t(MetricsKey.processValueMemory, megabytes)
        case .energyShare(let percent):   loc.t(MetricsKey.processValueEnergyShare, percent)
        }
    }

    private var valueColor: Color {
        switch value {
        case .cpuPercent:   .blue
        case .megabytes:    .green
        case .energyShare:  .orange
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)") // l10n-exempt: numeric interpolation only, no literal text
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)

            Text(name)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(valueText)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(valueColor)

            if let onKill {
                Button {
                    showingKillConfirmation = true
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help(loc.t(MetricsKey.terminateProcessHelp))
                .confirmationDialog(loc.t(CommonKey.terminateProcessTitle, name), isPresented: $showingKillConfirmation, titleVisibility: .visible) {
                    Button(loc.t(CommonKey.terminate), role: .destructive, action: onKill)
                    Button(loc.t(CommonKey.cancel), role: .cancel) {}
                } message: {
                    Text(loc.t(CommonKey.terminateProcessMessage))
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.cornerSM))
    }
}
