import XCTest
@testable import Echoelmusic

/// Performance tests for UnifiedControlHub
/// Ensures 60 Hz control loop can be maintained under load
@MainActor
final class UnifiedControlHubPerformanceTests: XCTestCase {

    var hub: UnifiedControlHub!

    override func setUp() async throws {
        hub = UnifiedControlHub()
    }

    override func tearDown() async throws {
        hub = nil
    }

    /// Test that control loop can maintain 60 Hz
    func testControlLoopFrequency() async throws {
        let expectation = XCTestExpectation(description: "Control loop runs at 60 Hz")

        hub.start()

        // Wait for 1 second
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Check frequency
        let frequency = hub.controlLoopFrequency

        hub.stop()

        // Should be close to 60 Hz (allow 10% margin)
        XCTAssertGreaterThan(frequency, 54.0, "Control loop frequency too low")
        XCTAssertLessThan(frequency, 66.0, "Control loop frequency too high")

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    /// Test memory usage stays within bounds
    func testMemoryUsage() {
        measure(metrics: [XCTMemoryMetric()]) {
            let hub = UnifiedControlHub()
            hub.start()

            // Simulate 60 control loop iterations
            for _ in 0..<60 {
                Thread.sleep(forTimeInterval: 0.0167)
            }

            hub.stop()
        }
    }

    /// Test CPU usage
    func testCPUUsage() {
        measure(metrics: [XCTCPUMetric()]) {
            let hub = UnifiedControlHub()
            hub.start()

            // Run for 1 second
            Thread.sleep(forTimeInterval: 1.0)

            hub.stop()
        }
    }

    /// Test enabling/disabling components doesn't leak memory
    func testComponentEnableDisableNoMemoryLeak() {
        weak var weakHub: UnifiedControlHub?

        autoreleasepool {
            let hub = UnifiedControlHub()
            weakHub = hub

            hub.start()

            // Enable all components
            hub.enableFaceTracking()
            hub.disableFaceTracking()

            hub.stop()
        }

        // Hub should be deallocated
        XCTAssertNil(weakHub, "UnifiedControlHub leaked memory")
    }
}
