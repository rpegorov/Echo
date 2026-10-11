import AppKit
import Carbon.HIToolbox
import Testing
@testable import Echo

private let storeKey = "wm.shortcuts"
private let versionKey = "wm.shortcuts.version"
private let storeVersionWithDuplicates = 2
private let controlCommand: NSEvent.ModifierFlags = [.control, .command]
private let leftArrow = KeyboardShortcut(keyCode: UInt32(kVK_LeftArrow), flags: controlCommand)
private let leftArrowWithRecorderFlags = KeyboardShortcut(
    keyCode: UInt32(kVK_LeftArrow), flags: controlCommand.union([.function, .numericPad]))

private func seed(_ defaults: UserDefaults, _ set: [WMCommand: KeyboardShortcut]) throws {
    let stringKeyed = Dictionary(uniqueKeysWithValues: set.map { ($0.key.rawValue, $0.value) })
    defaults.set(try JSONEncoder().encode(stringKeyed), forKey: storeKey)
    defaults.set(storeVersionWithDuplicates, forKey: versionKey)
}

@MainActor
private func holders(of shortcut: KeyboardShortcut, in settings: AppSettings) -> [WMCommand] {
    WMCommand.allCases.filter { settings.shortcut(for: $0).map(shortcut.collides(with:)) ?? false }
}

@MainActor
@Suite("AppSettings shortcut assignment over a store holding duplicate combinations")
struct AppSettingsDuplicateShortcutTests {

    @Test("every owner of a duplicated combination loses it and the first one in command order is reported")
    func allDuplicateOwnersAreDisplaced() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, [.leftHalf: leftArrow, .center: leftArrow])
            let settings = AppSettings(defaults: defaults)

            let displaced = settings.setShortcut(leftArrow, for: .maximize)

            #expect(displaced == .leftHalf)
            #expect(settings.shortcut(for: .leftHalf) == nil)
            #expect(settings.shortcut(for: .center) == nil)
            #expect(settings.shortcut(for: .maximize) == leftArrow)
            #expect(holders(of: leftArrow, in: settings) == [.maximize])
        }
    }

    @Test("the cleaned-up assignment is what a restart reads back")
    func cleanedAssignmentSurvivesRestart() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, [.leftHalf: leftArrow, .center: leftArrow])
            let settings = AppSettings(defaults: defaults)
            settings.setShortcut(leftArrow, for: .maximize)

            let restarted = AppSettings(defaults: defaults)

            #expect(restarted.shortcut(for: .leftHalf) == nil)
            #expect(restarted.shortcut(for: .center) == nil)
            #expect(restarted.shortcut(for: .maximize) == leftArrow)
            #expect(holders(of: leftArrow, in: restarted) == [.maximize])
        }
    }

    @Test("an owner holding the combination with recorder flags is displaced along with the plain owner")
    func recorderFlagOwnerIsDisplacedToo() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, [.leftHalf: leftArrowWithRecorderFlags, .center: leftArrow])
            let settings = AppSettings(defaults: defaults)

            let displaced = settings.setShortcut(leftArrow, for: .maximize)

            #expect(displaced == .leftHalf)
            #expect(settings.shortcut(for: .leftHalf) == nil)
            #expect(settings.shortcut(for: .center) == nil)
            #expect(holders(of: leftArrow, in: settings) == [.maximize])
        }
    }

    @Test("a recorded combination with fn displaces every plain duplicate owner")
    func recordedFlagsDisplaceAllDuplicates() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, [.leftHalf: leftArrow, .center: leftArrow])
            let settings = AppSettings(defaults: defaults)

            settings.setShortcut(leftArrowWithRecorderFlags, for: .maximize)

            #expect(settings.shortcut(for: .leftHalf) == nil)
            #expect(settings.shortcut(for: .center) == nil)
            #expect(holders(of: leftArrow, in: settings) == [.maximize])
        }
    }

    @Test("assigning the combination to the later duplicate owner leaves it as the only holder")
    func assigningToLaterDuplicateOwnerClearsTheOther() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, [.leftHalf: leftArrow, .center: leftArrow])
            let settings = AppSettings(defaults: defaults)

            let displaced = settings.setShortcut(leftArrow, for: .center)

            #expect(displaced == .leftHalf)
            #expect(settings.shortcut(for: .leftHalf) == nil)
            #expect(settings.shortcut(for: .center) == leftArrow)
            #expect(holders(of: leftArrow, in: settings) == [.center])
        }
    }

    @Test("assigning the combination to the first duplicate owner clears the later one and reports it")
    func assigningToFirstOwnerReportsLaterOne() throws {
        try withScratchDefaults { defaults in
            try seed(defaults, [.leftHalf: leftArrow, .center: leftArrow])
            let settings = AppSettings(defaults: defaults)

            let displaced = settings.setShortcut(leftArrow, for: .leftHalf)

            #expect(displaced == .center)
            #expect(settings.shortcut(for: .center) == nil)
            #expect(holders(of: leftArrow, in: settings) == [.leftHalf])
        }
    }
}
