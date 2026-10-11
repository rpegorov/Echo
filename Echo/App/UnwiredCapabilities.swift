//
//  UnwiredCapabilities.swift
//  Echo
//

import Foundation

/// Capabilities that exist in code but have no caller yet — kept visible so an in-progress
/// wave never silently ships dead code. Cleared by the integration task once wired.
enum UnwiredCapabilities {
    static let items: [String] = [
        "layout cycles",
        "move to next/previous display",
        "robust window placement",
        "system tiling switches",
        "hotkeys paused while recording",
        "shortcut backfill v3",
        "edge snap previews on zone change",
        "animated snap overlay with caption",
        "zone map",
        "layout thumbnails",
        "shortcut conflict warning",
    ]
}
