import AppKit
import Carbon.HIToolbox
import Testing
@testable import Echo

// Arrangement hotkeys live in the same `wm.shortcuts` set as command hotkeys, under `arrangement:<uuid>`.
// A combination has exactly one owner; the set is user data and unknown entries are never dropped.

private let storeKey = "wm.shortcuts"
private let versionKey = "wm.shortcuts.version"
private let autoRulesKey = "wm.autoRules.enabled"

private let controlCommand: NSEvent.ModifierFlags = [.control, .command]

private func combo(_ keyCode: Int, _ flags: NSEvent.ModifierFlags = controlCommand) -> KeyboardShortcut {
    KeyboardShortcut(keyCode: UInt32(keyCode), flags: flags)
}

private let comboA = combo(kVK_ANSI_A)
private let comboB = combo(kVK_ANSI_B)

private func seed(_ defaults: UserDefaults, _ set: [String: KeyboardShortcut], version: Int = 4) throws {
    defaults.set(try JSONEncoder().encode(set), forKey: storeKey)
    defaults.set(version, forKey: versionKey)
}

private func stored(_ defaults: UserDefaults) throws -> [String: KeyboardShortcut] {
    let data = try #require(defaults.data(forKey: storeKey))
    return try JSONDecoder().decode([String: KeyboardShortcut].self, from: data)
}

private func key(_ id: UUID) -> String { "arrangement:\(id.uuidString)" }

@Suite("Shortcut owner")
struct ShortcutOwnerTests {

    @Test("a command is stored under its raw value and read back from it", arguments: WMCommand.allCases)
    func commandKeyRoundTrip(command: WMCommand) {
        let owner = ShortcutOwner.command(command)
        #expect(owner.storageKey == command.rawValue)
        #expect(ShortcutOwner(storageKey: owner.storageKey) == owner)
    }

    @Test("an arrangement is stored under the arrangement prefix and its uuid")
    func arrangementKeyRoundTrip() {
        let id = UUID()
        let owner = ShortcutOwner.arrangement(id)

        #expect(owner.storageKey == "arrangement:" + id.uuidString)
        #expect(ShortcutOwner(storageKey: owner.storageKey) == owner)
        #expect(ShortcutOwner.arrangementPrefix == "arrangement:")
    }

    @Test("keys that are neither a command nor an arrangement are not owners",
          arguments: ["arrangement:not-a-uuid", "arrangement:", "arrangement", "", "bogus", "futureCommand",
                      "Arrangement:E621E1F8-C36C-495A-93FC-0C247A3E6E5F"])
    func garbageIsNotAnOwner(storageKey: String) {
        #expect(ShortcutOwner(storageKey: storageKey) == nil)
    }

    @Test("a command and an arrangement are different owners")
    func ownersAreDistinct() {
        #expect(ShortcutOwner.command(.leftHalf) != .arrangement(UUID()))
        #expect(Set([ShortcutOwner.arrangement(UUID()), .arrangement(UUID())]).count == 2)
    }
}

@MainActor
@Suite("Arrangement shortcuts in settings")
struct ArrangementShortcutSettingsTests {

    // MARK: Loading and persisting

    @Test("an arrangement entry of the stored set becomes an arrangement shortcut and a command stays a command")
    func arrangementEntryIsRecognized() throws {
        try withScratchDefaults { defaults in
            let id = UUID()
            try seed(defaults, [key(id): comboA, WMCommand.leftHalf.rawValue: comboB])

            let settings = AppSettings(defaults: defaults)

            #expect(settings.arrangementShortcuts == [id: comboA])
            #expect(settings.shortcut(for: .arrangement(id)) == comboA)
            #expect(settings.shortcut(for: .leftHalf) == comboB)
        }
    }

    @Test("the arrangement key and unknown keys are written back unchanged by any change")
    func unrelatedChangeKeepsArrangementAndUnknownEntries() throws {
        try withScratchDefaults { defaults in
            let orphan = UUID()
            try seed(defaults, [key(orphan): comboA, "future.thing": comboB])
            let settings = AppSettings(defaults: defaults)

            settings.setShortcut(combo(kVK_ANSI_H), for: .center)

            let set = try stored(defaults)
            #expect(set[key(orphan)] == comboA)
            #expect(set["future.thing"] == comboB)
            #expect(set["center"] == combo(kVK_ANSI_H))
        }
    }

    @Test("an arrangement shortcut is stored under its key and survives a restart")
    func arrangementShortcutIsPersisted() throws {
        try withScratchDefaults { defaults in
            let id = UUID()
            let settings = AppSettings(defaults: defaults)

            #expect(settings.setShortcut(comboA, for: .arrangement(id)) == nil)

            let set = try stored(defaults)
            #expect(set[key(id)] == comboA)
            #expect(AppSettings(defaults: defaults).shortcut(for: .arrangement(id)) == comboA)
        }
    }

