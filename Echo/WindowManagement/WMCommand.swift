//
//  WMCommand.swift
//  MonitorBarApp
//

import AppKit
import Carbon.HIToolbox

/// Команды, которым можно назначить горячую клавишу.
enum WMCommand: String, CaseIterable, Identifiable, Codable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird
    case leftTwoThirds, rightTwoThirds
    case center, maximize
    case nextDisplay, previousDisplay
    case openClipboard
    case switchLayout, convertWord, translateSelection
    case zone1, zone2, zone3, zone4, zone5, zone6, zone7, zone8, zone9

    var id: String { rawValue }

    /// Команды Ultra Switch регистрируются только при включённой фиче.
    var isUltraSwitchCommand: Bool {
        self == .switchLayout || self == .convertWord || self == .translateSelection
    }

    /// Localization key for the command's display name (Input table).
    var titleKey: InputKey {
        switch self {
        case .leftHalf:        return .commandLeftHalf
        case .rightHalf:       return .commandRightHalf
        case .topHalf:         return .commandTopHalf
        case .bottomHalf:      return .commandBottomHalf
        case .topLeft:         return .commandTopLeft
        case .topRight:        return .commandTopRight
        case .bottomLeft:      return .commandBottomLeft
        case .bottomRight:     return .commandBottomRight
        case .leftThird:       return .commandLeftThird
        case .centerThird:     return .commandCenterThird
        case .rightThird:      return .commandRightThird
        case .leftTwoThirds:   return .commandLeftTwoThirds
        case .rightTwoThirds:  return .commandRightTwoThirds
        case .center:          return .commandCenter
        case .maximize:        return .commandMaximize
        case .nextDisplay:     return .commandNextDisplay
        case .previousDisplay: return .commandPreviousDisplay
        case .openClipboard:   return .commandOpenClipboard
        case .switchLayout:    return .commandSwitchLayout
        case .convertWord:     return .commandConvertWord
        case .translateSelection: return .commandTranslateSelection
        case .zone1:           return .commandZone1
        case .zone2:           return .commandZone2
        case .zone3:           return .commandZone3
        case .zone4:           return .commandZone4
        case .zone5:           return .commandZone5
        case .zone6:           return .commandZone6
        case .zone7:           return .commandZone7
        case .zone8:           return .commandZone8
        case .zone9:           return .commandZone9
        }
    }

    /// Раскладка окна для команды (nil для не-оконных команд).
    var layout: WindowLayout? {
        switch self {
        case .leftHalf:       return .leftHalf
        case .rightHalf:      return .rightHalf
        case .topHalf:        return .topHalf
        case .bottomHalf:     return .bottomHalf
        case .topLeft:        return .topLeft
        case .topRight:       return .topRight
        case .bottomLeft:     return .bottomLeft
        case .bottomRight:    return .bottomRight
        case .leftThird:      return .leftThird
        case .centerThird:    return .centerThird
        case .rightThird:     return .rightThird
        case .leftTwoThirds:  return .leftTwoThirds
        case .rightTwoThirds: return .rightTwoThirds
        case .center:         return .center
        case .maximize:       return .maximize
        case .nextDisplay, .previousDisplay,
             .openClipboard, .switchLayout, .convertWord, .translateSelection,
             .zone1, .zone2, .zone3, .zone4, .zone5, .zone6, .zone7, .zone8, .zone9: return nil
        }
    }

    var displayDirection: DisplayDirection? {
        switch self {
        case .nextDisplay:     return .next
        case .previousDisplay: return .previous
        default:               return nil
        }
    }

    /// 1-based zone of the active grid this command places the focused window into.
    var zoneNumber: Int? {
        switch self {
        case .zone1: return 1
        case .zone2: return 2
        case .zone3: return 3
        case .zone4: return 4
        case .zone5: return 5
        case .zone6: return 6
        case .zone7: return 7
        case .zone8: return 8
        case .zone9: return 9
        default:     return nil
        }
    }

    static func zone(_ number: Int) -> WMCommand? {
        allCases.first { $0.zoneNumber == number }
    }

    var isWindowCommand: Bool { layout != nil || displayDirection != nil || zoneNumber != nil }

    /// Shortcut-set version that first shipped this command; drives the default backfill.
    var introducedInShortcutsVersion: Int {
        switch self {
        case .switchLayout, .convertWord, .translateSelection:
            return 2
        case .leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds,
             .nextDisplay, .previousDisplay:
            return 3
        case .zone1, .zone2, .zone3, .zone4, .zone5, .zone6, .zone7, .zone8, .zone9:
            return 4
        default:
            return 1
        }
    }

    /// Сочетание по умолчанию.
    var defaultShortcut: KeyboardShortcut? {
        let wm: NSEvent.ModifierFlags = [.control, .command]
        let extended: NSEvent.ModifierFlags = [.control, .option, .command]
        let zoneFlags: NSEvent.ModifierFlags = [.control, .option]
        switch self {
        case .leftHalf:      return KeyboardShortcut(keyCode: 123, flags: wm) // ←
        case .rightHalf:     return KeyboardShortcut(keyCode: 124, flags: wm) // →
        case .topHalf:       return KeyboardShortcut(keyCode: 126, flags: wm) // ↑
        case .bottomHalf:    return KeyboardShortcut(keyCode: 125, flags: wm) // ↓
        case .topLeft:       return KeyboardShortcut(keyCode: 32,  flags: wm) // U
        case .topRight:      return KeyboardShortcut(keyCode: 34,  flags: wm) // I
        case .bottomLeft:    return KeyboardShortcut(keyCode: 45,  flags: wm) // N
        case .bottomRight:   return KeyboardShortcut(keyCode: 46,  flags: wm) // M
        case .leftThird:       return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_D), flags: extended)
        case .centerThird:     return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_F), flags: extended)
        case .rightThird:      return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_G), flags: extended)
        case .leftTwoThirds:   return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_E), flags: extended)
        case .rightTwoThirds:  return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_T), flags: extended)
        case .center:        return KeyboardShortcut(keyCode: 40,  flags: wm) // l10n-exempt: comment, not user-facing — K, сжать и по центру
        case .maximize:      return KeyboardShortcut(keyCode: 38,  flags: wm) // l10n-exempt: comment, not user-facing — J, максимизация
        case .nextDisplay:     return KeyboardShortcut(keyCode: UInt32(kVK_RightArrow), flags: extended)
        case .previousDisplay: return KeyboardShortcut(keyCode: UInt32(kVK_LeftArrow), flags: extended)
        case .openClipboard: return KeyboardShortcut(keyCode: 9, flags: [.command, .shift]) // ⌘⇧V
        case .switchLayout:  return KeyboardShortcut(keyCode: 49, flags: [.option]) // ⌥Space
        case .convertWord:   return KeyboardShortcut(keyCode: 49, flags: [.option, .shift]) // ⌥⇧Space
        case .translateSelection: return KeyboardShortcut(keyCode: 17, flags: [.control, .option]) // ⌃⌥T
        case .zone1: return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_1), flags: zoneFlags)
        case .zone2: return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_2), flags: zoneFlags)
        case .zone3: return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_3), flags: zoneFlags)
        case .zone4: return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_4), flags: zoneFlags)
        case .zone5: return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_5), flags: zoneFlags)
        case .zone6: return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_6), flags: zoneFlags)
        case .zone7: return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_7), flags: zoneFlags)
        case .zone8: return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_8), flags: zoneFlags)
        case .zone9: return KeyboardShortcut(keyCode: UInt32(kVK_ANSI_9), flags: zoneFlags)
        }
    }
}
