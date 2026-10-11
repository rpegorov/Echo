import Foundation
@testable import Echo

// Reference files and builders shared by the persistence and store suites.
// The two JSON texts are the contract with every Echo that reads window-zones.json.

let fixtureGridID = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F") ?? UUID()
let fixtureArrangementID = UUID(uuidString: "A1000000-0000-4000-8000-000000000001") ?? UUID()
let fixtureTitledWindowID = UUID(uuidString: "A1000000-0000-4000-8000-000000000011") ?? UUID()
let fixtureUntitledWindowID = UUID(uuidString: "A1000000-0000-4000-8000-000000000012") ?? UUID()
let fixtureRuleID = UUID(uuidString: "A1000000-0000-4000-8000-000000000021") ?? UUID()

/// What the previous release wrote: schema version 1, no arrangements and no rules.
let v1ReferenceJSON = """
{"document":{"activeByDisplay":{"edid:1-2-3":{"template":{"kind":"twoByTwo"}},\
"uuid:AAAA":{"saved":{"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"}}},\
"grids":[{"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","name":"Thirds",\
"zones":[{"height":1,"width":0.3333333333333333,"x":0,"y":0},\
{"height":1,"width":0.3333333333333333,"x":0.3333333333333333,"y":0},\
{"height":1,"width":0.3333333333333333,"x":0.6666666666666666,"y":0}]}]},"schemaVersion":1}
"""

/// Two windows of one app (the first with a title hint), two displays, one rule; keys sorted.
/// A nil `titleHint` is an absent key.
let v2ReferenceJSON = """
{"document":{"activeByDisplay":{"edid:1-2-3":{"template":{"kind":"twoByTwo"}},\
"uuid:AAAA":{"saved":{"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"}}},\
"arrangements":[{"displays":{"edid:1-2-3":{"aspect":1.5,"name":"Laptop"},\
"uuid:AAAA":{"aspect":1.6,"name":"Studio Display"}},\
"id":"A1000000-0000-4000-8000-000000000001","name":"Review",\
"windows":[{"appName":"Terminal","bundleID":"com.apple.Terminal",\
"id":"A1000000-0000-4000-8000-000000000011",\
"slot":{"display":"uuid:AAAA","rect":{"height":1,"width":0.5,"x":0,"y":0}},"titleHint":"build"},\
{"appName":"Terminal","bundleID":"com.apple.Terminal",\
"id":"A1000000-0000-4000-8000-000000000012",\
"slot":{"display":"edid:1-2-3","rect":{"height":0.5,"width":0.5,"x":0.5,"y":0}}}]}],\
"autoRules":[{"appName":"Safari","bundleID":"com.apple.Safari",\
"display":{"aspect":1.6,"name":"Studio Display"},\
"id":"A1000000-0000-4000-8000-000000000021","isEnabled":true,\
"slot":{"display":"uuid:AAAA","rect":{"height":1,"width":0.5,"x":0.5,"y":0}}}],\
"grids":[{"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","name":"Thirds",\
"zones":[{"height":1,"width":0.3333333333333333,"x":0,"y":0},\
{"height":1,"width":0.3333333333333333,"x":0.3333333333333333,"y":0},\
{"height":1,"width":0.3333333333333333,"x":0.6666666666666666,"y":0}]}]},"schemaVersion":2}
"""

func fixtureSlot(
    _ display: String = "uuid:AAAA", _ x: Double = 0, _ y: Double = 0, _ width: Double = 0.5, _ height: Double = 1
) -> ZoneSlot {
    ZoneSlot(display: display, rect: UnitRect(x: x, y: y, width: width, height: height))
}

func fixtureWindow(
    id: UUID = UUID(), bundleID: String = "com.apple.Terminal", appName: String = "Terminal",
    titleHint: String? = nil, slot: ZoneSlot = fixtureSlot()
) -> ArrangedWindow {
    ArrangedWindow(id: id, bundleID: bundleID, appName: appName, titleHint: titleHint, slot: slot)
}

func fixtureArrangement(
    id: UUID = UUID(), name: String = "Work", windows: [ArrangedWindow]? = nil
) -> Arrangement {
    Arrangement(
        id: id, name: name, windows: windows ?? [fixtureWindow()],
        displays: ["uuid:AAAA": SavedDisplay(name: "Studio Display", aspect: 1.6)])
}

func fixtureRule(
    id: UUID = UUID(), bundleID: String = "com.apple.Safari", appName: String = "Safari",
    slot: ZoneSlot = fixtureSlot("uuid:AAAA", 0.5, 0, 0.5, 1), isEnabled: Bool = true
) -> AutoRule {
    AutoRule(
        id: id, bundleID: bundleID, appName: appName, slot: slot,
        display: SavedDisplay(name: "Studio Display", aspect: 1.6), isEnabled: isEnabled)
}

/// The document `v2ReferenceJSON` stands for.
func v2ReferenceDocument() -> GridDocument {
    GridDocument(
        grids: [ZoneGrid(id: fixtureGridID, name: "Thirds", zones: GridTemplate.threeColumns.zones)],
        activeByDisplay: [
            "uuid:AAAA": .saved(id: fixtureGridID),
            "edid:1-2-3": .template(kind: .twoByTwo)
        ],
        arrangements: [
            Arrangement(
                id: fixtureArrangementID,
                name: "Review",
                windows: [
                    fixtureWindow(id: fixtureTitledWindowID, titleHint: "build", slot: fixtureSlot("uuid:AAAA", 0, 0, 0.5, 1)),
                    fixtureWindow(id: fixtureUntitledWindowID, titleHint: nil, slot: fixtureSlot("edid:1-2-3", 0.5, 0, 0.5, 0.5))
                ],
                displays: [
                    "uuid:AAAA": SavedDisplay(name: "Studio Display", aspect: 1.6),
                    "edid:1-2-3": SavedDisplay(name: "Laptop", aspect: 1.5)
                ])
        ],
        autoRules: [fixtureRule(id: fixtureRuleID)]
    )
}
