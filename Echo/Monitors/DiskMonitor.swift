//
//  DiskMonitor.swift
//  MonitorBarApp
//

import Foundation

/// Монитор использования диска через FileManager.
actor DiskMonitor: DiskMonitoring {

    func info() async -> DiskMetrics {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            guard
                let total = attrs[.systemSize]     as? Int64,
                let free  = attrs[.systemFreeSize] as? Int64
            else { return DiskMetrics() }
            return DiskMetrics(used: total - free, total: total)
        } catch {
            return DiskMetrics()
        }
    }
}
