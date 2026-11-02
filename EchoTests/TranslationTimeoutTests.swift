//
//  TranslationTimeoutTests.swift
//  EchoTests
//
//  A translation session that never answers must not hang `translate` forever.
//  Before the watchdog, one lost session left SelectionTranslator.isBusy raised
//  permanently, and the translate hotkey silently died until relaunch.
//

import Foundation
import Synchronization
import Testing
@testable import Echo

@MainActor
struct TranslationTimeoutTests {

    private enum Timing {
        static let sessionTimeout: TimeInterval = 0.2
        static let pollInterval: TimeInterval = 0.05
        static let guardWindow: TimeInterval = 5
    }

    @Test("lost session resolves instead of hanging forever")
    func lostSessionResolvesInsteadOfHanging() async {
        let service = TranslationService()
        service.sessionTimeout = Timing.sessionTimeout
        let done = Mutex(false)

        let pending = Task { @MainActor in
            let result = await service.translate("hello")
            done.withLock { $0 = true }
            return result
        }

        let deadline = Date().addingTimeInterval(Timing.guardWindow)
        while Date() < deadline && !done.withLock({ $0 }) {
            try? await Task.sleep(for: .seconds(Timing.pollInterval))
        }

        guard done.withLock({ $0 }) else {
            Issue.record("translate() hung: the session watchdog did not fire")
            return
        }
        // The result itself is not asserted: on a machine with installed
        // translation models the real session may answer, while a model-less
        // environment yields nil from the watchdog. The contract tested here
        // is "never hangs forever".
    }
}
