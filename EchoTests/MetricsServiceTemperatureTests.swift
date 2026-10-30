import XCTest
@testable import Echo

@MainActor
final class MetricsServiceTemperatureTests: XCTestCase {

    func testRefreshAppendsTemperatureHistory() async {
        let sample = TemperatureSample(cpu: 61.5, gpu: 48.0)
        let service = MetricsService(temperature: MockTemperatureMonitor(sample: sample))

        await service.refresh()

        XCTAssertEqual(service.cpuTemperatureHistory, [61.5])
        XCTAssertEqual(service.gpuTemperatureHistory, [48.0])
        XCTAssertTrue(service.temperatureAvailable)
        XCTAssertEqual(service.metrics.temperature.cpu, 61.5)
        XCTAssertEqual(service.metrics.temperature.gpu, 48.0)
    }

    func testUnavailableMonitorHidesTheTab() async {
        let service = MetricsService(temperature: MockTemperatureMonitor(sample: nil))

        await service.refresh()

        XCTAssertFalse(service.temperatureAvailable)
        XCTAssertTrue(service.cpuTemperatureHistory.isEmpty)
        XCTAssertTrue(service.gpuTemperatureHistory.isEmpty)
    }

    func testAvailabilityRecoversAfterAMissedRead() async {
        let monitor = ScriptedTemperatureMonitor(samples: [
            nil,
            TemperatureSample(cpu: 60, gpu: 50)
        ])
        let service = MetricsService(temperature: monitor)

        await service.refresh()
        XCTAssertFalse(service.temperatureAvailable)

        await service.refresh()
        XCTAssertTrue(service.temperatureAvailable)
    }

    func testMissingComponentCarriesLastValueForward() async {
        let monitor = ScriptedTemperatureMonitor(samples: [
            TemperatureSample(cpu: 60, gpu: 50),
            TemperatureSample(cpu: 62, gpu: nil)
        ])
        let service = MetricsService(temperature: monitor)

        await service.refresh()
        await service.refresh()

        XCTAssertEqual(service.cpuTemperatureHistory, [60, 62])
        XCTAssertEqual(service.gpuTemperatureHistory, [50, 50])
    }
}

private actor ScriptedTemperatureMonitor: TemperatureMonitoring {
    private var samples: [TemperatureSample?]

    init(samples: [TemperatureSample?]) {
        self.samples = samples
    }

    func read() async -> TemperatureSample? {
        guard !samples.isEmpty else { return nil }
        return samples.removeFirst()
    }
}
