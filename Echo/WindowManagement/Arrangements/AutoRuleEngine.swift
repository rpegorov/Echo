//
//  AutoRuleEngine.swift
//  Echo
//

import AppKit
import ApplicationServices
import Combine
import os

/// Puts new windows of apps with an enabled auto rule into the rule's zone.
/// Event-driven only: work happens on launch, terminate, rule changes and window creation.
@MainActor
final class AutoRuleEngine {

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Echo",
        category: "AutoRuleEngine"
    )

    private struct Watch {
        let bundleID: String
        let observer: any WindowCreationObserving
    }

    private let store: GridStore
    private let frames: any WindowFrameSetting
    private let displays: @MainActor () -> [DisplaySnapshot]
    private let gap: @MainActor () -> CGFloat
    private let workspace: NSWorkspace
    private let hasPermission: @MainActor () -> Bool
    private let makeObserver: @MainActor (Int32, @escaping @MainActor (AXUIElement) -> Void)
        -> (any WindowCreationObserving)?

    private var subscriptions: [AnyCancellable] = []
    private var watches: [pid_t: Watch] = [:]
    /// Processes whose observer could not be created; not retried until the app is launched again.
    private var failedPIDs: Set<pid_t> = []

    init(
        store: GridStore,
        frames: any WindowFrameSetting,
        displays: @escaping @MainActor () -> [DisplaySnapshot],
        gap: @escaping @MainActor () -> CGFloat,
        workspace: NSWorkspace,
        hasPermission: @escaping @MainActor () -> Bool = { AXIsProcessTrusted() },
        makeObserver: @escaping @MainActor (Int32, @escaping @MainActor (AXUIElement) -> Void)
            -> (any WindowCreationObserving)? = { WindowCreationObserver(pid: $0, onWindowCreated: $1) }
    ) {
        self.store = store
        self.frames = frames
        self.displays = displays
        self.gap = gap
        self.workspace = workspace
        self.hasPermission = hasPermission
        self.makeObserver = makeObserver
    }

    /// Idempotent: true attaches observers for running apps with an enabled rule and follows launches;
    /// false removes every observer and subscription.
    func update(enabled: Bool) {
        if enabled {
            start()
        } else {
            stop()
        }
    }

    /// Bundle ids that need an observer.
    static func observedBundleIDs(rules: [AutoRule]) -> Set<String> {
        Set(rules.lazy.filter(\.isEnabled).map(\.bundleID))
    }

    /// Frame for a new window of `bundleID`; nil when the app has no enabled rule or the rule's display is gone.
    static func targetFrame(
        forBundleID bundleID: String,
        rules: [AutoRule],
        displays: [DisplaySnapshot],
        gap: CGFloat
    ) -> CGRect? {
        guard let rule = rules.first(where: { $0.isEnabled && $0.bundleID == bundleID }) else { return nil }
        return SlotPlacement.frame(for: rule.slot, displays: displays, gap: gap)
    }

    // MARK: - Lifecycle

    private func start() {
        guard subscriptions.isEmpty else { return }
        let center = workspace.notificationCenter
        subscriptions = [
            center.publisher(for: NSWorkspace.didLaunchApplicationNotification)
                .sink { [weak self] note in
                    let app = Self.application(in: note)
                    MainActor.assumeIsolated { self?.appLaunched(app) }
                },
            center.publisher(for: NSWorkspace.didTerminateApplicationNotification)
                .sink { [weak self] note in
                    let app = Self.application(in: note)
                    MainActor.assumeIsolated { self?.appTerminated(app) }
                },
            // @Published emits the current value on subscription, which performs the initial attach.
            store.$document
                .map(\.rules)
                .removeDuplicates()
                .sink { [weak self] rules in
                    MainActor.assumeIsolated { self?.rulesChanged(rules) }
                }
        ]
    }

    private func stop() {
        subscriptions.removeAll()
        watches.values.forEach { $0.observer.invalidate() }
        watches.removeAll()
        failedPIDs.removeAll()
    }

    private static func application(in note: Notification) -> NSRunningApplication? {
        note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }

    // MARK: - Events

    /// An app launched after the engine started: its first window may exist before the observer does.
    private func appLaunched(_ app: NSRunningApplication?) {
        guard let app, let bundleID = app.bundleIdentifier,
              Self.observedBundleIDs(rules: store.document.rules).contains(bundleID)
        else { return }
        failedPIDs.remove(app.processIdentifier)
        guard attach(to: app, bundleID: bundleID) else { return }
        placeExistingWindows(of: app.processIdentifier, bundleID: bundleID)
    }

    private func appTerminated(_ app: NSRunningApplication?) {
        guard let pid = app?.processIdentifier else { return }
        detach(pid)
        failedPIDs.remove(pid)
    }

    /// Apps already running get an observer only; their open windows stay where they are.
    private func rulesChanged(_ rules: [AutoRule]) {
        let wanted = Self.observedBundleIDs(rules: rules)
        for (pid, watch) in watches where !wanted.contains(watch.bundleID) {
            detach(pid)
        }
        for app in workspace.runningApplications where !app.isTerminated {
            guard let bundleID = app.bundleIdentifier, wanted.contains(bundleID),
                  watches[app.processIdentifier] == nil, !failedPIDs.contains(app.processIdentifier)
            else { continue }
            attach(to: app, bundleID: bundleID)
        }
    }

    // MARK: - Observers

    @discardableResult
    private func attach(to app: NSRunningApplication, bundleID: String) -> Bool {
        let pid = app.processIdentifier
        // Already watched (a rule change saw the app before its launch notification): the caller still sweeps.
        guard watches[pid] == nil, hasPermission() else { return watches[pid] != nil }
        let observer = makeObserver(pid) { [weak self] window in
            self?.place(window, bundleID: bundleID)
        }
        guard let observer else {
            failedPIDs.insert(pid)
            Self.log.error("no observer for pid=\(pid) bundle=\(bundleID, privacy: .public)")
            return false
        }
        watches[pid] = Watch(bundleID: bundleID, observer: observer)
        return true
    }

    private func detach(_ pid: pid_t) {
        watches.removeValue(forKey: pid)?.observer.invalidate()
    }

    // MARK: - Placement

    private func placeExistingWindows(of pid: pid_t, bundleID: String) {
        for window in AXWindow.windows(of: AXWindow.applicationElement(pid: pid)) {
            place(window, bundleID: bundleID)
        }
    }

    private func place(_ window: AXUIElement, bundleID: String) {
        AXWindow.bounded(window)
        guard let frame = Self.targetFrame(
            forBundleID: bundleID,
            rules: store.document.rules,
            displays: displays(),
            gap: gap()
        ), AXWindow.isEligible(window) else { return }
        frames.setFrame(frame, for: window)
    }
}
