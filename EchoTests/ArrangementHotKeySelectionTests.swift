import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import Echo

// Which arrangement hotkeys the registrar installs: only saved arrangements, only while the window
// manager is on. A key with no arrangement behind it is an orphan and is never registered.

private let comboA = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_A), flags: [.control, .command])
private let comboB = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_B), flags: [.control, .command])
private let comboC = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_C), flags: [.control, .command])
private let comboD = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_D), flags: [.control, .command])
private let comboE = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_E), flags: [.control, .command])

@MainActor
@Suite("Arrangement hotkey selection")
struct ArrangementHotKeySelectionTests {

    @Test("a saved arrangement with a shortcut is registered")
    func savedArrangementIsRegistered() {
        let id = UUID()

        let chosen = HotKeyRegistrar.arrangementHotKeys(
            shortcuts: [id: comboA], existing: [id], commandShortcuts: [], windowManagerEnabled: true)

        #expect(chosen.map(\.0) == [id])
        #expect(chosen.map(\.1) == [comboA])
    }

    @Test("a shortcut whose arrangement is gone is an orphan and is not registered")
    func orphanIsSkipped() {
        let saved = UUID()
        let orphan = UUID()

        let chosen = HotKeyRegistrar.arrangementHotKeys(
            shortcuts: [saved: comboA, orphan: comboB], existing: [saved],
            commandShortcuts: [], windowManagerEnabled: true)

        #expect(chosen.map(\.0) == [saved])
    }

    @Test("nothing is registered while the window manager is off")
    func windowManagerOffRegistersNothing() {
        let id = UUID()

        #expect(HotKeyRegistrar.arrangementHotKeys(
            shortcuts: [id: comboA], existing: [id], commandShortcuts: [], windowManagerEnabled: false).isEmpty)
    }

    @Test("no shortcuts or no arrangements register nothing")
    func emptyInputs() {
        let id = UUID()

        #expect(HotKeyRegistrar.arrangementHotKeys(
            shortcuts: [:], existing: [id], commandShortcuts: [], windowManagerEnabled: true).isEmpty)
        #expect(HotKeyRegistrar.arrangementHotKeys(
            shortcuts: [id: comboA], existing: [], commandShortcuts: [], windowManagerEnabled: true).isEmpty)
    }

    @Test("a key already used by a command is skipped; its neighbours stay")
    func commandCollisionIsSkipped() {
        let clashing = UUID()
        let free = UUID()

        let chosen = HotKeyRegistrar.arrangementHotKeys(
            shortcuts: [clashing: comboA, free: comboB],
            existing: [clashing, free],
            commandShortcuts: [comboA],
            windowManagerEnabled: true)

        #expect(chosen.map(\.0) == [free])
    }

    @Test("registration order is stable across calls")
    func orderIsStable() {
        let ids = (0..<5).map { _ in UUID() }
        let shortcuts = Dictionary(uniqueKeysWithValues: zip(ids, [comboA, comboB, comboC, comboD, comboE]))

        let first = HotKeyRegistrar.arrangementHotKeys(
            shortcuts: shortcuts, existing: Set(ids), commandShortcuts: [], windowManagerEnabled: true)
        let second = HotKeyRegistrar.arrangementHotKeys(
            shortcuts: shortcuts, existing: Set(ids), commandShortcuts: [], windowManagerEnabled: true)

        #expect(first.map(\.0) == second.map(\.0))
        #expect(first.map(\.0) == ids.sorted { $0.uuidString < $1.uuidString })
    }
}
