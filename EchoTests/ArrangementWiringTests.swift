import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import Echo

private let nextGridCombo = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_G), flags: [.control, .command])
private let arrangementCombo = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_W), flags: [.control, .command])

/// The overlay a collaborator was built with, read from its stored `overlay` property.
private func overlay(of collaborator: Any) -> AnyObject? {
    Mirror(reflecting: collaborator).children.first { $0.label == "overlay" }.flatMap { $0.value as AnyObject }
}

@MainActor
@Suite("Arrangement and next-grid wiring")
struct ArrangementWiringTests {

    private func makeEnvironment(
        _ defaults: UserDefaults, document: GridDocument = .empty
    ) -> AppEnvironment {
        AppEnvironment(
            defaults: defaults, system: SystemLanguages(preferred: { [] }),
            gridStorage: InMemoryGridStorage(document: document))
    }

    @Test("the composition root exposes the overlay, arrangement service, rule engine and grid cycler, each built once")
    func environmentBuildsTheWindowManagerCollaborators() {
        withScratchDefaults { defaults in
            let environment = makeEnvironment(defaults)

            #expect(environment.snapOverlay === environment.snapOverlay)
            #expect(environment.arrangements === environment.arrangements)
            #expect(environment.autoRules === environment.autoRules)
            #expect(environment.gridCycler === environment.gridCycler)
        }
    }

    @Test("drag-to-snap and the next-grid flash draw on the same overlay")
    func snapperAndGridCyclerShareOneOverlay() {
        withScratchDefaults { defaults in
            let environment = makeEnvironment(defaults)

            #expect(overlay(of: environment.snapper) === environment.snapOverlay)
            #expect(overlay(of: environment.gridCycler) === environment.snapOverlay)
        }
    }

    @Test("the arrangement service reads the grid store the environment owns")
    func arrangementServiceUsesTheEnvironmentStore() {
        let saved = fixtureArrangement(id: fixtureArrangementID)
        let document = GridDocument(grids: [], activeByDisplay: [:], arrangements: [saved], autoRules: nil)
        withScratchDefaults { defaults in
            let environment = makeEnvironment(defaults, document: document)

            #expect(environment.arrangements.arrangementIDs == [fixtureArrangementID])
        }
    }

    @Test("next grid has no shortcut until one is bound, and then it is registered exactly when the window manager is on")
    func nextGridHotKeyFollowsBindingAndWindowManagerFlag() {
        withScratchDefaults { defaults in
            let settings = makeEnvironment(defaults).settings
            #expect(settings.shortcut(for: .nextGrid) == nil)

            settings.setShortcut(nextGridCombo, for: .nextGrid)

            #expect(settings.shortcut(for: .nextGrid) == nextGridCombo)
            #expect(HotKeyRegistrar.shouldRegister(
                .nextGrid, windowManagerEnabled: true, ultraSwitchEnabled: false, autoConvertEnabled: false))
            #expect(!HotKeyRegistrar.shouldRegister(
                .nextGrid, windowManagerEnabled: false, ultraSwitchEnabled: true, autoConvertEnabled: true))
        }
    }

    @Test("a shortcut bound to a saved arrangement reaches the registrar's hotkey list only while the window manager is on")
    func arrangementShortcutIsRegisteredUnderTheWindowManagerFlag() {
        let saved = fixtureArrangement(id: fixtureArrangementID)
        let document = GridDocument(grids: [], activeByDisplay: [:], arrangements: [saved], autoRules: nil)
        withScratchDefaults { defaults in
            let environment = makeEnvironment(defaults, document: document)
            let settings = environment.settings
            settings.setShortcut(arrangementCombo, for: .arrangement(fixtureArrangementID))

            @MainActor func chosen(windowManagerEnabled: Bool) -> [UUID] {
                HotKeyRegistrar.arrangementHotKeys(
                    shortcuts: settings.arrangementShortcuts,
                    existing: environment.arrangements.arrangementIDs,
                    commandShortcuts: WMCommand.allCases.compactMap { settings.shortcut(for: $0) },
                    windowManagerEnabled: windowManagerEnabled
                ).map(\.0)
            }

            #expect(chosen(windowManagerEnabled: true) == [fixtureArrangementID])
            #expect(chosen(windowManagerEnabled: false).isEmpty)
        }
    }
}
