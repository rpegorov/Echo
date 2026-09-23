//
//  LocalizedHost.swift
//  Echo
//

import SwiftUI

/// Wraps a root view so it observes the shared `Localizer` and gets the matching `Locale`,
/// without resetting view state (no `.id(language)`).
struct LocalizedHost<Content: View>: View {
    @ObservedObject var localizer: Localizer
    let content: Content

    var body: some View {
        content
            .environmentObject(localizer)
            .environment(\.locale, localizer.locale)
    }
}

/// Every `NSHostingController` in the app is created through this factory so it is wrapped
/// in `LocalizedHost` and reacts to language changes on the fly.
enum HostingFactory {
    @MainActor
    static func make<V: View>(_ root: V, localizer: Localizer) -> NSHostingController<LocalizedHost<V>> {
        NSHostingController(rootView: LocalizedHost(localizer: localizer, content: root))
    }
}
