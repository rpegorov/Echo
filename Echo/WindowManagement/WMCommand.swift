//
//  WMCommand.swift
//  MonitorBarApp
//

import AppKit

/// Команды, которым можно назначить горячую клавишу.
enum WMCommand: String, CaseIterable, Identifiable, Codable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case center, maximize
    case openClipboard
    case switchLayout, convertWord, translateSelection

    var id: String { rawValue }

    /// Команды Ultra Switch регистрируются только при включённой фиче.
    var isUltraSwitchCommand: Bool {
        self == .switchLayout || self == .convertWord || self == .translateSelection
    }

    var title: String {
        switch self {
        case .leftHalf:      return "Left Half"
        case .rightHalf:     return "Right Half"
        case .topHalf:       return "Top Half"
        case .bottomHalf:    return "Bottom Half"
        case .topLeft:       return "Top Left"
        case .topRight:      return "Top Right"
        case .bottomLeft:    return "Bottom Left"
        case .bottomRight:   return "Bottom Right"
        case .center:        return "Center"
        case .maximize:      return "Maximize"
        case .openClipboard: return "Open Clipboard History"
        case .switchLayout:  return "Switch Layout"
        case .convertWord:   return "Convert Last Word"
        case .translateSelection: return "Перевести выделенное"
        }
    }

    /// Раскладка окна для команды (nil для не-оконных команд).
    var layout: WindowLayout? {
        switch self {
        case .leftHalf:      return .leftHalf
        case .rightHalf:     return .rightHalf
        case .topHalf:       return .topHalf
        case .bottomHalf:    return .bottomHalf
        case .topLeft:       return .topLeft
        case .topRight:      return .topRight
        case .bottomLeft:    return .bottomLeft
        case .bottomRight:   return .bottomRight
        case .center:        return .center
        case .maximize:      return .maximize
        case .openClipboard, .switchLayout, .convertWord, .translateSelection: return nil
        }
    }

    var isWindowCommand: Bool { layout != nil }

    /// Сочетание по умолчанию.
    var defaultShortcut: KeyboardShortcut? {
        let wm: NSEvent.ModifierFlags = [.control, .command]
        switch self {
        case .leftHalf:      return KeyboardShortcut(keyCode: 123, flags: wm) // ←
        case .rightHalf:     return KeyboardShortcut(keyCode: 124, flags: wm) // →
        case .topHalf:       return KeyboardShortcut(keyCode: 126, flags: wm) // ↑
        case .bottomHalf:    return KeyboardShortcut(keyCode: 125, flags: wm) // ↓
        case .topLeft:       return KeyboardShortcut(keyCode: 32,  flags: wm) // U
        case .topRight:      return KeyboardShortcut(keyCode: 34,  flags: wm) // I
        case .bottomLeft:    return KeyboardShortcut(keyCode: 45,  flags: wm) // N
        case .bottomRight:   return KeyboardShortcut(keyCode: 46,  flags: wm) // M
        case .center:        return KeyboardShortcut(keyCode: 40,  flags: wm) // K — сжать и по центру
        case .maximize:      return KeyboardShortcut(keyCode: 38,  flags: wm) // J — максимизация
        case .openClipboard: return KeyboardShortcut(keyCode: 9, flags: [.command, .shift]) // ⌘⇧V
        case .switchLayout:  return KeyboardShortcut(keyCode: 49, flags: [.option]) // ⌥Space
        case .convertWord:   return KeyboardShortcut(keyCode: 49, flags: [.option, .shift]) // ⌥⇧Space
        case .translateSelection: return KeyboardShortcut(keyCode: 17, flags: [.control, .option]) // ⌃⌥T
        }
    }
}
