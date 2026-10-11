//
//  ArrangementEditorLayout.swift
//  Echo
//

import CoreGraphics
import Foundation

/// Windows of one display that share a slot, drawn together.
struct ArrangementSlotGroup: Equatable {
    let rect: UnitRect
    /// Index of the zone of the display's grid the slot coincides with; nil for a slot outside the grid.
    let zoneIndex: Int?
    let windowIDs: [UUID]
}

/// How `count` icons are packed into a slot.
struct ArrangementIconGrid: Equatable {
    let iconSize: CGFloat
    let columns: Int
    /// Icons drawn; the remaining `count - visible` collapse into one "+N" cell after them.
    let visible: Int
    let totalCount: Int

    var hidden: Int { totalCount - visible }
    var overflow: Bool { visible < totalCount }

    /// Cells drawn, the "+N" cell included.
    var cellCount: Int { visible + (overflow ? 1 : 0) }
}

/// Pure geometry of the arrangement editor.
enum ArrangementEditorLayout {

    /// Height of every canvas: all displays share one height and sit in a row, so the row must fit the width
    /// and each canvas its caption within the height.
    static func canvasHeight(
        available: CGSize, aspects: [Double], spacing: CGFloat, captionHeight: CGFloat, captionSpacing: CGFloat
    ) -> CGFloat {
        let totalAspect = aspects.reduce(0, +)
        guard totalAspect > 0 else { return 0 }
        let rowWidth = available.width - spacing * CGFloat(aspects.count - 1)
        let heightByWidth = rowWidth / CGFloat(totalAspect)
        let heightByHeight = available.height - captionHeight - captionSpacing
        return max(0, min(heightByWidth, heightByHeight))
    }

    /// Whether two slot rects describe the same area.
    static func sameArea(_ lhs: UnitRect, _ rhs: UnitRect) -> Bool {
        let tolerance = GridEditing.tolerance
        return abs(lhs.x - rhs.x) <= tolerance && abs(lhs.y - rhs.y) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }

    /// Windows placed on `displayKey`, grouped by slot in order of first appearance.
    static func groups(of windows: [ArrangedWindow], on displayKey: String, zones: [UnitRect]) -> [ArrangementSlotGroup] {
        var groups: [ArrangementSlotGroup] = []
        for window in windows where window.slot.display == displayKey {
            if let index = groups.firstIndex(where: { sameArea($0.rect, window.slot.rect) }) {
                let group = groups[index]
                groups[index] = ArrangementSlotGroup(
                    rect: group.rect, zoneIndex: group.zoneIndex, windowIDs: group.windowIDs + [window.id]
                )
            } else {
                let zoneIndex = zones.firstIndex { sameArea($0, window.slot.rect) }
                groups.append(ArrangementSlotGroup(rect: window.slot.rect, zoneIndex: zoneIndex, windowIDs: [window.id]))
            }
        }
        return groups
    }

    /// The largest icons that fit `count` of them into `area`; below `minSize` the slot shows as many as fit
    /// and a "+N" cell for the rest.
    static func iconGrid(
        count: Int, in area: CGSize, spacing: CGFloat, maxSize: CGFloat, minSize: CGFloat
    ) -> ArrangementIconGrid {
        guard count > 0 else { return ArrangementIconGrid(iconSize: maxSize, columns: 1, visible: 0, totalCount: 0) }
        var best: (size: CGFloat, columns: Int)?
        for columns in 1...count {
            let rows = (count + columns - 1) / columns
            let size = min(
                (area.width - spacing * CGFloat(columns - 1)) / CGFloat(columns),
                (area.height - spacing * CGFloat(rows - 1)) / CGFloat(rows),
                maxSize
            )
            if size > (best?.size ?? -.infinity) { best = (size, columns) }
        }
        if let best, best.size >= minSize {
            return ArrangementIconGrid(iconSize: best.size, columns: best.columns, visible: count, totalCount: count)
        }
        let columns = max(1, Int(((area.width + spacing) / (minSize + spacing)).rounded(.down)))
        let rows = max(0, Int(((area.height + spacing) / (minSize + spacing)).rounded(.down)))
        let capacity = columns * rows
        let visible = max(0, min(count, capacity - 1))
        return ArrangementIconGrid(iconSize: minSize, columns: columns, visible: visible, totalCount: count)
    }

    /// Top-left corner of cell `index` of `grid` inside `area`, the block of cells centred in it.
    static func cellOrigin(index: Int, grid: ArrangementIconGrid, in area: CGRect, spacing: CGFloat) -> CGPoint {
        let columns = max(grid.columns, 1)
        let rows = (grid.cellCount + columns - 1) / columns
        let usedColumns = min(columns, grid.cellCount)
        let blockWidth = CGFloat(usedColumns) * grid.iconSize + CGFloat(max(usedColumns - 1, 0)) * spacing
        let blockHeight = CGFloat(rows) * grid.iconSize + CGFloat(max(rows - 1, 0)) * spacing
        let row = index / columns
        // The last row is centred on its own so a short row does not hang to the left.
        let rowCells = row == rows - 1 ? grid.cellCount - row * columns : columns
        let rowWidth = CGFloat(rowCells) * grid.iconSize + CGFloat(max(rowCells - 1, 0)) * spacing
        let originX = area.midX - blockWidth / 2 + (blockWidth - rowWidth) / 2
        return CGPoint(
            x: originX + CGFloat(index % columns) * (grid.iconSize + spacing),
            y: area.midY - blockHeight / 2 + CGFloat(row) * (grid.iconSize + spacing)
        )
    }
}
