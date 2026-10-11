//
//  UnwiredCapabilities.swift
//  Echo
//

import Foundation

/// Capabilities that exist in code but have no caller yet — kept visible so an in-progress
/// wave never silently ships dead code. Cleared by the integration task once wired.
enum UnwiredCapabilities {
    static let items: [String] = [
        "zone hotkeys",
        "grid drag mode",
        "span across zones",
        "grid overlay",
        "grid editor window",
        "grids settings section",
        "grid modifier setting",
        "option-drag tiling switch",
        "zone command icons",
        "grid file recovery",
    ]
}
