//
//  UnwiredCapabilities.swift
//  Echo
//

import Foundation

/// Capabilities that exist in code but have no caller yet — kept visible so an in-progress
/// wave never silently ships dead code. Cleared by the integration task once wired.
enum UnwiredCapabilities {
    static let items: [String] = [
        "l10n.languagePicker",
        "l10n.appKitRefresh"
    ]
}
