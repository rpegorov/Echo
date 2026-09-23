//
//  PowerSourceMonitor.swift
//  Echo
//

import Foundation
import IOKit.ps

/// One-shot reader of the Mac's internal battery state via IOKit power sources.
struct PowerSourceMonitor: PowerSourceReading {

    func hasBattery() -> Bool {
        internalBatterySource() != nil
    }

    func read() -> BatteryReading? {
        guard let source = internalBatterySource() else { return nil }

        guard
            let currentCapacity = source[kIOPSCurrentCapacityKey as String] as? Int,
            let maxCapacity = source[kIOPSMaxCapacityKey as String] as? Int,
            maxCapacity > 0
        else { return nil }

        let level = Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())
        let isCharging = (source[kIOPSIsChargingKey as String] as? Bool) ?? false
        let isOnAC = (source[kIOPSPowerSourceStateKey as String] as? String) == kIOPSACPowerValue

        return BatteryReading(date: Date(), level: level, isCharging: isCharging, isOnAC: isOnAC)
    }

    /// Returns the description dictionary of the internal battery power source, if present.
    private func internalBatterySource() -> [String: Any]? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                as? [String: Any]
            else { continue }
            guard description[kIOPSTypeKey as String] as? String == kIOPSInternalBatteryType else {
                continue
            }
            return description
        }
        return nil
    }
}
