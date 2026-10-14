//
//  GridsPrefsSection.swift
//  Echo
//

import SwiftUI

/// "Grids" section of Preferences: the active grid per display, the list of saved grids,
/// and the modifier that turns a window drag into grid mode.
struct GridsPrefsSection: View {
    @ObservedObject var store: GridStore
    @ObservedObject var settings: AppSettings
    let onOpenEditor: (GridEditorRequest) -> Void

    @EnvironmentObject private var loc: Localizer

    @State private var displays: [ConnectedDisplay]
    @State private var renamingID: UUID?
    @State private var renameText = ""
    @FocusState private var renameFieldFocused: Bool
    @State private var deletionCandidate: ZoneGrid?
    @State private var saveFailure: GridStorageError?

    init(
        store: GridStore,
        settings: AppSettings,
        onOpenEditor: @escaping (GridEditorRequest) -> Void,
        displays: [ConnectedDisplay] = DisplayIdentity.connectedDisplays()
    ) {
        self.store = store
        self.settings = settings
        self.onOpenEditor = onOpenEditor
        _displays = State(initialValue: displays)
    }

    private var isReadOnly: Bool { store.isReadOnly }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Grids.cardSpacing) {
            PrefTitle(loc.t(InputKey.gridsTitle))
            if let notice = store.loadNotice { noticeLine(notice) }
            if let saveFailure { failureLine(saveFailure) }
            displaysCard
            savedGridsCard
            modifierCard
        }
        .confirmationDialog(
            deletionTitle,
            isPresented: Binding(
                get: { deletionCandidate != nil },
                set: { if !$0 { deletionCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(loc.t(InputKey.gridDeleteAction), role: .destructive, action: deleteCandidate)
        } message: {
            Text(loc.t(InputKey.gridDeleteConfirmMessage))
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displays = DisplayIdentity.connectedDisplays()
        }
    }

    // MARK: - Displays

    private var displaysCard: some View {
        PrefCard {
            VStack(spacing: 0) {
                ForEach(displays) { display in
                    displayRow(display)
                    if display.id != displays.last?.id { Divider().opacity(DS.Grids.dividerOpacity) }
                }
            }
        }
    }

    private func displayRow(_ display: ConnectedDisplay) -> some View {
        HStack(spacing: DS.Grids.rowSpacing) {
            GridThumbnailView(
                zones: store.activeZones(for: display.key, aspect: display.aspect),
                visibleSize: display.visibleSize
            )
            Text(display.name)
                .font(DS.Grids.rowFont)
                .lineLimit(DS.Grids.nameLineLimit)
                .truncationMode(.middle)
                .help(display.name)
            Spacer(minLength: 0)
            activeGridPicker(for: display)
            Button(loc.t(InputKey.gridEditButton)) { openEditor(for: display) }
                .disabled(isReadOnly)
        }
        .padding(.vertical, DS.Grids.rowVerticalPadding)
    }

    private func activeGridPicker(for display: ConnectedDisplay) -> some View {
        Picker(loc.t(InputKey.gridActiveLabel), selection: selectionBinding(for: display)) {
            Section(loc.t(InputKey.gridTemplatesSection)) {
                ForEach(GridTemplate.allCases, id: \.self) { template in
                    Text(loc.t(template.titleKey)).tag(ActiveGridRef.template(kind: template))
                }
            }
            Section(loc.t(InputKey.gridSavedSection)) {
                ForEach(store.document.grids) { grid in
                    Text(grid.name).tag(ActiveGridRef.saved(id: grid.id))
                }
            }
        }
        .labelsHidden()
        .frame(width: DS.Grids.activeGridPickerWidth)
        .disabled(isReadOnly)
    }

    private func selectionBinding(for display: ConnectedDisplay) -> Binding<ActiveGridRef> {
        Binding(
            get: {
                store.document.activeRef(for: display.key)
                    ?? ActiveGridRef.template(kind: GridTemplate.default(forAspect: display.aspect))
            },
            set: { choose($0, for: display) }
        )
    }

    // MARK: - Saved grids

    private var savedGridsCard: some View {
        PrefCard {
            VStack(alignment: .leading, spacing: DS.Grids.groupSpacing) {
                HStack {
                    Text(loc.t(InputKey.gridSavedSection)).font(DS.Grids.titleFont)
                    Spacer(minLength: 0)
                    Button(loc.t(InputKey.gridNewButton), action: newGrid)
                        .disabled(isReadOnly)
                }
                if store.document.grids.isEmpty {
                    PrefCaption(loc.t(InputKey.gridsEmpty))
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.document.grids) { grid in
                            gridRow(grid)
                            if grid.id != store.document.grids.last?.id {
                                Divider().opacity(DS.Grids.dividerOpacity)
                            }
                        }
                    }
                }
            }
        }
    }

    private func gridRow(_ grid: ZoneGrid) -> some View {
        HStack(spacing: DS.Grids.rowSpacing) {
            nameColumn(grid)
            Spacer(minLength: 0)
            Button(loc.t(InputKey.gridEditButton)) { openEditor(for: grid) }
                .disabled(isReadOnly || isRenaming(grid))
            deleteButton(grid)
        }
        .padding(.vertical, DS.Grids.rowVerticalPadding)
        .contextMenu {
            Button(loc.t(InputKey.gridRenameAction)) { startRenaming(grid) }
                .disabled(isReadOnly || isRenaming(grid))
            Divider()
            Button(loc.t(InputKey.gridDeleteAction), role: .destructive) { deletionCandidate = grid }
                .disabled(isReadOnly)
        }
    }

    @ViewBuilder
    private func nameColumn(_ grid: ZoneGrid) -> some View {
        if isRenaming(grid) {
            TextField(loc.t(InputKey.gridRenameAction), text: $renameText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: DS.Grids.renameFieldWidth)
                .focused($renameFieldFocused)
                .onAppear { renameFieldFocused = true }
                .onSubmit { commitRename(of: grid) }
                .onExitCommand(perform: endRenaming)
                .onChange(of: renameFieldFocused) { _, focused in
                    if !focused { endRenaming() }
                }
                .accessibilityLabel(loc.t(InputKey.gridRenameAction))
        } else {
            VStack(alignment: .leading, spacing: DS.Grids.nameCountSpacing) {
                Text(grid.name)
                    .font(DS.Grids.rowFont)
                    .lineLimit(DS.Grids.nameLineLimit)
                    .truncationMode(.middle)
                Text(loc.t(InputKey.gridZoneCount, Int64(grid.zones.count)))
                    .font(DS.Grids.detailFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func deleteButton(_ grid: ZoneGrid) -> some View {
        Button {
            deletionCandidate = grid
        } label: {
            Image(systemName: DS.Grids.deleteIcon)
                .font(DS.Grids.actionIconFont)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(isReadOnly || isRenaming(grid))
        .accessibilityLabel(loc.t(InputKey.gridDeleteAction))
    }

    // MARK: - Drag modifier

    private var modifierCard: some View {
        PrefCard {
            VStack(alignment: .leading, spacing: DS.Grids.groupSpacing) {
                HStack {
                    Text(loc.t(InputKey.gridModifierLabel)).font(DS.Grids.titleFont)
                    Spacer(minLength: 0)
                    Picker(loc.t(InputKey.gridModifierLabel), selection: $settings.gridModifier) {
                        ForEach(GridDragModifier.allCases, id: \.self) { modifier in
                            Text(loc.t(modifier.titleKey)).tag(modifier)
                        }
                    }
                    .labelsHidden()
                    .frame(width: DS.Grids.modifierPickerWidth)
                }
                PrefCaption(loc.t(
                    InputKey.gridsCaption,
                    settings.gridModifier.glyphs,
                    GridDragModifier.spanGlyph
                ))
            }
        }
    }

    // MARK: - Actions

    private func choose(_ ref: ActiveGridRef, for display: ConnectedDisplay) {
        commit { () throws(GridStorageError) in try store.setActive(ref, for: display.key) }
    }

    private func openEditor(for display: ConnectedDisplay) {
        onOpenEditor(GridEditorRequest(
            source: editorSource(for: display),
            display: display.key,
            activatesOnSave: true
        ))
    }

    private func openEditor(for grid: ZoneGrid) {
        onOpenEditor(GridEditorRequest(
            source: .saved(grid.id),
            display: displays.first?.key,
            activatesOnSave: false
        ))
    }

    private func editorSource(for display: ConnectedDisplay) -> GridEditorRequest.Source {
        switch store.document.activeRef(for: display.key) {
        case .template(kind: let kind): return .template(kind)
        case .saved(id: let id):        return .saved(id)
        case nil:                       return .template(GridTemplate.default(forAspect: display.aspect))
        }
    }

    private func newGrid() {
        let aspect = displays.first.map(\.aspect)
            ?? DS.ZoneMap.fallbackDisplaySize.width / DS.ZoneMap.fallbackDisplaySize.height
        onOpenEditor(GridEditorRequest(
            source: .template(GridTemplate.default(forAspect: aspect)),
            display: displays.first?.key,
            activatesOnSave: false
        ))
    }

    private func startRenaming(_ grid: ZoneGrid) {
        renamingID = grid.id
        renameText = grid.name
    }

    private func commitRename(of grid: ZoneGrid) {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        endRenaming()
        guard !name.isEmpty else { return }
        commit { () throws(GridStorageError) in try store.rename(grid.id, to: name) }
    }

    private func endRenaming() {
        renamingID = nil
        renameText = ""
    }

    private func deleteCandidate() {
        guard let grid = deletionCandidate else { return }
        deletionCandidate = nil
        commit { () throws(GridStorageError) in try store.delete(grid.id) }
    }

    /// Runs one store change; a thrown error becomes the section's failure line.
    private func commit(_ change: () throws(GridStorageError) -> Void) {
        do {
            try change()
            saveFailure = nil
        } catch {
            saveFailure = error
        }
    }

    // MARK: - State helpers

    private func isRenaming(_ grid: ZoneGrid) -> Bool {
        renamingID == grid.id
    }

    private var deletionTitle: String {
        loc.t(InputKey.gridDeleteConfirmTitle, deletionCandidate?.name ?? "")
    }
}

extension GridsPrefsSection {
    private func noticeLine(_ notice: GridLoadNotice) -> some View {
        messageLine(text(for: notice))
    }

    private func failureLine(_ error: GridStorageError) -> some View {
        messageLine(loc.t(InputKey.gridSaveFailedMessage, failureDetail(of: error)))
    }

    private func messageLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Grids.rowSpacing) {
            Image(systemName: DS.GridEditor.messageIcon)
                .foregroundStyle(DS.Grids.noticeColor)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Grids.detailFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func text(for notice: GridLoadNotice) -> String {
        switch notice {
        case .loadFailed(let fileName): return loc.t(InputKey.gridLoadFailedMessage, fileName)
        case .newerVersion:             return loc.t(InputKey.gridReadOnlyMessage)
        case .unavailable:              return loc.t(InputKey.gridUnavailableMessage)
        }
    }

    /// Human-readable cause of a failed save, shown after the localized "Couldn't save grids" prefix.
    private func failureDetail(of error: GridStorageError) -> String {
        switch error {
        case .writeFailed(let detail), .readFailed(let detail): return detail
        case .unreadable(let fileName):                         return fileName
        case .invalidGrid:                                      return loc.t(InputKey.gridInvalidMessage)
        case .locationUnavailable, .newerSchema, .readOnly,
             .invalidSlot:                                      return loc.t(InputKey.gridUnavailableMessage)
        }
    }
}
