//
//  ProcessEnergySnapshot.swift
//  Echo
//

import Foundation

/// One sampling pass over all processes' energy counters.
struct ProcessEnergySnapshot: Equatable {
    let date: Date
    let machTime: UInt64
    let entries: [ProcessKey: ProcessEnergyEntry]
}
