//
//  AppAttribution.swift
//  Echo
//

import Foundation
import Synchronization

/// Resolves the macOS application that owns an executable, so helper
/// processes (e.g. Chrome renderers) are attributed to their parent `.app`.
enum AppAttribution {

    // A `Mutex`-protected cache: no `nonisolated(unsafe)` escape hatch needed,
    // since `Mutex` itself is the synchronization primitive (Synchronization
    // framework, macOS 15+).
    private static let cache = Mutex<[String: (name: String, bundleID: String?)]>([:])

    /// - Parameters:
    ///   - path: The process's executable path, if known.
    ///   - fallbackName: Used when no `.app` bundle is found in `path`.
    static func app(forExecutablePath path: String?, fallbackName: String) -> (name: String, bundleID: String?) {
        guard let path, let bundlePath = outermostAppBundle(in: path) else {
            return (fallbackName, nil)
        }

        if let cached = cache.withLock({ $0[bundlePath] }) {
            return cached
        }

        let resolved = resolve(bundlePath: bundlePath)
        cache.withLock { $0[bundlePath] = resolved }
        return resolved
    }

    // MARK: - Private

    /// Finds the first (outermost) path component ending in `.app`, e.g.
    /// `/Applications/Google Chrome.app` inside a renderer helper's path.
    private static func outermostAppBundle(in executablePath: String) -> String? {
        var accumulated = ""
        for component in executablePath.components(separatedBy: "/") {
            accumulated += component + "/"
            if component.hasSuffix(".app") {
                return String(accumulated.dropLast())
            }
        }
        return nil
    }

    private static func resolve(bundlePath: String) -> (name: String, bundleID: String?) {
        let bundleURL = URL(fileURLWithPath: bundlePath)
        let defaultName = bundleURL.deletingPathExtension().lastPathComponent

        guard let bundle = Bundle(url: bundleURL) else {
            return (defaultName, nil)
        }

        // Prefer the user-facing display name (e.g. "Google Chrome") over the
        // internal bundle name (e.g. "Chrome"), since this is what the user
        // recognizes as the app that drained their battery.
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? defaultName

        return (name, bundle.bundleIdentifier)
    }
}
