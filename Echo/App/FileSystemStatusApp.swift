//
//  FileSystemStatusApp.swift
//  MonitorBarApp
//
//  Created by Ростислав Егоров on 08.12.2025.
//

import SwiftUI

/// Главная точка входа приложения для мониторинга системы
@main
struct Echo: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }

    /// Инициализация приложения
    init() {
        // Скрыть иконку из Dock, оставить только в строке меню
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
