//
//  SystemTiling.swift
//  Echo
//

import Foundation

/// Which of macOS's own drag-tiling switches collide with Echo's behaviour.
struct TilingConflict: Equatable, Sendable {
    let edge: Bool
    let optionDrag: Bool
    var exists: Bool { edge || optionDrag }
}

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

    /// "Hold Option while dragging windows to tile"; an absent key counts as on, as macOS ships it.
    var isOptionDragEnabled: Bool {
        guard let defaults else { return false }
        return isOn(in: defaults, key: Keys.optionDrag)
    }

    /// Writes false to that one switch; restarting WindowManager is the caller's job.
    func disableOptionDrag() {
        guard let defaults else { return }
        defaults.set(false, forKey: Keys.optionDrag)
    }

    /// Option-drag tiling only conflicts when Echo's grid modifier includes Option.
    func conflict(gridModifier: GridDragModifier) -> TilingConflict {
        TilingConflict(edge: isEnabled, optionDrag: gridModifier.usesOption && isOptionDragEnabled)
    }

    private let defaults: UserDefaults?

    private enum Keys {
        static let edgeDrag = "EnableTilingByEdgeDrag"
        static let topDrag = "EnableTopTilingByEdgeDrag"
        static let optionDrag = "EnableTilingOptionAccelerator"
    }

    // macOS enables edge tiling by default, so an absent key still counts as on.
    private func isOn(in defaults: UserDefaults, key: String) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }
}
