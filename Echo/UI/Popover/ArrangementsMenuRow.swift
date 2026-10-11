//
//  ArrangementsMenuRow.swift
//  Echo
//

import SwiftUI

/// Popover row: a menu of saved arrangements; choosing one applies it and the row reports what was placed.
struct ArrangementsMenuRow: View {
    @ObservedObject var store: GridStore
    @ObservedObject var settings: AppSettings
    /// Applies the arrangement and returns the honest outcome.
    let onApply: (UUID) -> ArrangementApplyReport
    @EnvironmentObject private var loc: Localizer

    @State private var outcome: ArrangementApplyOutcome?
    @State private var isHovering = false

    private enum Metrics {
        static let titleSize: CGFloat = 12
        static let countSize: CGFloat = 11
        static let chevronSize: CGFloat = 9
        static let verticalPadding: CGFloat = 5
        static let reportSpacing: CGFloat = 2
        static let hoverInset: CGFloat = 8
        static let reportDuration: Duration = .seconds(10)
    }

    private var items: [ArrangementsMenuItem] {
        ArrangementsMenuModel.items(arrangements: store.document.savedArrangements, shortcuts: settings.arrangementShortcuts)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.reportSpacing) {
            menu
            if let outcome { ArrangementApplyReportView(report: outcome.report) }
        }
        .task(id: outcome?.id) {
            guard outcome != nil else { return }
            do {
                try await Task.sleep(for: Metrics.reportDuration)
            } catch {
                return // cancelled: the row went away or a newer report replaced this one
            }
            outcome = nil
        }
    }

    // MARK: - Menu

    private var menu: some View {
        Menu {
            if items.isEmpty {
                Button(loc.t(InputKey.arrangementsMenuEmpty)) {}
                    .disabled(true)
            } else {
                ForEach(items) { item in
                    Button(title(for: item)) { apply(item) }
                }
            }
        } label: {
            HStack {
                Text(loc.t(InputKey.arrangementsMenuTitle))
                    .font(.system(size: Metrics.titleSize))
                    .foregroundStyle(.secondary)
                Spacer()
                if !items.isEmpty {
                    Text(items.count.formatted())
                        .font(.system(size: Metrics.countSize, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: Metrics.chevronSize, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.gutter)
            .padding(.vertical, Metrics.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: DS.cornerSM)
                    .fill(isHovering ? DS.pressHighlight : .clear)
                    .padding(.horizontal, Metrics.hoverInset)
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    /// Name and key glyphs are data, joined by a wide space so the glyphs read as a trailing hint.
    private func title(for item: ArrangementsMenuItem) -> String {
        guard let shortcut = item.shortcut else { return item.name }
        return item.name + "\u{2003}" + shortcut.displayString(spaceName: loc.t(InputKey.keySpace))
    }

    private func apply(_ item: ArrangementsMenuItem) {
        outcome = ArrangementApplyOutcome(report: onApply(item.id))
    }
}

/// The lines under the row after an apply: what was placed and what was skipped, and why.
struct ArrangementApplyReportView: View {
    let report: ArrangementApplyReport
    @EnvironmentObject private var loc: Localizer

    private enum Metrics {
        static let textSize: CGFloat = 10
        static let spacing: CGFloat = 2
        static let bottomPadding: CGFloat = 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            ForEach(ArrangementsMenuModel.reportLines(report, using: loc), id: \.self) { line in
                Text(line)
                    .font(.system(size: Metrics.textSize))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, DS.gutter)
        .padding(.bottom, Metrics.bottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .transition(.opacity)
    }
}
