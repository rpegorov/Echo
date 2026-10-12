import AppKit
import Carbon.HIToolbox
import Testing
@testable import Echo

@Suite("Shortcut collision")
struct KeyboardShortcutCollisionTests {

    private let controlCommand: NSEvent.ModifierFlags = [.control, .command]
    private var leftHalfDefault: KeyboardShortcut { WMCommand.leftHalf.defaultShortcut! }

    @Test("control-command-left recorded with fn and numeric-pad flags collides with the default")
    func arrowFromRecorderCollidesWithDefault() {
        let recorded = KeyboardShortcut(
            keyCode: UInt32(kVK_LeftArrow),
            flags: controlCommand.union([.function, .numericPad]))
        #expect(recorded.collides(with: leftHalfDefault))
        #expect(leftHalfDefault.collides(with: recorded))
    }

    @Test("caps lock does not change the combination")
    func capsLockIsIgnored() {
        let recorded = KeyboardShortcut(
            keyCode: UInt32(kVK_LeftArrow), flags: controlCommand.union(.capsLock))
        #expect(recorded.collides(with: leftHalfDefault))
    }

    @Test("an extra shift makes it a different combination")
    func extraModifierDoesNotCollide() {
        let recorded = KeyboardShortcut(
            keyCode: UInt32(kVK_LeftArrow), flags: controlCommand.union(.shift))
        #expect(!recorded.collides(with: leftHalfDefault))
        #expect(!leftHalfDefault.collides(with: recorded))
    }

    @Test("a missing modifier makes it a different combination")
    func missingModifierDoesNotCollide() {
        let recorded = KeyboardShortcut(keyCode: UInt32(kVK_LeftArrow), flags: [.command])
        #expect(!recorded.collides(with: leftHalfDefault))
        #expect(!leftHalfDefault.collides(with: recorded))
    }

    @Test("the same modifiers on another key do not collide")
    func differentKeyDoesNotCollide() {
        let recorded = KeyboardShortcut(keyCode: UInt32(kVK_RightArrow), flags: controlCommand)
        #expect(!recorded.collides(with: leftHalfDefault))
    }

    @Test("control-option-command-left does not collide with control-command-left")
    func optionVariantIsDistinct() {
        let previous = WMCommand.previousDisplay.defaultShortcut!
        #expect(!previous.collides(with: leftHalfDefault))
    }

    @Test("a separately built identical combination collides")
    func identicalShortcutsCollide() {
        let copy = KeyboardShortcut(keyCode: leftHalfDefault.keyCode, flags: controlCommand)
        #expect(copy.collides(with: leftHalfDefault))
    }
}
