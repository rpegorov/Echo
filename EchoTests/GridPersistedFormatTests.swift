import Foundation
import Testing
@testable import Echo

// The persisted shape of the grid document is a contract with every Echo that reads the file.
// Changing it without raising `GridFileStorage.schemaVersion` must turn this suite red;
// a version bump needs a new reference in ArrangementFixtures. The reference catches changed keys and types;
// the stored-property lists catch additions, which an Optional field would hide from the reference.

private let referenceVersion = 2

private func sortedEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
}

@Suite("Grid persisted format")
struct GridPersistedFormatTests {

    @Test("the reference file belongs to the current schema version")
    @MainActor
    func referenceMatchesCurrentVersion() {
        #expect(GridFileStorage.schemaVersion == referenceVersion)
    }

    @Test("the document encodes to exactly the reference JSON")
    @MainActor
    func encodingMatchesReference() throws {
        let envelope = GridFileEnvelope(schemaVersion: GridFileStorage.schemaVersion, document: v2ReferenceDocument())

        let text = try #require(String(data: try sortedEncoder().encode(envelope), encoding: .utf8))

        #expect(text == v2ReferenceJSON)
    }

    @Test("the reference JSON decodes to the reference document")
    func decodingMatchesReference() throws {
        let envelope = try JSONDecoder().decode(GridFileEnvelope.self, from: Data(v2ReferenceJSON.utf8))
        #expect(envelope.schemaVersion == referenceVersion)
        #expect(envelope.document == v2ReferenceDocument())
    }

    @Test("a window without a title hint is stored without the key")
    func missingTitleHintIsAbsentKey() throws {
        let data = try sortedEncoder().encode(fixtureWindow(titleHint: nil))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["titleHint"] == nil)
    }

    @Test("a version 1 file decodes without arrangements and rules")
    func versionOneReferenceDecodes() throws {
        let envelope = try JSONDecoder().decode(GridFileEnvelope.self, from: Data(v1ReferenceJSON.utf8))

        #expect(envelope.schemaVersion == 1)
        #expect(envelope.document.arrangements == nil)
        #expect(envelope.document.autoRules == nil)
        #expect(envelope.document.grids == v2ReferenceDocument().grids)
        #expect(envelope.document.activeByDisplay == v2ReferenceDocument().activeByDisplay)
    }

    @Test("a document without arrangements or rules is stored without those keys")
    func emptyOptionalsAreAbsentKeys() throws {
        let data = try sortedEncoder().encode(GridDocument.empty)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["grids", "activeByDisplay"])
    }

    @Test("template names are stored identifiers")
    func templateRawValues() {
        #expect(GridTemplate.allCases.map(\.rawValue)
                == ["twoColumns", "threeColumns", "twoByTwo", "mainAndSide", "mainAndTwoSides"])
    }

    @Test("grid modifier names are stored identifiers")
    func gridModifierRawValues() {
        #expect(GridDragModifier.allCases.map(\.rawValue) == ["option", "command", "optionCommand"])
    }

    @Test("the document is a JSON object keyed by display strings")
    func displaysAreObjectKeys() throws {
        let data = try JSONEncoder().encode(v2ReferenceDocument())
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let active = try #require(object["activeByDisplay"] as? [String: Any])
        #expect(Set(active.keys) == ["uuid:AAAA", "edid:1-2-3"])
        let arrangements = try #require(object["arrangements"] as? [[String: Any]])
        let displays = try #require(arrangements.first?["displays"] as? [String: Any])
        #expect(Set(displays.keys) == ["uuid:AAAA", "edid:1-2-3"])
    }

    @Test("the stored properties of every persisted type are the ones the reference was made for")
    func storedPropertyNames() {
        func names(_ value: Any) -> Set<String> { Set(Mirror(reflecting: value).children.compactMap(\.label)) }
        #expect(names(GridFileEnvelope(schemaVersion: 2, document: .empty)) == ["schemaVersion", "document"])
        #expect(names(GridDocument.empty) == ["grids", "activeByDisplay", "arrangements", "autoRules"])
        #expect(names(ZoneGrid(id: UUID(), name: "", zones: [])) == ["id", "name", "zones"])
        #expect(names(UnitRect(x: 0, y: 0, width: 1, height: 1)) == ["x", "y", "width", "height"])
        #expect(names(fixtureSlot()) == ["display", "rect"])
        #expect(names(SavedDisplay(name: "", aspect: 1)) == ["name", "aspect"])
        #expect(names(fixtureArrangement()) == ["id", "name", "windows", "displays"])
        #expect(names(fixtureWindow()) == ["id", "bundleID", "appName", "titleHint", "slot"])
        #expect(names(fixtureRule()) == ["id", "bundleID", "appName", "slot", "display", "isEnabled"])
    }
}