    @Test("clearing an arrangement shortcut removes its key, notifies once and touches nothing else")
    func clearingRemovesTheKey() throws {
        try withScratchDefaults { defaults in
            let id = UUID()
            try seed(defaults, [key(id): comboA, WMCommand.leftHalf.rawValue: comboB, "future.thing": comboB])
            let settings = AppSettings(defaults: defaults)
            var calls = 0
            settings.onChange = { calls += 1 }

            #expect(settings.setShortcut(nil, for: .arrangement(id)) == nil)

            #expect(settings.shortcut(for: .arrangement(id)) == nil)
            #expect(settings.arrangementShortcuts.isEmpty)
            let set = try stored(defaults)
            #expect(set[key(id)] == nil)
            #expect(set["leftHalf"] == comboB)
            #expect(set["future.thing"] == comboB)
            #expect(calls == 1)
        }
    }

    // MARK: Ownership

    @Test("owner(using:) finds an arrangement, including through recorder-only flags")
    func ownerFindsArrangement() throws {
        try withScratchDefaults { defaults in
            let id = UUID()
            try seed(defaults, [key(id): comboA])
            let settings = AppSettings(defaults: defaults)

            #expect(settings.owner(using: comboA) == .arrangement(id))
            #expect(settings.owner(using: combo(kVK_ANSI_A, controlCommand.union(.function))) == .arrangement(id))
            #expect(settings.owner(using: comboB) == nil)
        }
    }

