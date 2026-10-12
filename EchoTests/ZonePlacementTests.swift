import CoreGraphics
import Testing
@testable import Echo

private let visible = CGRect(x: 100, y: 50, width: 1600, height: 900)

@Suite("Zone placement")
struct ZonePlacementTests {

    @Test("zone numbers are 1-based and give the frame of that zone", arguments: GridTemplate.allCases)
    func framesMatchZones(template: GridTemplate) {
        let zones = template.zones
        for number in 1...zones.count {
            let frame = ZonePlacement.frame(forZone: number, of: zones, visible: visible, gap: 10)
            #expect(frame == zones[number - 1].frame(in: visible, gap: 10), "\(template) zone \(number)")
        }
    }

    @Test("zone 1 of two columns is the left half, the last zone the right half")
    func firstAndLast() {
        let zones = GridTemplate.twoColumns.zones
        #expect(ZonePlacement.frame(forZone: 1, of: zones, visible: visible, gap: 0) == CGRect(x: 100, y: 50, width: 800, height: 900))
        #expect(ZonePlacement.frame(forZone: 2, of: zones, visible: visible, gap: 0) == CGRect(x: 900, y: 50, width: 800, height: 900))
    }

    @Test("a gap insets every side by half of it")
    func gapInsets() {
        let frame = ZonePlacement.frame(forZone: 1, of: GridTemplate.twoColumns.zones, visible: visible, gap: 20)
        #expect(frame == CGRect(x: 110, y: 60, width: 780, height: 880))
    }

    @Test("a number outside the grid has no frame", arguments: [0, -1, 3, 9])
    func outOfRange(number: Int) {
        #expect(ZonePlacement.frame(forZone: number, of: GridTemplate.twoColumns.zones, visible: visible, gap: 0) == nil)
    }

    @Test("an empty grid has no frame")
    func emptyGrid() {
        #expect(ZonePlacement.frame(forZone: 1, of: [], visible: visible, gap: 0) == nil)
    }
}
