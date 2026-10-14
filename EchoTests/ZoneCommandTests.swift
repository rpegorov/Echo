import AppKit
import Carbon.HIToolbox
import Testing
@testable import Echo

private let zoneCommands: [WMCommand] = [.zone1, .zone2, .zone3, .zone4, .zone5, .zone6, .zone7, .zone8, .zone9]
private let digitKeyCodes = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                             kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]

private let storeKey = "wm.shortcuts"
private let versionKey = "wm.shortcuts.version"
private let modifierKey = "wm.gridModifier"

private func shortcut(_ keyCode: Int, _ flags: NSEvent.ModifierFlags) -> KeyboardShortcut {
    KeyboardShortcut(keyCode: UInt32(keyCode), flags: flags)
}

private func zoneShortcut(_ number: Int) -> KeyboardShortcut {
    shortcut(digitKeyCodes[number - 1], [.control, .option])
}

/// The shortcut set an install holds before the zone commands exist: every default but the zones.
private func versionThreeSet() -> [String: KeyboardShortcut] {
    var set: [String: KeyboardShortcut] = [:]
    for command in WMCommand.allCases where command.zoneNumber == nil {
        if let defaultShortcut = command.defaultShortcut { set[command.rawValue] = defaultShortcut }
    }
    return set
}

private func seed(_ defaults: UserDefaults, _ set: [String: KeyboardShortcut], version: Int) throws {
    defaults.set(try JSONEncoder().encode(set), forKey: storeKey)
    defaults.set(version, forKey: versionKey)
}

private func storedSet(_ defaults: UserDefaults) throws -> [String: KeyboardShortcut] {
    let data = try #require(defaults.data(forKey: storeKey))
    return try JSONDecoder().decode([String: KeyboardShortcut].self, from: data)
}

@Suite("Zone commands")
struct ZoneCommandTests {

    @Test("zone commands sit on control-option plus the digit of their number")
    func zoneDefaults() {
        for number in 1...9 {
            #expect(WMCommand.zone(number)?.defaultShortcut == zoneShortcut(number), "zone \(number)")
        }
    }

    @Test("zone numbers 1 to 9 map to commands and back; anything else maps to none")
    func zoneNumbers() {
        for number in 1...9 { #expect(WMCommand.zone(number)?.zoneNumber == number) }
        for number in [-1, 0, 10, 100] { #expect(WMCommand.zone(number) == nil, "\(number)") }
        #expect(zoneCommands.compactMap(\.zoneNumber) == Array(1...9))
    }

    @Test("zone commands are window commands and not Ultra Switch commands", arguments: zoneCommands)
    func zoneCommandKind(command: WMCommand) {
        #expect(command.isWindowCommand)
        #expect(!command.isUltraSwitchCommand)
        #expect(command.layout == nil)
        #expect(command.displayDirection == nil)
    }

    @Test("no zone default collides with the default of any other command")
    func zonesAreFreeOfOtherDefaults() {
        for zone in zoneCommands {
            let own = zone.defaultShortcut
            for other in WMCommand.allCases where other != zone {
                guard let own, let theirs = other.defaultShortcut else { continue }
                #expect(!own.collides(with: theirs), "\(zone) collides with \(other)")
            }
        }
    }

    @Test("no zone default takes a combination macOS already uses")
    func zonesAvoidSystemCombinations() {
        var reserved = digitKeyCodes.map { shortcut($0, [.control]) }
        reserved += [shortcut(kVK_Space, [.control, .option]),
                     shortcut(kVK_ANSI_3, [.shift, .command]),
                     shortcut(kVK_ANSI_4, [.shift, .command])]
        for zone in zoneCommands {
            guard let own = zone.defaultShortcut else { continue }
            for taken in reserved { #expect(!own.collides(with: taken), "\(zone)") }
        }
    }

    @Test("a zone shortcut matches by physical key under a non-Latin layout")
    func zoneMatchesPhysicalKey() {
        let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.control, .option], timestamp: 0, windowNumber: 0,
            context: nil, characters: "¡", charactersIgnoringModifiers: "1", isARepeat: false,
            keyCode: UInt16(kVK_ANSI_1))
        guard let event else {
            Issue.record("could not build a key event")
            return
        }
        #expect(zoneShortcut(1).matches(keyCode: UInt32(event.keyCode), flags: event.modifierFlags))
    }
}

@MainActor
@Suite("Zone shortcut backfill")
struct ZoneBackfillTests {

