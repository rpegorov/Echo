import AppKit
import Carbon.HIToolbox
import Testing
@testable import Echo

private let controlCommand: NSEvent.ModifierFlags = [.control, .command]
private let controlOptionCommand: NSEvent.ModifierFlags = [.control, .option, .command]

private func keyEvent(keyCode: Int, characters: String, flags: NSEvent.ModifierFlags) -> NSEvent {
    NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
        context: nil, characters: characters, charactersIgnoringModifiers: characters,
        isARepeat: false, keyCode: UInt16(keyCode))!
}

@Suite("Window manager commands")
struct WMCommandTests {

    @Test("default shortcuts are unique under the collision rule")
    func defaultsDoNotCollide() {
        let defaults = WMCommand.allCases.compactMap { command in command.defaultShortcut.map { (command, $0) } }
        for (i, first) in defaults.enumerated() {
            for second in defaults[(i + 1)...] {
                #expect(!first.1.collides(with: second.1), "\(first.0) collides with \(second.0)")
            }
        }
    }

    @Test("no default takes a combination the system already uses",
          arguments: [
            ("control-command-F", kVK_ANSI_F, controlCommand),
            ("control-command-D", kVK_ANSI_D, controlCommand),
            ("control-command-Q", kVK_ANSI_Q, controlCommand),
            ("control-command-Space", kVK_Space, controlCommand),
            ("control-option-command-8", kVK_ANSI_8, controlOptionCommand),
            ("control-option-command-comma", kVK_ANSI_Comma, controlOptionCommand),
            ("control-option-command-period", kVK_ANSI_Period, controlOptionCommand)
          ])
    func defaultsAvoidSystemCombinations(name: String, keyCode: Int, flags: NSEvent.ModifierFlags) {
        let reserved = KeyboardShortcut(keyCode: UInt32(keyCode), flags: flags)
        for command in WMCommand.allCases {
            if let shortcut = command.defaultShortcut {
                #expect(!shortcut.collides(with: reserved), "\(command) takes \(name)")
            }
        }
    }

    @Test("the new layout and display commands use the control-option-command family from the plan",
          arguments: [
            (WMCommand.leftThird, kVK_ANSI_D),
            (.centerThird, kVK_ANSI_F),
            (.rightThird, kVK_ANSI_G),
            (.leftTwoThirds, kVK_ANSI_E),
            (.rightTwoThirds, kVK_ANSI_T),
            (.previousDisplay, kVK_LeftArrow),
            (.nextDisplay, kVK_RightArrow)
          ])
    func newCommandDefaults(command: WMCommand, keyCode: Int) {
        let shortcut = command.defaultShortcut
        #expect(shortcut?.keyCode == UInt32(keyCode))
        #expect(shortcut?.collides(with: KeyboardShortcut(keyCode: UInt32(keyCode), flags: controlOptionCommand)) == true)
    }

    @Test("every command that is not a layout, a display move or a grid command is a clipboard or Ultra Switch command")
    func windowCommandsAreLayoutsOrDisplays() {
        let others: Set<WMCommand> = [.openClipboard, .switchLayout, .convertWord, .translateSelection]
        for command in WMCommand.allCases {
            let expected = !others.contains(command)
            #expect(command.isWindowCommand == expected, "\(command)")
            if command.isWindowCommand {
                let kinds = [command.layout != nil, command.displayDirection != nil, command.zoneNumber != nil]
                let expectedKinds = command == .nextGrid ? 0 : 1
                #expect(kinds.filter { $0 }.count == expectedKinds, "\(command)")
                #expect(!command.isUltraSwitchCommand, "\(command)")
            }
        }
        #expect(WMCommand.nextDisplay.displayDirection == .next)
        #expect(WMCommand.previousDisplay.displayDirection == .previous)
        #expect(WMCommand.nextDisplay.layout == nil)
        #expect(WMCommand.previousDisplay.layout == nil)
    }

    @Test("every layout is reachable from exactly one command")
    func layoutsMapBackToOneCommand() {
        let layouts = WMCommand.allCases.compactMap(\.layout)
        #expect(Set(layouts) == Set(WindowLayout.allCases))
        #expect(layouts.count == WindowLayout.allCases.count)
    }

    @Test("every command has a default and a title present in English and Russian")
    @MainActor
    func commandsHaveDefaultsAndTitles() {
        let en = Localizer(preference: .fixed(.en))
        let ru = Localizer(preference: .fixed(.ru))
        var englishTitles: Set<String> = []
        for command in WMCommand.allCases {
            if command == .nextGrid {
                #expect(command.defaultShortcut == nil)
            } else {
                #expect(command.defaultShortcut != nil, "\(command) has no default")
            }
            let english = en.t(command.titleKey)
            let russian = ru.t(command.titleKey)
            #expect(english != command.titleKey.rawValue, "\(command) title missing in en")
            #expect(russian != command.titleKey.rawValue, "\(command) title missing in ru")
            englishTitles.insert(english)
        }
        #expect(englishTitles.count == WMCommand.allCases.count)
    }

    @Test("each command reports the shortcut-set version that introduced it")
    func introducedVersions() {
        let original: [WMCommand] = [.leftHalf, .rightHalf, .topHalf, .bottomHalf, .topLeft, .topRight,
                                     .bottomLeft, .bottomRight, .center, .maximize, .openClipboard]
        let ultra: [WMCommand] = [.switchLayout, .convertWord, .translateSelection]
        let added: [WMCommand] = [.leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds,
                                  .nextDisplay, .previousDisplay]
        for command in original { #expect(command.introducedInShortcutsVersion == 1, "\(command)") }
        for command in ultra { #expect(command.introducedInShortcutsVersion == 2, "\(command)") }
        let zones: [WMCommand] = [.zone1, .zone2, .zone3, .zone4, .zone5, .zone6, .zone7, .zone8, .zone9]
        for command in added { #expect(command.introducedInShortcutsVersion == 3, "\(command)") }
        for command in zones { #expect(command.introducedInShortcutsVersion == 4, "\(command)") }
        // No default shortcut, so the backfill has nothing to add whatever the version says.
        #expect(WMCommand.nextGrid.introducedInShortcutsVersion == 1)
        #expect(original.count + ultra.count + added.count + zones.count + 1 == WMCommand.allCases.count)
    }

    @Test("a shortcut matches by physical key, whatever character the active layout produces",
          arguments: [("d", "d"), ("в", "в"), ("ш", "ш")])
    func matchingIgnoresTheTypedCharacter(_: String, character: String) {
        let shortcut = WMCommand.leftThird.defaultShortcut!
        let event = keyEvent(keyCode: kVK_ANSI_D, characters: character, flags: controlOptionCommand)
        #expect(shortcut.matches(keyCode: UInt32(event.keyCode), flags: event.modifierFlags))
        let recorded = KeyboardShortcut(keyCode: UInt32(event.keyCode), flags: event.modifierFlags)
        #expect(recorded.collides(with: shortcut))
    }

    @Test("the same character on another physical key does not match")
    func differentKeyWithSameCharacterDoesNotMatch() {
        let shortcut = WMCommand.leftThird.defaultShortcut!
        let event = keyEvent(keyCode: kVK_ANSI_F, characters: "d", flags: controlOptionCommand)
        #expect(!shortcut.matches(keyCode: UInt32(event.keyCode), flags: event.modifierFlags))
    }
}
