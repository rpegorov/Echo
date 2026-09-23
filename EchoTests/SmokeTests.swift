//
//  SmokeTests.swift
//  EchoTests
//

import Testing
@testable import Echo

/// Проверяет, что тестовый хост запускается и не создаёт MenuBarController.
struct SmokeTests {
    @Test func appDelegateDoesNotComposeUnderTestHost() {
        let delegate = AppDelegate()
        #expect(delegate.isComposed == false)
    }
}
