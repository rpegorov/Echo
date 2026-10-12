import CoreGraphics
import Testing
@testable import Echo

// Zone-grid editing operations. The invariant every operation must keep: zones inside the unit
// square, pairwise non-overlapping, total area 1, in reading order. `ZoneOracle` restates it
// independently of `GridEditing.isValid`.

private func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> UnitRect {
    UnitRect(x: x, y: y, width: width, height: height)
}

private func approximately(_ a: UnitRect, _ b: UnitRect, tolerance: Double = 1e-9) -> Bool {
    abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance
        && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
}

private func approximately(_ a: [UnitRect], _ b: [UnitRect]) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy { approximately($0, $1) }
}

private func approximately(_ a: GridEdge, _ b: GridEdge) -> Bool {
    a.axis == b.axis && abs(a.position - b.position) <= 1e-9
        && abs(a.start - b.start) <= 1e-9 && abs(a.end - b.end) <= 1e-9
}

private func containsEdge(_ edges: [GridEdge], _ expected: GridEdge) -> Bool {
    edges.contains { approximately($0, expected) }
}

private func edge(_ axis: GridEdge.Axis, _ position: Double, _ start: Double, _ end: Double) -> GridEdge {
    GridEdge(axis: axis, position: position, start: start, end: end)
}

/// Left half full height; the right half split into a top and a bottom zone (a T-junction).
private let tJunction = [rect(0, 0, 0.5, 1), rect(0.5, 0.5, 0.5, 0.5), rect(0.5, 0, 0.5, 0.5)]

@Suite("Grid editing: invariant")
struct GridEditingInvariantTests {

    @Test("every template is valid and already in canonical order", arguments: GridTemplate.allCases)
    func templatesAreValid(template: GridTemplate) {
        #expect(GridEditing.isValid(template.zones))
        #expect(GridEditing.canonicalOrder(template.zones) == template.zones)
    }

    @Test("canonical order is top edge descending, then left edge ascending")
    func canonicalOrdering() {
        let shuffled = [rect(0.5, 0, 0.5, 0.5), rect(0, 0.5, 0.5, 0.5), rect(0, 0, 0.5, 0.5), rect(0.5, 0.5, 0.5, 0.5)]
        #expect(GridEditing.canonicalOrder(shuffled) == GridTemplate.twoByTwo.zones)
    }

    @Test("a broken zone set is not valid",
          arguments: [
            ("empty", [UnitRect]()),
            ("overlap", [rect(0, 0, 0.6, 1), rect(0.5, 0, 0.5, 1)]),
            ("gap", [rect(0, 0, 0.4, 1), rect(0.5, 0, 0.5, 1)]),
            ("outside the square", [rect(0, 0, 0.5, 1), rect(0.5, 0, 0.6, 1)]),
            ("negative origin", [rect(-0.1, 0, 0.6, 1), rect(0.5, 0, 0.5, 1)]),
            ("out of reading order", [rect(0.5, 0, 0.5, 1), rect(0, 0, 0.5, 1)]),
            ("zero width", [rect(0, 0, 0, 1), rect(0, 0, 1, 1)])
          ])
    func invalidSets(name: String, zones: [UnitRect]) {
        #expect(!GridEditing.isValid(zones), "\(name)")
    }
}

@Suite("Grid editing: split")
struct GridEditingSplitTests {

    @Test("splitting along columns cuts a zone into a left and a right half")
    func splitColumns() throws {
        let result = try #require(GridEditing.split(GridTemplate.twoColumns.zones, at: 0, along: .columns))
        #expect(approximately(result, [rect(0, 0, 0.25, 1), rect(0.25, 0, 0.25, 1), rect(0.5, 0, 0.5, 1)]))
        #expect(GridEditing.isValid(result))
    }

    @Test("splitting along rows cuts a zone into a top and a bottom half, kept in reading order")
    func splitRows() throws {
        let result = try #require(GridEditing.split(GridTemplate.twoColumns.zones, at: 0, along: .rows))
        #expect(approximately(result, [rect(0, 0.5, 0.5, 0.5), rect(0.5, 0, 0.5, 1), rect(0, 0, 0.5, 0.5)]))
        #expect(GridEditing.isValid(result))
    }

    @Test("a zone whose half would be thinner than the minimum is refused")
    func splitRefusedAtMinimum() {
        let thin = [rect(0, 0, 0.19, 1), rect(0.19, 0, 0.81, 1)]
        #expect(GridEditing.split(thin, at: 0, along: .columns) == nil)
        #expect(GridEditing.split(thin, at: 0, along: .rows) != nil)
        let short = [rect(0, 0.81, 1, 0.19), rect(0, 0, 1, 0.81)]
        #expect(GridEditing.split(short, at: 0, along: .rows) == nil)
    }

