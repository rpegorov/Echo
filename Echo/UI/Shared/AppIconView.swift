//
//  AppIconView.swift
//  Echo
//

import AppKit
import SwiftUI

/// The app's icon by bundle id, a generic app icon when it is not installed.
struct AppIconView: View {
    let bundleID: String
    let size: CGFloat

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var icon: NSImage {
        let workspace = NSWorkspace.shared
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
            return workspace.icon(for: .applicationBundle)
        }
        return workspace.icon(forFile: url.path)
    }
}
