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
    case commandLeftThird
    case commandCenterThird
    case commandRightThird
    case commandLeftTwoThirds
    case commandRightTwoThirds
    case commandNextDisplay
    case commandPreviousDisplay
    case commandOpenClipboard
    case commandSwitchLayout
    case commandConvertWord
    case commandTranslateSelection
    case commandZone1
    case commandZone2
    case commandZone3
    case commandZone4
    case commandZone5
    case commandZone6
    case commandZone7
    case commandZone8
    case commandZone9
    case commandNextGrid

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

    // MARK: Zone map, layout cycling, shortcut conflicts
    case layoutCyclingTitle
    case layoutCyclingCaption
    case zoneMapTitle
    case zoneMapCaption
    case zoneMapDisplayLabel
    case zoneGroupHalves
    case zoneGroupVerticalHalves
    case zoneGroupQuarters
    case zoneGroupThirds
    case zoneGroupTwoThirds
    case zoneGroupCenterAndFull
    case shortcutConflictMessage
    case shortcutReassignButton
    case shortcutClearButton

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

    // MARK: Grids (templates, drag modifier, settings section)
    case gridTemplateTwoColumns
    case gridTemplateThreeColumns
    case gridTemplateTwoByTwo
    case gridTemplateMainAndSide
    case gridTemplateMainAndTwoSides
    case gridModifierOption
    case gridModifierCommand
    case gridModifierOptionCommand
    case gridModifierLabel
    case gridsTitle
    case gridsCaption
    case gridActiveLabel
    case gridTemplatesSection
    case gridSavedSection
    case gridsEmpty
    case gridNewButton
    case gridEditButton
    case gridRenameAction
    case gridDeleteAction
    case gridDeleteConfirmTitle
    case gridDeleteConfirmMessage
    case gridZoneCount
    case gridLoadFailedMessage
    case gridReadOnlyMessage
    case gridUnavailableMessage
    case gridInvalidMessage
    case gridSaveFailedMessage
    case gridZoneCommandsGroup
    case tilingOptionConflictCaption

    // MARK: Grid editor and overlay
    case gridEditorWindowTitle
    case gridEditorNameLabel
    case gridEditorTemplateMenu
    case gridEditorHint
    case gridEditorSplitColumns
    case gridEditorSplitRows
    case gridEditorMergeLeft
    case gridEditorMergeRight
    case gridEditorMergeAbove
    case gridEditorMergeBelow
    case gridEditorSave
    case gridEditorBorderHandle
    case gridZoneNumber
    case gridZonesSpan

    // MARK: Arrangements and auto placement
    case arrangementsTitle
    case arrangementsCaption
    case arrangementsEmpty
    case arrangementCaptureButton
    case arrangementNameLabel
    case arrangementDefaultName
    case arrangementNoWindowsMessage
    case arrangementApplyButton
    case arrangementApplyResult
    case arrangementNotRunning
    case arrangementDeleteConfirmMessage
    case arrangementPermissionMessage
    case arrangementEditorWindowTitle
    case arrangementEditorHint
    case arrangementMoveMenu
    case arrangementRemoveApp
    case arrangementDisplayDisconnected
    case arrangementCustomArea
    case arrangementsMenuTitle
    case arrangementsMenuEmpty
    case autoRulesTitle
    case autoRulesCaption
    case autoRulesToggle
    case autoRulesEmpty
    case autoRuleAddButton
    case autoRuleSummary
    case autoRuleSheetTitle
    case autoRuleAppLabel
    case autoRuleOtherApp
    case autoRuleDisplayLabel
    case autoRuleZoneLabel
    case autoRuleReplaceNotice
    case arrangementWindowCount
    case arrangementDisplayMissingCount
    case arrangementNoWindowCount
    case arrangementSaveFailedMessage
    case arrangementSaveNotFoundReason
    case arrangementSaveInvalidSlotReason
    case arrangementEditorEmpty
    case arrangementUnknownOwnerName
}
