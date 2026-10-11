//
//  GridCanvasView.swift
//  Echo
//

import AppKit
import SwiftUI

/// Drawing geometry of the canvas: the same `UnitRect.frame(in:gap:)` a dropped window gets, in top-left coordinates.
enum GridCanvasLayout {
    /// A window gap in points of the display, expressed in points of a canvas `canvasWidth` wide.
    static func scaledGap(_ gap: Double, canvasWidth: CGFloat, displayWidth: CGFloat) -> CGFloat {
        guard displayWidth > 0 else { return 0 }
        return CGFloat(gap) * canvasWidth / displayWidth
    }

    static func frames(for zones: [UnitRect], in size: CGSize, gap: CGFloat) -> [CGRect] {
        let canvas = CGRect(origin: .zero, size: size)
        return zones.map { zone in
            let cocoa = zone.frame(in: canvas, gap: gap)
            // frame(in:gap:) is bottom-left based, SwiftUI draws from the top.
            return CGRect(x: cocoa.minX, y: size.height - cocoa.maxY, width: cocoa.width, height: cocoa.height)
        }
    }

    /// Cutting across the longer side of a zone gives the more even halves.
    static func longSideAxis(of size: CGSize) -> SplitAxis {
        size.width >= size.height ? .columns : .rows
    }

    /// The axis a click on zone `index` splits along: its longer side, or the other one with Option held.
    static func splitAxis(forZone index: Int, of zones: [UnitRect], in size: CGSize, optionHeld: Bool) -> SplitAxis {
        let frames = frames(for: zones, in: size, gap: 0)
        let longSide = longSideAxis(of: frames[index].size)
        return optionHeld ? longSide.other : longSide
    }

    /// The line a split along `axis` would draw across `frame`, `inset` short of the frame's sides.
    static func splitLine(in frame: CGRect, axis: SplitAxis, inset: CGFloat) -> (from: CGPoint, to: CGPoint) {
        switch axis {
        case .columns:
            return (CGPoint(x: frame.midX, y: frame.minY + inset), CGPoint(x: frame.midX, y: frame.maxY - inset))
        case .rows:
            return (CGPoint(x: frame.minX + inset, y: frame.midY), CGPoint(x: frame.maxX - inset, y: frame.midY))
        }
    }

    /// A canvas point (top-left origin) in unit space (origin bottom-left), clamped to the square.
    static func unitPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        GridSnapResolver.unitPoint(
            CGPoint(x: point.x, y: size.height - point.y),
            in: CGRect(origin: .zero, size: size)
        )
    }

    /// The coordinate of `point` across a border of the given axis, in unit space.
    static func position(of point: CGPoint, across axis: GridEdge.Axis, in size: CGSize) -> Double {
        let unit = unitPoint(point, in: size)
        return axis == .vertical ? unit.x : unit.y
    }

    /// The border whose grab strip holds `point`; the nearest one when strips overlap.
    static func edge(at point: CGPoint, among edges: [GridEdge], in size: CGSize, hitWidth: CGFloat) -> GridEdge? {
        let reach = hitWidth / 2
        var best: (edge: GridEdge, distance: CGFloat)?
        for edge in edges {
            let strip = handleRect(for: edge, in: size, thickness: hitWidth, endInset: -reach)
            guard strip.contains(point) else { continue }
            let center = edge.axis == .vertical ? edge.position * size.width : size.height - edge.position * size.height
            let distance = abs((edge.axis == .vertical ? point.x : point.y) - center)
            if distance < (best?.distance ?? .greatestFiniteMagnitude) { best = (edge, distance) }
        }
        return best?.edge
    }

    /// The rect of a border's handle in canvas points, `endInset` shorter at both ends.
    static func handleRect(for edge: GridEdge, in size: CGSize, thickness: CGFloat, endInset: CGFloat) -> CGRect {
        switch edge.axis {
        case .vertical:
            let top = size.height * (1 - edge.end) + endInset
            let bottom = size.height * (1 - edge.start) - endInset
            return CGRect(x: edge.position * size.width - thickness / 2, y: top, width: thickness, height: max(0, bottom - top))
        case .horizontal:
            let left = size.width * edge.start + endInset
            let right = size.width * edge.end - endInset
            let y = size.height * (1 - edge.position) - thickness / 2
            return CGRect(x: left, y: y, width: max(0, right - left), height: thickness)
        }
    }
}