    @Test("a stored set of the previous version gains exactly the nine zone defaults")
    func previousSetGainsZones() throws {
        try withScratchDefaults { defaults in
            let before = versionThreeSet()
            try seed(defaults, before, version: 3)

            let settings = AppSettings(defaults: defaults)

            for number in 1...9 {
                #expect(settings.shortcut(for: try #require(WMCommand.zone(number))) == zoneShortcut(number), "zone \(number)")
            }
            let stored = try storedSet(defaults)
            #expect(stored.count == before.count + 9)
            for (key, value) in before { #expect(stored[key] == value, "\(key)") }
            #expect(defaults.integer(forKey: versionKey) == 4)
        }
    }

    @Test("a user combination on control-option-1 leaves zone 1 unbound and zones 2 to 9 bound")
    func userOwnedZoneCombination() throws {
        try withScratchDefaults { defaults in
            var set = versionThreeSet()
            let mine = zoneShortcut(1)
            set["leftThird"] = mine
            try seed(defaults, set, version: 3)

            let settings = AppSettings(defaults: defaults)

            #expect(settings.shortcut(for: .zone1) == nil)
            #expect(settings.shortcut(for: .leftThird) == mine)
            for number in 2...9 {
                #expect(settings.shortcut(for: try #require(WMCommand.zone(number))) == zoneShortcut(number), "zone \(number)")
            }
        }
    }

    @Test("a combination held under a foreign key blocks the zone default and survives")
    func foreignKeyBlocksZone() throws {
        try withScratchDefaults { defaults in
            var set = versionThreeSet()
            let key = "arrangement:\(UUID().uuidString)"
            set[key] = zoneShortcut(2)
            try seed(defaults, set, version: 3)

            let settings = AppSettings(defaults: defaults)

            #expect(settings.shortcut(for: .zone2) == nil)
            #expect(settings.shortcut(for: .zone1) == zoneShortcut(1))
            #expect(try storedSet(defaults)[key] == zoneShortcut(2))
        }
    }

    @Test("a shortcut the user removed before the upgrade stays removed")
    func removedShortcutStaysRemoved() throws {
        try withScratchDefaults { defaults in
            var set = versionThreeSet()
            set.removeValue(forKey: "leftHalf")
            set.removeValue(forKey: "nextDisplay")
            try seed(defaults, set, version: 3)

            let settings = AppSettings(defaults: defaults)

            #expect(settings.shortcut(for: .leftHalf) == nil)
            #expect(settings.shortcut(for: .nextDisplay) == nil)
            #expect(settings.shortcut(for: .zone5) == zoneShortcut(5))
        }
    }

    @Test("running the upgrade twice changes nothing the second time")
    func upgradeIsIdempotent() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, versionThreeSet(), version: 3)
            _ = AppSettings(defaults: defaults)
            let afterFirst = try storedSet(defaults)

            let second = AppSettings(defaults: defaults)

            #expect(try storedSet(defaults) == afterFirst)
            #expect(defaults.integer(forKey: versionKey) == 4)
            for number in 1...9 {
                #expect(second.shortcut(for: try #require(WMCommand.zone(number))) == zoneShortcut(number))
            }
        }
    }

    @Test("a zone shortcut the user cleared after the upgrade is not brought back")
    func clearedZoneStaysCleared() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, versionThreeSet(), version: 3)
            let first = AppSettings(defaults: defaults)
            first.setShortcut(nil, for: .zone3)

            let second = AppSettings(defaults: defaults)

            #expect(second.shortcut(for: .zone3) == nil)
            #expect(second.shortcut(for: .zone4) == zoneShortcut(4))
        }
    }
}

@MainActor
@Suite("Grid drag modifier setting")
struct GridModifierSettingTests {

    @Test("a fresh install uses option")
    func defaultIsOption() {
        withScratchDefaults { defaults in
            #expect(AppSettings(defaults: defaults).gridModifier == .option)
        }
    }

    @Test("the chosen modifier survives a restart", arguments: GridDragModifier.allCases)
    func survivesRestart(modifier: GridDragModifier) {
        withScratchDefaults { defaults in
            AppSettings(defaults: defaults).gridModifier = modifier
            #expect(AppSettings(defaults: defaults).gridModifier == modifier)
        }
    }

    @Test("an unknown stored value reads as option", arguments: ["control", "", "OPTION", "shift"])
    func unknownValueFallsBack(raw: String) {
        withScratchDefaults { defaults in
            defaults.set(raw, forKey: modifierKey)
            #expect(AppSettings(defaults: defaults).gridModifier == .option)
        }
    }

    @Test("a stored value of the wrong type reads as option")
    func wrongTypeFallsBack() {
        withScratchDefaults { defaults in
            defaults.set(5, forKey: modifierKey)
            #expect(AppSettings(defaults: defaults).gridModifier == .option)
        }
    }

    @Test("control is never a grid modifier and option is reported only where it is held")
    func modifierFlags() {
        for modifier in GridDragModifier.allCases {
            #expect(!modifier.flags.contains(.control), "\(modifier)")
        }
        #expect(GridDragModifier.spanFlags == [.control])
        #expect(GridDragModifier.option.usesOption)
        #expect(GridDragModifier.optionCommand.usesOption)
        #expect(!GridDragModifier.command.usesOption)
    }
}
