//
//  ZoneMapView.swift
//  Echo
//

import AppKit
import SwiftUI

/// A display as the zone map needs it: a name for the picker and the area windows can occupy.
struct ZoneMapDisplay: Identifiable, Equatable {
    let id: Int
    let name: String
    let visible: CGRect

    static let fallback = ZoneMapDisplay(
        id: 0,
        name: "",
        visible: CGRect(origin: .zero, size: DS.ZoneMap.fallbackDisplaySize)
    )

    /// Connected displays in system order; the first one carries the menu bar.
    @MainActor
    static func connected() -> [ZoneMapDisplay] {
        NSScreen.screens.enumerated().map {
            ZoneMapDisplay(id: $0.offset, name: $0.element.localizedName, visible: $0.element.visibleFrame)
        }
    }

    @MainActor
    static var primary: ZoneMapDisplay { connected().first ?? fallback }

    /// The largest size with this display's proportions that fits `bounds`.
    func size(fitting bounds: CGSize) -> CGSize {
        let source = visible.width > 0 && visible.height > 0 ? visible.size : DS.ZoneMap.fallbackDisplaySize
        let scale = min(bounds.width / source.width, bounds.height / source.height)
        return CGSize(width: source.width * scale, height: source.height * scale)
    }

    /// A window gap in points of this display, expressed in points of a drawing `mapWidth` wide.
    func scaledGap(_ gap: Double, mapWidth: CGFloat) -> CGFloat {
        let width = visible.width > 0 ? visible.width : DS.ZoneMap.fallbackDisplaySize.width
        return CGFloat(gap) * mapWidth / width
    }
}

extension WindowLayout {
    /// The zone in a top-left-origin drawing `size` wide; the geometry itself comes from `frame(in:gap:)`.
    func drawRect(in size: CGSize, gap: CGFloat) -> CGRect {
        let cocoa = frame(in: CGRect(origin: .zero, size: size), gap: gap)
        // frame(in:gap:) is bottom-left based, SwiftUI draws from the top.
        return CGRect(x: cocoa.minX, y: size.height - cocoa.maxY, width: cocoa.width, height: cocoa.height)
    }
}

/// Map of where each window command puts a window; clicking a zone records that command's shortcut.
struct ZoneMapView: View {
    @ObservedObject var settings: AppSettings
    let displays: [ZoneMapDisplay]
    @EnvironmentObject private var loc: Localizer

    @State private var group: LayoutGroup
    @State private var displayID: Int
    @State private var activeCommand: WMCommand?

    init(settings: AppSettings, displays: [ZoneMapDisplay]) {
        self.settings = settings
        self.displays = displays
        _group = State(initialValue: .halves)
        _displayID = State(initialValue: displays.first?.id ?? ZoneMapDisplay.fallback.id)
    }

    private var display: ZoneMapDisplay {
        displays.first { $0.id == displayID } ?? displays.first ?? .fallback
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.ZoneMap.sectionSpacing) {
            VStack(alignment: .leading, spacing: DS.ZoneMap.zoneTextSpacing) {
                Text(loc.t(InputKey.zoneMapTitle)).font(DS.ZoneMap.titleFont)
                PrefCaption(loc.t(InputKey.zoneMapCaption))
            }
            if displays.count > 1 { displayPicker }
            groupChips
            schematics.frame(maxWidth: .infinity)
            if let activeCommand { activeRow(activeCommand) }
        }
    }

    // MARK: - Controls

    private var displayPicker: some View {
        HStack {
            Text(loc.t(InputKey.zoneMapDisplayLabel)).font(DS.ZoneMap.chipFont)
            Picker(loc.t(InputKey.zoneMapDisplayLabel), selection: $displayID) {
                ForEach(displays) { Text($0.name).tag($0.id) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            Spacer(minLength: 0)
        }
    }

    private var groupChips: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: DS.ZoneMap.chipSpacing),
            count: DS.ZoneMap.chipColumns
        )
        return LazyVGrid(columns: columns, spacing: DS.ZoneMap.chipSpacing) {
            ForEach(LayoutGroup.allCases, id: \.self) { candidate in
                GroupChip(title: loc.t(candidate.titleKey), isSelected: candidate == group) {
                    group = candidate
                }
            }
        }
    }

    @ViewBuilder
    private var schematics: some View {
        if group.hasOverlap {
            HStack(spacing: DS.ZoneMap.mapSpacing) {
                ForEach(group.layouts, id: \.self) { layout in
                    schematic([layout], bounds: DS.ZoneMap.pairMapBounds)
                }
            }
        } else {
            schematic(group.layouts, bounds: DS.ZoneMap.singleMapBounds)
        }
    }

    private func schematic(_ layouts: [WindowLayout], bounds: CGSize) -> some View {
        ZoneSchematic(settings: settings, display: display, layouts: layouts, bounds: bounds) { command in
            activeCommand = command
            settings.setRecordingCommand(command)
        }
    }

    private func activeRow(_ command: WMCommand) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(loc.t(command.titleKey)).font(DS.ZoneMap.titleFont)
            Spacer()
            ShortcutRecorderView(command: command, settings: settings).id(command)
        }
    }
}