/// The display's visible area with the grid's zones drawn at the proportions of that display.
struct GridCanvasView: View {
    @ObservedObject var model: GridEditorModel
    /// Visible size of the display the grid is for; sets the canvas aspect and the gap scale.
    let displaySize: CGSize
    @ObservedObject var settings: AppSettings

    @EnvironmentObject private var loc: Localizer
    /// True from the first event of a press until it ends, so a press is classified once.
    @State private var pressBegan = false
    /// Tracks the press itself; SwiftUI resets it to false when the gesture ends or is cancelled.
    @GestureState private var isPressing = false
    @StateObject private var optionWatcher = OptionKeyWatcher()

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let gap = GridCanvasLayout.scaledGap(settings.windowGap, canvasWidth: size.width, displayWidth: displaySize.width)
            let frames = GridCanvasLayout.frames(for: model.draft.zones, in: size, gap: gap)
            ZStack(alignment: .topLeading) {
                // The zone number is its index (reading order), so the index is its identity.
                ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                    zoneView(index: index, size: frame.size)
                        .offset(x: frame.minX, y: frame.minY)
                }
                splitPreview(frames: frames, in: size)
                ForEach(model.edges, id: \.self) { edge in
                    handleView(edge, in: size)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(pressGesture(in: size))
            .onContinuousHover { phase in hover(phase, in: size) }
        }
        .aspectRatio(displaySize.width / displaySize.height, contentMode: .fit)
        .background {
            RoundedRectangle(cornerRadius: DS.GridEditor.canvasCorner)
                .fill(DS.GridEditor.canvasFill)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.GridEditor.canvasCorner)
                        .strokeBorder(DS.GridEditor.canvasStroke, lineWidth: DS.GridEditor.hairline)
                }
        }
        .accessibilityElement(children: .contain)
        .onChange(of: (model.activeEdge ?? model.hoveredEdge)?.axis) { _, axis in
            EdgeCursor.show(for: axis)
        }
        .onChange(of: isPressing) { _, pressing in
            if !pressing { abandonPress() }
        }
        .onDisappear {
            EdgeCursor.show(for: nil)
            optionWatcher.stop()
            abandonPress()
        }
    }

    // MARK: - Zones

    private func zoneView(index: Int, size: CGSize) -> some View {
        let number = index + 1
        let shortcut = shortcutText(forZone: number)
        let isHovered = model.hoveredZone == index && model.hoveredEdge == nil && !model.isDragging
        return ZStack {
            RoundedRectangle(cornerRadius: DS.GridEditor.zoneCorner)
                .fill(isHovered ? DS.GridEditor.zoneHoverFill : DS.GridEditor.zoneFill)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.GridEditor.zoneCorner)
                        .strokeBorder(DS.GridEditor.zoneStroke, lineWidth: DS.GridEditor.zoneStrokeWidth)
                }
            ZoneLabel(number: number, shortcut: shortcut)
                .padding(DS.GridEditor.zoneLabelInset)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: DS.GridEditor.zoneCorner))
        .contextMenu { zoneMenu(index: index) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName(number: number, shortcut: shortcut))
        .accessibilityActions { zoneMenu(index: index) }
    }

    @ViewBuilder
    private func zoneMenu(index: Int) -> some View {
        Button(loc.t(InputKey.gridEditorSplitColumns)) { model.split(zone: index, along: .columns) }
            .disabled(!model.canSplit(zone: index, along: .columns))
        Button(loc.t(InputKey.gridEditorSplitRows)) { model.split(zone: index, along: .rows) }
            .disabled(!model.canSplit(zone: index, along: .rows))
        Divider()
        mergeButton(InputKey.gridEditorMergeLeft, index: index, toward: .left)
        mergeButton(InputKey.gridEditorMergeRight, index: index, toward: .right)
        mergeButton(InputKey.gridEditorMergeAbove, index: index, toward: .above)
        mergeButton(InputKey.gridEditorMergeBelow, index: index, toward: .below)
    }

    private func mergeButton(_ key: InputKey, index: Int, toward direction: GridDirection) -> some View {
        Button(loc.t(key)) { model.merge(zone: index, toward: direction) }
            .disabled(model.mergeTarget(zone: index, toward: direction) == nil)
    }

    /// Zones past the ninth have no command, hence no shortcut.
    private func shortcutText(forZone number: Int) -> String? {
        WMCommand.zone(number)
            .flatMap(settings.shortcut(for:))
            .map { $0.displayString(spaceName: loc.t(InputKey.keySpace)) }
    }

    private func accessibilityName(number: Int, shortcut: String?) -> String {
        let name = loc.t(InputKey.gridZoneNumber, number)
        return shortcut.map { name + " " + $0 } ?? name
    }

    // MARK: - Split preview

    /// A dashed line where a click on the hovered zone would split it; absent when the zone cannot be halved.
    @ViewBuilder
    private func splitPreview(frames: [CGRect], in size: CGSize) -> some View {
        if let index = model.hoveredZone, model.hoveredEdge == nil, !model.isDragging, frames.indices.contains(index) {
            let axis = GridCanvasLayout.splitAxis(
                forZone: index, of: model.draft.zones, in: size, optionHeld: optionWatcher.optionHeld
            )
            if model.canSplit(zone: index, along: axis) {
                let line = GridCanvasLayout.splitLine(in: frames[index], axis: axis, inset: DS.GridEditor.splitPreviewInset)
                Path { path in
                    path.move(to: line.from)
                    path.addLine(to: line.to)
                }
                .stroke(
                    DS.GridEditor.splitPreviewColor,
                    style: StrokeStyle(
                        lineWidth: DS.GridEditor.splitPreviewWidth,
                        lineCap: .round,
                        dash: DS.GridEditor.splitPreviewDash
                    )
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Border handles

    private func handleView(_ edge: GridEdge, in size: CGSize) -> some View {
        let emphasized = edge == model.activeEdge || (model.activeEdge == nil && edge == model.hoveredEdge)
        let thickness = emphasized ? DS.GridEditor.handleThicknessEmphasized : DS.GridEditor.handleThickness
        let rect = GridCanvasLayout.handleRect(
            for: edge, in: size, thickness: thickness, endInset: DS.GridEditor.handleEndInset
        )
        return Capsule()
            .fill(emphasized ? DS.GridEditor.handleFillEmphasized : DS.GridEditor.handleFill)
            .overlay {
                if emphasized {
                    Capsule().strokeBorder(DS.GridEditor.handleOutline, lineWidth: DS.GridEditor.handleOutlineWidth)
                }
            }
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)
            .accessibilityLabel(loc.t(InputKey.gridEditorBorderHandle))
    }

    // MARK: - Pointer

    private func hover(_ phase: HoverPhase, in size: CGSize) {
        guard !model.isDragging else { return }
        switch phase {
        case .active(let point):
            optionWatcher.start()
            let edge = GridCanvasLayout.edge(at: point, among: model.edges, in: size, hitWidth: DS.GridEditor.handleHitWidth)
            model.setHover(zone: zoneIndex(at: point, in: size), edge: edge)
        case .ended:
            optionWatcher.stop()
            model.setHover(zone: nil, edge: nil)
        }
    }

    /// Ends what a press left behind when SwiftUI cancelled the gesture without `onEnded`.
    private func abandonPress() {
        guard pressBegan else { return }
        pressBegan = false
        model.endDrag()
    }

    private func pressGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isPressing) { _, pressing, _ in pressing = true }
            .onChanged { value in
                if !pressBegan {
                    pressBegan = true
                    beginDragIfOnEdge(at: value.startLocation, in: size)
                }
                guard let axis = model.dragAxis else { return }
                model.drag(toPointerPosition: GridCanvasLayout.position(of: value.location, across: axis, in: size))
            }
            .onEnded { value in
                guard pressBegan else { return }
                defer { pressBegan = false }
                if model.isDragging {
                    model.endDrag()
                    let edge = GridCanvasLayout.edge(at: value.location, among: model.edges, in: size, hitWidth: DS.GridEditor.handleHitWidth)
                    model.setHover(zone: zoneIndex(at: value.location, in: size), edge: edge)
                } else if hypot(value.translation.width, value.translation.height) <= DS.GridEditor.clickSlop {
                    click(at: value.startLocation, in: size)
                }
            }
    }

    private func beginDragIfOnEdge(at point: CGPoint, in size: CGSize) {
        guard !NSEvent.modifierFlags.contains(.control),
              let edge = GridCanvasLayout.edge(at: point, among: model.edges, in: size, hitWidth: DS.GridEditor.handleHitWidth)
        else { return }
        model.beginDrag(of: edge, pointerPosition: GridCanvasLayout.position(of: point, across: edge.axis, in: size))
    }

    /// Splits the zone across its longer side; Option splits the other way.
    private func click(at point: CGPoint, in size: CGSize) {
        // Control-click opens the context menu; it must not also split.
        guard !NSEvent.modifierFlags.contains(.control), let index = zoneIndex(at: point, in: size) else { return }
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        model.split(
            zone: index,
            along: GridCanvasLayout.splitAxis(forZone: index, of: model.draft.zones, in: size, optionHeld: optionHeld)
        )
    }

    private func zoneIndex(at point: CGPoint, in size: CGSize) -> Int? {
        GridSnapResolver.zoneIndex(at: GridCanvasLayout.unitPoint(point, in: size), in: model.draft.zones)
    }
}

