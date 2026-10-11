//
//  ArrangementMessages.swift
//  Echo
//

import Foundation

/// User-facing texts for load notices and failed arrangement or rule changes.
@MainActor
struct ArrangementMessages {
    let loc: Localizer

    func text(for notice: GridLoadNotice) -> String {
        switch notice {
        case .loadFailed(let fileName): return loc.t(InputKey.gridLoadFailedMessage, fileName)
        case .newerVersion:             return loc.t(InputKey.gridReadOnlyMessage)
        case .unavailable:              return loc.t(InputKey.gridUnavailableMessage)
        }
    }

    func text(for error: ArrangementError) -> String {
        switch error {
        case .storage(let storageError): return text(for: storageError)
        case .noWindows:                 return loc.t(InputKey.arrangementNoWindowsMessage)
        case .accessibilityDenied:       return loc.t(InputKey.arrangementPermissionMessage)
        case .notFound:                  return loc.t(InputKey.gridSaveFailedMessage, loc.t(InputKey.gridUnavailableMessage))
        }
    }

    func text(for error: GridStorageError) -> String {
        loc.t(InputKey.gridSaveFailedMessage, detail(of: error))
    }

    /// Human-readable cause of a failed save, shown after the localized "Couldn't save grids" prefix.
    private func detail(of error: GridStorageError) -> String {
        switch error {
        case .writeFailed(let detail), .readFailed(let detail): return detail
        case .unreadable(let fileName):                         return fileName
        case .invalidGrid:                                      return loc.t(InputKey.gridInvalidMessage)
        case .locationUnavailable, .newerSchema, .readOnly,
             .invalidSlot:                                      return loc.t(InputKey.gridUnavailableMessage)
        }
    }
}