    @Test("a zone exactly twice the minimum can still be split")
    func splitAtExactlyTwiceTheMinimum() throws {
        let zones = [rect(0, 0, 0.2, 1), rect(0.2, 0, 0.8, 1)]
        let result = try #require(GridEditing.split(zones, at: 0, along: .columns))
        #expect(GridEditing.isValid(result))
    }

    @Test("splitting leaves the other zones as they were")
    func splitKeepsNeighbours() throws {
        let result = try #require(GridEditing.split(GridTemplate.threeColumns.zones, at: 1, along: .rows))
        let others = GridTemplate.threeColumns.zones
        #expect(result.contains { approximately($0, others[0]) })
        #expect(result.contains { approximately($0, others[2]) })
        #expect(result.count == 4)
    }
}

@Suite("Grid editing: merge")
struct GridEditingMergeTests {

    @Test("in a 2x2 grid each zone has a candidate on its two inner sides and none on the outer ones")
    func candidatesInTwoByTwo() {
        let zones = GridTemplate.twoByTwo.zones   // upper-left, upper-right, lower-left, lower-right
        #expect(GridEditing.mergeCandidate(zones, of: 0, toward: .right) == 1)
        #expect(GridEditing.mergeCandidate(zones, of: 0, toward: .below) == 2)
        #expect(GridEditing.mergeCandidate(zones, of: 0, toward: .left) == nil)
        #expect(GridEditing.mergeCandidate(zones, of: 0, toward: .above) == nil)
        #expect(GridEditing.mergeCandidate(zones, of: 3, toward: .left) == 2)
        #expect(GridEditing.mergeCandidate(zones, of: 3, toward: .above) == 1)
        #expect(GridEditing.mergeCandidate(zones, of: 3, toward: .right) == nil)
        #expect(GridEditing.mergeCandidate(zones, of: 3, toward: .below) == nil)
    }

    @Test("a middle column has a candidate on both sides")
    func candidatesInColumns() {
        let zones = GridTemplate.mainAndTwoSides.zones
        #expect(GridEditing.mergeCandidate(zones, of: 1, toward: .left) == 0)
        #expect(GridEditing.mergeCandidate(zones, of: 1, toward: .right) == 2)
    }

    @Test("a neighbour that covers only part of the side, or more than it, is not a candidate")
    func noCandidateWithoutWholeSide() {
        #expect(GridEditing.mergeCandidate(tJunction, of: 0, toward: .right) == nil)
        #expect(GridEditing.mergeCandidate(tJunction, of: 1, toward: .left) == nil)
        #expect(GridEditing.mergeCandidate(tJunction, of: 1, toward: .below) == 2)
        #expect(GridEditing.mergeCandidate(tJunction, of: 2, toward: .above) == 1)
    }

    @Test("neighbours sharing a whole side merge into their union")
    func mergeNeighbours() throws {
        let top = try #require(GridEditing.merge(GridTemplate.twoByTwo.zones, 0, 1))
        #expect(approximately(top, [rect(0, 0.5, 1, 0.5), rect(0, 0, 0.5, 0.5), rect(0.5, 0, 0.5, 0.5)]))
        #expect(GridEditing.isValid(top))
        let right = try #require(GridEditing.merge(tJunction, 1, 2))
        #expect(approximately(right, [rect(0, 0, 0.5, 1), rect(0.5, 0, 0.5, 1)]))
    }

    @Test("merging is symmetric in its two arguments")
    func mergeIsSymmetric() {
        let zones = GridTemplate.twoByTwo.zones
        #expect(GridEditing.merge(zones, 0, 2) == GridEditing.merge(zones, 2, 0))
    }

    @Test("a union that is not a rectangle is refused", arguments: [(0, 1), (0, 2), (1, 0), (2, 0)])
    func lShapedUnionIsRefused(a: Int, b: Int) {
        #expect(GridEditing.merge(tJunction, a, b) == nil)
    }

    @Test("zones that do not touch cannot be merged")
    func nonNeighbours() {
        #expect(GridEditing.merge(GridTemplate.threeColumns.zones, 0, 2) == nil)
        #expect(GridEditing.merge(GridTemplate.twoByTwo.zones, 0, 3) == nil)
        #expect(GridEditing.merge(GridTemplate.twoByTwo.zones, 1, 2) == nil)
    }

    @Test("a candidate can always be merged")
    func candidateImpliesMerge() {
        let layouts = GridTemplate.allCases.map(\.zones) + [tJunction]
        for zones in layouts {
            for index in zones.indices {
                for direction in GridDirection.allCases {
                    guard let other = GridEditing.mergeCandidate(zones, of: index, toward: direction) else { continue }
                    #expect(GridEditing.merge(zones, index, other) != nil, "\(zones.count) zones: \(index) \(direction)")
                }
            }
        }
    }
}

