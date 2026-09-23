//
//  SystemKey.swift
//  Echo
//

import Foundation

/// Strings for AppKit chrome — window titles, status item accessibility description.
enum SystemKey: String, LocalizedKey {
    case windowTitleDetail
    case windowTitleClipboard
    case windowTitlePreferences
    case statusItemAccessibilityDescription

    static var table: String { "System" }
}
