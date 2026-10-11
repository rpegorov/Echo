//
//  ArrangementContracts.swift
//  Echo
//

import ApplicationServices
import Foundation

/// Outcome of applying an arrangement; `placed + notRunning + noWindow + displayMissing == total`.
struct ArrangementApplyReport: Equatable, Sendable {
    var placed = 0
    /// Number of entries in the arrangement.
    var total = 0
    /// Entries of apps that are not running.
    var notRunning = 0
    /// App names of those entries, in arrangement order, without repeats.
    var notRunningApps: [String] = []
    /// Entries whose app is running but has no window left to take.
    var noWindow = 0
    /// Entries whose display is not connected.
    var displayMissing = 0
}

enum ArrangementError: Error, Equatable {
    case storage(GridStorageError)
    /// Nothing on the current Space qualified for a snapshot.
    case noWindows
    case accessibilityDenied
    /// The arrangement was deleted while it was being edited.
    case notFound
}

@MainActor
protocol ArrangementApplying: AnyObject {
    /// Ids of saved arrangements; a hotkey under any other id is not registered.
    var arrangementIDs: Set<UUID> { get }
    @discardableResult
    func apply(_ id: UUID) -> ArrangementApplyReport
}

@MainActor
protocol ArrangementManaging: ArrangementApplying {
    /// Saves the windows open now under `name` and returns the new arrangement.
    func captureCurrent(named name: String) throws(ArrangementError) -> Arrangement
    /// Replaces the arrangement with the same id (editor save, rename); an unknown id throws `.notFound`.
    func save(_ arrangement: Arrangement) throws(ArrangementError)
    /// Removes the arrangement from the file, then its hotkey; a failed write keeps both.
    func delete(_ id: UUID) throws(ArrangementError)
}

@MainActor
protocol WindowCataloging: AnyObject {
    /// Eligible windows of regular apps except Echo: apps in launch order, windows in the order the app reports them.
    func windows() -> [CatalogWindow]
    /// Bundle ids of running regular apps.
    func runningBundleIDs() -> Set<String>
}

@MainActor
protocol WindowFrameSetting: AnyObject {
    func setFrame(_ frameCocoa: CGRect, for window: AXUIElement)
}

@MainActor
protocol GridCycling: AnyObject {
    /// Switches the display of the focused window (else under the pointer) to its next grid and shows it.
    func advance()
}
