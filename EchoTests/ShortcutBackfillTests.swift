import AppKit
import Carbon.HIToolbox
import Testing
@testable import Echo

private let originalCommands: [WMCommand] = [
    .leftHalf, .rightHalf, .topHalf, .bottomHalf, .topLeft, .topRight, .bottomLeft, .bottomRight,
    .center, .maximize, .openClipboard, .switchLayout, .convertWord, .translateSelection
]
private let addedCommands: [WMCommand] = [
    .leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds, .nextDisplay, .previousDisplay
]

private func previousVersionSet() -> [String: KeyboardShortcut] {
    Dictionary(uniqueKeysWithValues: originalCommands.map { ($0.rawValue, $0.defaultShortcut!) })
}

@Suite("Shortcut backfill")
struct ShortcutBackfillTests {

    @Test("a previous-version set receives the defaults of the new commands and nothing else changes")
    func addsNewDefaults() {
        let stored = previousVersionSet()
        let result = ShortcutBackfill.apply(to: stored, storedVersion: 2)

        for (key, value) in stored { #expect(result[key] == value, "\(key)") }
        for command in addedCommands { #expect(result[command.rawValue] == command.defaultShortcut, "\(command)") }
        #expect(result.count == stored.count + addedCommands.count)
    }

    @Test("an entry the user already has for a new command is never overwritten")
    func existingEntryIsKept() {
        var stored = previousVersionSet()
        let custom = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_H), flags: [.control, .command])
        stored["leftThird"] = custom
        #expect(ShortcutBackfill.apply(to: stored, storedVersion: 2)["leftThird"] == custom)
    }

    @Test("a default whose combination is taken, even with recorder flags, is skipped")
    func collidingDefaultIsSkipped() {
        var stored = previousVersionSet()
        stored["maximize"] = KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_D), flags: [.control, .option, .command, .function])
        let result = ShortcutBackfill.apply(to: stored, storedVersion: 2)
        #expect(result["leftThird"] == nil)
        #expect(result["maximize"] == stored["maximize"])
        #expect(result["centerThird"] == WMCommand.centerThird.defaultShortcut)
    }

    @Test("an entry under an unknown key keeps its combination reserved and is preserved")
    func unknownKeyBlocksAndSurvives() {
        var stored = previousVersionSet()
        let key = "arrangement:\(UUID().uuidString)"
        stored[key] = WMCommand.rightTwoThirds.defaultShortcut!
        let result = ShortcutBackfill.apply(to: stored, storedVersion: 2)
        #expect(result[key] == stored[key])
        #expect(result["rightTwoThirds"] == nil)
    }

    @Test("the current version and newer ones are returned unchanged", arguments: [3, 4, 99])
    func currentVersionIsUntouched(version: Int) {
        let stored = previousVersionSet()
        #expect(ShortcutBackfill.apply(to: stored, storedVersion: version) == stored)
    }

    @Test("a missing marker counts as the first version: removed window commands stay removed",
          arguments: [0, 1])
    func versionZeroIsTreatedAsOne(version: Int) {
        var stored = previousVersionSet()
        stored.removeValue(forKey: "leftHalf")
        stored.removeValue(forKey: "switchLayout")
        let result = ShortcutBackfill.apply(to: stored, storedVersion: version)
        #expect(result["leftHalf"] == nil)
        #expect(result["switchLayout"] == WMCommand.switchLayout.defaultShortcut)
        for command in addedCommands { #expect(result[command.rawValue] == command.defaultShortcut, "\(command)") }
    }

    @Test("an empty set from a previous version only gains the new commands")
    func emptySetGainsOnlyNewCommands() {
        let result = ShortcutBackfill.apply(to: [:], storedVersion: 2)
        #expect(Set(result.keys) == Set(addedCommands.map(\.rawValue)))
    }
}
