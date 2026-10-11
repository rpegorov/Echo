import Testing
@testable import Echo

@MainActor
@Suite("Window manager wiring")
struct WindowManagerWiringTests {

    @Test("display-move commands are registered exactly when the window manager is on",
          arguments: [WMCommand.nextDisplay, .previousDisplay])
    func displayCommandsFollowWindowManagerFlag(command: WMCommand) {
        #expect(HotKeyRegistrar.shouldRegister(
            command, windowManagerEnabled: true, ultraSwitchEnabled: false, autoConvertEnabled: false))
        #expect(!HotKeyRegistrar.shouldRegister(
            command, windowManagerEnabled: false, ultraSwitchEnabled: true, autoConvertEnabled: true))
    }

    @Test("every layout command is gated by the window manager flag, not by Ultra Switch",
          arguments: WMCommand.allCases.filter { $0.layout != nil })
    func layoutCommandsFollowWindowManagerFlag(command: WMCommand) {
        #expect(HotKeyRegistrar.shouldRegister(
            command, windowManagerEnabled: true, ultraSwitchEnabled: false, autoConvertEnabled: false))
        #expect(!HotKeyRegistrar.shouldRegister(
            command, windowManagerEnabled: false, ultraSwitchEnabled: true, autoConvertEnabled: true))
    }

    @Test("the composition root builds the drag-to-snap controller and reuses it")
    func environmentBuildsSnapper() {
        withScratchDefaults { defaults in
            let environment = AppEnvironment(defaults: defaults, system: SystemLanguages(preferred: { [] }))

            let first = environment.snapper
            #expect(first === environment.snapper)
        }
    }
}
