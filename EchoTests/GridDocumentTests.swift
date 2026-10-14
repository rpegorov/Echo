import Foundation
import Testing
@testable import Echo

private let display = DisplayKey(rawValue: "uuid:DISPLAY-A")

private func grid(_ name: String = "Work", zones: [UnitRect] = GridTemplate.twoByTwo.zones) -> ZoneGrid {
    ZoneGrid(id: UUID(), name: name, zones: zones)
}

@Suite("Grid document")
struct GridDocumentTests {

    // MARK: Active zones

    @Test("a display with a template gets that template's zones whatever its shape")
    func templateIsHonoured() {
        var document = GridDocument.empty
        document.setActive(.template(kind: .twoByTwo), for: display)
        #expect(document.activeZones(for: display, aspect: 3.56) == GridTemplate.twoByTwo.zones)
    }

    @Test("a display with a saved grid gets its zones")
    func savedGridIsHonoured() {
        var document = GridDocument.empty
        let work = grid(zones: GridTemplate.mainAndTwoSides.zones)
        document.save(work)
        document.setActive(.saved(id: work.id), for: display)
        #expect(document.activeZones(for: display, aspect: 1.6) == work.zones)
    }

    @Test("a saved grid that no longer exists falls back to the default for the aspect")
    func missingSavedGridFallsBack() {
        var document = GridDocument.empty
        document.setActive(.saved(id: UUID()), for: display)
        #expect(document.activeZones(for: display, aspect: 1.6) == GridTemplate.twoColumns.zones)
        #expect(document.activeZones(for: display, aspect: 2.39) == GridTemplate.threeColumns.zones)
    }

    @Test("a saved grid without zones falls back to the default so a window always has a target")
    func emptySavedGridFallsBack() {
        var document = GridDocument.empty
        let hollow = grid(zones: [])
        document.save(hollow)
        document.setActive(.saved(id: hollow.id), for: display)
        #expect(document.activeZones(for: display, aspect: 1.6) == GridTemplate.twoColumns.zones)
    }

    @Test("a display with no key or no choice gets the default for its aspect")
    func unknownDisplayFallsBack() {
        let document = GridDocument.empty
        #expect(document.activeZones(for: nil, aspect: 1.78) == GridTemplate.twoColumns.zones)
        #expect(document.activeZones(for: display, aspect: 1.78) == GridTemplate.twoColumns.zones)
        #expect(document.activeZones(for: nil, aspect: 3.56) == GridTemplate.threeColumns.zones)
    }

    // MARK: Editing

    @Test("saving replaces the grid with the same id and appends a new one")
    func saveReplacesOrAppends() {
        var document = GridDocument.empty
        let first = grid("First")
        document.save(first)
        document.save(grid("Second"))
        var edited = first
        edited.zones = GridTemplate.threeColumns.zones
        document.save(edited)

        #expect(document.grids.count == 2)
        #expect(document.grids[0] == edited)
    }

    @Test("renaming an unknown grid changes nothing")
    func renameUnknown() {
        var document = GridDocument(grids: [grid()], activeByDisplay: [:])
        let before = document
        document.rename(UUID(), to: "Nope")
        #expect(document == before)
    }

    @Test("deleting a grid releases displays that used it and keeps template choices")
    func deleteReleases() {
        var document = GridDocument.empty
        let doomed = grid()
        document.save(doomed)
        document.setActive(.saved(id: doomed.id), for: display)
        document.setActive(.template(kind: .mainAndSide), for: DisplayKey(rawValue: "uuid:B"))

        document.delete(doomed.id)

        #expect(document.grids.isEmpty)
        #expect(document.activeRef(for: display) == nil)
        #expect(document.activeRef(for: DisplayKey(rawValue: "uuid:B")) == .template(kind: .mainAndSide))
    }
}

@Suite("Grid templates")
struct GridTemplateTests {

    @Test("every template covers the visible area exactly, in reading order", arguments: GridTemplate.allCases)
    func templateIsValid(template: GridTemplate) {
        #expect(ZoneOracle.violation(in: template.zones) == nil, "\(template)")
        #expect(template.zones.count >= 2)
    }

    @Test("the default template switches at the ultrawide aspect",
          arguments: [
            (1.6, GridTemplate.twoColumns), (1.78, .twoColumns), (1.99, .twoColumns),
            (2.0, .threeColumns), (2.39, .threeColumns), (3.56, .threeColumns)
          ])
    func defaultByAspect(aspect: Double, expected: GridTemplate) {
        #expect(GridTemplate.default(forAspect: aspect) == expected)
    }

    @Test("a new grid carries the template's zones, the given name and a fresh id")
    func makeGrid() {
        let first = GridTemplate.mainAndSide.makeGrid(named: "Main")
        let second = GridTemplate.mainAndSide.makeGrid(named: "Main")
        #expect(first.zones == GridTemplate.mainAndSide.zones)
        #expect(first.name == "Main")
        #expect(first.id != second.id)
    }

    @Test("every template title exists in English and Russian", arguments: GridTemplate.allCases)
    @MainActor
    func titles(template: GridTemplate) {
        let en = Localizer(preference: .fixed(.en))
        let ru = Localizer(preference: .fixed(.ru))
        #expect(en.t(template.titleKey) != template.titleKey.rawValue)
        #expect(ru.t(template.titleKey) != template.titleKey.rawValue)
    }
}

@Suite("Display key")
struct DisplayKeyTests {

    @Test("a display with a UUID is keyed by it")
    func uuidBranch() {
        let key = DisplayKey(uuid: "37D8832A-2D66-02CA-B9F7-8F30A301B230", vendor: 1, model: 2, serial: 3)
        #expect(key.rawValue == "uuid:37D8832A-2D66-02CA-B9F7-8F30A301B230")
    }

    @Test("a display without a UUID is keyed by vendor, model and serial")
    func edidBranch() {
        let key = DisplayKey(uuid: nil, vendor: 1552, model: 40_960, serial: 0)
        #expect(key.rawValue == "edid:1552-40960-0")
    }

    @Test("the two forms never share a storage key")
    func formsAreDistinct() {
        let byUUID = DisplayKey(uuid: "1-2-3", vendor: 1, model: 2, serial: 3)
        let byEDID = DisplayKey(uuid: nil, vendor: 1, model: 2, serial: 3)
        #expect(byUUID != byEDID)
    }

    @Test("a key rebuilt from its raw value is the same key")
    func rawValueRoundTrip() {
        let key = DisplayKey(uuid: nil, vendor: 7, model: 8, serial: 9)
        #expect(DisplayKey(rawValue: key.rawValue) == key)
    }

    @Test("two displays differing in any one number get different keys")
    func numbersAllMatter() {
        let base = DisplayKey(uuid: nil, vendor: 1, model: 2, serial: 3)
        #expect(base != DisplayKey(uuid: nil, vendor: 9, model: 2, serial: 3))
        #expect(base != DisplayKey(uuid: nil, vendor: 1, model: 9, serial: 3))
        #expect(base != DisplayKey(uuid: nil, vendor: 1, model: 2, serial: 9))
    }
}
