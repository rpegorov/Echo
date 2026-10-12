//
//  ArrangementRowView.swift
//  Echo
//

import SwiftUI

/// One saved arrangement: name, app icons, window count, hotkey recorder and its actions.
struct ArrangementRowView: View {
    let arrangement: Arrangement
    @ObservedObject var settings: AppSettings
    /// Outcome of the last apply; shown until the next action.
    let report: ArrangementApplyReport?
    let isReadOnly: Bool
    let hasAXPermission: Bool
    let onApply: () -> Void
    let onEdit: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var loc: Localizer

    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var renameFieldFocused: Bool

    private typealias Tokens = DS.Arrangements

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.rowSpacing) {
            HStack(alignment: .top, spacing: Tokens.rowSpacing) {
                nameColumn
                Spacer(minLength: 0)
                ShortcutRecorderView(owner: .arrangement(arrangement.id), settings: settings)
            }
            actionsRow
            if let report { ApplyReportView(report: report) }
        }
        .padding(.vertical, Tokens.rowVerticalPadding)
        .contextMenu {
            Button(loc.t(InputKey.gridRenameAction), action: startRenaming)
                .disabled(isReadOnly || isRenaming)
            Divider()
            Button(loc.t(InputKey.gridDeleteAction), role: .destructive, action: onDelete)
                .disabled(isReadOnly)
        }
    }

    // MARK: - Name

    @ViewBuilder
    private var nameColumn: some View {
        if isRenaming {
            TextField(loc.t(InputKey.gridRenameAction), text: $renameText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: Tokens.renameFieldWidth)
                .focused($renameFieldFocused)
                .onAppear { renameFieldFocused = true }
                .onSubmit(commitRename)
                .onExitCommand(perform: endRenaming)
                .onChange(of: renameFieldFocused) { _, focused in
                    if !focused { endRenaming() }
                }
                .accessibilityLabel(loc.t(InputKey.gridRenameAction))
        } else {
            VStack(alignment: .leading, spacing: Tokens.textSpacing) {
                Text(arrangement.name)
                    .font(Tokens.rowFont)
                    .lineLimit(Tokens.nameLineLimit)
                    .truncationMode(.middle)
                    .help(arrangement.name)
                HStack(spacing: Tokens.rowSpacing) {
                    IconStrip(windows: arrangement.windows)
                    Text(loc.t(InputKey.arrangementWindowCount, Int64(arrangement.windows.count)))
                        .font(Tokens.detailFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(Tokens.nameLineLimit)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsRow: some View {
        HStack(spacing: Tokens.rowSpacing) {
            Button(loc.t(InputKey.arrangementApplyButton), action: onApply)
                .disabled(!hasAXPermission)
            Button(loc.t(InputKey.gridEditButton), action: onEdit)
                .disabled(isReadOnly || isRenaming)
            Spacer(minLength: 0)
            iconButton(Tokens.renameIcon, label: InputKey.gridRenameAction, action: startRenaming)
            iconButton(Tokens.deleteIcon, label: InputKey.gridDeleteAction, action: onDelete)
        }
    }

    private func iconButton(_ symbol: String, label: InputKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Tokens.actionIconFont)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(isReadOnly || isRenaming)
        .accessibilityLabel(loc.t(label))
        .help(loc.t(label))
    }

    private func startRenaming() {
        renameText = arrangement.name
        isRenaming = true
    }

    private func commitRename() {
        let name = ArrangementPresentation.trimmedName(renameText)
        endRenaming()
        guard let name, name != arrangement.name else { return }
        onRename(name)
    }

    private func endRenaming() {
        isRenaming = false
        renameText = ""
    }
}

/// App icons of an arrangement, capped, with the rest as "+N".
private struct IconStrip: View {
    let windows: [ArrangedWindow]

    private typealias Tokens = DS.Arrangements

    var body: some View {
        let summary = ArrangementPresentation.iconSummary(of: windows, limit: Tokens.maxIcons)
        HStack(spacing: Tokens.iconSpacing) {
            ForEach(summary.bundleIDs, id: \.self) { bundleID in
                AppIconView(bundleID: bundleID, size: Tokens.iconSize)
            }
            if summary.overflow > 0 {
                Text(summary.overflow, format: .number.sign(strategy: .always(includingZero: false)))
                    .font(Tokens.overflowFont)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The lines under an arrangement after "Apply": what was placed and what was skipped, and why.
private struct ApplyReportView: View {
    let report: ArrangementApplyReport

    @EnvironmentObject private var loc: Localizer

    private typealias Tokens = DS.Arrangements

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.reportSpacing) {
            line(loc.t(InputKey.arrangementApplyResult, Int64(report.placed), Int64(report.total)))
            if !report.notRunningApps.isEmpty {
                line(loc.t(InputKey.arrangementNotRunning, appList))
            }
            if report.displayMissing > 0 {
                line(loc.t(InputKey.arrangementDisplayMissingCount, Int64(report.displayMissing)))
            }
            if report.noWindow > 0 {
                line(loc.t(InputKey.arrangementNoWindowCount, Int64(report.noWindow)))
            }
        }
    }

    private var appList: String {
        report.notRunningApps.formatted(.list(type: .and).locale(loc.locale))
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(Tokens.detailFont)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
