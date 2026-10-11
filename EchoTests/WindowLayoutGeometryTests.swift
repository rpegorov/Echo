import CoreGraphics
import Testing
@testable import Echo

private let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
private let tolerance: CGFloat = 0.001

private func expectFrame(
    _ actual: CGRect, _ expected: CGRect,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(abs(actual.minX - expected.minX) < tolerance, "minX \(actual) vs \(expected)", sourceLocation: sourceLocation)
    #expect(abs(actual.minY - expected.minY) < tolerance, "minY \(actual) vs \(expected)", sourceLocation: sourceLocation)
    #expect(abs(actual.width - expected.width) < tolerance, "width \(actual) vs \(expected)", sourceLocation: sourceLocation)
    #expect(abs(actual.height - expected.height) < tolerance, "height \(actual) vs \(expected)", sourceLocation: sourceLocation)
}

/// Reference frames: halves and quarters of the visible area, centre at 60 %, inset by half the gap.
private func legacyFrame(_ layout: WindowLayout, in v: CGRect, gap: CGFloat) -> CGRect? {
    let halfW = v.width / 2
    let halfH = v.height / 2
    let raw: CGRect
    switch layout {
    case .leftHalf:    raw = CGRect(x: v.minX, y: v.minY, width: halfW, height: v.height)
    case .rightHalf:   raw = CGRect(x: v.minX + halfW, y: v.minY, width: halfW, height: v.height)
    case .topHalf:     raw = CGRect(x: v.minX, y: v.minY + halfH, width: v.width, height: halfH)
    case .bottomHalf:  raw = CGRect(x: v.minX, y: v.minY, width: v.width, height: halfH)
    case .topLeft:     raw = CGRect(x: v.minX, y: v.minY + halfH, width: halfW, height: halfH)
    case .topRight:    raw = CGRect(x: v.minX + halfW, y: v.minY + halfH, width: halfW, height: halfH)
    case .bottomLeft:  raw = CGRect(x: v.minX, y: v.minY, width: halfW, height: halfH)
    case .bottomRight: raw = CGRect(x: v.minX + halfW, y: v.minY, width: halfW, height: halfH)
    case .center:      raw = CGRect(x: v.midX - v.width * 0.3, y: v.midY - v.height * 0.3,
                                    width: v.width * 0.6, height: v.height * 0.6)
    case .maximize:    raw = v
    default:           return nil
    }
    return raw.insetBy(dx: gap / 2, dy: gap / 2)
}

private let legacyLayouts: [WindowLayout] = WindowLayout.allCases.filter { legacyFrame($0, in: screen, gap: 0) != nil }

@Suite("Window layout geometry")
struct WindowLayoutGeometryTests {

    @Test("the ten original layouts keep their exact frames on 1440x875 with an 8 pt gap")
    func originalLayoutsKeepLiteralFrames() {
        let expected: [WindowLayout: CGRect] = [
            .leftHalf: CGRect(x: 4, y: 4, width: 712, height: 867),
            .rightHalf: CGRect(x: 724, y: 4, width: 712, height: 867),
            .topHalf: CGRect(x: 4, y: 441.5, width: 1432, height: 429.5),
            .bottomHalf: CGRect(x: 4, y: 4, width: 1432, height: 429.5),
            .topLeft: CGRect(x: 4, y: 441.5, width: 712, height: 429.5),
            .topRight: CGRect(x: 724, y: 441.5, width: 712, height: 429.5),
            .bottomLeft: CGRect(x: 4, y: 4, width: 712, height: 429.5),
            .bottomRight: CGRect(x: 724, y: 4, width: 712, height: 429.5),
            .center: CGRect(x: 292, y: 179, width: 856, height: 517),
            .maximize: CGRect(x: 4, y: 4, width: 1432, height: 867)
        ]
        #expect(expected.count == 10)
        for (layout, frame) in expected {
            expectFrame(layout.frame(in: screen, gap: 8), frame)
        }
    }

    @Test("the original layouts match the legacy formula on displays with an offset origin",
          arguments: [
            CGRect(x: 0, y: 0, width: 1440, height: 875),
            CGRect(x: -1920, y: 25, width: 1920, height: 1055),
            CGRect(x: 1440, y: -300, width: 2560, height: 1415)
          ],
          [CGFloat(0), 8, 20])
    func originalLayoutsMatchLegacyFormula(visible: CGRect, gap: CGFloat) {
        for layout in legacyLayouts {
            let expected = legacyFrame(layout, in: visible, gap: gap)!
            expectFrame(layout.frame(in: visible, gap: gap), expected)
        }
    }

