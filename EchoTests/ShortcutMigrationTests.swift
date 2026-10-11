import AppKit
import Carbon.HIToolbox
import Testing
@testable import Echo

// The stored shortcut set is user data: a read never overwrites, deletes or revives what the user chose.
private let storeKey = "wm.shortcuts"
private let versionKey = "wm.shortcuts.version"
private let currentVersion = 3

private let controlCommand: NSEvent.ModifierFlags = [.control, .command]
private let controlOptionCommand: NSEvent.ModifierFlags = [.control, .option, .command]

private let layoutCommands: [WMCommand] = [
    .leftHalf, .rightHalf, .topHalf, .bottomHalf, .topLeft, .topRight, .bottomLeft, .bottomRight,
    .center, .maximize
]
private let ultraCommands: [WMCommand] = [.switchLayout, .convertWord, .translateSelection]
private let addedCommands: [WMCommand] = [
    .leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds, .nextDisplay, .previousDisplay
]

private func shortcut(_ keyCode: Int, _ flags: NSEvent.ModifierFlags) -> KeyboardShortcut {
    KeyboardShortcut(keyCode: UInt32(keyCode), flags: flags)
}

/// The set a pre-thirds build stored for an untouched install.
private func legacySet(includingUltraSwitch: Bool = true) -> [String: KeyboardShortcut] {
    var commands = layoutCommands + [.openClipboard]
    if includingUltraSwitch { commands += ultraCommands }
    return Dictionary(uniqueKeysWithValues: commands.map { ($0.rawValue, $0.defaultShortcut!) })
}

private func seed(_ defaults: UserDefaults, _ set: [String: KeyboardShortcut], version: Int?) throws {
    defaults.set(try JSONEncoder().encode(set), forKey: storeKey)
    if let version { defaults.set(version, forKey: versionKey) }
}

private func storedSet(_ defaults: UserDefaults) throws -> [String: KeyboardShortcut] {
    let data = try #require(defaults.data(forKey: storeKey))
    return try JSONDecoder().decode([String: KeyboardShortcut].self, from: data)
}

@MainActor
private func expectDefaults(
    _ settings: AppSettings, for commands: [WMCommand],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    for command in commands {
        #expect(settings.shortcut(for: command) == command.defaultShortcut, "\(command)", sourceLocation: sourceLocation)
    }
}

@MainActor
private func expectBound(
    _ settings: AppSettings, _ command: WMCommand, to expected: KeyboardShortcut?,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(settings.shortcut(for: command) == expected, "\(command)", sourceLocation: sourceLocation)
}

@MainActor
@Suite("Shortcut set migration")
struct ShortcutMigrationTests {

    // MARK: Fresh install

