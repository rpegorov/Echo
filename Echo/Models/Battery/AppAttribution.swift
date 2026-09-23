//
//  AppAttribution.swift
//  Echo
//

import Foundation

/// Resolves the macOS application that owns an executable, so helper
/// processes (e.g. Chrome renderers) are attributed to their parent `.app`.
enum AppAttribution {

    private static let cacheLock = NSLock()
    // Guarded exclusively by `cacheLock` — never accessed outside it.
    nonisolated(unsafe) private static var cache: [String: (name: String, bundleID: String?)] = [:]

    /// - Parameters:
    ///   - path: The process's executable path, if known.
    ///   - fallbackName: Used when no `.app` bundle is found in `path`.
    static func app(forExecutablePath path: String?, fallbackName: String) -> (name: String, bundleID: String?) {
        guard let path, let bundlePath = outermostAppBundle(in: path) else {
            return (fallbackName, nil)
        }

        cacheLock.lock()
        let cached = cache[bundlePath]
        cacheLock.unlock()
        if let cached {
            return cached
        }

        let resolved = resolve(bundlePath: bundlePath)

        cacheLock.lock()
        cache[bundlePath] = resolved
        cacheLock.unlock()

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

        let name = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? defaultName

        return (name, bundle.bundleIdentifier)
    }
}
