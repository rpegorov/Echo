import CoreGraphics
import Testing
@testable import Echo

private let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
private let gap: CGFloat = 8

enum FrameEdge: CaseIterable { case left, right, bottom, top }

/// Moves a single edge of `frame` by `delta`, leaving the other three in place.
private func moving(_ edge: FrameEdge, of frame: CGRect, by delta: CGFloat) -> CGRect {
    switch edge {
    case .left:   return CGRect(x: frame.minX + delta, y: frame.minY, width: frame.width - delta, height: frame.height)
    case .right:  return CGRect(x: frame.minX, y: frame.minY, width: frame.width + delta, height: frame.height)
    case .bottom: return CGRect(x: frame.minX, y: frame.minY + delta, width: frame.width, height: frame.height - delta)
    case .top:    return CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height + delta)
    }
}

@Suite("Layout matcher")
struct LayoutMatcherTests {

    @Test("every layout's own frame matches itself among all layouts", arguments: WindowLayout.allCases)
    func exactFrameMatches(layout: WindowLayout) {
        let frame = layout.frame(in: visible, gap: gap)
        #expect(LayoutMatcher.match(frame, among: WindowLayout.allCases, visible: visible, gap: gap) == layout)
    }

    @Test("an edge off by 23 pt or exactly 24 pt still matches", arguments: FrameEdge.allCases, [CGFloat(23), 24, -23, -24])
    func deviationWithinToleranceMatches(edge: FrameEdge, delta: CGFloat) {
        let frame = moving(edge, of: WindowLayout.leftHalf.frame(in: visible, gap: gap), by: delta)
        #expect(LayoutMatcher.match(frame, among: [.leftHalf], visible: visible, gap: gap) == .leftHalf)
    }

    @Test("an edge off by 25 pt does not match", arguments: FrameEdge.allCases, [CGFloat(25), -25])
    func deviationBeyondToleranceDoesNotMatch(edge: FrameEdge, delta: CGFloat) {
        let frame = moving(edge, of: WindowLayout.leftHalf.frame(in: visible, gap: gap), by: delta)
        #expect(LayoutMatcher.match(frame, among: [.leftHalf], visible: visible, gap: gap) == nil)
    }

    @Test("the candidate with the smallest deviation wins, whatever the candidate order")
    func nearestCandidateWins() {
        let small = CGRect(x: 0, y: 0, width: 100, height: 100)
        let nearHalf = CGRect(x: 0, y: 0, width: 58, height: 100)
        let nearTwoThirds = CGRect(x: 0, y: 0, width: 60, height: 100)
        for candidates in [[WindowLayout.leftHalf, .leftTwoThirds], [.leftTwoThirds, .leftHalf]] {
            #expect(LayoutMatcher.match(nearHalf, among: candidates, visible: small, gap: 0) == .leftHalf)
            #expect(LayoutMatcher.match(nearTwoThirds, among: candidates, visible: small, gap: 0) == .leftTwoThirds)
        }
    }

    @Test("a window on another display does not match layouts of this one")
    func otherDisplayDoesNotMatch() {
        let other = CGRect(x: 1440, y: 0, width: 1440, height: 875)
        let frame = WindowLayout.leftHalf.frame(in: other, gap: gap)
        #expect(LayoutMatcher.match(frame, among: WindowLayout.allCases, visible: visible, gap: gap) == nil)
    }

    @Test("matching works on a display with a negative origin")
    func negativeOriginMatches() {
        let display = CGRect(x: -1920, y: 120, width: 1920, height: 1055)
        let frame = WindowLayout.bottomRight.frame(in: display, gap: gap)
        #expect(LayoutMatcher.match(frame, among: WindowLayout.allCases, visible: display, gap: gap) == .bottomRight)
    }

    @Test("no candidates means no match")
    func emptyCandidates() {
        let frame = WindowLayout.maximize.frame(in: visible, gap: gap)
        #expect(LayoutMatcher.match(frame, among: [], visible: visible, gap: gap) == nil)
    }

    @Test("an arbitrary window is not mistaken for a layout")
    func arbitraryWindowDoesNotMatch() {
        let frame = CGRect(x: 100, y: 120, width: 500, height: 300)
        #expect(LayoutMatcher.match(frame, among: WindowLayout.allCases, visible: visible, gap: gap) == nil)
    }
}
