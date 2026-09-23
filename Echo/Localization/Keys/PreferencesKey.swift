//
//  PreferencesKey.swift
//  Echo
//

import Foundation

/// Strings for the Preferences window shell and its General, Monitoring, Power,
/// Appearance, Menu Bar, Updates and Clipboard sections (S2a owns this table).
enum PreferencesKey: String, LocalizedKey {
    // Section titles (shared by the sidebar list and each section's own heading).
    case sectionGeneral
    case sectionMonitoring
    case sectionPower
    case sectionAppearance
    case sectionMenuBar
    case sectionWindowManager
    case sectionUltraSwitch
    case sectionSnippets
    case sectionKeyboard
    case sectionUpdates
    case sectionClipboard

    // General
    case languageTitle
    case languageCaption
    case launchAtLoginTitle
    case launchAtLoginCaption

    // Shared interval formatting (Monitoring, Power, Menu Bar)
    case intervalSeconds

    // Monitoring
    case updateIntervalTitle
    case updateIntervalCaption

    // Power
    case pauseWhenHiddenTitle
    case pauseWhenHiddenCaption
    case pauseOnSleepTitle
    case pauseOnSleepCaption
    case lowPowerThrottleTitle
    case lowPowerThrottleCaption
    case lowPowerIntervalTitle

    // Appearance
    case themeTitle
    case themeCaption
    case appearanceSystem
    case appearanceLight
    case appearanceDark

    // Menu Bar
    case menuBarModeTitle
    case menuBarModeAppIcon
    case menuBarModeMetrics
    case menuBarModeCustom
    case menuBarMetricsTitle
    case menuBarMetricsCaption
    case menuBarIntervalTitle
    case menuBarIntervalCaption
    case customIconNoneTitle
    case customIconCaption
    case customIconChooseButton
    case customIconRemoveButton

    // Updates
    case updatesInstalledVersion
    case updatesCheckNowButton
    case updatesAutoCheckTitle
    case updatesAutoCheckCaption
    case updatesAutoDownloadTitle
    case updatesAutoDownloadCaption
    case updatesFeedTitle
    case updatesFeedCaption
    case updatesNeverChecked
    case updatesLastCheck

    // Clipboard
    case clipboardEnableTitle
    case clipboardEnableCaption

    static var table: String { "Preferences" }
}

extension PreferencesView.PrefSection {
    /// Localized display name; `rawValue` stays a persisted identifier.
    var titleKey: PreferencesKey {
        switch self {
        case .general:       return .sectionGeneral
        case .monitoring:    return .sectionMonitoring
        case .power:         return .sectionPower
        case .appearance:    return .sectionAppearance
        case .menuBar:       return .sectionMenuBar
        case .windowManager: return .sectionWindowManager
        case .ultraSwitch:   return .sectionUltraSwitch
        case .snippets:      return .sectionSnippets
        case .keyboard:      return .sectionKeyboard
        case .updates:       return .sectionUpdates
        case .clipboard:     return .sectionClipboard
        }
    }
}

extension AppearanceMode {
    /// Localized display name; `rawValue` stays a persisted identifier.
    var titleKey: PreferencesKey {
        switch self {
        case .system: return .appearanceSystem
        case .light:  return .appearanceLight
        case .dark:   return .appearanceDark
        }
    }
}

extension MenuBarIconMode {
    /// Localized display name; `rawValue` stays a persisted identifier.
    var titleKey: PreferencesKey {
        switch self {
        case .appIcon: return .menuBarModeAppIcon
        case .metrics: return .menuBarModeMetrics
        case .custom:  return .menuBarModeCustom
        }
    }
}
