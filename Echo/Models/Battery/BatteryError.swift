//
//  BatteryError.swift
//  Echo
//

import Foundation

/// Errors surfaced from battery history storage.
enum BatteryError: Error, Equatable {
    case storage(String)
}
