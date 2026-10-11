//
//  ShortcutRecorderView.swift
//  MonitorBarApp
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Shortcut field: click to start capturing the next key press.
/// A combination owned by another command or arrangement is never applied silently; the user confirms the reassignment.
struct ShortcutRecorderView: View {
    let owner: ShortcutOwner
    @ObservedObject var settings: AppSettings
    @EnvironmentObject private var loc: Localizer
    /// Names arrangement owners in the conflict notice; injected at the settings window root.
    @EnvironmentObject private var gridStore: GridStore

    @State private var monitor: Any?
    @State private var pending: PendingShortcut?
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    private typealias Recorder = DS.ZoneMap.Recorder

    /// A recorded combination held back because another owner holds it; `ownerName` is what the notice shows.
    private struct PendingShortcut {
        let shortcut: KeyboardShortcut
        let ownerName: String
    }

    init(owner: ShortcutOwner, settings: AppSettings) {
        self.owner = owner
        self.settings = settings
    }

    init(command: WMCommand, settings: AppSettings) {
        self.init(owner: .command(command), settings: settings)
    }

    private var isRecording: Bool { settings.recordingOwner == owner }

    var body: some View {
        VStack(alignment: .trailing, spacing: Recorder.conflictSpacing) {
            HStack(spacing: Recorder.spacing) {
                recordButton
                if settings.shortcut(for: owner) != nil { clearButton }
            }
            if let pending { conflictNotice(pending) }
        }
        .onChange(of: settings.recordingOwner, initial: true) { _, _ in syncMonitor() }
        .onDisappear {
            removeMonitor()
            if isRecording { settings.setRecordingOwner(nil) }
        }
    }

    // MARK: - Subviews

    private var recordButton: some View {
        Button(action: toggleRecording) {
            Text(label)
                .font(Recorder.font)
                .foregroundStyle(isRecording ? DS.accent : .primary)
                .frame(minWidth: Recorder.minWidth)
                .padding(.horizontal, Recorder.horizontalPadding)
                .padding(.vertical, Recorder.verticalPadding)
                .background(fill, in: RoundedRectangle(cornerRadius: DS.cornerSM))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.cornerSM)
                        .strokeBorder(Recorder.strokeRecording, lineWidth: DS.ZoneMap.hairline)
                        .opacity(isRecording ? 1 : 0)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DS.cornerSM)
                        .strokeBorder(DS.accent, lineWidth: DS.ZoneMap.focusStroke)
                        .opacity(isFocused ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovering = $0 }
        .accessibilityLabel(ownerName(owner) ?? label)
        .accessibilityValue(label)
    }

    private var clearButton: some View {
        Button {
            clearPending()
            if isRecording { settings.setRecordingOwner(nil) }
            settings.setShortcut(nil, for: owner)
        } label: {
            Image(systemName: "trash")
                .font(Recorder.clearIconFont)
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(loc.t(InputKey.shortcutClearButton))
    }

    private func conflictNotice(_ pending: PendingShortcut) -> some View {
        VStack(alignment: .trailing, spacing: Recorder.conflictSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: Recorder.conflictIconSpacing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Recorder.conflictIconColor)
                    .accessibilityHidden(true)
                Text(loc.t(
                    InputKey.shortcutConflictMessage,
                    pending.shortcut.displayString(spaceName: loc.t(InputKey.keySpace)),
                    pending.ownerName
                ))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
            }
            .font(Recorder.conflictFont)

            HStack(spacing: Recorder.spacing) {
                Button(loc.t(CommonKey.cancel), action: clearPending)
                    .buttonStyle(.bordered)
                Button(loc.t(InputKey.shortcutReassignButton)) { reassign(pending) }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
            }
            .controlSize(.small)
        }
        .frame(maxWidth: Recorder.conflictMaxWidth, alignment: .trailing)
    }

    // MARK: - State

    private var fill: Color {
        if isRecording { return Recorder.fillRecording }
        return isHovering ? Recorder.fillHover : Recorder.fill
    }

    private var label: String {
        if isRecording { return loc.t(InputKey.shortcutRecording) }
        guard let shortcut = settings.shortcut(for: owner) else { return loc.t(CommonKey.none) }
        return shortcut.displayString(spaceName: loc.t(InputKey.keySpace))
    }

    // MARK: - Actions

    private func toggleRecording() {
        clearPending()
        settings.setRecordingOwner(isRecording ? nil : owner)
    }

    private func clearPending() {
        pending = nil
    }

    private func reassign(_ pending: PendingShortcut) {
        settings.setShortcut(pending.shortcut, for: owner)
        clearPending()
    }

    // MARK: - Capture

    /// The key monitor lives exactly while `settings.recordingOwner` is this owner.
    private func syncMonitor() {
        if isRecording {
            clearPending()
            installMonitor()
        } else {
            removeMonitor()
        }
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Local monitors fire on the main thread.
            MainActor.assumeIsolated {
                capture(event)
            }
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func capture(_ event: NSEvent) {
        // A key event can still be queued after recording ended; it must not reassign anything.
        guard isRecording else { return }
        defer { settings.setRecordingOwner(nil) }
        guard event.keyCode != UInt16(kVK_Escape) else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shortcut = KeyboardShortcut(keyCode: UInt32(event.keyCode), flags: flags)
        if let holder = settings.owner(using: shortcut), holder != owner, let name = ownerName(holder) {
            pending = PendingShortcut(shortcut: shortcut, ownerName: name)
        } else {
            settings.setShortcut(shortcut, for: owner)
        }
    }

    /// nil for an arrangement missing from the document; its shortcut is taken over without asking.
    private func ownerName(_ owner: ShortcutOwner) -> String? {
        switch owner {
        case .command(let command):
            return loc.t(command.titleKey)
        case .arrangement(let id):
            return gridStore.document.savedArrangements.first { $0.id == id }?.name
        }
    }
}
