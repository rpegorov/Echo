//
//  GridLoadNotice.swift
//  Echo
//

/// What the user is told about a grid file that could not be loaded normally.
enum GridLoadNotice: Equatable, Sendable {
    /// The file was unreadable and has been moved aside under `fileName`; templates are in use.
    case loadFailed(fileName: String)
    /// The file was written by a newer Echo and is read-only here.
    case newerVersion
    /// The file cannot be read or replaced, so grid changes cannot be saved.
    case unavailable

    var messageKey: InputKey {
        switch self {
        case .loadFailed:   return .gridLoadFailedMessage
        case .newerVersion: return .gridReadOnlyMessage
        case .unavailable:  return .gridUnavailableMessage
        }
    }
}
