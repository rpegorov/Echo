//
//  RAMMonitor.swift
//  MonitorBarApp
//

import Foundation

/// Монитор оперативной памяти через vm_statistics64.
/// total берётся из ProcessInfo.physicalMemory — реальный объём RAM, а не
/// вычисленный used+free, который занижает значение из-за speculative free pool.
actor RAMMonitor: RAMMonitoring {

    func info() async -> RAMMetrics {
        var stats = vm_statistics64()
        var count = UInt32(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let hostResult = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard hostResult == KERN_SUCCESS else { return RAMMetrics() }

        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            return RAMMetrics()
        }

        let page       = Int64(pageSize)
        let active     = Int64(stats.active_count)          * page
        let wired      = Int64(stats.wire_count)            * page
        let compressed = Int64(stats.compressor_page_count) * page

        // Activity Monitor formula: App Memory (active) + Wired + Compressed.
        // inactive = "Cached Files" — не входит в "Used".
        let used  = active + wired + compressed
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        let free  = max(total - used, 0)

        return RAMMetrics(used: used, free: free, total: total)
    }
}
