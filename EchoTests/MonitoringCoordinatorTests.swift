import AppKit
import Testing
@testable import Echo

/// T3b — MonitoringCoordinator.stop() must actually remove its sleep/wake/
/// power tokens, not just null them out while a block is still registered
/// with NSWorkspace/NotificationCenter.
///
/// `MetricsService` exposes no other observable state, but `interval`
/// (`private(set)`, so internal — readable via `@testable import`) is enough:
/// the wake handler recomputes and re-applies `currentInterval` from
/// `AppSettings` unconditionally. So after `stop()`, changing the setting the
/// handler would read and then posting the notification isolates exactly one
/// thing — whether the handler still runs.
@Suite("MonitoringCoordinator")
@MainActor
struct MonitoringCoordinatorTests {

    private func ephemeralSettings() -> AppSettings {
        let suiteName = "EchoTests.monitoring-coordinator.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppSettings(defaults: defaults)
    }

    @Test("stop() removes the wake observer: a notification posted after stop() has no effect")
    func stopRemovesWakeObserver() async {
        let settings = ephemeralSettings()
        settings.pauseWhenHidden = false
        settings.lowPowerThrottle = false
        settings.menuBarInterval = 5

        let metrics = MetricsService()
        let coordinator = MonitoringCoordinator(settings: settings, metrics: metrics)
        coordinator.isUIVisible = { false }

        coordinator.start()
        #expect(metrics.interval == 5)

        coordinator.stop()

        // If the wake observer were still attached, its handler would read
        // this new value and push it into `metrics`. Isolated by only the
        // observer's presence, since nothing else in this test can call
        // `applyMonitoring()`.
        settings.menuBarInterval = 99

        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        // NSWorkspace's notification center dispatches to `queue: .main`
        // asynchronously rather than synchronously on post; yielding (not
        // sleeping a guessed interval) lets that already-queued block run
        // before the assertion, without introducing timing-dependent flake.
        for _ in 0..<10 { await Task.yield() }

        #expect(
            metrics.interval == 5,
            "stop() must remove the wake observer; interval became \(metrics.interval) after a notification posted following stop()"
        )
    }
}
