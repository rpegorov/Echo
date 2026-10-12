//
//  DisplayArrangement.swift
//  Echo
//

import CoreGraphics

extension UnitRect {
    /// The rect `frame` occupies relative to `visible`.
    init(frame: CGRect, in visible: CGRect) {
        self.init(
            x: (frame.minX - visible.minX) / visible.width,
            y: (frame.minY - visible.minY) / visible.height,
            width: frame.width / visible.width,
            height: frame.height / visible.height
        )
    }
}

enum DisplayArrangement {
    /// Indices of `frames` in spatial order: left to right, top to bottom for equal left edges.
    static func spatialOrder(_ frames: [CGRect]) -> [Int] {
        frames.indices.sorted { lhs, rhs in
            if frames[lhs].minX != frames[rhs].minX { return frames[lhs].minX < frames[rhs].minX }
            return frames[lhs].maxY > frames[rhs].maxY
        }
    }

    /// Index of the frame the window overlaps most; nil when it overlaps none.
    static func displayIndex(of window: CGRect, in frames: [CGRect]) -> Int? {
        var bestIndex: Int?
        var bestArea: CGFloat = 0
        for (index, frame) in frames.enumerated() {
            let overlap = window.intersection(frame)
            let area = overlap.width * overlap.height
            guard area > bestArea else { continue }
            bestIndex = index
            bestArea = area
        }
        return bestIndex
    }

    /// Index reached from `index` in `direction`, wrapping; `frames` are screen frames.
    static func neighbour(of index: Int, direction: DisplayDirection, in frames: [CGRect]) -> Int {
        guard frames.count > 1 else { return index }
        let order = spatialOrder(frames)
        guard let position = order.firstIndex(of: index) else { return index }
        let step = direction == .next ? 1 : -1
        return order[(position + step + order.count) % order.count]
    }

    /// Frame on the target display: same layout when the window sits in one, else same proportions, clamped.
    static func movedFrame(_ frame: CGRect, from source: CGRect, to target: CGRect, gap: CGFloat) -> CGRect {
        if let layout = LayoutMatcher.match(frame, among: WindowLayout.allCases, visible: source, gap: gap) {
            return layout.frame(in: target, gap: gap)
        }
        let proportional = UnitRect(frame: frame, in: source).frame(in: target, gap: 0)
        let size = CGSize(
            width: min(proportional.width, target.width),
            height: min(proportional.height, target.height)
        )
        let origin = WindowPlacement.clampedOrigin(target: proportional, actualSize: size, visible: target)
        return CGRect(origin: origin, size: size)
    }
}
