//
//  InputKey.swift
//  Echo
//

import Foundation

/// Strings for window management / Ultra Switch / snippets / shortcuts preferences,
/// the shortcut recorder, and hotkey command names (S2b owns cases and the Input table).
enum InputKey: String, LocalizedKey {
    static var table: String { "Input" }

    // MARK: Hotkey command names (WMCommand)
    case commandLeftHalf
    case commandRightHalf
    case commandTopHalf
    case commandBottomHalf
    case commandTopLeft
    case commandTopRight
    case commandBottomLeft
    case commandBottomRight
    case commandCenter
    case commandMaximize
    case commandOpenClipboard
    case commandSwitchLayout
    case commandConvertWord
    case commandTranslateSelection

    // MARK: Shortcut recorder / display
    case shortcutRecording
    case keySpace

    // MARK: Window Manager section
    case windowManagerTitle
    case windowManagerEnableTitle
    case windowManagerEnableCaption
    case windowSpacingTitle
    case windowSpacingValue
    case accessibilityGrantedTitle
    case accessibilityMissingTitle
    case accessibilityMissingCaption
    case openSettingsButton
    case relaunchAppButton
    case tilingConflictTitle
    case tilingConflictCaption
    case disableSystemTilingButton

    // MARK: Ultra Switch section
    case ultraSwitchTitle
    case ultraSwitchEnableTitle
    case ultraSwitchEnableCaption
    case autoConvertTitle
    case autoConvertCaption
    case privacyNoteCaption
    case statusRunningTitle
    case statusDisabledTitle
    case statusNeedsInputMonitoringTitle
    case statusRunningDetail
    case statusDisabledDetail
    case statusNeedsAccessibilityDetail
    case statusNeedsInputMonitoringDetail
    case afterUpdateHint
    case allowButton
    case singleLayoutWarning
    case conversionUndoCaption
    case translationCaption

    // MARK: Snippets section
    case snippetsTitle
    case snippetsHowItWorksTitle
    case snippetsHowItWorksCaption
    case snippetsDisabledWarning
    case snippetsNewTitle
    case snippetsAbbreviationPlaceholder
    case snippetsExpansionPlaceholder
    case addButton
    case snippetsEmptyCaption

    // MARK: Shortcuts section
    case shortcutsTitle
    case clipboardHistorySectionTitle
}
