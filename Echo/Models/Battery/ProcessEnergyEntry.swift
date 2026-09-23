//
//  ProcessEnergyEntry.swift
//  Echo
//

import Foundation

/// Raw per-process energy counter read at sample time.
struct ProcessEnergyEntry: Equatable {
    let energyNJ: UInt64
    let executablePath: String?
    let name: String
}
