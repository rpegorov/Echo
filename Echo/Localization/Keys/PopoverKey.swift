//
//  PopoverKey.swift
//  Echo
//

import Foundation

/// Strings for the popover and the clipboard history window (S1a owns cases and the Popover table).
enum PopoverKey: String, LocalizedKey {
    case utilitiesSectionTitle
    case keyboardCleaningTitle
    case keyboardCleaningPermissionHint
    case preventSleepTitle
    case autoLayoutFixTitle
    case accessibilityAccessRequired
    case inputMonitoringAccessRequired
    case clipboardHistoryTitle
    case openHistory
    case clear
    case clipboardEmptyTitle
    case clipboardEmptyHint
    case clipboardImageLabel
    case clipboardMoreFiles
    case clipboardKindText
    case clipboardKindFile
    case clipboardCopiedAt

    static var table: String { "Popover" }
}
