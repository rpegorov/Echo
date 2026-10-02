//
//  ExternalAppTracker.swift
//  Echo
//

import AppKit
import Combine

/// Remembers the last app other than Echo that became active. The popover
/// activates Echo, so a window opened from it learns here which app to hand
/// focus back to.
@MainActor
final class ExternalAppTracker {

    private(set) var lastApp: NSRunningApplication?
    private var activationObserver: AnyCancellable?

    init(workspace: NSWorkspace = .shared) {
        lastApp = Self.external(workspace.frontmostApplication)
        activationObserver = workspace.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                MainActor.assumeIsolated {
                    guard let app = Self.external(app) else { return }
                    self?.lastApp = app
                }
            }
    }

    private static func external(_ app: NSRunningApplication?) -> NSRunningApplication? {
        app?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : app
    }
}
