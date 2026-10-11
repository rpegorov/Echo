//
//  ShortcutHolder.swift
//  Echo
//

import Foundation

/// Who the recorder names when a new shortcut is already taken.
enum ShortcutHolder {
    /// nil for an arrangement missing from the document, whose shortcut is taken over without asking.
    /// A read-only store has an empty document, so there the arrangement may still exist in the file: ask instead.
    static func name(
        of owner: ShortcutOwner,
        arrangements: [Arrangement],
        isReadOnly: Bool,
        commandTitle: (WMCommand) -> String,
        unknownArrangementName: String
    ) -> String? {
        switch owner {
        case .command(let command):
            return commandTitle(command)
        case .arrangement(let id):
            if let saved = arrangements.first(where: { $0.id == id }) { return saved.name }
            return isReadOnly ? unknownArrangementName : nil
        }
    }
}
