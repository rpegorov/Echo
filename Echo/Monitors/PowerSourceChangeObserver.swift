//
//  PowerSourceChangeObserver.swift
//  Echo
//

import Foundation
import IOKit.ps

/// Observes IOKit power source change notifications and forwards them to a
/// main-actor callback. Runs its run-loop source on the main run loop.
@MainActor
final class PowerSourceChangeObserver: PowerSourceObserving {

    private var onChange: (() -> Void)?
    private var runLoopSource: CFRunLoopSource?

    /// `start()` gives the IOKit callback a manually retained reference to
    /// this instance; only `stop()` releases it. The owner must call `stop()` —
    /// `BatteryService.stop()` does, from `applicationWillTerminate`.
    func start(onChange: @escaping () -> Void) {
        stop()

        self.onChange = onChange

        let context = Unmanaged.passRetained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let observer = Unmanaged<PowerSourceChangeObserver>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                observer.onChange?()
            }
        }, context)?.takeRetainedValue() else {
            Unmanaged<PowerSourceChangeObserver>.fromOpaque(context).release()
            return
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    func stop() {
        guard let source = runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = nil
        onChange = nil
        Unmanaged.passUnretained(self).release()
    }
}
