//
//  BatteryKey.swift
//  Echo
//

import Foundation

/// Strings for the Battery detail tab (chart, energy list, empty states).
enum BatteryKey: String, LocalizedKey {
    case noDataYet
    case chargingNoDrain
    case storageError
    case currentUserProcessesFootnote
    case charging
    case onBattery

    static var table: String { "Battery" }
}
