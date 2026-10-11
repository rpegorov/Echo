//
//  AXWindowCatalog.swift
//  Echo
//

import AppKit
import ApplicationServices

/// Enumerates the eligible windows of running regular apps through Accessibility.
@MainActor
final class AXWindowCatalog: WindowCataloging {
    /// Upper bound for one AX request to an app, so a hung app cannot stall the main thread for long.
    static let messagingTimeout: Float = 1

    private let workspace: NSWorkspace
    private let ownBundleID: String?

    init(workspace: NSWorkspace, ownBundleID: String?) {
        self.workspace = workspace
        self.ownBundleID = ownBundleID
    }

    func windows() -> [CatalogWindow] {
        regularApps().flatMap { app, bundleID in windows(of: app, bundleID: bundleID) }
    }

    func runningBundleIDs() -> Set<String> {
        Set(regularApps().map(\.bundleID))
    }

    /// Regular apps other than Echo in launch order; the pid breaks ties and orders apps without a launch date.
    private func regularApps() -> [(app: NSRunningApplication, bundleID: String)] {
        workspace.runningApplications
            .compactMap { app -> (app: NSRunningApplication, bundleID: String)? in
                guard app.activationPolicy == .regular, !app.isTerminated,
                      let bundleID = app.bundleIdentifier, bundleID != ownBundleID
                else { return nil }
                return (app, bundleID)
            }
            .sorted { lhs, rhs in
                let left = lhs.app.launchDate ?? .distantFuture
                let right = rhs.app.launchDate ?? .distantFuture
                return left == right ? lhs.app.processIdentifier < rhs.app.processIdentifier : left < right
            }
    }

    private func windows(of app: NSRunningApplication, bundleID: String) -> [CatalogWindow] {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
        let appName = app.localizedName ?? bundleID
        return AXWindow.windows(of: element).enumerated().compactMap { ordinal, window in
            guard AXWindow.isEligible(window), let frame = AXWindow.frame(of: window) else { return nil }
            let snapshot = WindowSnapshot(
                ref: WindowRef(pid: app.processIdentifier, ordinal: ordinal),
                bundleID: bundleID,
                appName: appName,
                title: AXWindow.title(of: window),
                frame: frame
            )
            return CatalogWindow(snapshot: snapshot, element: window)
        }
    }
}
