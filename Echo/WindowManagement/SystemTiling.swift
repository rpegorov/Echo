//
//  SystemTiling.swift
//  Echo
//

import Foundation

/// Reads and writes macOS's own edge-tiling switches in the com.apple.WindowManager domain.
struct SystemTiling {
    /// UserDefaults(suiteName: "com.apple.WindowManager") in production.
    init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    /// Either edge-tiling switch is on or absent.
    var isEnabled: Bool {
        guard let defaults else { return false }
        return isOn(in: defaults, key: Keys.edgeDrag) || isOn(in: defaults, key: Keys.topDrag)
    }

    /// Writes false to both switches; restarting WindowManager is the caller's job.
    func disable() {
        guard let defaults else { return }
        defaults.set(false, forKey: Keys.edgeDrag)
        defaults.set(false, forKey: Keys.topDrag)
    }

    private let defaults: UserDefaults?

    private enum Keys {
        static let edgeDrag = "EnableTilingByEdgeDrag"
        static let topDrag = "EnableTopTilingByEdgeDrag"
    }

    // macOS enables edge tiling by default, so an absent key still counts as on.
    private func isOn(in defaults: UserDefaults, key: String) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }
}
