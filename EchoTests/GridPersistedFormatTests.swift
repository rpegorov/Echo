import Foundation
import Testing
@testable import Echo

// The persisted shape of the grid document is a contract with every Echo that reads the file.
// Changing it without raising `GridFileStorage.schemaVersion` must turn this suite red;
// a version bump needs a new reference below. The reference catches changed keys and types; the
// stored-property lists catch additions, which an Optional field would hide from the reference.

private let referenceVersion = 1

private let savedID = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F") ?? UUID()

private let referenceJSON = """
{"document":{"activeByDisplay":{"edid:1-2-3":{"template":{"kind":"twoByTwo"}},\
"uuid:AAAA":{"saved":{"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"}}},\
"grids":[{"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","name":"Thirds",\
"zones":[{"height":1,"width":0.3333333333333333,"x":0,"y":0},\
{"height":1,"width":0.3333333333333333,"x":0.3333333333333333,"y":0},\
{"height":1,"width":0.3333333333333333,"x":0.6666666666666666,"y":0}]}]},"schemaVersion":1}
"""

private func referenceDocument() -> GridDocument {
    GridDocument(
        grids: [ZoneGrid(id: savedID, name: "Thirds", zones: GridTemplate.threeColumns.zones)],
        activeByDisplay: [
            "uuid:AAAA": .saved(id: savedID),
            "edid:1-2-3": .template(kind: .twoByTwo)
        ]
    )
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let envelope = GridFileEnvelope(schemaVersion: GridFileStorage.schemaVersion, document: referenceDocument())

        let text = try #require(String(data: try encoder.encode(envelope), encoding: .utf8))

        #expect(text == referenceJSON)
    }

    @Test("the reference JSON decodes to the reference document")
    func decodingMatchesReference() throws {
        let envelope = try JSONDecoder().decode(GridFileEnvelope.self, from: Data(referenceJSON.utf8))
        #expect(envelope.schemaVersion == referenceVersion)
        #expect(envelope.document == referenceDocument())
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
        let data = try JSONEncoder().encode(referenceDocument())
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let active = try #require(object["activeByDisplay"] as? [String: Any])
        #expect(Set(active.keys) == ["uuid:AAAA", "edid:1-2-3"])
    }

    @Test("the stored properties of every persisted type are the ones the reference was made for")
    func storedPropertyNames() {
        func names(_ value: Any) -> [String] { Mirror(reflecting: value).children.compactMap(\.label) }
        #expect(names(GridFileEnvelope(schemaVersion: 1, document: .empty)) == ["schemaVersion", "document"])
        #expect(names(GridDocument.empty) == ["grids", "activeByDisplay"])
        #expect(names(ZoneGrid(id: UUID(), name: "", zones: [])) == ["id", "name", "zones"])
        #expect(names(UnitRect(x: 0, y: 0, width: 1, height: 1)) == ["x", "y", "width", "height"])
    }
}
