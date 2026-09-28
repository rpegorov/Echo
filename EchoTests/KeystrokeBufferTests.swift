//
//  KeystrokeBufferTests.swift
//  EchoTests
//
//  Буфер набранного и распознавание хоткеев раскладки: то, от чего зависит,
//  найдёт ли ручная конвертация (отмена автозамены) слово для исправления.
//

import AppKit
import Testing
@testable import Echo

@MainActor
struct KeystrokeBufferTests {

    private func type(_ text: String, into buffer: KeystrokeBuffer) {
        text.forEach { buffer.append($0) }
    }

    @Test func backspaceOverTailReturnsWordForConversion() {
        let buffer = KeystrokeBuffer()
        type("ghbdtn ", into: buffer)

        buffer.backspace()

        let candidate = buffer.wordForManualConversion()
        #expect(candidate?.word == "ghbdtn")
        #expect(candidate?.deleteCount == 6)
    }

    @Test func retypingAfterBackspaceExtendsTheSameWord() {
        let buffer = KeystrokeBuffer()
        type("ghbd ", into: buffer)

        buffer.backspace()
        type("tn", into: buffer)

        #expect(buffer.wordForManualConversion()?.word == "ghbdtn")
    }

    @Test func backspaceWithinTailKeepsCompletedWord() {
        let buffer = KeystrokeBuffer()
        type("ghbdtn  ", into: buffer)

        buffer.backspace()

        let candidate = buffer.wordForManualConversion()
        #expect(candidate?.word == "ghbdtn")
        #expect(candidate?.tail == " ")
        #expect(candidate?.deleteCount == 7)
    }

    @Test func backspaceBeyondKnownTextClearsBuffer() {
        let buffer = KeystrokeBuffer()
        type("ab", into: buffer)

        (0..<3).forEach { _ in buffer.backspace() }

        #expect(buffer.wordForManualConversion() == nil)
    }

    @Test func shortcutMatchesOnlyExactModifiers() {
        let convert = KeyboardShortcut(keyCode: 49, flags: [.option, .shift])

        #expect(convert.matches(keyCode: 49, flags: [.option, .shift]))
        #expect(!convert.matches(keyCode: 49, flags: [.option]))
        #expect(!convert.matches(keyCode: 49, flags: [.option, .shift, .command]))
        #expect(!convert.matches(keyCode: 50, flags: [.option, .shift]))
    }

    @Test func shortcutIgnoresNonModifierFlags() {
        let switchLayout = KeyboardShortcut(keyCode: 49, flags: [.option])

        #expect(switchLayout.matches(keyCode: 49, flags: [.option, .capsLock]))
    }
}
