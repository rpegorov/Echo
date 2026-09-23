import AppKit
import Testing
@testable import Echo

/// T1 — proves the feature is reachable from the real composition root, not
/// only from its own module: the test host must not build a live
/// MenuBarController, and the app bundle must declare both languages.
@Suite("Composition wiring")
struct CompositionWiringTests {

    @Test("AppDelegate skips composition under the test host")
    @MainActor
    func appDelegateIsNotComposedUnderTestHost() {
        let delegate = AppDelegate()
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        #expect(delegate.isComposed == false)
    }

    @Test("the app bundle declares English and Russian as supported languages")
    func bundleDeclaresEnglishAndRussian() {
        let localizations = Set(Bundle.main.localizations)
        #expect(localizations.contains("en"))
        #expect(localizations.contains("ru"))
    }
}
