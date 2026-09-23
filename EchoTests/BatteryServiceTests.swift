//
//  BatteryServiceTests.swift
//  EchoTests
//
//  Tests written against the WAVE 3 plan contract for BatteryService (task B4):
//  "init(power:observer:energy:store:sleeper:tick:now:), start(), stop(),
//  @Published hasBattery/current/history/lastError". Every collaborator is
//  faked; the TickSleeper fake is driven manually via continuations so no
//  real time ever passes — no sleep(), no Task.sleep, no polling loops.
//

import Testing
@testable import Echo
import Foundation

// MARK: - Fakes

private struct FakePowerSourceReading: PowerSourceReading, Sendable {
    var batteryPresent: Bool
    var reading: BatteryReading?
    func hasBattery() -> Bool { batteryPresent }
    func read() -> BatteryReading? { reading }
}

@MainActor
private final class FakePowerSourceObserving: PowerSourceObserving {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private var onChange: (() -> Void)?

    func start(onChange: @escaping () -> Void) {
        startCallCount += 1
        self.onChange = onChange
    }

    func stop() {
        stopCallCount += 1
    }

    func fireChange() { onChange?() }
}

private final class FakeProcessEnergyReading: ProcessEnergyReading, @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [ProcessEnergySnapshot]
    private(set) var callCount = 0

    init(_ snapshots: [ProcessEnergySnapshot]) { self.queue = snapshots }

    /// Synchronous helper: keeping lock/unlock out of the lexical body of an
    /// `async` function avoids "unavailable from asynchronous contexts".
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func snapshot() async -> ProcessEnergySnapshot {
        withLock {
            let value = queue.isEmpty
                ? ProcessEnergySnapshot(date: .now, machTime: 0, entries: [:])
                : queue[min(callCount, queue.count - 1)]
            callCount += 1
            return value
        }
    }
}

/// Records every store operation and can be told to fail on demand. Exposes
/// `waitForReadings`/`waitForIntervals` so tests can await a specific number
/// of appends without any timer — pure continuation-based synchronization.
private final class FakeBatteryHistoryStore: BatteryHistoryStoring, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var loadCallCount = 0
    private(set) var compactCallCount = 0
    private(set) var appendedReadings: [BatteryReading] = []
    private(set) var appendedIntervals: [EnergyInterval] = []
    var historyToLoad = BatteryHistory()
    var loadError: Error?
    var appendReadingError: Error?

    private var readingWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var intervalWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    /// Synchronous helper: keeping lock/unlock out of the lexical body of an
    /// `async` function avoids "unavailable from asynchronous contexts".
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func load(since: Date) async throws -> BatteryHistory {
        withLock { loadCallCount += 1 }
        if let loadError { throw loadError }
        return historyToLoad
    }

    func append(_ reading: BatteryReading) async throws {
        if let appendReadingError { throw appendReadingError }
        let ready = withLock { () -> [(Int, CheckedContinuation<Void, Never>)] in
            appendedReadings.append(reading)
            let ready = readingWaiters.filter { appendedReadings.count >= $0.0 }
            readingWaiters.removeAll { appendedReadings.count >= $0.0 }
            return ready
        }
        ready.forEach { $0.1.resume() }
    }

    func append(_ interval: EnergyInterval) async throws {
        let ready = withLock { () -> [(Int, CheckedContinuation<Void, Never>)] in
            appendedIntervals.append(interval)
            let ready = intervalWaiters.filter { appendedIntervals.count >= $0.0 }
            intervalWaiters.removeAll { appendedIntervals.count >= $0.0 }
            return ready
        }
        ready.forEach { $0.1.resume() }
    }

    func compact(keepingSince: Date) async throws {
        withLock { compactCallCount += 1 }
    }

    func waitForReadings(count: Int) async {
        let alreadyDone = withLock { appendedReadings.count >= count }
        if alreadyDone { return }
        await withCheckedContinuation { continuation in
            withLock { readingWaiters.append((count, continuation)) }
        }
    }

    func waitForIntervals(count: Int) async {
        let alreadyDone = withLock { appendedIntervals.count >= count }
        if alreadyDone { return }
        await withCheckedContinuation { continuation in
            withLock { intervalWaiters.append((count, continuation)) }
        }
    }
}

