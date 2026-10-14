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
    @Published var cpuTemperatureHistory: [Double] = []
    @Published var gpuTemperatureHistory: [Double] = []
    @Published private(set) var temperatureAvailable = true

    private let cpu:     any CPUMonitoring
    private let ram:     any RAMMonitoring
    private let disk:    any DiskMonitoring
    private let network: any NetworkMonitoring
    private let temperature: any TemperatureMonitoring
    private let processes = ProcessMonitor()

    private var task: Task<Void, Never>?

    /// Интервал опроса, секунды. Применяется со следующей итерации цикла.
    private(set) var interval: TimeInterval = 1.0

    init(
        cpu:     any CPUMonitoring     = CPUMonitor(),
        ram:     any RAMMonitoring     = RAMMonitor(),
        disk:    any DiskMonitoring    = DiskMonitor(),
        network: any NetworkMonitoring = NetworkMonitor(),
        temperature: any TemperatureMonitoring = SMCTemperatureMonitor()
    ) {
        self.cpu     = cpu
        self.ram     = ram
        self.disk    = disk
        self.network = network
        self.temperature = temperature
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

    private let historyCapacity = 60

    /// Устанавливает интервал опроса (минимум 0.2 с). Текущая итерация
    /// досыпает по старому значению, новое применяется со следующей.
    func setInterval(_ seconds: TimeInterval) {
        interval = max(0.2, seconds)
    }

    // MARK: - Private

    func refresh() async {
        async let cpuUsage   = cpu.currentUsage()
        async let ramInfo    = ram.info()
        async let diskInfo   = disk.info()
        async let netSpeed   = network.speed()
        async let topCPU     = processes.topByCPU(limit: 1)
        async let topRAM     = processes.topByRAM(limit: 1)
        async let temps      = temperature.read()

        let (usage, ramData, diskData, netData, cpuProcesses, ramProcesses) = await (cpuUsage, ramInfo, diskInfo, netSpeed, topCPU, topRAM)
        let temperatureSample = await temps

        metrics.cpu.usage    = usage
        metrics.ram          = ramData
        metrics.disk         = diskData
        metrics.network      = netData
        if let temperatureSample {
            metrics.temperature = temperatureSample
        } else {
            temperatureAvailable = false
        }

        appendHistory(cpu: usage, ram: ramData, net: netData, cpuProcess: cpuProcesses.first, ramProcess: ramProcesses.first, at: .now)
        appendTemperature(temperatureSample)
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

    /// A missing component keeps its last known value so both chart lines stay
    /// aligned with the shared time axis.
    private func appendTemperature(_ sample: TemperatureSample?) {
        guard let sample else { return }
        cpuTemperatureHistory.append(sample.cpu ?? cpuTemperatureHistory.last ?? 0)
        gpuTemperatureHistory.append(sample.gpu ?? gpuTemperatureHistory.last ?? 0)
        if cpuTemperatureHistory.count > historyCapacity {
            cpuTemperatureHistory.removeFirst()
            gpuTemperatureHistory.removeFirst()
        }
    }
}
