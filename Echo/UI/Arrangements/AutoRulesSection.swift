//
//  AutoRulesSection.swift
//  Echo
//

import SwiftUI

/// "Auto Placement" block: the master switch, one row per rule, and the sheet that adds a rule.
struct AutoRulesSection: View {
    @ObservedObject var store: GridStore
    @ObservedObject var settings: AppSettings

    @EnvironmentObject private var loc: Localizer

    @State private var displays: [ConnectedDisplay]
    @State private var sheetApps: [RuleApplication]?
    @State private var failure: String?

    private typealias Tokens = DS.Arrangements

    init(
        store: GridStore,
        settings: AppSettings,
        displays: [ConnectedDisplay] = DisplayIdentity.connectedDisplays()
    ) {
        self.store = store
        self.settings = settings
        _displays = State(initialValue: displays)
    }

    private var rules: [AutoRule] { store.document.rules }
    private var messages: ArrangementMessages { ArrangementMessages(loc: loc) }

    var body: some View {
        PrefCard {
            VStack(alignment: .leading, spacing: Tokens.groupSpacing) {
                header
                PrefCaption(loc.t(InputKey.autoRulesCaption))
                if let failure { ArrangementMessageLine(text: failure) }
                if rules.isEmpty {
                    PrefCaption(loc.t(InputKey.autoRulesEmpty))
                } else {
                    ruleList
                }
            }
        }
        .sheet(isPresented: Binding(get: { sheetApps != nil }, set: { if !$0 { sheetApps = nil } })) {
            AutoRuleSheet(
                apps: sheetApps ?? [],
                displays: displays,
                zonesFor: { store.activeZones(for: $0.key, aspect: $0.aspect) },
                hasRule: { store.document.rule(forBundleID: $0) != nil },
                onSave: save
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displays = DisplayIdentity.connectedDisplays()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.groupSpacing) {
            Text(loc.t(InputKey.autoRulesTitle)).font(Tokens.titleFont)
            HStack(spacing: Tokens.rowSpacing) {
                Toggle(loc.t(InputKey.autoRulesToggle), isOn: $settings.autoRulesEnabled)
                    .toggleStyle(.switch)
                Spacer(minLength: 0)
                Button(loc.t(InputKey.autoRuleAddButton)) { sheetApps = RuleApplication.running() }
                    .disabled(store.isReadOnly)
            }
        }
    }

    // MARK: - Rules

    private var ruleList: some View {
        VStack(spacing: 0) {
            ForEach(rules) { rule in
                ruleRow(rule)
                if rule.id != rules.last?.id { Divider().opacity(Tokens.dividerOpacity) }
            }
        }
    }

    private func ruleRow(_ rule: AutoRule) -> some View {
        HStack(spacing: Tokens.rowSpacing) {
            Toggle(rule.appName, isOn: enabledBinding(for: rule))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(store.isReadOnly)
                .accessibilityLabel(rule.appName)
            AppIconView(bundleID: rule.bundleID, size: Tokens.ruleIconSize)
            Text(summary(of: rule))
                .font(Tokens.rowFont)
                .lineLimit(Tokens.summaryLineLimit)
                .truncationMode(.tail)
                .help(summary(of: rule))
            Spacer(minLength: 0)
            Button { delete(rule) } label: {
                Image(systemName: Tokens.deleteIcon)
                    .font(Tokens.actionIconFont)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(store.isReadOnly)
            .accessibilityLabel(loc.t(InputKey.gridDeleteAction))
            .help(loc.t(InputKey.gridDeleteAction))
        }
        .padding(.vertical, Tokens.rowVerticalPadding)
    }

    private func summary(of rule: AutoRule) -> String {
        let zones = store.document.activeZones(
            for: DisplayKey(rawValue: rule.slot.display),
            aspect: rule.display.aspect
        )
        let area: String
        switch ArrangementPresentation.label(for: rule.slot, zones: zones) {
        case .zone(let number): area = loc.t(InputKey.gridZoneNumber, Int64(number))
        case .customArea:       area = loc.t(InputKey.arrangementCustomArea)
        }
        return loc.t(InputKey.autoRuleSummary, rule.appName, area, rule.display.name)
    }

    // MARK: - Actions

    private func enabledBinding(for rule: AutoRule) -> Binding<Bool> {
        Binding(
            get: { store.document.rules.first { $0.id == rule.id }?.isEnabled ?? rule.isEnabled },
            set: { isEnabled in
                perform { () throws(GridStorageError) in try store.setRuleEnabled(rule.id, isEnabled) }
            }
        )
    }

    private func delete(_ rule: AutoRule) {
        perform { () throws(GridStorageError) in try store.deleteRule(rule.id) }
    }

    private func save(_ rule: AutoRule) -> String? {
        do {
            try store.saveRule(rule)
            failure = nil
            return nil
        } catch {
            return messages.text(for: error)
        }
    }

    /// Runs one store change; a thrown error becomes the block's failure line.
    private func perform(_ change: () throws(GridStorageError) -> Void) {
        do {
            try change()
            failure = nil
        } catch {
            failure = messages.text(for: error)
        }
    }
}