/// Drives BatteryService's polling loop deterministically: the loop calls
/// `sleep(for:)` and suspends; the test resumes it explicitly, one tick at a
/// time, and can wait until the loop is back inside `sleep` (meaning the
/// previous tick finished running).
/// `@unchecked Sendable`: all mutable state is confined to `@MainActor`
/// (the only isolation this fake is ever driven from in tests), matching the
/// now-`Sendable` `TickSleeper` protocol without introducing a separate lock.
@MainActor
private final class FakeTickSleeper: TickSleeper, @unchecked Sendable {
    private var pendingSleeps: [CheckedContinuation<Void, Error>] = []
    private var sleepCallWaiters: [CheckedContinuation<Void, Never>] = []

    func sleep(for interval: Duration) async throws {
        try await withCheckedThrowingContinuation { continuation in
            pendingSleeps.append(continuation)
            let waiters = sleepCallWaiters
            sleepCallWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
    }

    func waitUntilWaitingForSleep() async {
        if !pendingSleeps.isEmpty { return }
        await withCheckedContinuation { sleepCallWaiters.append($0) }
    }

    /// Resumes the oldest pending tick and waits until the loop reaches its
    /// next sleep call again — i.e. until that tick has fully finished.
    func advanceOneTick() async {
        if pendingSleeps.isEmpty { await waitUntilWaitingForSleep() }
        guard !pendingSleeps.isEmpty else { return }
        pendingSleeps.removeFirst().resume()
        await waitUntilWaitingForSleep()
    }

    /// Resumes the oldest pending sleep without waiting for the loop to reach
    /// another `sleep()` call afterwards. Use this after `stop()`: a
    /// cancelled loop is contractually not expected to sleep again, so
    /// `advanceOneTick()`'s post-resume wait would hang forever.
    func resumePendingSleepWithoutWaiting() {
        guard !pendingSleeps.isEmpty else { return }
        pendingSleeps.removeFirst().resume()
    }
}

// MARK: - Test data helpers

@MainActor
private enum Fixtures {
    static let onBatteryReading = BatteryReading(date: .now, level: 80, isCharging: false, isOnAC: false)
    static let onACReading = BatteryReading(date: .now, level: 100, isCharging: false, isOnAC: true)

    static func snapshot(_ energyNJ: UInt64, machTime: UInt64) -> ProcessEnergySnapshot {
        ProcessEnergySnapshot(
            date: .now,
            machTime: machTime,
            entries: [ProcessKey(pid: 1, startAbstime: 1): ProcessEnergyEntry(energyNJ: energyNJ, executablePath: nil, name: "App")]
        )
    }
}

// MARK: - Tests

@MainActor
@Suite("BatteryService — requirement B4")
struct BatteryServiceTests {

    private func makeService(
        hasBattery: Bool = true,
        reading: BatteryReading? = Fixtures.onBatteryReading,
        store: FakeBatteryHistoryStore = FakeBatteryHistoryStore(),
        energy: FakeProcessEnergyReading = FakeProcessEnergyReading([Fixtures.snapshot(0, machTime: 0), Fixtures.snapshot(100, machTime: 1)]),
        observer: FakePowerSourceObserving = FakePowerSourceObserving(),
        sleeper: FakeTickSleeper = FakeTickSleeper()
    ) -> BatteryService {
        BatteryService(
            power: FakePowerSourceReading(batteryPresent: hasBattery, reading: reading),
            observer: observer,
            energy: energy,
            store: store,
            sleeper: sleeper,
            tick: .seconds(300),
            now: { .now }
        )
    }

    // MARK: Positive

    @Test("[wiring] start() on a battery Mac loads history and records an initial reading")
    func startLoadsHistoryAndRecordsReading() async {
        let store = FakeBatteryHistoryStore()
        let service = makeService(store: store)

        service.start()
        await store.waitForReadings(count: 1)

        #expect(store.loadCallCount >= 1)
        #expect(service.hasBattery == true)
        #expect(service.current == Fixtures.onBatteryReading)
        #expect(store.appendedReadings == [Fixtures.onBatteryReading])
    }

