import XCTest
@testable import Blab

/// Tests for LatencyMeasurement system
@available(iOS 15.0, *)
final class LatencyMeasurementTests: XCTestCase {

    var latencyMonitor: LatencyMeasurement!
    var mockAudioEngine: MockAudioEngine!

    override func setUp() {
        super.setUp()
        latencyMonitor = LatencyMeasurement.shared
        mockAudioEngine = MockAudioEngine()
    }

    override func tearDown() {
        latencyMonitor.stop()
        latencyMonitor.resetStatistics()
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testSingletonInstance() {
        let instance1 = LatencyMeasurement.shared
        let instance2 = LatencyMeasurement.shared
        XCTAssertTrue(instance1 === instance2, "LatencyMeasurement should be a singleton")
    }

    func testInitialState() {
        XCTAssertFalse(latencyMonitor.isMonitoring, "Should not be monitoring initially")
        XCTAssertEqual(latencyMonitor.currentLatency, 0, "Initial latency should be 0")
        XCTAssertEqual(latencyMonitor.bufferLatency, 0, "Initial buffer latency should be 0")
        XCTAssertEqual(latencyMonitor.processingLatency, 0, "Initial processing latency should be 0")
    }

    // MARK: - Start/Stop Tests

    func testStartMonitoring() {
        latencyMonitor.start(audioEngine: mockAudioEngine)
        XCTAssertTrue(latencyMonitor.isMonitoring, "Should be monitoring after start")
    }

    func testStopMonitoring() {
        latencyMonitor.start(audioEngine: mockAudioEngine)
        latencyMonitor.stop()
        XCTAssertFalse(latencyMonitor.isMonitoring, "Should not be monitoring after stop")
    }

    // MARK: - Processing Latency Tests

    func testMarkProcessingStartEnd() {
        latencyMonitor.markProcessingStart()
        // Simulate some processing time
        Thread.sleep(forTimeInterval: 0.001) // 1ms
        latencyMonitor.markProcessingEnd()

        XCTAssertGreaterThan(latencyMonitor.processingLatency, 0, "Processing latency should be > 0")
        XCTAssertLessThan(latencyMonitor.processingLatency, 10, "Processing latency should be < 10ms for test")
    }

    // MARK: - Statistics Tests

    func testStatisticsUpdate() {
        latencyMonitor.start(audioEngine: mockAudioEngine)

        // Simulate some latency measurements
        for _ in 0..<10 {
            latencyMonitor.markProcessingStart()
            Thread.sleep(forTimeInterval: 0.001)
            latencyMonitor.markProcessingEnd()
            Thread.sleep(forTimeInterval: 0.02) // Wait for measurement cycle
        }

        XCTAssertGreaterThan(latencyMonitor.statistics.sampleCount, 0, "Should have samples")
        XCTAssertGreaterThan(latencyMonitor.statistics.average, 0, "Average should be > 0")
    }

    func testResetStatistics() {
        latencyMonitor.start(audioEngine: mockAudioEngine)

        // Generate some data
        for _ in 0..<5 {
            latencyMonitor.markProcessingStart()
            latencyMonitor.markProcessingEnd()
        }

        latencyMonitor.resetStatistics()

        XCTAssertEqual(latencyMonitor.statistics.sampleCount, 0, "Sample count should be 0 after reset")
        XCTAssertEqual(latencyMonitor.statistics.minimum, 0, "Minimum should be 0 after reset")
        XCTAssertEqual(latencyMonitor.statistics.maximum, 0, "Maximum should be 0 after reset")
    }

    // MARK: - Alert Tests

    func testLatencyAlert() {
        latencyMonitor.start(audioEngine: mockAudioEngine)

        // Test normal latency
        mockAudioEngine.simulatedBufferSize = 128
        mockAudioEngine.simulatedSampleRate = 48000
        Thread.sleep(forTimeInterval: 0.1) // Wait for measurement

        let alert = latencyMonitor.getAlert()
        // With small buffer, should be normal
        XCTAssertEqual(alert, .normal, "Should be normal with small buffer")
    }

    func testTargetLatencyCheck() {
        latencyMonitor.start(audioEngine: mockAudioEngine)

        // Small buffer should meet target
        mockAudioEngine.simulatedBufferSize = 128
        mockAudioEngine.simulatedSampleRate = 48000
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertFalse(latencyMonitor.exceedsTarget, "Should meet 5ms target with 128 buffer @ 48kHz")
    }

    // MARK: - Export Tests

    func testExportStatistics() {
        latencyMonitor.start(audioEngine: mockAudioEngine)
        Thread.sleep(forTimeInterval: 0.1) // Generate some data

        let exported = latencyMonitor.exportStatistics()

        XCTAssertNotNil(exported["currentLatency"], "Should export currentLatency")
        XCTAssertNotNil(exported["statistics"], "Should export statistics")
        XCTAssertNotNil(exported["alert"], "Should export alert")
        XCTAssertNotNil(exported["timestamp"], "Should export timestamp")
    }
}

// MARK: - Mock Audio Engine

class MockAudioEngine: AudioEngine {
    var simulatedBufferSize: Int = 256
    var simulatedSampleRate: Double = 48000.0

    override var bufferSize: Int {
        return simulatedBufferSize
    }

    override var sampleRate: Double {
        return simulatedSampleRate
    }
}