// MARK: - Schematic

/// One screen drawing with a clickable cell per layout.
private struct ZoneSchematic: View {
    @ObservedObject var settings: AppSettings
    let display: ZoneMapDisplay
    let layouts: [WindowLayout]
    let bounds: CGSize
    let onSelect: (WMCommand) -> Void

    var body: some View {
        let size = display.size(fitting: bounds)
        let gap = display.scaledGap(settings.windowGap, mapWidth: size.width)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: DS.ZoneMap.screenCorner)
                .fill(DS.ZoneMap.screenFill)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.ZoneMap.screenCorner)
                        .strokeBorder(DS.ZoneMap.screenStroke, lineWidth: DS.ZoneMap.hairline)
                }
            ForEach(layouts, id: \.self) { layout in
                let rect = layout.drawRect(in: size, gap: gap)
                ZoneCell(layout: layout, settings: settings) { onSelect(layout.command) }
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Zone cell

private struct ZoneCell: View {
    let layout: WindowLayout
    @ObservedObject var settings: AppSettings
    let action: () -> Void
    @EnvironmentObject private var loc: Localizer

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    private var isRecording: Bool { settings.recordingCommand == layout.command }

    private var title: String { loc.t(layout.command.titleKey) }

    private var shortcutText: String {
        if isRecording { return loc.t(InputKey.shortcutRecording) }
        guard let shortcut = settings.shortcut(for: layout.command) else { return loc.t(CommonKey.none) }
        return shortcut.displayString(spaceName: loc.t(InputKey.keySpace))
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.ZoneMap.zoneTextSpacing) {
                Text(title)
                    .font(DS.ZoneMap.zoneTitleFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(DS.ZoneMap.zoneTitleLines)
                    .multilineTextAlignment(.center)
                Text(shortcutText)
                    .font(DS.ZoneMap.zoneShortcutFont)
                    .foregroundStyle(isRecording ? DS.accent : .primary)
                    .lineLimit(1)
            }
            .minimumScaleFactor(DS.ZoneMap.zoneMinimumTextScale)
            .padding(DS.ZoneMap.zoneInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(ZoneCellStyle(isRecording: isRecording, isHovering: isHovering, isFocused: isFocused))
        .focused($isFocused)
        .onHover { isHovering = $0 }
        .help(title)
        .accessibilityLabel(title)
        .accessibilityValue(shortcutText)
    }
}

private struct ZoneCellStyle: ButtonStyle {
    let isRecording: Bool
    let isHovering: Bool
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: DS.ZoneMap.zoneCorner)
        configuration.label
            .background(fill(pressed: configuration.isPressed), in: shape)
            .overlay {
                shape.strokeBorder(
                    isRecording ? DS.ZoneMap.zoneStrokeRecording : DS.ZoneMap.zoneStroke,
                    lineWidth: DS.ZoneMap.hairline
                )
            }
            .overlay {
                shape.strokeBorder(DS.accent, lineWidth: DS.ZoneMap.focusStroke)
                    .opacity(isFocused ? 1 : 0)
            }
            .contentShape(shape)
    }

    private func fill(pressed: Bool) -> Color {
        if pressed { return DS.ZoneMap.zoneFillPressed }
        if isRecording { return DS.ZoneMap.zoneFillRecording }
        return isHovering ? DS.ZoneMap.zoneFillHover : DS.ZoneMap.zoneFill
    }
}

// MARK: - Group chip

private struct GroupChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.ZoneMap.chipCorner)
        Button(action: action) {
            Text(title)
                .font(DS.ZoneMap.chipFont)
                .lineLimit(DS.ZoneMap.chipTitleLines)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.ZoneMap.chipVerticalPadding)
                .padding(.horizontal, DS.ZoneMap.chipHorizontalPadding)
                .background(fill, in: shape)
                .overlay {
                    shape.strokeBorder(DS.ZoneMap.chipStrokeSelected, lineWidth: DS.ZoneMap.hairline)
                        .opacity(isSelected ? 1 : 0)
                }
                .overlay {
                    shape.strokeBorder(DS.accent, lineWidth: DS.ZoneMap.focusStroke)
                        .opacity(isFocused ? 1 : 0)
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fill: Color {
        if isSelected { return DS.ZoneMap.chipFillSelected }
        return isHovering ? DS.ZoneMap.chipFillHover : DS.ZoneMap.chipFill
    }
}
