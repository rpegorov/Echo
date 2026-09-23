//
//  SystemKey.swift
//  Echo
//

import Foundation

/// Strings for AppKit chrome — window titles, status item accessibility description
/// (S3 owns cases and the System table).
enum SystemKey: LocalizedKey {
    static var table: String { "System" }

    var rawValue: String {
        switch self {}
    }
    init?(rawValue: String) { nil }
    static var allCases: [SystemKey] { [] }
}
