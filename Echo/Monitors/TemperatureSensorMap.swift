//
//  TemperatureSensorMap.swift
//  Echo
//

import Foundation

/// Maps the SMC keys a Mac exposes to CPU and GPU sensor sets. Key families
/// are undocumented and differ per chip generation; the rules encode the
/// families verified on M-series Macs (M1–M4) plus the classic Intel keys.
/// Some firmwares report stored limits on unused keys of these families —
/// the static-key filter keeps them out of the maximum.
enum TemperatureSensorMap {

    /// M3 GPUs report through Tf* keys; the Tg* family only reappears on M4.
    private static let m3GPUKeys: Set<String> = [
        "Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A"
    ]
    private static let intelCPUKeys: Set<String> = ["TC0P", "TC0D", "TC0E", "TC0F"]
    private static let intelGPUKeys: Set<String> = ["TG0P", "TG0D"]

    private static let cpuPrefixes = ["Tp", "Te", "Tf"]

    static func gpuKeys(available: Set<String>) -> Set<String> {
        let appleSilicon = available.filter { $0.hasPrefix("Tg") }
        if !appleSilicon.isEmpty { return appleSilicon }
        let m3GPU = m3GPUKeys.intersection(available)
        if !m3GPU.isEmpty { return m3GPU }
        return intelGPUKeys.intersection(available)
    }

    static func cpuKeys(available: Set<String>) -> Set<String> {
        let gpu = gpuKeys(available: available)
        let appleSilicon = available
            .filter { key in cpuPrefixes.contains { key.hasPrefix($0) } }
            .subtracting(gpu)
        if !appleSilicon.isEmpty { return appleSilicon }
        return intelCPUKeys.intersection(available)
    }
}
