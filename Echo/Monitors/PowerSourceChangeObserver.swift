//
//  PowerSourceChangeObserver.swift
//  Echo
//

import Foundation
import IOKit.ps
import os

/// Observes IOKit power source change notifications and forwards them to a
/// main-actor callback. Runs its run-loop source on the main run loop.
@MainActor
final class PowerSourceChangeObserver: PowerSourceObserving {

    private nonisolated static let logger = Logger(subsystem: "com.echo.app", category: "PowerSourceChangeObserver")

    private var onChange: (() -> Void)?
    private var runLoopSource: CFRunLoopSource?

    /// Mirrors whether `runLoopSource` is set, readable from `deinit`
    /// (nonisolated, and `CFRunLoopSource` isn't `Sendable`). Only ever
    /// written on the main actor alongside `runLoopSource` itself, and
    /// `deinit` only runs once nothing else can be touching this instance, so
    /// the unsynchronized read here is safe.
    private nonisolated(unsafe) var hasActiveRunLoopSource = false

    /// `start()` hands this instance a manual `Unmanaged.passRetained` self
    /// reference that only `stop()` releases; if the last other reference is
    /// dropped without `stop()` having run, that retain keeps this object
    /// alive forever — this deinit only fires by some other misuse, and
    /// signals it loudly instead of leaking silently.
    deinit {
        guard hasActiveRunLoopSource else { return }
        assertionFailure("PowerSourceChangeObserver deinitialized without stop() — the run loop source and its retained self reference leaked")
        Self.logger.fault("PowerSourceChangeObserver deinitialized without stop() — the run loop source and its retained self reference leaked")
    }

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
        hasActiveRunLoopSource = true
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func stop() {
        guard let source = runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = nil
        hasActiveRunLoopSource = false
        onChange = nil
        Unmanaged.passUnretained(self).release()
    }
}
