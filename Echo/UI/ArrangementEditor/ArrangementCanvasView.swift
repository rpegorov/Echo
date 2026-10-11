//
//  ArrangementCanvasView.swift
//  Echo
//

import SwiftUI

/// One display of the arrangement: the zones of its grid with the apps' icons in their slots.
struct ArrangementCanvasView: View {
    @ObservedObject var model: ArrangementEditorModel
    let display: ArrangementEditorDisplay
    /// The window gap setting, in points of the display.
    let windowGap: Double
    let targets: [ArrangementEditorDisplay]
    let space: NamedCoordinateSpace

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let gap = GridCanvasLayout.scaledGap(
                windowGap, canvasWidth: size.width, displayWidth: display.referenceWidth)
            let frames = GridCanvasLayout.frames(for: display.zones, in: size, gap: gap)
            ZStack(alignment: .topLeading) {
                ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                    zoneView(index: index, size: frame.size)
                        .offset(x: frame.minX, y: frame.minY)
                }
                ArrangementSlotsLayer(
                    model: model,
                    display: display,
                    windows: model.draft.windows.filter { $0.slot.display == display.key },
                    draggedID: model.drag?.windowID,
                    targets: targets,
                    canvasSize: size,
                    scaledGap: gap,
                    space: space
                )
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .background {
            RoundedRectangle(cornerRadius: DS.ArrangementEditor.canvasCorner)
                .fill(DS.ArrangementEditor.canvasFill)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.ArrangementEditor.canvasCorner)
                        .strokeBorder(DS.ArrangementEditor.canvasStroke, lineWidth: DS.ArrangementEditor.hairline)
                }
        }
        .opacity(display.isConnected ? 1 : DS.ArrangementEditor.disconnectedOpacity)
        .onGeometryChange(for: CGRect.self) { [space] in $0.frame(in: space) } action: { frame in
            model.canvasFrames[display.key] = frame
        }
        .accessibilityElement(children: .contain)
    }

    private func zoneView(index: Int, size: CGSize) -> some View {
        let isDropTarget = model.drag?.target == ArrangementEditorModel.DropTarget(display: display.key, zone: index)
        return RoundedRectangle(cornerRadius: DS.ArrangementEditor.zoneCorner)
            .fill(isDropTarget ? DS.ArrangementEditor.zoneDropFill : DS.ArrangementEditor.zoneFill)
            .overlay {
                RoundedRectangle(cornerRadius: DS.ArrangementEditor.zoneCorner)
                    .strokeBorder(DS.ArrangementEditor.zoneStroke, lineWidth: DS.ArrangementEditor.zoneStrokeWidth)
            }
            .overlay(alignment: .topLeading) {
                Text(index + 1, format: .number)
                    .font(DS.ArrangementEditor.zoneNumberFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(DS.ArrangementEditor.zoneLabelInset)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: DS.ArrangementEditor.zoneCorner))
            .accessibilityHidden(true)
    }
}

/// The icons of the apps by slot. Its inputs are plain values, so it is redrawn when the entries change,
/// not on every pointer move of a drag.
private struct ArrangementSlotsLayer: View {
    let model: ArrangementEditorModel
    let display: ArrangementEditorDisplay
    let windows: [ArrangedWindow]
    let draggedID: UUID?
    let targets: [ArrangementEditorDisplay]
    let canvasSize: CGSize
    let scaledGap: CGFloat
    let space: NamedCoordinateSpace

    @EnvironmentObject private var loc: Localizer

    var body: some View {
        let groups = ArrangementEditorLayout.groups(of: windows, on: display.key, zones: display.zones)
        let frames = GridCanvasLayout.frames(for: groups.map(\.rect), in: canvasSize, gap: scaledGap)
        ZStack(alignment: .topLeading) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                slotView(group: group, frame: frames[index])
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }

    private func slotView(group: ArrangementSlotGroup, frame: CGRect) -> some View {
        let isCustom = group.zoneIndex == nil
        let inset = min(
            DS.ArrangementEditor.iconInset, min(frame.width, frame.height) * DS.ArrangementEditor.iconInsetShare)
        let insetOnBothSides = inset + inset
        let showsLabel = isCustom
            && frame.height >= DS.ArrangementEditor.customLabelHeight
                + DS.ArrangementEditor.iconMinSize + insetOnBothSides
        let labelHeight = showsLabel ? DS.ArrangementEditor.customLabelHeight : 0
        let area = CGRect(
            x: frame.minX + inset,
            y: frame.minY + inset + labelHeight,
            width: max(0, frame.width - insetOnBothSides),
            height: max(0, frame.height - insetOnBothSides - labelHeight)
        )
        let grid = ArrangementEditorLayout.iconGrid(
            count: group.windowIDs.count,
            in: area.size,
            spacing: DS.ArrangementEditor.iconSpacing,
            maxSize: DS.ArrangementEditor.iconMaxSize,
            minSize: min(DS.ArrangementEditor.iconMinSize, area.width, area.height)
        )
        let zoneName = group.zoneIndex.map { loc.t(InputKey.gridZoneNumber, $0 + 1) }
            ?? loc.t(InputKey.arrangementCustomArea)
        return ZStack(alignment: .topLeading) {
            if isCustom { customOutline(frame: frame, showsLabel: showsLabel) }
            ForEach(Array(group.windowIDs.prefix(grid.visible).enumerated()), id: \.element) { cell, id in
                if let window = windows.first(where: { $0.id == id }) {
                    icon(window, zoneName: zoneName, size: grid.iconSize, at: origin(cell, grid, area))
                }
            }
            if grid.overflow {
                overflowCell(count: grid.hidden, size: grid.iconSize, at: origin(grid.visible, grid, area))
            }
        }
    }

