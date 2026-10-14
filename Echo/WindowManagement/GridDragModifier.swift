//
//  GridDragModifier.swift
//  Echo
//

import AppKit

/// Modifier that turns a window drag into grid mode.
/// Control is not offered: held at mouse-down it turns the click into a secondary click.
enum GridDragModifier: String, CaseIterable, Codable, Sendable {
    case option, command, optionCommand

    var flags: NSEvent.ModifierFlags {
        switch self {
        case .option:        return [.option]
        case .command:       return [.command]
        case .optionCommand: return [.option, .command]
        }
    }

    /// Held in grid mode once the drag has begun, stretches the window over several zones.
    static var spanFlags: NSEvent.ModifierFlags { [.control] }

    var usesOption: Bool { flags.contains(.option) }

    var glyphs: String {
        switch self {
        case .option:        return "⌥"
        case .command:       return "⌘"
        case .optionCommand: return "⌥⌘"
        }
    }

    static let spanGlyph = "⌃"

    var titleKey: InputKey {
        switch self {
        case .option:        return .gridModifierOption
        case .command:       return .gridModifierCommand
        case .optionCommand: return .gridModifierOptionCommand
        }
    }
}
