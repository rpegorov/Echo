//
//  CommonKey.swift
//  Echo
//

import Foundation

/// Strings shared across feature areas. Read-only after T2 — adding a case here needs
/// architect sign-off since every consumer would gain access to it.
enum CommonKey: String, LocalizedKey {
    case cancel
    case ok
    case quit
    case quitApp
    case preferences
    case loading
    case noMatches
    case none
    case system
    case version
    case terminate
    case terminateProcessTitle
    case terminateProcessMessage
    case searchProcess
    case grantAccess

    static var table: String { "Common" }
}
