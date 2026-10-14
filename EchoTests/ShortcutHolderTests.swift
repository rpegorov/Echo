//
//  ShortcutHolderTests.swift
//  EchoTests
//

import Foundation
import Testing
@testable import Echo

@Suite("Shortcut holder naming")
struct ShortcutHolderTests {
    private let known = fixtureArrangement(name: "Focus", windows: [])

    private func name(_ owner: ShortcutOwner, isReadOnly: Bool) -> String? {
        ShortcutHolder.name(
            of: owner,
            arrangements: [known],
            isReadOnly: isReadOnly,
            commandTitle: { _ in "Left Half" },
            unknownArrangementName: "Another arrangement"
        )
    }

    @Test("a command holder is named by its title")
    func commandIsNamed() {
        #expect(name(.command(.leftHalf), isReadOnly: false) == "Left Half")
    }

    @Test("a saved arrangement is named by its name")
    func savedArrangementIsNamed() {
        #expect(name(.arrangement(known.id), isReadOnly: false) == "Focus")
    }

    @Test("an orphan arrangement shortcut is taken over without asking")
    func orphanIsNotNamed() {
        #expect(name(.arrangement(UUID()), isReadOnly: false) == nil)
    }

    @Test("a read-only store may still hold an unknown arrangement, so the recorder asks")
    func readOnlyUnknownArrangementIsNamed() {
        #expect(name(.arrangement(UUID()), isReadOnly: true) == "Another arrangement")
    }
}
