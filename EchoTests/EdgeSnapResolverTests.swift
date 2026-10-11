import CoreGraphics
import Testing
@testable import Echo

private let mainScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let negativeOriginScreen = CGRect(x: -1920, y: 120, width: 1920, height: 1080)
private let screens = [mainScreen, negativeOriginScreen]

@Suite("Edge snap resolver")
struct EdgeSnapResolverTests {

    @Test("the four corners resolve to quarters", arguments: screens)
    func cornersResolveToQuarters(screen: CGRect) {
        let inset: CGFloat = 2
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + inset, y: screen.maxY - inset), in: screen) == .topLeft)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.maxX - inset, y: screen.maxY - inset), in: screen) == .topRight)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + inset, y: screen.minY + inset), in: screen) == .bottomLeft)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.maxX - inset, y: screen.minY + inset), in: screen) == .bottomRight)
    }

    @Test("a corner reaches 120 pt along either edge", arguments: screens)
    func cornerExtendsAlongBothEdges(screen: CGRect) {
        let size = EdgeSnapResolver.cornerSize
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + 1, y: screen.maxY - size), in: screen) == .topLeft)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + size, y: screen.maxY - 1), in: screen) == .topLeft)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.maxX - 1, y: screen.minY + size), in: screen) == .bottomRight)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.maxX - size, y: screen.minY + 1), in: screen) == .bottomRight)
    }

    @Test("just past the corner the edge zone takes over", arguments: screens)
    func pastTheCornerTheEdgeWins(screen: CGRect) {
        let size = EdgeSnapResolver.cornerSize
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + 1, y: screen.maxY - size - 1), in: screen) == .leftHalf)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + size + 1, y: screen.maxY - 1), in: screen) == .maximize)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.maxX - 1, y: screen.maxY - size - 1), in: screen) == .rightHalf)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + size + 1, y: screen.minY + 1), in: screen) == .bottomHalf)
    }

    @Test("the middle of the top edge maximizes, left and right give halves, bottom gives the bottom half",
          arguments: screens)
    func edgesResolveToHalvesAndMaximize(screen: CGRect) {
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.midX, y: screen.maxY - 1), in: screen) == .maximize)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + 1, y: screen.midY), in: screen) == .leftHalf)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.maxX - 1, y: screen.midY), in: screen) == .rightHalf)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.midX, y: screen.minY + 1), in: screen) == .bottomHalf)
    }

    @Test("the edge band is 4 pt wide, inclusive", arguments: screens)
    func edgeThresholdBoundary(screen: CGRect) {
        let edge = EdgeSnapResolver.edgeThreshold
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + edge, y: screen.midY), in: screen) == .leftHalf)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + edge + 1, y: screen.midY), in: screen) == nil)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.midX, y: screen.maxY - edge), in: screen) == .maximize)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.midX, y: screen.maxY - edge - 1), in: screen) == nil)
    }

    @Test("the middle of the screen and the area just inside the edge band resolve to nothing", arguments: screens)
    func interiorResolvesToNothing(screen: CGRect) {
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.midX, y: screen.midY), in: screen) == nil)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + 40, y: screen.midY), in: screen) == nil)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + 40, y: screen.maxY - 40), in: screen) == nil)
    }

    @Test("a screen left of the origin is judged against its own frame")
    func negativeOriginIsNotConfusedWithZero() {
        let screen = negativeOriginScreen
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: screen.minX + 1, y: 600), in: screen) == .leftHalf)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: -1, y: 600), in: screen) == .rightHalf)
        #expect(EdgeSnapResolver.layout(at: CGPoint(x: -960, y: 600), in: screen) == nil)
    }
}
