//
//  HotKeyRegistrationTests.swift
//  EchoTests
//
//  Which commands own a global hotkey. The undo of an auto-correction is a
//  repeated word conversion, so it must stay available whenever the
//  auto-correct tap is running — independently of the Ultra Switch hotkeys.
//

import Testing
@testable import Echo

@MainActor
struct HotKeyRegistrationTests {

    @Test("word conversion follows the auto-correct switch, not the hotkey master switch")
    func convertWordFollowsAutoCorrect() {
        #expect(HotKeyRegistrar.shouldRegister(
            .convertWord, windowManagerEnabled: false, ultraSwitchEnabled: false, autoConvertEnabled: true))
        #expect(!HotKeyRegistrar.shouldRegister(
            .convertWord, windowManagerEnabled: false, ultraSwitchEnabled: true, autoConvertEnabled: false))
    }

    @Test("layout switch and translation follow the Ultra Switch hotkeys")
    func layoutHotkeysFollowUltraSwitch() {
        #expect(HotKeyRegistrar.shouldRegister(
            .switchLayout, windowManagerEnabled: false, ultraSwitchEnabled: true, autoConvertEnabled: false))
        #expect(!HotKeyRegistrar.shouldRegister(
            .switchLayout, windowManagerEnabled: false, ultraSwitchEnabled: false, autoConvertEnabled: true))
        #expect(HotKeyRegistrar.shouldRegister(
            .translateSelection, windowManagerEnabled: false, ultraSwitchEnabled: true, autoConvertEnabled: true))
        #expect(!HotKeyRegistrar.shouldRegister(
            .translateSelection, windowManagerEnabled: false, ultraSwitchEnabled: false, autoConvertEnabled: true))
    }

    @Test("window commands follow Window Manager, clipboard is always registered")
    func windowAndClipboardGates() {
        #expect(HotKeyRegistrar.shouldRegister(
            .leftHalf, windowManagerEnabled: true, ultraSwitchEnabled: false, autoConvertEnabled: false))
        #expect(!HotKeyRegistrar.shouldRegister(
            .leftHalf, windowManagerEnabled: false, ultraSwitchEnabled: false, autoConvertEnabled: false))
        #expect(HotKeyRegistrar.shouldRegister(
            .openClipboard, windowManagerEnabled: false, ultraSwitchEnabled: false, autoConvertEnabled: false))
    }
}
