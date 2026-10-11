//
//  ArrangementsPrefsView.swift
//  Echo
//

import SwiftUI

/// "Arrangements" section of Preferences: saved arrangements with their hotkeys, and the auto-placement rules.
struct ArrangementsPrefsView: View {
    @ObservedObject var store: GridStore
    @ObservedObject var settings: AppSettings
    let arrangements: any ArrangementManaging
    let hasAXPermission: Bool
    let onOpenEditor: (UUID) -> Void

    @EnvironmentObject private var loc: Localizer

    @State private var lastReport: AppliedReport?
    @State private var deletionCandidate: Arrangement?
    @State private var failure: String?
    @State private var isNamingCapture = false

    private typealias Tokens = DS.Arrangements

    private struct AppliedReport {
        let id: UUID
        let report: ArrangementApplyReport
    }

    private var messages: ArrangementMessages { ArrangementMessages(loc: loc) }
    private var saved: [Arrangement] { store.document.savedArrangements }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.cardSpacing) {
            PrefTitle(loc.t(InputKey.arrangementsTitle))
            if let notice = store.loadNotice { ArrangementMessageLine(text: messages.text(for: notice)) }
            if !hasAXPermission { ArrangementMessageLine(text: loc.t(InputKey.arrangementPermissionMessage)) }
            if let failure { ArrangementMessageLine(text: failure) }
            arrangementsCard
            AutoRulesSection(store: store, settings: settings)
        }
        .sheet(isPresented: $isNamingCapture) {
            ArrangementNameSheet(defaultName: defaultName, onSave: capture)
        }
        .confirmationDialog(
            loc.t(InputKey.gridDeleteConfirmTitle, deletionCandidate?.name ?? ""),
            isPresented: Binding(
                get: { deletionCandidate != nil },
                set: { if !$0 { deletionCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(loc.t(InputKey.gridDeleteAction), role: .destructive, action: deleteCandidate)
        } message: {
            Text(loc.t(InputKey.arrangementDeleteConfirmMessage))
        }
    }

    // MARK: - List

    private var arrangementsCard: some View {
        PrefCard {
            VStack(alignment: .leading, spacing: Tokens.groupSpacing) {
                HStack(alignment: .top, spacing: Tokens.rowSpacing) {
                    PrefCaption(loc.t(InputKey.arrangementsCaption))
                    Spacer(minLength: 0)
                    Button(loc.t(InputKey.arrangementCaptureButton)) { isNamingCapture = true }
                        .disabled(store.isReadOnly || !hasAXPermission)
                }
                if saved.isEmpty {
                    PrefCaption(loc.t(InputKey.arrangementsEmpty))
                } else {
                    list
                }
            }
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(saved) { arrangement in
                ArrangementRowView(
                    arrangement: arrangement,
                    settings: settings,
                    report: lastReport?.id == arrangement.id ? lastReport?.report : nil,
                    isReadOnly: store.isReadOnly,
                    hasAXPermission: hasAXPermission,
                    onApply: { apply(arrangement) },
                    onEdit: { onOpenEditor(arrangement.id) },
                    onRename: { rename(arrangement, to: $0) },
                    onDelete: { deletionCandidate = arrangement }
                )
                if arrangement.id != saved.last?.id { Divider().opacity(Tokens.dividerOpacity) }
            }
        }
    }

    // MARK: - Actions

    private var defaultName: String {
        let number = ArrangementPresentation.defaultNameNumber(
            existingNames: saved.map(\.name),
            count: saved.count,
            nameFor: { loc.t(InputKey.arrangementDefaultName, Int64($0)) }
        )
        return loc.t(InputKey.arrangementDefaultName, Int64(number))
    }

    private func apply(_ arrangement: Arrangement) {
        failure = nil
        lastReport = AppliedReport(id: arrangement.id, report: arrangements.apply(arrangement.id))
    }

    private func capture(named name: String) -> String? {
        do {
            _ = try arrangements.captureCurrent(named: name)
            resetFeedback()
            return nil
        } catch {
            return messages.text(for: error)
        }
    }

    private func rename(_ arrangement: Arrangement, to name: String) {
        var renamed = arrangement
        renamed.name = name
        perform { () throws(ArrangementError) in try arrangements.save(renamed) }
    }

    private func deleteCandidate() {
        guard let arrangement = deletionCandidate else { return }
        deletionCandidate = nil
        perform { () throws(ArrangementError) in try arrangements.delete(arrangement.id) }
    }

    /// Runs one service change; a thrown error becomes the section's failure line.
    private func perform(_ change: () throws(ArrangementError) -> Void) {
        resetFeedback()
        do {
            try change()
        } catch {
            failure = messages.text(for: error)
        }
    }

    private func resetFeedback() {
        failure = nil
        lastReport = nil
    }
}
