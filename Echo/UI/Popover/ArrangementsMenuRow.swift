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

    private var items: [ArrangementsMenuItem] {
        ArrangementsMenuModel.items(
            arrangements: store.document.savedArrangements, shortcuts: settings.arrangementShortcuts)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Arrangements.menuReportSpacing) {
            menu
            if let outcome { ArrangementApplyReportView(report: outcome.report) }
        }
        .task(id: outcome?.id) {
            guard outcome != nil else { return }
            do {
                try await Task.sleep(for: DS.Arrangements.menuReportDuration)
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
                    .font(DS.Arrangements.menuRowTitleFont)
                    .foregroundStyle(.secondary)
                Spacer()
                if !items.isEmpty {
                    Text(items.count.formatted())
                        .font(DS.Arrangements.menuRowCountFont)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(DS.Arrangements.menuRowChevronFont)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.gutter)
            .padding(.vertical, DS.Arrangements.menuRowVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: DS.cornerSM)
                    .fill(isHovering ? DS.pressHighlight : .clear)
                    .padding(.horizontal, DS.Arrangements.menuRowHoverInset)
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

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Arrangements.menuReportSpacing) {
            ForEach(ArrangementsMenuModel.reportLines(report, using: loc), id: \.self) { line in
                Text(line)
                    .font(DS.Arrangements.menuReportFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, DS.gutter)
        .padding(.bottom, DS.Arrangements.menuReportBottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .transition(.opacity)
    }
}
