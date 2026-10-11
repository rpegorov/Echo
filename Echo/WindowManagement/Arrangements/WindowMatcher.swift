//
//  WindowMatcher.swift
//  Echo
//

import Foundation

/// One paired entry and open window, as indices into the arrays passed to `WindowMatcher.match`.
struct WindowMatch: Equatable, Sendable {
    let entry: Int
    let window: Int
}

/// Pairs the saved entries of one app with its open windows: by exact title first, then in order.
enum WindowMatcher {
    static func match(entries: [ArrangedWindow], windows: [WindowSnapshot]) -> [WindowMatch] {
        var claimed: Set<Int> = []
        var matched: [Int: Int] = [:]
        for (entryIndex, entry) in entries.enumerated() {
            guard let titleHint = entry.titleHint else { continue }
            guard let windowIndex = windows.indices.first(where: {
                !claimed.contains($0) && windows[$0].title == titleHint
            })
            else { continue }
            claimed.insert(windowIndex)
            matched[entryIndex] = windowIndex
        }
        for entryIndex in entries.indices where matched[entryIndex] == nil {
            guard let windowIndex = windows.indices.first(where: { !claimed.contains($0) }) else { break }
            claimed.insert(windowIndex)
            matched[entryIndex] = windowIndex
        }
        return matched
            .sorted { $0.key < $1.key }
            .map { WindowMatch(entry: $0.key, window: $0.value) }
    }
}
