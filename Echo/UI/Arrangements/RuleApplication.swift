//
//  RuleApplication.swift
//  Echo
//

import AppKit
import UniformTypeIdentifiers

/// An app an auto-placement rule can target.
struct RuleApplication: Identifiable, Equatable {
    let bundleID: String
    /// Shown and stored as data, not a localization key.
    let name: String

    var id: String { bundleID }
}

extension RuleApplication {

    private static let applicationsDirectory = URL(fileURLWithPath: "/Applications")

    /// Running regular apps except Echo, by name.
    @MainActor
    static func running() -> [RuleApplication] {
        let ownBundleID = Bundle.main.bundleIdentifier
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> RuleApplication? in
            guard app.activationPolicy == .regular,
                  let bundleID = app.bundleIdentifier,
                  bundleID != ownBundleID,
                  let name = app.localizedName else { return nil }
            return RuleApplication(bundleID: bundleID, name: name)
        }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Lets the user pick an app bundle; nil when cancelled or the bundle has no identifier.
    @MainActor
    static func choose() -> RuleApplication? {
        let panel = NSOpenPanel()
        panel.directoryURL = applicationsDirectory
        panel.allowedContentTypes = [.application]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return RuleApplication(at: url)
    }

    init?(at url: URL) {
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return nil }
        self.init(bundleID: bundleID, name: FileManager.default.displayName(atPath: url.path))
    }
}