    private func origin(_ cell: Int, _ grid: ArrangementIconGrid, _ area: CGRect) -> CGPoint {
        ArrangementEditorLayout.cellOrigin(index: cell, grid: grid, in: area, spacing: DS.ArrangementEditor.iconSpacing)
    }

    private func icon(_ window: ArrangedWindow, zoneName: String, size: CGFloat, at origin: CGPoint) -> some View {
        ArrangementAppIcon(
            model: model,
            window: window,
            zoneName: zoneName,
            size: size,
            isDragged: draggedID == window.id,
            targets: targets,
            space: space
        )
        .offset(x: origin.x, y: origin.y)
    }

    private func overflowCell(count: Int, size: CGFloat, at origin: CGPoint) -> some View {
        RoundedRectangle(cornerRadius: DS.ArrangementEditor.overflowCorner)
            .fill(DS.ArrangementEditor.overflowFill)
            .frame(width: size, height: size)
            .overlay {
                Text(count, format: .number.sign(strategy: .always(includingZero: false)))
                    .font(DS.ArrangementEditor.overflowFont)
                    .lineLimit(1)
                    .minimumScaleFactor(DS.ArrangementEditor.textMinimumScale)
            }
            .offset(x: origin.x, y: origin.y)
            .accessibilityHidden(true)
    }

    /// A slot that matches no zone of the grid keeps its place, dashed.
    private func customOutline(frame: CGRect, showsLabel: Bool) -> some View {
        RoundedRectangle(cornerRadius: DS.ArrangementEditor.zoneCorner)
            .fill(DS.ArrangementEditor.customFill)
            .overlay {
                RoundedRectangle(cornerRadius: DS.ArrangementEditor.zoneCorner)
                    .strokeBorder(
                        DS.ArrangementEditor.customStroke,
                        style: StrokeStyle(
                            lineWidth: DS.ArrangementEditor.customStrokeWidth,
                            dash: DS.ArrangementEditor.customDash
                        )
                    )
            }
            .overlay(alignment: .topLeading) {
                if showsLabel {
                    Text(loc.t(InputKey.arrangementCustomArea))
                        .font(DS.ArrangementEditor.customLabelFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, DS.ArrangementEditor.zoneLabelInset)
                        .padding(.top, DS.ArrangementEditor.iconSpacing)
                }
            }
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
            .accessibilityHidden(true)
    }
}

/// An app's icon in its slot: dragged to another zone, or moved and removed from its context menu.
private struct ArrangementAppIcon: View {
    let model: ArrangementEditorModel
    let window: ArrangedWindow
    let zoneName: String
    let size: CGFloat
    let isDragged: Bool
    let targets: [ArrangementEditorDisplay]
    let space: NamedCoordinateSpace

    @EnvironmentObject private var loc: Localizer
    /// Resets to false when the gesture ends or is cancelled, so an abandoned drag cannot stay on screen.
    @GestureState private var isDragging = false

    var body: some View {
        AppIconView(bundleID: window.bundleID, size: size)
            .opacity(isDragged ? DS.ArrangementEditor.draggedSourceOpacity : 1)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onChange(of: isDragging) { _, dragging in
                if !dragging { model.cancelDrag() }
            }
            .contextMenu { menu }
            .help(helpText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(helpText)
            .accessibilityValue(zoneName)
            .accessibilityActions { menu }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: DS.ArrangementEditor.dragThreshold, coordinateSpace: space)
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { model.dragChanged(window: window.id, location: $0.location) }
            .onEnded { model.dragEnded(window: window.id, location: $0.location) }
    }

    /// App name, then the window title it had when remembered; both are data.
    private var helpText: String {
        window.titleHint.map { "\(window.appName)\n\($0)" } ?? window.appName
    }

    @ViewBuilder
    private var menu: some View {
        Menu(loc.t(InputKey.arrangementMoveMenu)) {
            ForEach(targets) { display in
                Menu(displayTitle(display)) {
                    ForEach(Array(display.zones.enumerated()), id: \.offset) { index, zone in
                        Button(loc.t(InputKey.gridZoneNumber, index + 1)) {
                            model.move(window: window.id, toDisplay: display.key, zone: index)
                        }
                        .disabled(isCurrent(display, zone))
                    }
                }
            }
        }
        Button(loc.t(InputKey.arrangementRemoveApp), role: .destructive) {
            model.remove(window: window.id)
        }
    }

    private func displayTitle(_ display: ArrangementEditorDisplay) -> String {
        display.isConnected ? display.name : loc.t(InputKey.arrangementDisplayDisconnected, display.name)
    }

    private func isCurrent(_ display: ArrangementEditorDisplay, _ zone: UnitRect) -> Bool {
        window.slot.display == display.key && ArrangementEditorLayout.sameArea(window.slot.rect, zone)
    }
}
