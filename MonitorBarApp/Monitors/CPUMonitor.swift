//
//  CPUMonitor.swift
//  MonitorBarApp
//

import Foundation

/// Delta-based CPU monitor. Each method maintains its own prev-snapshot so
/// currentUsage() and perCoreUsage() can be polled independently without
/// corrupting each other's baseline.
actor CPUMonitor: CPUMonitoring {

    private var prevOverall: [(user: Int32, system: Int32, idle: Int32, nice: Int32)] = []
    private var prevPerCore: [(user: Int32, system: Int32, idle: Int32, nice: Int32)] = []

    func currentUsage() async -> Double {
        guard let snapshot = takeCPUSnapshot() else { return 0 }
        defer { prevOverall = snapshot }

        guard !prevOverall.isEmpty, prevOverall.count == snapshot.count else { return 0 }

        var totalIdle = 0
        var totalAll  = 0
        for (prev, curr) in zip(prevOverall, snapshot) {
            let idle   = Int(curr.idle)   - Int(prev.idle)
            let user   = Int(curr.user)   - Int(prev.user)
            let system = Int(curr.system) - Int(prev.system)
            let nice   = Int(curr.nice)   - Int(prev.nice)
            totalIdle += idle
            totalAll  += idle + user + system + nice
        }
        guard totalAll > 0 else { return 0 }
        return max(0, min(100, (1.0 - Double(totalIdle) / Double(totalAll)) * 100))
    }

    func perCoreUsage() async -> [Double] {
        guard let snapshot = takeCPUSnapshot() else { return [] }
        defer { prevPerCore = snapshot }

        guard !prevPerCore.isEmpty, prevPerCore.count == snapshot.count else { return [] }

        return zip(prevPerCore, snapshot).map { prev, curr in
            let idle   = Int(curr.idle)   - Int(prev.idle)
            let user   = Int(curr.user)   - Int(prev.user)
            let system = Int(curr.system) - Int(prev.system)
            let nice   = Int(curr.nice)   - Int(prev.nice)
            let total  = idle + user + system + nice
            guard total > 0 else { return 0 }
            return max(0, min(100, (1.0 - Double(idle) / Double(total)) * 100))
        }
    }

    // MARK: - Private

    private func takeCPUSnapshot() -> [(user: Int32, system: Int32, idle: Int32, nice: Int32)]? {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo = mach_msg_type_number_t(0)
        var numCPU: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPU,
            &cpuInfo,
            &numCpuInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else { return nil }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(numCpuInfo)
            )
        }

        return (0..<Int(clamping: numCPU)).map { i in
            let offset = i * Int(clamping: CPU_STATE_MAX)
            return (
                user:   info[offset + Int(CPU_STATE_USER)],
                system: info[offset + Int(CPU_STATE_SYSTEM)],
                idle:   info[offset + Int(CPU_STATE_IDLE)],
                nice:   info[offset + Int(CPU_STATE_NICE)]
            )
        }
    }
}
