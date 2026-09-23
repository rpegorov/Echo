//
//  AppDelegate.swift
//  MonitorBarApp
//
//  Created by Ростислав Егоров on 08.12.2025.
//

import Cocoa
import SwiftUI

/// Делегат приложения для управления жизненным циклом и MenuBar
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    /// true только после того, как MenuBarController был создан
    private(set) var isComposed = false

    /// Признак запуска приложения как хоста для юнит-тестов
    private var isRunningAsTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Вызывается после завершения запуска приложения
    /// Инициализирует контроллер строки меню, кроме случая запуска под тестами
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningAsTestHost else { return }
        menuBarController = MenuBarController(environment: AppEnvironment())
        isComposed = true
    }

    /// Определяет, должно ли приложение завершиться при закрытии последнего окна
    /// - Parameter sender: Объект отправителя
    /// - Returns: false, чтобы приложение продолжало работать в строке меню
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