@Suite("Grid editing: edges")
struct GridEditingEdgesTests {

    @Test("two columns have one full-height border")
    func twoColumns() {
        let edges = GridEditing.edges(of: GridTemplate.twoColumns.zones)
        #expect(edges.count == 1)
        #expect(containsEdge(edges, edge(.vertical, 0.5, 0, 1)))
    }

    @Test("a 2x2 grid has four borders, one per arm of the cross")
    func twoByTwo() {
        let edges = GridEditing.edges(of: GridTemplate.twoByTwo.zones)
        #expect(edges.count == 4)
        #expect(containsEdge(edges, edge(.vertical, 0.5, 0, 0.5)))
        #expect(containsEdge(edges, edge(.vertical, 0.5, 0.5, 1)))
        #expect(containsEdge(edges, edge(.horizontal, 0.5, 0, 0.5)))
        #expect(containsEdge(edges, edge(.horizontal, 0.5, 0.5, 1)))
    }

    @Test("a T-junction gives the long zone's side as one border")
    func tJunctionEdges() {
        let edges = GridEditing.edges(of: tJunction)
        #expect(edges.count == 2)
        #expect(containsEdge(edges, edge(.vertical, 0.5, 0, 1)))
        #expect(containsEdge(edges, edge(.horizontal, 0.5, 0.5, 1)))
    }

    @Test("a main zone with two side columns has two borders")
    func mainAndTwoSides() {
        let edges = GridEditing.edges(of: GridTemplate.mainAndTwoSides.zones)
        #expect(edges.count == 2)
        #expect(containsEdge(edges, edge(.vertical, 0.25, 0, 1)))
        #expect(containsEdge(edges, edge(.vertical, 0.75, 0, 1)))
    }

    @Test("a single zone has no border")
    func singleZone() {
        #expect(GridEditing.edges(of: [rect(0, 0, 1, 1)]).isEmpty)
    }
}

@Suite("Grid editing: move")
struct GridEditingMoveTests {

    private func columnsEdge() throws -> GridEdge {
        try #require(GridEditing.edges(of: GridTemplate.twoColumns.zones).first)
    }

    @Test("moving a border resizes the zones on both sides")
    func moveResizes() throws {
        let result = GridEditing.move(try columnsEdge(), to: 0.3, in: GridTemplate.twoColumns.zones)
        #expect(approximately(result, [rect(0, 0, 0.3, 1), rect(0.3, 0, 0.7, 1)]))
    }

    @Test("the position is rounded to the edge step", arguments: [(0.3012, 0.3), (0.3026, 0.305), (0.4999, 0.5)])
    func moveRounds(position: Double, expected: Double) throws {
        let result = GridEditing.move(try columnsEdge(), to: position, in: GridTemplate.twoColumns.zones)
        #expect(abs(result[0].width - expected) <= 1e-9)
    }

    @Test("a border stops where the thinnest touching zone reaches the minimum")
    func moveClamps() throws {
        let zones = GridTemplate.twoColumns.zones
        let low = GridEditing.move(try columnsEdge(), to: 0.02, in: zones)
        let high = GridEditing.move(try columnsEdge(), to: 0.99, in: zones)
        #expect(abs(low[0].width - GridEditing.minimumZoneExtent) <= 1e-9)
        #expect(abs(high[1].width - GridEditing.minimumZoneExtent) <= 1e-9)
    }

    @Test("the result is computed from the zones given, so a drag does not accumulate")
    func dragFromSnapshotDoesNotDrift() throws {
        let zones = GridTemplate.twoColumns.zones
        let border = try columnsEdge()
        for position in [0.31, 0.42, 0.28, 0.77] { _ = GridEditing.move(border, to: position, in: zones) }
        #expect(approximately(GridEditing.move(border, to: 0.5, in: zones), zones))
    }

