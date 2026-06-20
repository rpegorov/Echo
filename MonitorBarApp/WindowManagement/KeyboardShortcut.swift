//
//  KeyboardShortcut.swift
//  MonitorBarApp
//

import AppKit
import Carbon.HIToolbox

/// Сочетание клавиш: виртуальный keyCode + модификаторы (Cocoa-маска).
struct KeyboardShortcut: Codable, Equatable {
    var keyCode: UInt32
    /// NSEvent.ModifierFlags.rawValue (device-independent подмножество).
    var modifiers: UInt32

    init(keyCode: UInt32, flags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = UInt32(flags.intersection(.deviceIndependentFlagsMask).rawValue)
    }

    /// Модификаторы в формате Carbon (для RegisterEventHotKey).
    var carbonModifiers: UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        return carbon
    }

    /// Человекочитаемая запись, напр. "⌃⌘←".
    var displayString: String {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option)  { result += "⌥" }
        if flags.contains(.shift)   { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        result += Self.keySymbol(keyCode)
        return result
    }

    /// Символ клавиши по виртуальному keyCode (ANSI-раскладка).
    static func keySymbol(_ code: UInt32) -> String {
        if let special = specialKeys[code] { return special }
        if let letter = ansiKeys[code] { return letter }
        return "?"
    }

    private static let specialKeys: [UInt32: String] = [
        123: "←", 124: "→", 125: "↓", 126: "↑",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 76: "⌅"
    ]

    private static let ansiKeys: [UInt32: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
        34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
        12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
        16: "Y", 6: "Z",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0"
    ]
}
