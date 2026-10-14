import AppKit
import Carbon.HIToolbox
import Testing
@testable import Echo

private let controlCommand: NSEvent.ModifierFlags = [.control, .command]

@MainActor
@Suite("AppSettings shortcut assignment")
struct AppSettingsShortcutTests {

    @Test("reassigning a combination takes it from its previous command and reports that command")
    func reassignmentDisplacesPreviousOwner() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            let leftArrow = KeyboardShortcut(keyCode: UInt32(kVK_LeftArrow), flags: controlCommand)

            let displaced = settings.setShortcut(leftArrow, for: .rightHalf)

            #expect(displaced == .command(.leftHalf))
            #expect(settings.shortcut(for: .leftHalf) == nil)
            #expect(settings.shortcut(for: .rightHalf) == leftArrow)
            #expect(settings.owner(using: leftArrow) == .command(.rightHalf))
        }
    }

    @Test("a combination recorded with fn still displaces the owner of the plain combination")
    func recorderFlagsStillDisplace() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            let recorded = KeyboardShortcut(
                keyCode: UInt32(kVK_LeftArrow), flags: controlCommand.union([.function, .numericPad]))

            let displaced = settings.setShortcut(recorded, for: .topHalf)

            #expect(displaced == .command(.leftHalf))
            #expect(settings.shortcut(for: .leftHalf) == nil)
        }
    }

    @Test("assigning a command its own combination removes nothing")
    func sameCommandKeepsEverything() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            let before = WMCommand.allCases.map { settings.shortcut(for: $0) }
            let own = KeyboardShortcut(
                keyCode: UInt32(kVK_LeftArrow), flags: controlCommand.union(.function))

            let displaced = settings.setShortcut(own, for: .leftHalf)

            #expect(displaced == nil)
            #expect(WMCommand.allCases.map { settings.shortcut(for: $0) }.filter { $0 != nil }.count
                    == before.filter { $0 != nil }.count)
            #expect(settings.shortcut(for: .leftHalf) == own)
        }
    }

    @Test("a free combination displaces nobody and leaves other commands alone")
    func freeCombinationDisplacesNobody() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            let free = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_H), flags: [.control, .option, .command, .shift])

            #expect(settings.setShortcut(free, for: .center) == nil)
            #expect(settings.shortcut(for: .center) == free)
            #expect(settings.shortcut(for: .maximize) == WMCommand.maximize.defaultShortcut)
            #expect(settings.shortcut(for: .leftHalf) == WMCommand.leftHalf.defaultShortcut)
        }
    }

    @Test("clearing a shortcut removes it and displaces nobody")
    func clearingRemovesOnlyThatCommand() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)

            #expect(settings.setShortcut(nil, for: .topHalf) == nil)

            #expect(settings.shortcut(for: .topHalf) == nil)
            #expect(settings.shortcut(for: .bottomHalf) == WMCommand.bottomHalf.defaultShortcut)
        }
    }

    @Test("a reassignment survives a restart and the displaced command stays unbound")
    func reassignmentIsPersisted() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            let leftArrow = KeyboardShortcut(keyCode: UInt32(kVK_LeftArrow), flags: controlCommand)
            settings.setShortcut(leftArrow, for: .rightHalf)

            let restarted = AppSettings(defaults: defaults)

            #expect(restarted.shortcut(for: .rightHalf) == leftArrow)
            #expect(restarted.shortcut(for: .leftHalf) == nil)
        }
    }

    @Test("setShortcut notifies once per call, displacement included")
    func setShortcutNotifiesOnce() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            var calls = 0
            settings.onChange = { calls += 1 }

            settings.setShortcut(WMCommand.leftHalf.defaultShortcut, for: .rightHalf)
            #expect(calls == 1)
            settings.setShortcut(nil, for: .center)
            #expect(calls == 2)
        }
    }

    @Test("recording notifies only when the recording command changes")
    func recordingNotifiesOnChangeOnly() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            var calls = 0
            settings.onChange = { calls += 1 }

            settings.setRecordingOwner(nil)
            #expect(calls == 0)
            #expect(!settings.isRecordingShortcut)

            settings.setRecordingOwner(.command(.leftHalf))
            #expect(calls == 1)
            #expect(settings.isRecordingShortcut)
            #expect(settings.recordingOwner == .command(.leftHalf))

            settings.setRecordingOwner(.command(.leftHalf))
            #expect(calls == 1)

            settings.setRecordingOwner(nil)
            #expect(calls == 2)
            #expect(!settings.isRecordingShortcut)
            #expect(settings.recordingOwner == nil)
        }
    }

    @Test("starting another recording replaces the current one")
    func newRecordingReplacesCurrent() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            var calls = 0
            settings.onChange = { calls += 1 }

            settings.setRecordingOwner(.command(.leftHalf))
            settings.setRecordingOwner(.command(.rightHalf))

            #expect(settings.recordingOwner == .command(.rightHalf))
            #expect(calls == 2)
        }
    }

    @Test("the recording state is not persisted")
    func recordingIsNotPersisted() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            settings.setRecordingOwner(.command(.leftHalf))

            let restarted = AppSettings(defaults: defaults)

            #expect(restarted.recordingOwner == nil)
        }
    }

    @Test("layout cycling is on by default and the choice is persisted")
    func layoutCyclingDefaultAndPersistence() {
        withScratchDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            #expect(settings.layoutCyclingEnabled)

            settings.layoutCyclingEnabled = false

            #expect(!AppSettings(defaults: defaults).layoutCyclingEnabled)
        }
    }
}