    @Test("a fresh install gets every default and records the current version")
    func freshInstallGetsAllDefaults() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)

            expectDefaults(settings, for: WMCommand.allCases)
            #expect(defaults.integer(forKey: versionKey) == currentVersion)
        }
    }

    // MARK: Upgrade from the previous version

    @Test("upgrading keeps a rebound combination in place and adds the seven new defaults")
    func upgradeKeepsReboundShortcutAndAddsNewCommands() throws {
        try withScratchDefaults { defaults in
            var set = legacySet()
            let rebound = shortcut(kVK_ANSI_H, controlCommand)
            set["leftHalf"] = rebound
            try seed(defaults, set, version: 2)

            let settings = AppSettings(defaults: defaults)

            expectBound(settings, .leftHalf, to: rebound)
            for command in layoutCommands + [.openClipboard] + ultraCommands where command != .leftHalf {
                expectBound(settings, command, to: command.defaultShortcut)
            }
            expectDefaults(settings, for: addedCommands)
        }
    }

    @Test("upgrading persists the merged set and the new version marker")
    func upgradePersistsMergedSet() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, legacySet(), version: 2)

            _ = AppSettings(defaults: defaults)

            let stored = try storedSet(defaults)
            #expect(Set(stored.keys) == Set(WMCommand.allCases.map(\.rawValue)))
            #expect(defaults.integer(forKey: versionKey) == currentVersion)
        }
    }

    @Test("a new command stays unbound when the user already owns its default combination")
    func userOwnedCombinationBlocksNewDefault() throws {
        try withScratchDefaults { defaults in
            var set = legacySet()
            let claimed = WMCommand.leftThird.defaultShortcut!
            set["maximize"] = claimed
            try seed(defaults, set, version: 2)

            let settings = AppSettings(defaults: defaults)

            expectBound(settings, .leftThird, to: nil)
            expectBound(settings, .maximize, to: claimed)
            expectDefaults(settings, for: addedCommands.filter { $0 != .leftThird })
            #expect(AppSettings(defaults: defaults).shortcut(for: .leftThird) == nil)
        }
    }

    @Test("a combination the user owns with an extra fn flag still blocks the colliding default")
    func recorderFlagsOnStoredShortcutStillBlock() throws {
        try withScratchDefaults { defaults in
            var set = legacySet()
            let stored = shortcut(kVK_ANSI_F, controlOptionCommand.union(.function))
            set["maximize"] = stored
            try seed(defaults, set, version: 2)

            let settings = AppSettings(defaults: defaults)

            expectBound(settings, .centerThird, to: nil)
            expectBound(settings, .maximize, to: stored)
        }
    }

    @Test("a shortcut the user removed is not brought back, new defaults are still added")
    func removedShortcutStaysRemoved() throws {
        try withScratchDefaults { defaults in
            var set = legacySet()
            set.removeValue(forKey: "leftHalf")
            set.removeValue(forKey: "translateSelection")
            try seed(defaults, set, version: 2)

            let settings = AppSettings(defaults: defaults)

            expectBound(settings, .leftHalf, to: nil)
            expectBound(settings, .translateSelection, to: nil)
            expectDefaults(settings, for: addedCommands)
            #expect(try storedSet(defaults)["leftHalf"] == nil)
        }
    }

    // MARK: Sets without a trustworthy version

    @Test("a set without a version marker is read as the first version: window commands stay removed, newer ones arrive",
          arguments: [nil, 1] as [Int?])
    func unversionedSetIsTreatedAsFirstVersion(version: Int?) throws {
        try withScratchDefaults { defaults in
            var set = legacySet(includingUltraSwitch: false)
            set.removeValue(forKey: "leftHalf")
            set.removeValue(forKey: "topHalf")
            let rebound = shortcut(kVK_ANSI_H, controlCommand)
            set["rightHalf"] = rebound
            try seed(defaults, set, version: version)

            let settings = AppSettings(defaults: defaults)

            expectBound(settings, .leftHalf, to: nil)
            expectBound(settings, .topHalf, to: nil)
            expectBound(settings, .rightHalf, to: rebound)
            expectDefaults(settings, for: ultraCommands)
            expectDefaults(settings, for: addedCommands)
            #expect(defaults.integer(forKey: versionKey) == currentVersion)
        }
    }

    @Test("a version marker newer than the app leaves the set and the marker untouched")
    func newerVersionMarkerIsRespected() throws {
        try withScratchDefaults { defaults in
            var set = legacySet()
            set.removeValue(forKey: "leftHalf")
            try seed(defaults, set, version: currentVersion + 1)

            let settings = AppSettings(defaults: defaults)

            for command in addedCommands { expectBound(settings, command, to: nil) }
            expectBound(settings, .leftHalf, to: nil)
            #expect(defaults.integer(forKey: versionKey) == currentVersion + 1)
            #expect(try storedSet(defaults) == set)
        }
    }

    // MARK: Foreign keys and odd values

    @Test("a stored key that is not a command survives reading and writing")
    func unknownKeySurvivesRoundTrip() throws {
        try withScratchDefaults { defaults in
            let key = "arrangement:\(UUID().uuidString)"
            let combination = shortcut(kVK_ANSI_9, controlOptionCommand)
            var set = legacySet()
            set[key] = combination
            try seed(defaults, set, version: 2)

            let settings = AppSettings(defaults: defaults)
            #expect(try storedSet(defaults)[key] == combination)

            settings.setShortcut(shortcut(kVK_ANSI_H, controlCommand), for: .center)
            #expect(try storedSet(defaults)[key] == combination)
        }
    }

    @Test("a combination held by an unknown key blocks the colliding default")
    func unknownKeyBlocksCollidingDefault() throws {
        try withScratchDefaults { defaults in
            let key = "arrangement:\(UUID().uuidString)"
            var set = legacySet()
            set[key] = WMCommand.leftThird.defaultShortcut!
            try seed(defaults, set, version: 2)

            let settings = AppSettings(defaults: defaults)

            expectBound(settings, .leftThird, to: nil)
            expectDefaults(settings, for: addedCommands.filter { $0 != .leftThird })
            #expect(try storedSet(defaults)[key] == WMCommand.leftThird.defaultShortcut)
        }
    }

    @Test("two commands on one combination both keep it and nothing new is added on top")
    func duplicatedCombinationIsKept() throws {
        try withScratchDefaults { defaults in
            var set = legacySet()
            let duplicate = WMCommand.centerThird.defaultShortcut!
            set["center"] = duplicate
            set["maximize"] = duplicate
            try seed(defaults, set, version: 2)

            let settings = AppSettings(defaults: defaults)

            expectBound(settings, .center, to: duplicate)
            expectBound(settings, .maximize, to: duplicate)
            expectBound(settings, .centerThird, to: nil)
            expectDefaults(settings, for: addedCommands.filter { $0 != .centerThird })
            let stored = try storedSet(defaults)
            #expect(stored["center"] == duplicate)
            #expect(stored["maximize"] == duplicate)
        }
    }

    @Test("a value with an extra field still decodes and the set is not reset to defaults")
    func extraFieldInStoredValueIsTolerated() throws {
        withScratchDefaults { defaults in
            let controlCommandRaw = UInt32(controlCommand.rawValue)
            let json = """
            {
              "leftHalf": {"keyCode": \(kVK_ANSI_H), "modifiers": \(controlCommandRaw), "label": "custom"},
              "rightHalf": {"keyCode": \(kVK_RightArrow), "modifiers": \(controlCommandRaw)}
            }
            """
            defaults.set(Data(json.utf8), forKey: storeKey)
            defaults.set(2, forKey: versionKey)

            let settings = AppSettings(defaults: defaults)

            expectBound(settings, .leftHalf, to: shortcut(kVK_ANSI_H, controlCommand))
            expectBound(settings, .rightHalf, to: shortcut(kVK_RightArrow, controlCommand))
            expectBound(settings, .topHalf, to: nil)
        }
    }

    // MARK: Repeat launches

    @Test("launching again at the current version changes neither the set nor the marker")
    func relaunchIsIdempotent() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, legacySet(), version: 2)
            _ = AppSettings(defaults: defaults)
            let afterFirst = try storedSet(defaults)

            let second = AppSettings(defaults: defaults)

            #expect(try storedSet(defaults) == afterFirst)
            #expect(defaults.integer(forKey: versionKey) == currentVersion)
            for command in WMCommand.allCases {
                expectBound(second, command, to: afterFirst[command.rawValue])
            }
        }
    }

    @Test("a default the user cleared after the upgrade is not re-added on the next launch")
    func clearedNewDefaultStaysCleared() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, legacySet(), version: 2)
            let first = AppSettings(defaults: defaults)
            first.setShortcut(nil, for: .leftThird)

            let second = AppSettings(defaults: defaults)

            expectBound(second, .leftThird, to: nil)
            expectDefaults(second, for: addedCommands.filter { $0 != .leftThird })
        }
    }

    // MARK: Damaged data

    @Test("data that is not a shortcut dictionary falls back to defaults without crashing",
          arguments: ["not json at all", "[1, 2, 3]", "{\"leftHalf\": 5}"])
    func damagedDataFallsBackToDefaults(raw: String) {
        withScratchDefaults { defaults in
            defaults.set(Data(raw.utf8), forKey: storeKey)
            defaults.set(2, forKey: versionKey)

            let settings = AppSettings(defaults: defaults)

            expectDefaults(settings, for: WMCommand.allCases)
        }
    }

    @Test("a stored value of the wrong type falls back to defaults")
    func wrongStorageTypeFallsBackToDefaults() {
        withScratchDefaults { defaults in
            defaults.set("oops", forKey: storeKey)

            let settings = AppSettings(defaults: defaults)

            expectDefaults(settings, for: WMCommand.allCases)
        }
    }
}