    @Test("in a 2x2 grid a border segment moves only the zones beside it")
    func segmentMovesOnlyItsNeighbours() throws {
        let zones = GridTemplate.twoByTwo.zones
        let lower = try #require(GridEditing.edges(of: zones).first {
            $0.axis == .vertical && $0.start < 0.25
        })
        let result = GridEditing.move(lower, to: 0.3, in: zones)
        #expect(approximately(result[0], zones[0]))
        #expect(approximately(result[1], zones[1]))
        #expect(approximately(result[2], rect(0, 0, 0.3, 0.5)))
        #expect(approximately(result[3], rect(0.3, 0, 0.7, 0.5)))
    }

    @Test("a long border moves every zone on its far side")
    func longBorderMovesBothZones() throws {
        let border = try #require(GridEditing.edges(of: tJunction).first { $0.axis == .vertical })
        let result = GridEditing.move(border, to: 0.7, in: tJunction)
        #expect(approximately(result, [rect(0, 0, 0.7, 1), rect(0.7, 0.5, 0.3, 0.5), rect(0.7, 0, 0.3, 0.5)]))
    }

    @Test("the minimum applies to the thinnest of the zones touching a border")
    func clampUsesThinnestNeighbour() throws {
        let border = try #require(GridEditing.edges(of: tJunction).first { $0.axis == .horizontal })
        let result = GridEditing.move(border, to: 0.97, in: tJunction)
        #expect(GridEditing.isValid(result))
        #expect(abs(result[1].height - GridEditing.minimumZoneExtent) <= 1e-9)
    }
}

/// Deterministic generator: the same seed gives the same chains on every machine.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

private func borderViolation(_ zones: [UnitRect]) -> String? {
    let edges = GridEditing.edges(of: zones)
    for (index, first) in edges.enumerated() {
        for second in edges[(index + 1)...] where first.axis == second.axis {
            let overlap = min(first.end, second.end) - max(first.start, second.start)
            if abs(first.position - second.position) < GridEditing.tolerance && overlap > GridEditing.tolerance {
                return "borders \(first) and \(second) lie on top of each other"
            }
        }
    }
    return nil
}

@Suite("Grid editing: random chains")
struct GridEditingFuzzTests {
    private static let chainsPerTemplate = 1000
    private static let stepsPerChain = 12
    private static let zoneLimit = 24

    @Test("after every split, merge and move the grid is valid, its borders are distinct and no zone is thinner than the minimum",
          arguments: Array(zip(0..., GridTemplate.allCases)))
    func chainsKeepTheInvariant(index: Int, template: GridTemplate) {
        var random = SplitMix64(seed: 0xEC40 + UInt64(index))
        for chain in 0..<Self.chainsPerTemplate {
            var zones = template.zones
            for step in 0..<Self.stepsPerChain {
                guard let next = Self.apply(randomOperationTo: zones, using: &random) else { continue }
                let context = "\(template) chain \(chain) step \(step)"
                if let broken = ZoneOracle.violation(in: next.zones) {
                    Issue.record("\(context) after \(next.name): \(broken)")
                    return
                }
                if !GridEditing.isValid(next.zones) {
                    Issue.record("\(context) after \(next.name): isValid rejects a grid the oracle accepts")
                    return
                }
                if let overlap = borderViolation(next.zones) {
                    Issue.record("\(context) after \(next.name): \(overlap)")
                    return
                }
                if let thin = next.zones.first(where: {
                    min($0.width, $0.height) < GridEditing.minimumZoneExtent - GridEditing.tolerance
                }) {
                    Issue.record("\(context) after \(next.name): zone below the minimum extent \(thin)")
                    return
                }
                if next.expectedCountChange != next.zones.count - zones.count {
                    Issue.record("\(context) after \(next.name): zone count went \(zones.count) -> \(next.zones.count)")
                    return
                }
                zones = next.zones
            }
        }
    }

    private struct Outcome {
        let name: String
        let zones: [UnitRect]
        let expectedCountChange: Int
    }

    private static func apply(randomOperationTo zones: [UnitRect], using random: inout SplitMix64) -> Outcome? {
        switch Int.random(in: 0..<3, using: &random) {
        case 0:
            guard zones.count < zoneLimit else { return nil }
            let axis: SplitAxis = Bool.random(using: &random) ? .columns : .rows
            let index = Int.random(in: 0..<zones.count, using: &random)
            return GridEditing.split(zones, at: index, along: axis).map { Outcome(name: "split", zones: $0, expectedCountChange: 1) }
        case 1:
            let index = Int.random(in: 0..<zones.count, using: &random)
            guard let direction = GridDirection.allCases.randomElement(using: &random),
                  let other = GridEditing.mergeCandidate(zones, of: index, toward: direction) else { return nil }
            guard let merged = GridEditing.merge(zones, index, other) else {
                Issue.record("mergeCandidate named zone \(other) for \(index) but merge refused")
                return nil
            }
            return Outcome(name: "merge", zones: merged, expectedCountChange: -1)
        default:
            guard let border = GridEditing.edges(of: zones).randomElement(using: &random) else { return nil }
            let position = Double.random(in: -0.1...1.1, using: &random)
            return Outcome(name: "move", zones: GridEditing.move(border, to: position, in: zones), expectedCountChange: 0)
        }
    }
}
