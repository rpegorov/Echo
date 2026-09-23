//
//  ProcessEnergySampler.swift
//  Echo
//

import AppKit
import Darwin
import Foundation

/// Samples per-process energy counters via `proc_pid_rusage(RUSAGE_INFO_V6)`.
/// Only the current user's processes are readable without elevated
/// privileges; others fail with EPERM/ESRCH and are skipped.
actor ProcessEnergySampler: ProcessEnergyReading {

    func snapshot() async -> ProcessEnergySnapshot {
        let date = Date()
        let machTime = mach_absolute_time()
        let samples = Self.allPids().compactMap(Self.sample(pid:))

        // Intel Macs never populate ri_energy_nj; fall back to ri_billed_energy
        // for the whole snapshot when every sample read zero.
        let useBilledEnergy = !samples.isEmpty && samples.allSatisfy { $0.energyNJ == 0 }

        var entries: [ProcessKey: ProcessEnergyEntry] = [:]
        entries.reserveCapacity(samples.count)
        for sample in samples {
            let energyNJ = useBilledEnergy ? sample.billedEnergyNJ : sample.energyNJ
            entries[sample.key] = ProcessEnergyEntry(
                energyNJ: energyNJ,
                executablePath: sample.executablePath,
                name: sample.name
            )
        }

        return ProcessEnergySnapshot(date: date, machTime: machTime, entries: entries)
    }

    // MARK: - Private

    private struct RawSample {
        let key: ProcessKey
        let energyNJ: UInt64
        let billedEnergyNJ: UInt64
        let executablePath: String?
        let name: String
    }

    private static func allPids() -> [pid_t] {
        let requiredSize = proc_listallpids(nil, 0)
        guard requiredSize > 0 else { return [] }

        let capacity = Int(requiredSize) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: capacity)
        let actualSize = proc_listallpids(&pids, requiredSize)
        guard actualSize > 0 else { return [] }

        let count = min(pids.count, Int(actualSize) / MemoryLayout<pid_t>.size)
        return Array(pids.prefix(count))
    }

    private static func sample(pid: pid_t) -> RawSample? {
        var info = rusage_info_v6()
        let result = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rawPointer in
                proc_pid_rusage(pid, RUSAGE_INFO_V6, rawPointer)
            }
        }
        // EPERM (another user's process) or ESRCH (process already gone):
        // skip silently, this pid contributes nothing to the snapshot.
        guard result == 0 else { return nil }

        let executablePath = executablePath(forPid: pid)
        let key = ProcessKey(pid: pid, startAbstime: info.ri_proc_start_abstime)
        return RawSample(
            key: key,
            energyNJ: info.ri_energy_nj,
            billedEnergyNJ: info.ri_billed_energy,
            executablePath: executablePath,
            name: name(forPid: pid, executablePath: executablePath)
        )
    }

    /// NSRunningApplication first (visible apps), else the parent `.app` of
    /// the executable path via ``AppAttribution``, else the raw proc name.
    private static func name(forPid pid: pid_t, executablePath: String?) -> String {
        if let running = NSRunningApplication(processIdentifier: pid), let localizedName = running.localizedName {
            return localizedName
        }
        if let executablePath {
            let baseName = (executablePath as NSString).lastPathComponent
            return AppAttribution.app(forExecutablePath: executablePath, fallbackName: baseName).name
        }
        return procName(pid: pid) ?? "pid \(pid)"
    }

    /// `PROC_PIDPATHINFO_MAXSIZE` (`4 * MAXPATHLEN`) is a computed macro the
    /// Clang importer does not bridge, so it is inlined here.
    private static let maxPathInfoSize = Int(4 * PATH_MAX)

    private static func executablePath(forPid pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Self.maxPathInfoSize)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func procName(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 1024)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }
}
