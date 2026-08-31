//
//  MetricsService.swift
//  MonitorBarApp
//

import Foundation

/// Сервис сбора метрик. Параллельный опрос через async let, история — здесь.
@MainActor
final class MetricsService: ObservableObject {

    @Published var metrics = SystemMetrics()

    // Истории (последние 60 точек = 60 секунд при интервале 1 с)
    @Published var cpuHistory:     [Double]                          = []
    @Published var ramHistory:     [(used: Double, total: Double)]   = []
    @Published var networkHistory: [(download: Double, upload: Double)] = []

    private let cpu:     any CPUMonitoring
    private let ram:     any RAMMonitoring
    private let disk:    any DiskMonitoring
    private let network: any NetworkMonitoring

    private var task: Task<Void, Never>?

    /// Интервал опроса, секунды. Применяется со следующей итерации цикла.
    private(set) var interval: TimeInterval = 1.0

    init(
        cpu:     any CPUMonitoring     = CPUMonitor(),
        ram:     any RAMMonitoring     = RAMMonitor(),
        disk:    any DiskMonitoring    = DiskMonitor(),
        network: any NetworkMonitoring = NetworkMonitor()
    ) {
        self.cpu     = cpu
        self.ram     = ram
        self.disk    = disk
        self.network = network
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: .seconds(self.interval))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// Устанавливает интервал опроса (минимум 0.2 с). Текущая итерация
    /// досыпает по старому значению, новое применяется со следующей.
    func setInterval(_ seconds: TimeInterval) {
        interval = max(0.2, seconds)
    }

    // MARK: - Private

    private func refresh() async {
        async let cpuUsage   = cpu.currentUsage()
        async let ramInfo    = ram.info()
        async let diskInfo   = disk.info()
        async let netSpeed   = network.speed()

        let (usage, ramData, diskData, netData) = await (cpuUsage, ramInfo, diskInfo, netSpeed)

        metrics.cpu.usage    = usage
        metrics.ram          = ramData
        metrics.disk         = diskData
        metrics.network      = netData

        appendHistory(cpu: usage, ram: ramData, net: netData)
    }

    private func appendHistory(cpu: Double, ram: RAMMetrics, net: NetworkMetrics) {
        cpuHistory.append(cpu)
        if cpuHistory.count > 60 { cpuHistory.removeFirst() }

        let usedGB  = Double(ram.used)  / 1_073_741_824
        let totalGB = Double(ram.total) / 1_073_741_824
        ramHistory.append((used: usedGB, total: totalGB))
        if ramHistory.count > 60 { ramHistory.removeFirst() }

        networkHistory.append((download: net.download, upload: net.upload))
        if networkHistory.count > 60 { networkHistory.removeFirst() }
    }
}
