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
    @Published var historyDates: [Date] = []
    @Published var resourceHistory: [ResourceSnapshot] = []

    private let cpu:     any CPUMonitoring
    private let ram:     any RAMMonitoring
    private let disk:    any DiskMonitoring
    private let network: any NetworkMonitoring
    private let processes = ProcessMonitor()

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
        async let topCPU     = processes.topByCPU(limit: 1)
        async let topRAM     = processes.topByRAM(limit: 1)

        let (usage, ramData, diskData, netData, cpuProcesses, ramProcesses) = await (cpuUsage, ramInfo, diskInfo, netSpeed, topCPU, topRAM)

        metrics.cpu.usage    = usage
        metrics.ram          = ramData
        metrics.disk         = diskData
        metrics.network      = netData

        appendHistory(cpu: usage, ram: ramData, net: netData, cpuProcess: cpuProcesses.first, ramProcess: ramProcesses.first, at: .now)
    }

    private func appendHistory(cpu: Double, ram: RAMMetrics, net: NetworkMetrics, cpuProcess: MonitoredProcess?, ramProcess: MonitoredProcess?, at timestamp: Date) {
        cpuHistory.append(cpu)
        if cpuHistory.count > 60 { cpuHistory.removeFirst() }

        let usedGB  = Double(ram.used)  / 1_073_741_824
        let totalGB = Double(ram.total) / 1_073_741_824
        ramHistory.append((used: usedGB, total: totalGB))
        if ramHistory.count > 60 { ramHistory.removeFirst() }

        networkHistory.append((download: net.download, upload: net.upload))
        resourceHistory.append(ResourceSnapshot(cpuProcessName: cpuProcess?.name ?? "—", cpuPercent: cpuProcess?.value ?? 0, ramProcessName: ramProcess?.name ?? "—", ramMB: ramProcess?.value ?? 0))
        historyDates.append(timestamp)
        if networkHistory.count > 60 {
            networkHistory.removeFirst()
            historyDates.removeFirst()
            resourceHistory.removeFirst()
        }
    }
}
