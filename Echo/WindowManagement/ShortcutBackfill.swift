import Foundation

/// Adds default shortcuts of commands introduced after the version a stored set was written at.
enum ShortcutBackfill {
    /// A set without a version marker predates versioning; it counts as version 1 so that a
    /// default the user deleted from it is not restored.
    private static let firstTrackedVersion = 1

    /// `stored` plus defaults of commands newer than `storedVersion`; never overwrites an entry,
    /// never adds a combination that collides with any stored one (unknown keys included).
    static func apply(to stored: [String: KeyboardShortcut], storedVersion: Int) -> [String: KeyboardShortcut] {
        let effectiveVersion = max(storedVersion, firstTrackedVersion)
        var result = stored
        for command in WMCommand.allCases where command.introducedInShortcutsVersion > effectiveVersion {
            guard result[command.rawValue] == nil,
                  let shortcut = command.defaultShortcut,
                  !result.values.contains(where: { $0.collides(with: shortcut) })
            else { continue }
            result[command.rawValue] = shortcut
        }
        return result
    }
}
