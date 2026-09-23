//
//  PowerSourceObserving.swift
//  Echo
//

import Foundation

/// Notifies on power source changes (IOPS) independent of the polling tick.
@MainActor
protocol PowerSourceObserving {
    func start(onChange: @escaping () -> Void)
    func stop()
}
