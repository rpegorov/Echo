import Testing
@testable import Echo

private let zoneCommands: [WMCommand] = [.zone1, .zone2, .zone3, .zone4, .zone5, .zone6, .zone7, .zone8, .zone9]

@MainActor
@Suite("Grid wiring")
struct GridWiringTests {

    @Test("zone commands are registered exactly when the window manager is on", arguments: zoneCommands)
    func zoneHotKeysFollowWindowManagerFlag(command: WMCommand) {
        #expect(HotKeyRegistrar.shouldRegister(
            command, windowManagerEnabled: true, ultraSwitchEnabled: false, autoConvertEnabled: false))
        #expect(!HotKeyRegistrar.shouldRegister(
            command, windowManagerEnabled: false, ultraSwitchEnabled: true, autoConvertEnabled: true))
    }

    @Test("the composition root builds its grid store over the storage it was given")
    func environmentUsesGivenStorage() throws {
        let stored = GridDocument(
            grids: [GridTemplate.mainAndSide.makeGrid(named: "Seed")],
            activeByDisplay: [:]
        )
        let storage = InMemoryGridStorage(document: stored)
        try withScratchDefaults { defaults in
            let environment = AppEnvironment(
                defaults: defaults, system: SystemLanguages(preferred: { [] }), gridStorage: storage)

            #expect(environment.gridStore.document == stored)

            try environment.gridStore.save(GridTemplate.twoByTwo.makeGrid(named: "Added"))
            #expect(storage.saveCount == 1)
            #expect(storage.document.grids.map(\.name) == ["Seed", "Added"])
        }
    }

    @Test("a storage that cannot be read reaches the composition root as a read-only store")
    func environmentSurfacesLoadFailure() {
        let storage = InMemoryGridStorage(loadError: .newerSchema(9))
        withScratchDefaults { defaults in
            let environment = AppEnvironment(
                defaults: defaults, system: SystemLanguages(preferred: { [] }), gridStorage: storage)

            #expect(environment.gridStore.isReadOnly)
            #expect(environment.gridStore.loadNotice == .newerVersion)
        }
    }
}
