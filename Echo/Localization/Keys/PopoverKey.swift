//
//  PopoverKey.swift
//  Echo
//

import Foundation

/// Strings for the popover (S1a owns cases and the Popover table).
enum PopoverKey: LocalizedKey {
    static var table: String { "Popover" }

    var rawValue: String {
        switch self {}
    }
    init?(rawValue: String) { nil }
    static var allCases: [PopoverKey] { [] }
}
