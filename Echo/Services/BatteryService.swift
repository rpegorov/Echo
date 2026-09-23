//
//  BatteryService.swift
//  Echo
//

import Foundation

/// Owns the live 24h battery history: a reading on every power-source change
/// and every 5 minutes, plus a per-app ``EnergyInterval`` every 5 minutes
/// while on battery. Runs independently of UI visibility — `start()`/`stop()`
/// own every task and observer it creates.
@MainActor
final class BatteryService: ObservableObject {
    @Published private(set) var hasBattery: Bool = false
    @Published private(set) var current: BatteryReading?
    @Published private(set) var history = BatteryHistory()
    @Published private(set) var lastError: BatteryError?

    private static let historyWindow: TimeInterval = 24 * 60 * 60
    private static let compactInterval: TimeInterval = 60 * 60
    private static let topAppsLimit = 10

    private let power: PowerSourceReading
    private let observer: PowerSourceObserving
    private let energy: ProcessEnergyReading
    private let store: BatteryHistoryStoring
    private let sleeper: TickSleeper
    private let tick: Duration
    private let now: () -> Date

    private var runLoopTask: Task<Void, Never>?
    private var energyBaseline: ProcessEnergySnapshot?
    private var lastCompactDate: Date?

    /// Owns power-source-change processing: the IOKit callback only enqueues,
    /// this single consumer task drains one at a time, so changes stay
    /// serialized and `stop()` can cancel every in-flight one instead of
    /// leaving untracked `Task`s that could append after shutdown.
    private var powerChangeContinuation: AsyncStream<Void>.Continuation?
    private var powerChangeConsumerTask: Task<Void, Never>?

    init(
        power: PowerSourceReading,
        observer: PowerSourceObserving,
        energy: ProcessEnergyReading,
        store: BatteryHistoryStoring,
        sleeper: TickSleeper,
        tick: Duration = .seconds(300),
        now: @escaping () -> Date = Date.init
    ) {
        self.power = power
        self.observer = observer
        self.energy = energy
        self.store = store
        self.sleeper = sleeper
        self.tick = tick
        self.now = now
    }

    /// No-ops on a Mac without a battery, and on a second call while already
    /// running (never creates a second tick loop).
    func start() {
        guard runLoopTask == nil else { return }
        hasBattery = power.hasBattery()
        guard hasBattery else { return }

        runLoopTask = Task { [weak self] in
            await self?.run()
        }
    }

    /// Cancels the tick loop and stops the power-source observer. Safe to
    /// call more than once.
    func stop() {
        runLoopTask?.cancel()
        runLoopTask = nil
        observer.stop()

        powerChangeContinuation?.finish()
        powerChangeContinuation = nil
        powerChangeConsumerTask?.cancel()
        powerChangeConsumerTask = nil
    }

    // MARK: - Startup

    private func run() async {
        await loadInitialHistory()
        guard !Task.isCancelled else { return }

        await recordCurrentReading()
        if let reading = current, !reading.isOnAC {
            energyBaseline = await energy.snapshot()
        }
        guard !Task.isCancelled else { return }

        startPowerChangeConsumer()
        observer.start { [weak self] in
            self?.handlePowerSourceChange()
        }

        lastCompactDate = now()
        await runTickLoop()
    }

    private func startPowerChangeConsumer() {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        powerChangeContinuation = continuation
        powerChangeConsumerTask = Task { [weak self] in
            for await _ in stream {
                await self?.processPowerSourceChange()
            }
        }
    }

    private func loadInitialHistory() async {
        let cutoff = now().addingTimeInterval(-Self.historyWindow)
        do {
            history = try await store.load(since: cutoff)
            try await store.compact(keepingSince: cutoff)
        } catch {
            recordError(error)
        }
    }

    // MARK: - Power-source change

    private func handlePowerSourceChange() {
        powerChangeContinuation?.yield()
    }

    private func processPowerSourceChange() async {
        // Defends against a change that was already enqueued when stop() ran:
        // the stream is drained cooperatively, so a pending yield can still
        // reach here after `runLoopTask` was cleared.
        guard runLoopTask != nil else { return }
        guard let reading = power.read() else { return }
        let previous = current
        current = reading

        if reading.isOnAC {
            energyBaseline = nil
        } else if energyBaseline == nil {
            energyBaseline = await energy.snapshot()
        }

        guard readingChanged(previous, reading) else { return }
        await appendReading(reading)
    }

    private func readingChanged(_ previous: BatteryReading?, _ next: BatteryReading) -> Bool {
        guard let previous else { return true }
        return previous.level != next.level
            || previous.isCharging != next.isCharging
            || previous.isOnAC != next.isOnAC
    }

    // MARK: - Tick loop

    private func runTickLoop() async {
        while !Task.isCancelled {
            do {
                try await sleeper.sleep(for: tick)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await performTick()
        }
    }

    private func performTick() async {
        await recordCurrentReading()
        await recordEnergyIntervalIfOnBattery()
        await compactIfDue()
    }

    private func recordEnergyIntervalIfOnBattery() async {
        guard let reading = current, !reading.isOnAC, let baseline = energyBaseline else { return }

        let snapshot = await energy.snapshot()
        let (total, top) = EnergyDelta.topApps(previous: baseline, current: snapshot, limit: Self.topAppsLimit)
        if total > 0 {
            let interval = EnergyInterval(start: baseline.date, end: now(), totalEnergyNJ: total, top: top)
            await appendInterval(interval)
        }
        energyBaseline = snapshot
    }

    private func compactIfDue() async {
        let currentDate = now()
        if let lastCompactDate, currentDate.timeIntervalSince(lastCompactDate) < Self.compactInterval {
            return
        }
        lastCompactDate = currentDate

        let cutoff = currentDate.addingTimeInterval(-Self.historyWindow)
        history = history.pruned(keepingSince: cutoff)
        do {
            try await store.compact(keepingSince: cutoff)
        } catch {
            recordError(error)
        }
    }

    // MARK: - History mutation

    private func recordCurrentReading() async {
        guard let reading = power.read() else { return }
        current = reading
        await appendReading(reading)
    }

    private func appendReading(_ reading: BatteryReading) async {
        history.readings.append(reading)
        prune()
        do {
            try await store.append(reading)
        } catch {
            recordError(error)
        }
    }

    private func appendInterval(_ interval: EnergyInterval) async {
        history.intervals.append(interval)
        prune()
        do {
            try await store.append(interval)
        } catch {
            recordError(error)
        }
    }

    private func prune() {
        history = history.pruned(keepingSince: now().addingTimeInterval(-Self.historyWindow))
    }

    private func recordError(_ error: Error) {
        lastError = (error as? BatteryError) ?? .storage(error.localizedDescription)
    }
}