    @Test("Two ticks on battery with a baseline append exactly one EnergyInterval")
    func twoTicksAppendExactlyOneInterval() async {
        let store = FakeBatteryHistoryStore()
        let sleeper = FakeTickSleeper()
        // Baseline snapshot, then one tick with genuine usage since baseline
        // (100 - 0). The queue is exhausted after that, so the second tick
        // reuses this same last snapshot as both its baseline and its
        // current reading — a zero delta, correctly producing no interval.
        let energy = FakeProcessEnergyReading([
            Fixtures.snapshot(0, machTime: 0),
            Fixtures.snapshot(100, machTime: 1),
        ])
        let service = makeService(store: store, energy: energy, sleeper: sleeper)

        service.start()
        await sleeper.waitUntilWaitingForSleep()
        await sleeper.advanceOneTick()
        await sleeper.advanceOneTick()

        #expect(store.appendedIntervals.count == 1)
    }

    @Test("On AC power, ticks never append an EnergyInterval")
    func onACTicksAppendNoIntervals() async {
        let store = FakeBatteryHistoryStore()
        let sleeper = FakeTickSleeper()
        let service = makeService(reading: Fixtures.onACReading, store: store, sleeper: sleeper)

        service.start()
        await sleeper.waitUntilWaitingForSleep()
        await sleeper.advanceOneTick()
        await sleeper.advanceOneTick()
        await sleeper.advanceOneTick()

        #expect(store.appendedIntervals.isEmpty)
    }

    @Test("stop() cancels the polling loop and stops the observer")
    func stopCancelsLoopAndObserver() async {
        let store = FakeBatteryHistoryStore()
        let sleeper = FakeTickSleeper()
        let observer = FakePowerSourceObserving()
        let service = makeService(store: store, observer: observer, sleeper: sleeper)

        service.start()
        await sleeper.waitUntilWaitingForSleep()
        service.stop()

        #expect(observer.stopCallCount >= 1)

        let intervalsBefore = store.appendedIntervals.count
        // A cancelled loop is not expected to reach `sleep()` again, so we
        // resume its pending sleep directly rather than via `advanceOneTick()`
        // (which would wait for exactly that — a wait that would never
        // resolve).
        sleeper.resumePendingSleepWithoutWaiting()
        // Give any (incorrectly) still-running loop a chance to act; nothing
        // should happen since the loop was cancelled. No real delay: just
        // yield the cooperative scheduler a few times.
        for _ in 0..<5 { await Task.yield() }
        #expect(store.appendedIntervals.count == intervalsBefore)
    }

    // MARK: Negative

    @Test("hasBattery == false: start() does nothing — no observer, no ticks, no store access")
    func noBatteryStartIsNoOp() async {
        let store = FakeBatteryHistoryStore()
        let sleeper = FakeTickSleeper()
        let observer = FakePowerSourceObserving()
        let service = makeService(hasBattery: false, reading: nil, store: store, observer: observer, sleeper: sleeper)

        service.start()

        #expect(service.hasBattery == false)
        #expect(observer.startCallCount == 0)
        #expect(store.loadCallCount == 0)
        #expect(store.appendedReadings.isEmpty)
    }

    @Test("A store append failure surfaces in lastError")
    func appendFailureSurfacesInLastError() async {
        let store = FakeBatteryHistoryStore()
        store.appendReadingError = BatteryError.storage("disk full")
        let service = makeService(store: store)

        service.start()
        await Task.yield()
        // Give the failing append a chance to propagate.
        for _ in 0..<20 where service.lastError == nil {
            await Task.yield()
        }

        #expect(service.lastError != nil)
    }

    @Test("Calling start() twice does not double-register the observer")
    func doubleStartDoesNotDoubleRegisterObserver() async {
        let store = FakeBatteryHistoryStore()
        let observer = FakePowerSourceObserving()
        let service = makeService(store: store, observer: observer)

        service.start()
        await store.waitForReadings(count: 1)
        service.start()
        await Task.yield()

        #expect(observer.startCallCount == 1)
    }

    @Test("A store load failure at start surfaces in lastError")
    func loadFailureSurfacesInLastError() async {
        let store = FakeBatteryHistoryStore()
        store.loadError = BatteryError.storage("unreadable")
        let service = makeService(store: store)

        service.start()
        for _ in 0..<20 where service.lastError == nil {
            await Task.yield()
        }

        #expect(service.lastError != nil)
    }
}