    @Test("when a command and an arrangement hold the same combination the command is the owner")
    func commandWinsOverArrangement() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, [key(UUID()): comboA, WMCommand.maximize.rawValue: comboA])

            let settings = AppSettings(defaults: defaults)

            #expect(settings.owner(using: comboA) == .command(.maximize))
        }
    }

    @Test("between two arrangements the smaller uuid string is the owner")
    func smallerUUIDWins() throws {
        try withScratchDefaults { defaults in
            let low = UUID(uuidString: "00000000-0000-4000-8000-000000000001") ?? UUID()
            let high = UUID(uuidString: "FFFFFFFF-0000-4000-8000-000000000001") ?? UUID()
            try seed(defaults, [key(high): comboA, key(low): comboA])

            #expect(AppSettings(defaults: defaults).owner(using: comboA) == .arrangement(low))
        }
    }

    @Test("recording a command's combination for an arrangement takes it from the command")
    func arrangementDisplacesCommand() throws {
        try withScratchDefaults { defaults in
            let id = UUID()
            let settings = AppSettings(defaults: defaults)
            let taken = try #require(WMCommand.leftHalf.defaultShortcut)

            let displaced = settings.setShortcut(taken, for: .arrangement(id))

            #expect(displaced == .command(.leftHalf))
            #expect(settings.shortcut(for: .leftHalf) == nil)
            #expect(settings.shortcut(for: .arrangement(id)) == taken)
            #expect(try stored(defaults)["leftHalf"] == nil)
        }
    }

    @Test("recording an arrangement's combination for a command takes it from the arrangement")
    func commandDisplacesArrangement() throws {
        try withScratchDefaults { defaults in
            let id = UUID()
            try seed(defaults, [key(id): comboA])
            let settings = AppSettings(defaults: defaults)

            let displaced = settings.setShortcut(comboA, for: .command(.center))

            #expect(displaced == .arrangement(id))
            #expect(settings.arrangementShortcuts.isEmpty)
            #expect(settings.shortcut(for: .center) == comboA)
            let set = try stored(defaults)
            #expect(set[key(id)] == nil)
            #expect(set["center"] == comboA)
        }
    }

    @Test("an arrangement shortcut for an arrangement id with no saved arrangement yields to a new owner")
    func orphanYieldsToNewOwner() throws {
        try withScratchDefaults { defaults in
            let orphan = UUID()
            let fresh = UUID()
            try seed(defaults, [key(orphan): comboA])
            let settings = AppSettings(defaults: defaults)

            #expect(settings.setShortcut(comboA, for: .arrangement(fresh)) == .arrangement(orphan))

            #expect(settings.arrangementShortcuts == [fresh: comboA])
        }
    }

    @Test("every other holder of a colliding combination loses it and the first in owner order is reported")
    func allHoldersAreDisplaced() throws {
        try withScratchDefaults { defaults in
            let id = UUID()
            try seed(defaults, [key(id): comboA, WMCommand.maximize.rawValue: comboA])
            let settings = AppSettings(defaults: defaults)

            let displaced = settings.setShortcut(comboA, for: .command(.center))

            #expect(displaced == .command(.maximize))
            #expect(settings.shortcut(for: .maximize) == nil)
            #expect(settings.shortcut(for: .arrangement(id)) == nil)
            #expect(settings.shortcut(for: .center) == comboA)
        }
    }

    @Test("assigning an owner its own combination displaces nobody")
    func ownCombinationDisplacesNobody() throws {
        try withScratchDefaults { defaults in
            let id = UUID()
            try seed(defaults, [key(id): comboA, WMCommand.leftHalf.rawValue: comboB])
            let settings = AppSettings(defaults: defaults)

            #expect(settings.setShortcut(comboA, for: .arrangement(id)) == nil)

            #expect(settings.shortcut(for: .arrangement(id)) == comboA)
            #expect(settings.shortcut(for: .leftHalf) == comboB)
        }
    }

    // MARK: Recording

    @Test("recording an owner notifies only when the recording owner changes and is not persisted")
    func recordingOwnerNotifiesOnChangeOnly() {
        withScratchDefaults { defaults in
            let id = UUID()
            let settings = AppSettings(defaults: defaults)
            var calls = 0
            settings.onChange = { calls += 1 }

            settings.setRecordingOwner(nil)
            #expect(calls == 0)

            settings.setRecordingOwner(.arrangement(id))
            #expect(calls == 1)
            #expect(settings.isRecordingShortcut)
            #expect(settings.recordingOwner == .arrangement(id))

            settings.setRecordingOwner(.arrangement(id))
            #expect(calls == 1)

            settings.setRecordingOwner(.command(.leftHalf))
            #expect(calls == 2)
            #expect(AppSettings(defaults: defaults).recordingOwner == nil)

            settings.setRecordingOwner(nil)
            #expect(calls == 3)
            #expect(!settings.isRecordingShortcut)
        }
    }

    // MARK: Versioning

    @Test("a stored set at the current version is not backfilled again and the marker stays 4")
    func currentVersionSetIsNotBackfilled() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, [key(UUID()): comboA, WMCommand.leftHalf.rawValue: comboB], version: 4)

            let settings = AppSettings(defaults: defaults)

            #expect(settings.shortcut(for: .leftThird) == nil)
            #expect(settings.shortcut(for: .zone1) == nil)
            #expect(defaults.integer(forKey: versionKey) == 4)
        }
    }

    @Test("a fresh install has no arrangement shortcuts and the marker is 4")
    func freshInstall() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)

            #expect(settings.arrangementShortcuts.isEmpty)
            #expect(defaults.integer(forKey: versionKey) == 4)
        }
    }

    @Test("a backfill of an older set keeps the arrangement entry and reserves its combination")
    func backfillKeepsArrangementEntry() throws {
        try withScratchDefaults { defaults in
            let id = UUID()
            let leftThird = try #require(WMCommand.leftThird.defaultShortcut)
            try seed(defaults, [key(id): leftThird, WMCommand.leftHalf.rawValue: comboB], version: 2)

            let settings = AppSettings(defaults: defaults)

            #expect(settings.shortcut(for: .arrangement(id)) == leftThird)
            #expect(settings.shortcut(for: .leftThird) == nil)
            #expect(try stored(defaults)[key(id)] == leftThird)
            #expect(defaults.integer(forKey: versionKey) == 4)
        }
    }

    // MARK: Auto rules switch and next grid

    @Test("auto rules are on by default and the switch is persisted and notifies")
    func autoRulesSwitch() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            #expect(settings.autoRulesEnabled)
            var calls = 0
            settings.onChange = { calls += 1 }

            settings.autoRulesEnabled = false

            #expect(calls == 1)
            #expect(defaults.object(forKey: autoRulesKey) as? Bool == false)
            #expect(!AppSettings(defaults: defaults).autoRulesEnabled)
        }
    }

    @Test("the next grid command has no default shortcut and registers under the window manager switch")
    func nextGridCommand() {
        withScratchDefaults { defaults in
            #expect(WMCommand.nextGrid.defaultShortcut == nil)
            #expect(WMCommand.nextGrid.isWindowCommand)
            #expect(WMCommand.nextGrid.rawValue == "nextGrid")
            #expect(AppSettings(defaults: defaults).shortcut(for: .nextGrid) == nil)
            #expect(HotKeyRegistrar.shouldRegister(
                .nextGrid, windowManagerEnabled: true, ultraSwitchEnabled: false, autoConvertEnabled: false))
            #expect(!HotKeyRegistrar.shouldRegister(
                .nextGrid, windowManagerEnabled: false, ultraSwitchEnabled: true, autoConvertEnabled: true))
        }
    }
}
