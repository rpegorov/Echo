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

    /// Вызывается после завершения запуска приложения
    /// Инициализирует контроллер строки меню
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
    }

    /// Определяет, должно ли приложение завершиться при закрытии последнего окна
    /// - Parameter sender: Объект отправителя
    /// - Returns: false, чтобы приложение продолжало работать в строке меню
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