/// Shows the resize cursor over a border handle and restores the previous cursor when the pointer leaves.
@MainActor
private enum EdgeCursor {
    private static var pushed = false

    static func show(for axis: GridEdge.Axis?) {
        if pushed {
            NSCursor.pop()
            pushed = false
        }
        guard let axis else { return }
        (axis == .vertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
        pushed = true
    }
}

/// Publishes whether Option is held while started; the local monitor lives only between `start` and `stop`.
@MainActor
private final class OptionKeyWatcher: ObservableObject {
    @Published private(set) var optionHeld = false
    private var monitor: Any?

    func start() {
        update(held: NSEvent.modifierFlags.contains(.option))
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let held = event.modifierFlags.contains(.option)
            MainActor.assumeIsolated { self?.update(held: held) }
            return event
        }
    }

    isolated deinit {
        stop()
    }

    private func update(held: Bool) {
        if optionHeld != held { optionHeld = held }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        optionHeld = false
    }
}

extension SplitAxis {
    fileprivate var other: SplitAxis { self == .columns ? .rows : .columns }
}

/// Zone number with its shortcut; drops the shortcut, then shrinks, when the zone is too small for both.
private struct ZoneLabel: View {
    let number: Int
    let shortcut: String?

    var body: some View {
        ViewThatFits {
            if let shortcut {
                VStack(spacing: DS.GridEditor.zoneLabelSpacing) {
                    numberText(font: DS.GridEditor.zoneNumberFont)
                    Text(shortcut)
                        .font(DS.GridEditor.zoneShortcutFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(DS.GridEditor.zoneTextLines)
                }
            }
            numberText(font: DS.GridEditor.zoneNumberFont)
            numberText(font: DS.GridEditor.zoneCompactNumberFont)
                .minimumScaleFactor(DS.GridEditor.zoneTextMinimumScale)
        }
    }

    private func numberText(font: Font) -> some View {
        Text(number, format: .number.grouping(.never))
            .font(font)
            .foregroundStyle(.primary)
            .lineLimit(DS.GridEditor.zoneTextLines)
    }
}
