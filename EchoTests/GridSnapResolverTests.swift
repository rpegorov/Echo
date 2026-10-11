import CoreGraphics
import Testing
@testable import Echo

private func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> UnitRect {
    UnitRect(x: x, y: y, width: width, height: height)
}

private func approximately(_ a: UnitRect, _ b: UnitRect) -> Bool {
    abs(a.x - b.x) <= 1e-9 && abs(a.y - b.y) <= 1e-9
        && abs(a.width - b.width) <= 1e-9 && abs(a.height - b.height) <= 1e-9
}

/// Top row in thirds, bottom row in halves: spanning across the uneven border has to grow.
private let staircase = [
    rect(0, 0.5, 1.0 / 3, 0.5), rect(1.0 / 3, 0.5, 1.0 / 3, 0.5), rect(2.0 / 3, 0.5, 1.0 / 3, 0.5),
    rect(0, 0, 0.5, 0.5), rect(0.5, 0, 0.5, 0.5)
]

@Suite("Grid snap resolver: point")
struct GridSnapPointTests {

    // A display to the left of the primary one: negative origin, as Cocoa reports it.
    private let visible = CGRect(x: -1920, y: 100, width: 1920, height: 1080)

    @Test("a point inside the visible area maps to its fraction of it")
    func insidePoint() {
        let point = GridSnapResolver.unitPoint(CGPoint(x: -960, y: 640), in: visible)
        #expect(abs(point.x - 0.5) <= 1e-9)
        #expect(abs(point.y - 0.5) <= 1e-9)
    }

    @Test("the corners of the visible area map to the corners of the unit square")
    func corners() {
        let origin = GridSnapResolver.unitPoint(CGPoint(x: -1920, y: 100), in: visible)
        let far = GridSnapResolver.unitPoint(CGPoint(x: 0, y: 1180), in: visible)
        #expect(origin == CGPoint(x: 0, y: 0))
        #expect(far == CGPoint(x: 1, y: 1))
    }

    @Test("a point outside is pressed to the nearest edge on each axis",
          arguments: [
            (CGPoint(x: -5000, y: 640), CGPoint(x: 0, y: 0.5)),
            (CGPoint(x: 300, y: 640), CGPoint(x: 1, y: 0.5)),
            (CGPoint(x: -960, y: -50), CGPoint(x: 0.5, y: 0)),
            (CGPoint(x: -960, y: 5000), CGPoint(x: 0.5, y: 1)),
            (CGPoint(x: 9000, y: -9000), CGPoint(x: 1, y: 0))
          ])
    func clamped(point: CGPoint, expected: CGPoint) {
        let result = GridSnapResolver.unitPoint(point, in: visible)
        #expect(abs(result.x - expected.x) <= 1e-9)
        #expect(abs(result.y - expected.y) <= 1e-9)
    }
}

@Suite("Grid snap resolver: zone under the pointer")
struct GridSnapZoneTests {

    @Test("a point inside a zone finds that zone")
    func insideZone() {
        let zones = GridTemplate.twoColumns.zones
        #expect(GridSnapResolver.zoneIndex(at: CGPoint(x: 0.25, y: 0.5), in: zones) == 0)
        #expect(GridSnapResolver.zoneIndex(at: CGPoint(x: 0.75, y: 0.5), in: zones) == 1)
    }

    @Test("on a shared border the lower index wins")
    func sharedBorder() {
        #expect(GridSnapResolver.zoneIndex(at: CGPoint(x: 0.5, y: 0.3), in: GridTemplate.twoColumns.zones) == 0)
        #expect(GridSnapResolver.zoneIndex(at: CGPoint(x: 0.5, y: 0.5), in: GridTemplate.twoByTwo.zones) == 0)
        #expect(GridSnapResolver.zoneIndex(at: CGPoint(x: 0.3, y: 0.5), in: GridTemplate.twoByTwo.zones) == 0)
    }

    @Test("the corners of the visible area belong to the zone that has them")
    func cornersBelongToAZone() {
        let columns = GridTemplate.twoColumns.zones
        #expect(GridSnapResolver.zoneIndex(at: CGPoint(x: 1, y: 1), in: columns) == 1)
        #expect(GridSnapResolver.zoneIndex(at: CGPoint(x: 0, y: 0), in: columns) == 0)
        let quarters = GridTemplate.twoByTwo.zones   // upper-left, upper-right, lower-left, lower-right
        #expect(GridSnapResolver.zoneIndex(at: CGPoint(x: 1, y: 1), in: quarters) == 1)
        #expect(GridSnapResolver.zoneIndex(at: CGPoint(x: 0, y: 1), in: quarters) == 0)
        #expect(GridSnapResolver.zoneIndex(at: CGPoint(x: 0, y: 0), in: quarters) == 2)
        #expect(GridSnapResolver.zoneIndex(at: CGPoint(x: 1, y: 0), in: quarters) == 3)
    }

