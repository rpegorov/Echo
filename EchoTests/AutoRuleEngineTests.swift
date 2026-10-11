import AppKit
import ApplicationServices
import Foundation
import Testing
@testable import Echo

// Pure decisions of the auto-rule engine: which apps are watched and where a new window goes.

private let hostDisplay = snapshotDisplay(key: "uuid:AAAA", frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
private let rightHalf = fixtureSlot("uuid:AAAA", 0.5, 0, 0.5, 1)

@MainActor
@Suite("Auto rules: observed apps")
struct ObservedBundleIDsTests {

    @Test("only enabled rules are observed")
    func disabledRulesExcluded() {
        let rules = [
            fixtureRule(bundleID: "com.on", isEnabled: true),
            fixtureRule(bundleID: "com.off", isEnabled: false)
        ]

        #expect(AutoRuleEngine.observedBundleIDs(rules: rules) == ["com.on"])
    }

    @Test("no rules observe nothing")
    func noRules() {
        #expect(AutoRuleEngine.observedBundleIDs(rules: []).isEmpty)
    }

    @Test("an app with an enabled and a disabled rule is observed once")
    func repeatedBundleCollapses() {
        let rules = [
            fixtureRule(bundleID: "com.app", isEnabled: false),
            fixtureRule(bundleID: "com.app", isEnabled: true)
        ]

        #expect(AutoRuleEngine.observedBundleIDs(rules: rules) == ["com.app"])
    }
}

@MainActor
@Suite("Auto rules: target frame")
struct TargetFrameForRuleTests {

    @Test("a new window of an app with an enabled rule goes to the rule's zone")
    func enabledRuleFrame() {
        let rules = [fixtureRule(bundleID: "com.app", slot: rightHalf)]

        let frame = AutoRuleEngine.targetFrame(forBundleID: "com.app", rules: rules, displays: [hostDisplay], gap: 0)

        #expect(frame == CGRect(x: 500, y: 0, width: 500, height: 800))
    }

    @Test("the gap insets the frame by half on every side")
    func gapInsetsFrame() {
        let rules = [fixtureRule(bundleID: "com.app", slot: rightHalf)]

        let frame = AutoRuleEngine.targetFrame(forBundleID: "com.app", rules: rules, displays: [hostDisplay], gap: 10)

        #expect(frame == CGRect(x: 505, y: 5, width: 490, height: 790))
    }

    @Test("a disabled rule gives no frame")
    func disabledRule() {
        let rules = [fixtureRule(bundleID: "com.app", slot: rightHalf, isEnabled: false)]

        #expect(AutoRuleEngine.targetFrame(forBundleID: "com.app", rules: rules, displays: [hostDisplay], gap: 0) == nil)
    }

    @Test("an app without a rule gives no frame")
    func otherApp() {
        let rules = [fixtureRule(bundleID: "com.app", slot: rightHalf)]

        #expect(AutoRuleEngine.targetFrame(forBundleID: "com.other", rules: rules, displays: [hostDisplay], gap: 0) == nil)
    }

    @Test("a rule whose display is not connected gives no frame")
    func displayNotConnected() {
        let rules = [fixtureRule(bundleID: "com.app", slot: fixtureSlot("uuid:GONE", 0.5, 0, 0.5, 1))]

        #expect(AutoRuleEngine.targetFrame(forBundleID: "com.app", rules: rules, displays: [hostDisplay], gap: 0) == nil)
    }

    @Test("the enabled rule wins over a disabled one for the same app")
    func enabledRuleWins() {
        let rules = [
            fixtureRule(bundleID: "com.app", slot: fixtureSlot("uuid:AAAA", 0, 0, 0.5, 1), isEnabled: false),
            fixtureRule(bundleID: "com.app", slot: rightHalf, isEnabled: true)
        ]

        let frame = AutoRuleEngine.targetFrame(forBundleID: "com.app", rules: rules, displays: [hostDisplay], gap: 0)

        #expect(frame == CGRect(x: 500, y: 0, width: 500, height: 800))
    }

    @Test("the frame uses the visible area of the display, not its full frame")
    func usesVisibleFrame() {
        let display = snapshotDisplay(
            key: "uuid:AAAA", frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visible: CGRect(x: 0, y: 0, width: 1000, height: 780))
        let rules = [fixtureRule(bundleID: "com.app", slot: rightHalf)]

        let frame = AutoRuleEngine.targetFrame(forBundleID: "com.app", rules: rules, displays: [display], gap: 0)

        #expect(frame == CGRect(x: 500, y: 0, width: 500, height: 780))
    }
}

// MARK: - Observer lifecycle

@MainActor
private final class FakeObserver: WindowCreationObserving {
    let pid: Int32
    private(set) var invalidations = 0

    init(pid: Int32) { self.pid = pid }

    func invalidate() { invalidations += 1 }
}

/// Records every creation attempt; a pid in `failing` yields no observer.
@MainActor
private final class ObserverFactory {
    private(set) var attempts: [Int32] = []
    private(set) var made: [FakeObserver] = []
    var failing: Set<Int32> = []

    func make(pid: Int32, onWindowCreated: @escaping @MainActor (AXUIElement) -> Void) -> (any WindowCreationObserving)? {
        attempts.append(pid)
        guard !failing.contains(pid) else { return nil }
        let observer = FakeObserver(pid: pid)
        made.append(observer)
        return observer
    }

    func live(_ pid: Int32) -> [FakeObserver] { made.filter { $0.pid == pid && $0.invalidations == 0 } }
}

private final class FakeApp: NSRunningApplication, @unchecked Sendable {
    private let bundle: String
    private let pid: pid_t

    init(bundle: String, pid: pid_t) {
        self.bundle = bundle
        self.pid = pid
        super.init()
    }

    override var bundleIdentifier: String? { bundle }
    override var processIdentifier: pid_t { pid }
    override var isTerminated: Bool { false }
}

/// A workspace with its own notification center and a settable list of running apps.
private final class FakeWorkspace: NSWorkspace, @unchecked Sendable {
    let center = NotificationCenter()
    var apps: [NSRunningApplication] = []

    override var notificationCenter: NotificationCenter { center }
    override var runningApplications: [NSRunningApplication] { apps }
}

private let appA = FakeApp(bundle: "com.test.a", pid: 90_001)
private let appB = FakeApp(bundle: "com.test.b", pid: 90_002)

@MainActor
private final class FrameSpy: WindowFrameSetting {
    private(set) var calls = 0
    func setFrame(_ frameCocoa: CGRect, for window: AXUIElement) { calls += 1 }
}

@MainActor
private struct EngineRig {
    let storage: InMemoryGridStorage
    let store: GridStore
    let workspace = FakeWorkspace()
    let factory = ObserverFactory()
    let frames = FrameSpy()
    let engine: AutoRuleEngine

    init(rules: [AutoRule], running: [NSRunningApplication] = [], hasPermission: Bool = true) {
        storage = InMemoryGridStorage(
            document: GridDocument(grids: [], activeByDisplay: [:], arrangements: nil, autoRules: rules))
        store = GridStore(storage: storage)
        workspace.apps = running
        let factory = factory
        engine = AutoRuleEngine(
            store: store, frames: frames, displays: { [hostDisplay] }, gap: { 0 }, workspace: workspace,
            hasPermission: { hasPermission },
            makeObserver: { pid, callback in factory.make(pid: pid, onWindowCreated: callback) })
    }

    func launch(_ app: NSRunningApplication) {
        workspace.apps.append(app)
        workspace.center.post(
            name: NSWorkspace.didLaunchApplicationNotification, object: workspace,
            userInfo: [NSWorkspace.applicationUserInfoKey: app])
    }

    func terminate(_ app: NSRunningApplication) {
        workspace.apps.removeAll { $0.processIdentifier == app.processIdentifier }
        workspace.center.post(
            name: NSWorkspace.didTerminateApplicationNotification, object: workspace,
            userInfo: [NSWorkspace.applicationUserInfoKey: app])
    }
}

@MainActor
@Suite("Auto rule engine: observer lifecycle")
struct AutoRuleEngineLifecycleTests {

    @Test("enabling attaches an observer to each running app with an enabled rule only")
    func startAttachesToRunningRuleApps() {
        let rig = EngineRig(
            rules: [fixtureRule(bundleID: "com.test.a"), fixtureRule(bundleID: "com.test.b", isEnabled: false)],
            running: [appA, appB])

        rig.engine.update(enabled: true)

        #expect(rig.factory.attempts == [appA.processIdentifier])
    }

    @Test("an app launched after the engine started is observed when its launch is announced")
    func launchAttachesImmediately() {
        let rig = EngineRig(rules: [fixtureRule(bundleID: "com.test.a")])
        rig.engine.update(enabled: true)
        #expect(rig.factory.attempts.isEmpty)

        rig.launch(appA)

        #expect(rig.factory.live(appA.processIdentifier).count == 1)
    }

    @Test("a launched app without a rule or with a disabled rule is not observed")
    func launchWithoutEnabledRule() {
        let rig = EngineRig(rules: [fixtureRule(bundleID: "com.test.b", isEnabled: false)])
        rig.engine.update(enabled: true)

        rig.launch(appA)
        rig.launch(appB)

        #expect(rig.factory.attempts.isEmpty)
    }

    @Test("enabling twice keeps one observer per app and one subscription")
    func updateIsIdempotent() {
        let rig = EngineRig(rules: [fixtureRule(bundleID: "com.test.a")], running: [appA])

        rig.engine.update(enabled: true)
        rig.engine.update(enabled: true)
        rig.launch(appB)

        #expect(rig.factory.attempts == [appA.processIdentifier])
        #expect(rig.factory.made[0].invalidations == 0)
    }

    @Test("a launch announcement for an app that already has an observer does not add a second one")
    func launchOfWatchedAppDoesNotDuplicate() {
        let rig = EngineRig(rules: [fixtureRule(bundleID: "com.test.a")], running: [appA])
        rig.engine.update(enabled: true)

        rig.launch(appA)

        #expect(rig.factory.live(appA.processIdentifier).count == 1)
    }

    @Test("disabling removes every observer once and ignores later launches")
    func disableRemovesEverything() {
        let rig = EngineRig(
            rules: [fixtureRule(bundleID: "com.test.a"), fixtureRule(bundleID: "com.test.b")], running: [appA])
        rig.engine.update(enabled: true)
        rig.launch(appB)
        #expect(rig.factory.made.count == 2)

        rig.engine.update(enabled: false)
        rig.engine.update(enabled: false)
        rig.terminate(appB)
        rig.launch(appB)

        #expect(rig.factory.made.allSatisfy { $0.invalidations == 1 })
        #expect(rig.factory.made.count == 2)
    }

    @Test("rule changes after disabling do not attach anything")
    func ruleChangeAfterDisable() throws {
        let rig = EngineRig(rules: [], running: [appA])
        rig.engine.update(enabled: true)
        rig.engine.update(enabled: false)

        try rig.store.saveRule(fixtureRule(bundleID: "com.test.a"))

        #expect(rig.factory.attempts.isEmpty)
    }

    @Test("enabling again after disabling attaches fresh observers to running apps")
    func reenableAttachesAgain() {
        let rig = EngineRig(rules: [fixtureRule(bundleID: "com.test.a")], running: [appA])
        rig.engine.update(enabled: true)
        rig.engine.update(enabled: false)

        rig.engine.update(enabled: true)

        #expect(rig.factory.made.count == 2)
        #expect(rig.factory.made[0].invalidations == 1)
        #expect(rig.factory.live(appA.processIdentifier).count == 1)
    }

    @Test("an app that quits loses its observer")
    func terminateDetaches() {
        let rig = EngineRig(rules: [fixtureRule(bundleID: "com.test.a")], running: [appA])
        rig.engine.update(enabled: true)

        rig.terminate(appA)

        #expect(rig.factory.made[0].invalidations == 1)
    }

    @Test("a relaunch after quitting gets a new observer")
    func relaunchAttachesAgain() {
        let rig = EngineRig(rules: [fixtureRule(bundleID: "com.test.a")], running: [appA])
        rig.engine.update(enabled: true)
        rig.terminate(appA)

        rig.launch(appA)

        #expect(rig.factory.made.count == 2)
        #expect(rig.factory.live(appA.processIdentifier).count == 1)
    }

    @Test("the quit of an unobserved app leaves the other observers alone")
    func terminateOfOtherAppKeepsObservers() {
        let rig = EngineRig(rules: [fixtureRule(bundleID: "com.test.a")], running: [appA])
        rig.engine.update(enabled: true)

        rig.terminate(appB)

        #expect(rig.factory.made[0].invalidations == 0)
    }
}

@MainActor
@Suite("Auto rule engine: rule changes")
struct AutoRuleEngineRuleChangeTests {

    @Test("deleting a rule removes its app's observer")
    func deletedRuleDetaches() throws {
        let rule = fixtureRule(bundleID: "com.test.a")
        let rig = EngineRig(rules: [rule], running: [appA])
        rig.engine.update(enabled: true)

        try rig.store.deleteRule(rule.id)

        #expect(rig.factory.made[0].invalidations == 1)
    }

    @Test("disabling a rule removes its observer and enabling it attaches a new one")
    func toggledRule() throws {
        let rule = fixtureRule(bundleID: "com.test.a")
        let rig = EngineRig(rules: [rule], running: [appA])
        rig.engine.update(enabled: true)

        try rig.store.setRuleEnabled(rule.id, false)
        #expect(rig.factory.live(appA.processIdentifier).isEmpty)

        try rig.store.setRuleEnabled(rule.id, true)
        #expect(rig.factory.live(appA.processIdentifier).count == 1)
        #expect(rig.factory.made.count == 2)
    }

    @Test("a new rule for a running app attaches an observer")
    func newRuleAttaches() throws {
        let rig = EngineRig(rules: [], running: [appA, appB])
        rig.engine.update(enabled: true)
        #expect(rig.factory.attempts.isEmpty)

        try rig.store.saveRule(fixtureRule(bundleID: "com.test.b"))

        #expect(rig.factory.attempts == [appB.processIdentifier])
    }

    @Test("a change to another app's rule leaves existing observers untouched")
    func unrelatedChangeKeepsObservers() throws {
        let rig = EngineRig(rules: [fixtureRule(bundleID: "com.test.a")], running: [appA, appB])
        rig.engine.update(enabled: true)

        try rig.store.saveRule(fixtureRule(bundleID: "com.test.b"))

        #expect(rig.factory.made.count == 2)
        #expect(rig.factory.made[0].invalidations == 0)
    }

    @Test("moving a rule to another zone keeps the observer")
    func slotChangeKeepsObserver() throws {
        let rule = fixtureRule(bundleID: "com.test.a")
        let rig = EngineRig(rules: [rule], running: [appA])
        rig.engine.update(enabled: true)

        try rig.store.saveRule(fixtureRule(id: rule.id, bundleID: "com.test.a", slot: fixtureSlot("uuid:AAAA", 0, 0, 0.5, 1)))

        #expect(rig.factory.made.count == 1)
        #expect(rig.factory.made[0].invalidations == 0)
    }

    @Test("rule changes never move the windows that are already open")
    func ruleChangeMovesNothing() throws {
        let rig = EngineRig(rules: [], running: [appA])
        rig.engine.update(enabled: true)

        try rig.store.saveRule(fixtureRule(bundleID: "com.test.a"))

        #expect(rig.frames.calls == 0)
    }
}

@MainActor
@Suite("Auto rule engine: failures and permission")
struct AutoRuleEngineFailureTests {

    @Test("without the accessibility permission no observer is created and nothing throws")
    func noPermissionNoObservers() throws {
        let rig = EngineRig(rules: [fixtureRule(bundleID: "com.test.a")], running: [appA], hasPermission: false)

        rig.engine.update(enabled: true)
        rig.launch(appB)
        try rig.store.saveRule(fixtureRule(bundleID: "com.test.b"))

        #expect(rig.factory.attempts.isEmpty)
    }

    @Test("a failed attach is not retried on rule changes")
    func failedAttachNotRetriedOnRuleChange() throws {
        let rig = EngineRig(rules: [fixtureRule(bundleID: "com.test.a")], running: [appA])
        rig.factory.failing = [appA.processIdentifier]
        rig.engine.update(enabled: true)
        #expect(rig.factory.attempts == [appA.processIdentifier])

        try rig.store.saveRule(fixtureRule(bundleID: "com.test.b"))

        #expect(rig.factory.attempts == [appA.processIdentifier])
    }

    @Test("a failed attach is retried when the app is launched again")
    func failedAttachRetriedOnRelaunch() {
        let rig = EngineRig(rules: [fixtureRule(bundleID: "com.test.a")], running: [appA])
        rig.factory.failing = [appA.processIdentifier]
        rig.engine.update(enabled: true)
        rig.factory.failing = []

        rig.terminate(appA)
        rig.launch(appA)

        #expect(rig.factory.attempts == [appA.processIdentifier, appA.processIdentifier])
        #expect(rig.factory.live(appA.processIdentifier).count == 1)
    }

    @Test("a failed attach on one app does not stop the others")
    func failureIsPerApp() {
        let rig = EngineRig(
            rules: [fixtureRule(bundleID: "com.test.a"), fixtureRule(bundleID: "com.test.b")], running: [appA, appB])
        rig.factory.failing = [appA.processIdentifier]

        rig.engine.update(enabled: true)

        #expect(rig.factory.live(appB.processIdentifier).count == 1)
    }
}
