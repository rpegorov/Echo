//
//  DetailState.swift
//  MonitorBarApp
//

import SwiftUI

/// Состояние детального окна: какая вкладка сейчас активна.
/// Отдельный ObservableObject, чтобы MenuBarController мог переключать вкладку
/// извне (по клику в поповере), а окно реактивно обновлялось.
@MainActor
final class DetailState: ObservableObject {
    @Published var tab: MetricTab = .cpu
}
