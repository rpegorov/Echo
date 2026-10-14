import Foundation

/// Runs `body` against an empty, uniquely named suite and removes the suite afterwards.
func withScratchDefaults<T>(_ body: (UserDefaults) throws -> T) rethrows -> T {
    let name = "EchoTests.Scratch.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    return try body(defaults)
}
