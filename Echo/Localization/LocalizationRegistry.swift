//
//  LocalizationRegistry.swift
//  Echo
//

import Foundation

/// Fixed list of every localization key type, used by completeness/orphan checks.
enum LocalizationRegistry {
    static let allKeyTypes: [any LocalizedKey.Type] = [
        CommonKey.self,
        PopoverKey.self,
        MetricsKey.self,
        PreferencesKey.self,
        InputKey.self,
        SystemKey.self
    ]
}
