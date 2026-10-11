//
//  ShortcutOwner.swift
//  Echo
//

import Foundation

/// Who a key combination belongs to in `wm.shortcuts`.
enum ShortcutOwner: Hashable, Sendable {
    case command(WMCommand)
    case arrangement(UUID)

    // l10n-exempt: storage identifiers
    static let arrangementPrefix = "arrangement:"

    /// `WMCommand.rawValue`, or `arrangement:<UUID>`.
    var storageKey: String {
        switch self {
        case .command(let command):   return command.rawValue
        case .arrangement(let id):    return Self.arrangementPrefix + id.uuidString
        }
    }

    /// nil for keys that are neither; they stay in `AppSettings.unrecognizedShortcutEntries`.
    init?(storageKey: String) {
        if let command = WMCommand(rawValue: storageKey) {
            self = .command(command)
        } else if storageKey.hasPrefix(Self.arrangementPrefix),
                  let id = UUID(uuidString: String(storageKey.dropFirst(Self.arrangementPrefix.count))) {
            self = .arrangement(id)
        } else {
            return nil
        }
    }
}
