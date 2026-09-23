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
    private var environment: AppEnvironment?
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
        let environment = AppEnvironment()
        self.environment = environment
        menuBarController = MenuBarController(environment: environment)
        isComposed = true
    }

    /// Определяет, должно ли приложение завершиться при закрытии последнего окна
    /// - Parameter sender: Объект отправителя
    /// - Returns: false, чтобы приложение продолжало работать в строке меню
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Останавливает фоновую работу перед завершением приложения.
    func applicationWillTerminate(_ notification: Notification) {
        environment?.battery.stop()
        environment?.monitoring.stop()
    }
}
