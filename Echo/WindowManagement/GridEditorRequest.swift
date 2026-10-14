//
//  GridEditorRequest.swift
//  Echo
//

import Foundation

/// What the grid editor opens with.
struct GridEditorRequest: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case template(GridTemplate)
        case saved(UUID)
    }

    let source: Source
    /// The canvas takes this display's proportions; nil means the menu-bar display.
    let display: DisplayKey?
    /// Saving also makes the grid active on `display`.
    let activatesOnSave: Bool
}
