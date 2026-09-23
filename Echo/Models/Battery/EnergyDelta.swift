//
//  EnergyDelta.swift
//  Echo
//

import Foundation

/// Computes per-app energy consumption between two process-energy snapshots.
enum EnergyDelta {

    /// - Returns: Total energy consumed across all apps, and the top
    ///   `limit` apps by energy, descending.
    static func topApps(
        previous: ProcessEnergySnapshot,
        current: ProcessEnergySnapshot,
        limit: Int
    ) -> (total: UInt64, top: [AppEnergyUsage]) {
        var perApp: [String: (name: String, bundleID: String?, energyNJ: UInt64)] = [:]

        for (key, entry) in current.entries {
            guard let delta = energyDelta(for: key, entry: entry, previous: previous) else { continue }

            let attribution = AppAttribution.app(forExecutablePath: entry.executablePath, fallbackName: entry.name)
            let appID = attribution.bundleID ?? attribution.name

            var aggregate = perApp[appID] ?? (name: attribution.name, bundleID: attribution.bundleID, energyNJ: 0)
            aggregate.energyNJ += delta
            perApp[appID] = aggregate
        }

        let total = perApp.values.reduce(UInt64(0)) { $0 + $1.energyNJ }
        let top = perApp
            .sorted { $0.value.energyNJ > $1.value.energyNJ }
            .prefix(limit)
            .map { appID, aggregate in
                AppEnergyUsage(id: appID, appName: aggregate.name, bundleID: aggregate.bundleID, energyNJ: aggregate.energyNJ)
            }

        return (total, top)
    }

    // MARK: - Private

    /// - Returns: `nil` when the process should not contribute to this
    ///   interval — either the counter went backwards (pid reuse guarded by
    ///   `ProcessKey`, should not normally happen) or it is a process that
    ///   already existed before `previous` but is missing from it (a process
    ///   this sampler could not read last time; its prior usage is unknown).
    private static func energyDelta(
        for key: ProcessKey,
        entry: ProcessEnergyEntry,
        previous: ProcessEnergySnapshot
    ) -> UInt64? {
        if let previousEntry = previous.entries[key] {
            guard entry.energyNJ >= previousEntry.energyNJ else { return nil }
            return entry.energyNJ - previousEntry.energyNJ
        }
        if key.startAbstime > previous.machTime {
            return entry.energyNJ
        }
        return nil
    }
}