    @Test("the three thirds cover the visible width without gaps or overlaps when the gap is zero",
          arguments: [
            CGRect(x: 0, y: 0, width: 1280, height: 775),
            CGRect(x: 0, y: 0, width: 3440, height: 1415),
            CGRect(x: -1728, y: 40, width: 1728, height: 1050)
          ])
    func thirdsTileTheWidth(visible: CGRect) {
        let left = WindowLayout.leftThird.frame(in: visible, gap: 0)
        let center = WindowLayout.centerThird.frame(in: visible, gap: 0)
        let right = WindowLayout.rightThird.frame(in: visible, gap: 0)
        #expect(abs(left.minX - visible.minX) < tolerance)
        #expect(abs(left.maxX - center.minX) < tolerance)
        #expect(abs(center.maxX - right.minX) < tolerance)
        #expect(abs(right.maxX - visible.maxX) < tolerance)
        for frame in [left, center, right] {
            #expect(abs(frame.minY - visible.minY) < tolerance)
            #expect(abs(frame.height - visible.height) < tolerance)
        }
    }

    @Test("neighbouring thirds end up exactly one gap apart")
    func thirdsAreOneGapApart() {
        let left = WindowLayout.leftThird.frame(in: screen, gap: 8)
        let center = WindowLayout.centerThird.frame(in: screen, gap: 8)
        let right = WindowLayout.rightThird.frame(in: screen, gap: 8)
        #expect(abs((center.minX - left.maxX) - 8) < tolerance)
        #expect(abs((right.minX - center.maxX) - 8) < tolerance)
    }

    @Test("two thirds span 2/3 of the width and stay anchored to their screen edge")
    func twoThirdsAnchorToEdges() {
        let left = WindowLayout.leftTwoThirds.frame(in: screen, gap: 0)
        let right = WindowLayout.rightTwoThirds.frame(in: screen, gap: 0)
        #expect(abs(left.width - screen.width * 2 / 3) < tolerance)
        #expect(abs(right.width - screen.width * 2 / 3) < tolerance)
        #expect(abs(left.minX - screen.minX) < tolerance)
        #expect(abs(right.maxX - screen.maxX) < tolerance)
    }

    @Test("every layout lies inside the visible area and has a positive size")
    func layoutsStayInsideVisibleArea() {
        for layout in WindowLayout.allCases {
            let frame = layout.frame(in: screen, gap: 8)
            #expect(frame.width > 0 && frame.height > 0, "\(layout)")
            #expect(screen.contains(frame), "\(layout) leaves the screen: \(frame)")
        }
    }

    @Test("a unit rect maps into a visible area with an offset origin and the gap applied")
    func unitRectMapsIntoOffsetArea() {
        let visible = CGRect(x: -1000, y: 50, width: 800, height: 400)
        let frame = UnitRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25).frame(in: visible, gap: 10)
        expectFrame(frame, CGRect(x: -800 + 5, y: 250 + 5, width: 400 - 10, height: 100 - 10))
    }

    @Test("layout cases and their unit rects are one-to-one with the command table")
    func commandRoundTrip() {
        for layout in WindowLayout.allCases {
            #expect(layout.command.layout == layout, "\(layout)")
        }
        let commands = WindowLayout.allCases.map(\.command)
        #expect(Set(commands).count == WindowLayout.allCases.count)
    }
}

@Suite("Layout groups")
struct LayoutGroupTests {

    @Test("every layout belongs to exactly one group and no group is empty")
    func eachLayoutInExactlyOneGroup() {
        for layout in WindowLayout.allCases {
            let owners = LayoutGroup.allCases.filter { $0.layouts.contains(layout) }
            #expect(owners.count == 1, "\(layout) is in \(owners.count) groups")
            #expect(owners.first == layout.group, "\(layout)")
        }
        for group in LayoutGroup.allCases {
            #expect(!group.layouts.isEmpty, "\(group)")
        }
        let listed = LayoutGroup.allCases.flatMap(\.layouts)
        #expect(listed.count == WindowLayout.allCases.count)
    }

    @Test("a group is flagged as overlapping exactly when two of its zones intersect")
    func overlapFlagMatchesGeometry() {
        for group in LayoutGroup.allCases {
            let frames = group.layouts.map { $0.frame(in: screen, gap: 0) }
            var intersects = false
            for i in frames.indices {
                for j in frames.indices where j > i {
                    let common = frames[i].intersection(frames[j])
                    if !common.isNull && common.width > tolerance && common.height > tolerance {
                        intersects = true
                    }
                }
            }
            #expect(group.hasOverlap == intersects, "\(group)")
        }
    }
}
