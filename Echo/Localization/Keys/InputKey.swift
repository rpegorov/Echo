//
//  InputKey.swift
//  Echo
//

import Foundation

/// Strings for window management / shortcuts / snippets preferences (S2b owns cases and the
/// Input table).
enum InputKey: LocalizedKey {
    static var table: String { "Input" }

    var rawValue: String {
        switch self {}
    }
    init?(rawValue: String) { nil }
    static var allCases: [InputKey] { [] }
}
