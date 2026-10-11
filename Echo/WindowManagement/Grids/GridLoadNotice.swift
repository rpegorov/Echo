//
//  GridLoadNotice.swift
//  Echo
//

/// What the user is told about a grid file that could not be loaded normally.
enum GridLoadNotice: Equatable, Sendable {
    case loadFailed(fileName: String)
    case newerVersion
    case unavailable

    var messageKey: InputKey {
        switch self {
        case .loadFailed:   return .gridLoadFailedMessage
        case .newerVersion: return .gridReadOnlyMessage
        case .unavailable:  return .gridUnavailableMessage
        }
    }
}
