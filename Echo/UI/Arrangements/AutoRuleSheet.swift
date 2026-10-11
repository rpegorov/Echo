//
//  AutoRuleSheet.swift
//  Echo
//

import SwiftUI

/// "New Rule": an app, a connected display and one zone of that display's active grid.
struct AutoRuleSheet: View {
    let apps: [RuleApplication]
    let displays: [ConnectedDisplay]
    let zonesFor: (ConnectedDisplay) -> [UnitRect]
    let hasRule: (String) -> Bool
    /// Saves the rule; returns the message to show when it could not be saved, nil on success.
    let onSave: (AutoRule) -> String?

    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    @State private var pickedApps: [RuleApplication]
    @State private var appID: String?
    @State private var displayID: String?
    @State private var zoneIndex: Int?
    @State private var failure: String?

    private typealias Tokens = DS.Arrangements

    init(
        apps: [RuleApplication],
        displays: [ConnectedDisplay],
        zonesFor: @escaping (ConnectedDisplay) -> [UnitRect],
        hasRule: @escaping (String) -> Bool,
        onSave: @escaping (AutoRule) -> String?
    ) {
        self.apps = apps
        self.displays = displays
        self.zonesFor = zonesFor
        self.hasRule = hasRule
        self.onSave = onSave
        _pickedApps = State(initialValue: [])
        _appID = State(initialValue: apps.first?.bundleID)
        _displayID = State(initialValue: displays.first?.id)
    }

    private var allApps: [RuleApplication] {
        apps + pickedApps.filter { picked in !apps.contains { $0.bundleID == picked.bundleID } }
    }

    private var selectedApp: RuleApplication? { allApps.first { $0.bundleID == appID } }
    private var selectedDisplay: ConnectedDisplay? { displays.first { $0.id == displayID } }
    private var zones: [UnitRect] { selectedDisplay.map(zonesFor) ?? [] }
    private var canSave: Bool { selectedApp != nil && selectedDisplay != nil && zoneIndex != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.sheetSpacing) {
            Text(loc.t(InputKey.autoRuleSheetTitle)).font(Tokens.titleFont)
            field(InputKey.autoRuleAppLabel) { appRow }
            field(InputKey.autoRuleDisplayLabel) { displayPicker }
            field(InputKey.autoRuleZoneLabel) { zonePicker }
            if let selectedApp, hasRule(selectedApp.bundleID) {
                ArrangementMessageLine(text: loc.t(InputKey.autoRuleReplaceNotice, selectedApp.name))
            }
            if let failure { ArrangementMessageLine(text: failure) }
            buttons
        }
        .padding(Tokens.sheetPadding)
        .frame(width: Tokens.sheetWidth)
    }

    private func field<Content: View>(_ label: InputKey, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: Tokens.rowSpacing) {
            Text(loc.t(label))
                .font(Tokens.rowFont)
                .frame(width: Tokens.sheetLabelWidth, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }

    // MARK: - Fields

    private var appRow: some View {
        HStack(spacing: Tokens.rowSpacing) {
            Picker(loc.t(InputKey.autoRuleAppLabel), selection: $appID) {
                ForEach(allApps) { app in
                    Text(app.name).tag(Optional(app.bundleID))
                }
            }
            .labelsHidden()
            Button(loc.t(InputKey.autoRuleOtherApp), action: chooseOther)
        }
    }

    private var displayPicker: some View {
        Picker(loc.t(InputKey.autoRuleDisplayLabel), selection: $displayID) {
            ForEach(displays) { display in
                Text(display.name).tag(Optional(display.id))
            }
        }
        .labelsHidden()
        .onChange(of: displayID) { _, _ in zoneIndex = nil }
    }

    @ViewBuilder
    private var zonePicker: some View {
        if let selectedDisplay {
            VStack(alignment: .leading, spacing: Tokens.rowSpacing) {
                ZonePickerView(zones: zones, visibleSize: selectedDisplay.visibleSize, selection: $zoneIndex)
                if let zoneIndex {
                    Text(loc.t(InputKey.gridZoneNumber, Int64(zoneIndex + 1)))
                        .font(Tokens.detailFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: Tokens.sheetButtonSpacing) {
            Spacer(minLength: 0)
            Button(loc.t(CommonKey.cancel)) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(loc.t(InputKey.gridEditorSave), action: save)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
        }
    }

    // MARK: - Actions

    private func chooseOther() {
        guard let app = RuleApplication.choose() else { return }
        if !allApps.contains(where: { $0.bundleID == app.bundleID }) { pickedApps.append(app) }
        appID = app.bundleID
    }

    private func save() {
        guard let app = selectedApp, let display = selectedDisplay, let zoneIndex, zones.indices.contains(zoneIndex) else {
            return
        }
        let rule = AutoRule(
            id: UUID(),
            bundleID: app.bundleID,
            appName: app.name,
            slot: ZoneSlot(display: display.id, rect: zones[zoneIndex]),
            display: SavedDisplay(name: display.name, aspect: display.aspect),
            isEnabled: true
        )
        failure = onSave(rule)
        if failure == nil { dismiss() }
    }
}

/// A display miniature whose zones are buttons; the chosen zone stays highlighted.
private struct ZonePickerView: View {
    let zones: [UnitRect]
    let visibleSize: CGSize
    @Binding var selection: Int?

    private typealias Tokens = DS.Arrangements

    var body: some View {
        let size = ArrangementPresentation.fittedSize(
            visible: visibleSize,
            in: Tokens.pickerBounds,
            fallback: DS.ZoneMap.fallbackDisplaySize
        )
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Tokens.pickerScreenCorner)
                .fill(Tokens.pickerScreenFill)
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.pickerScreenCorner)
                        .strokeBorder(Tokens.pickerScreenStroke, lineWidth: Tokens.pickerStrokeWidth)
                }
            ForEach(zones.indices, id: \.self) { index in
                let rect = zones[index].drawRect(in: size, gap: Tokens.pickerZoneGap)
                ZoneButton(number: index + 1, isSelected: selection == index) { selection = index }
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct ZoneButton: View {
    let number: Int
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var loc: Localizer
    @State private var isHovering = false

    private typealias Tokens = DS.Arrangements

    var body: some View {
        Button(action: action) {
            Text(number, format: .number)
                .font(Tokens.pickerZoneFont)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(DS.ZoneMap.zoneMinimumTextScale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(fill, in: RoundedRectangle(cornerRadius: Tokens.pickerZoneCorner))
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.pickerZoneCorner)
                        .strokeBorder(
                            isSelected ? Tokens.pickerZoneStrokeSelected : Tokens.pickerZoneStroke,
                            lineWidth: isSelected ? Tokens.pickerSelectedStrokeWidth : Tokens.pickerStrokeWidth
                        )
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(loc.t(InputKey.gridZoneNumber, Int64(number)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fill: Color {
        if isSelected { return Tokens.pickerZoneFillSelected }
        return isHovering ? Tokens.pickerZoneFillHover : Tokens.pickerZoneFill
    }
}