    @Test("every point of the unit square finds a zone in every template", arguments: GridTemplate.allCases)
    func everyPointHasAZone(template: GridTemplate) {
        for column in 0...20 {
            for row in 0...20 {
                let point = CGPoint(x: Double(column) / 20, y: Double(row) / 20)
                #expect(GridSnapResolver.zoneIndex(at: point, in: template.zones) != nil, "\(template) \(point)")
            }
        }
    }

    @Test("no zones, no answer")
    func noZones() {
        #expect(GridSnapResolver.zoneIndex(at: CGPoint(x: 0.5, y: 0.5), in: []) == nil)
    }
}

@Suite("Grid snap resolver: span")
struct GridSnapSpanTests {

    @Test("a span from a zone to itself is that zone")
    func singleZone() {
        for template in GridTemplate.allCases {
            for index in template.zones.indices {
                let span = GridSnapResolver.span(from: index, to: index, in: template.zones)
                #expect(span.indices == [index], "\(template) \(index)")
                #expect(approximately(span.rect, template.zones[index]), "\(template) \(index)")
            }
        }
    }

    @Test("two columns span both")
    func twoColumns() {
        let span = GridSnapResolver.span(from: 0, to: 1, in: GridTemplate.twoColumns.zones)
        #expect(span.indices == [0, 1])
        #expect(approximately(span.rect, rect(0, 0, 1, 1)))
    }

    @Test("the direction of the drag does not change the span")
    func symmetric() {
        let zones = GridTemplate.twoByTwo.zones
        #expect(GridSnapResolver.span(from: 0, to: 3, in: zones) == GridSnapResolver.span(from: 3, to: 0, in: zones))
        #expect(GridSnapResolver.span(from: 1, to: 2, in: zones) == GridSnapResolver.span(from: 2, to: 1, in: zones))
    }

    @Test("opposite corners of a 2x2 grid span all four zones")
    func diagonal() {
        let span = GridSnapResolver.span(from: 0, to: 3, in: GridTemplate.twoByTwo.zones)
        #expect(span.indices == [0, 1, 2, 3])
        #expect(approximately(span.rect, rect(0, 0, 1, 1)))
    }

    @Test("neighbours in a 2x2 grid span their row or column only")
    func rowAndColumn() {
        let zones = GridTemplate.twoByTwo.zones
        let row = GridSnapResolver.span(from: 0, to: 1, in: zones)
        #expect(row.indices == [0, 1])
        #expect(approximately(row.rect, rect(0, 0.5, 1, 0.5)))
        let column = GridSnapResolver.span(from: 1, to: 3, in: zones)
        #expect(column.indices == [1, 3])
        #expect(approximately(column.rect, rect(0.5, 0, 0.5, 1)))
    }

    @Test("zones that only touch the bounding box are left out")
    func touchingZonesAreNotPulledIn() {
        let span = GridSnapResolver.span(from: 0, to: 1, in: staircase)
        #expect(span.indices == [0, 1])
        #expect(approximately(span.rect, rect(0, 0.5, 2.0 / 3, 0.5)))
    }

    @Test("a span over an uneven border grows until it holds only whole zones")
    func growsToWholeZones() {
        let span = GridSnapResolver.span(from: 0, to: 3, in: staircase)
        #expect(span.indices == [0, 1, 2, 3, 4])
        #expect(approximately(span.rect, rect(0, 0, 1, 1)))
    }

    @Test("every span covers whole zones: nothing it overlaps sticks out", arguments: GridTemplate.allCases)
    func spansAreClosed(template: GridTemplate) {
        let zones = template.zones
        for anchor in zones.indices {
            for current in zones.indices {
                let span = GridSnapResolver.span(from: anchor, to: current, in: zones)
                #expect(span.indices.contains(anchor) && span.indices.contains(current))
                for (index, zone) in zones.enumerated() where ZoneOracle.overlapArea(zone, span.rect) > 1e-9 {
                    #expect(span.indices.contains(index), "\(template) \(anchor)->\(current) misses \(index)")
                    #expect(zone.x >= span.rect.x - 1e-9 && ZoneOracle.top(zone) <= ZoneOracle.top(span.rect) + 1e-9)
                }
            }
        }
    }
}
