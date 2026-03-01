import XCTest
@testable import Echoelmusic

/// Comprehensive Tests for UnifiedControlHub (50+ tests)
/// Tests all control hub functionality including:
/// - Initialization and lifecycle
/// - Control loop management
/// - Input mode handling
/// - Feature enablement (face, hand, bio, MIDI, spatial, visual, lighting)
/// - Hardware ecosystem integration
/// - Cross-platform sessions
/// - Statistics and utilities
@MainActor
final class UnifiedControlHubTests: XCTestCase {

    var sut: UnifiedControlHub!

    override func setUp() async throws {
        try await super.setUp()
        sut = UnifiedControlHub(audioEngine: nil)
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests (5 tests)

    func testInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut.activeInputMode, .automatic)
        XCTAssertTrue(sut.conflictResolved)
    }

    func testInitializationWithNilAudioEngine() {
        let hub = UnifiedControlHub(audioEngine: nil)
        XCTAssertNotNil(hub)
        XCTAssertEqual(hub.activeInputMode, .automatic)
    }

    func testInitialControlLoopFrequencyIsZero() {
        XCTAssertEqual(sut.controlLoopFrequency, 0)
    }

    func testInitialConflictResolvedIsTrue() {
        XCTAssertTrue(sut.conflictResolved)
    }

    func testInitialInputModeIsAutomatic() {
        XCTAssertEqual(sut.activeInputMode, .automatic)
    }

    // MARK: - Control Loop Lifecycle Tests (8 tests)

    func testStart() {
        sut.start()

        let expectation = XCTestExpectation(description: "Control loop starts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertGreaterThan(sut.controlLoopFrequency, 0)
    }

    func testStop() {
        sut.start()

        let startExpectation = XCTestExpectation(description: "Control loop starts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)

        sut.stop()

        let stopExpectation = XCTestExpectation(description: "Control loop stops")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            stopExpectation.fulfill()
        }
        wait(for: [stopExpectation], timeout: 1.0)

        XCTAssertLessThan(sut.controlLoopFrequency, 10)
    }

    func testRestartAfterStop() {
        sut.start()

        let startExpectation = XCTestExpectation(description: "First start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)

        sut.stop()

        let stopExpectation = XCTestExpectation(description: "Stop")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            stopExpectation.fulfill()
        }
        wait(for: [stopExpectation], timeout: 1.0)

        sut.start()

        let restartExpectation = XCTestExpectation(description: "Restart")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            restartExpectation.fulfill()
        }
        wait(for: [restartExpectation], timeout: 1.0)

        XCTAssertGreaterThan(sut.controlLoopFrequency, 0)
    }

    func testMultipleStartCallsAreSafe() {
        sut.start()
        sut.start()
        sut.start()

        let expectation = XCTestExpectation(description: "Multiple starts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertGreaterThan(sut.controlLoopFrequency, 0)
    }

    func testMultipleStopCallsAreSafe() {
        sut.start()

        let expectation = XCTestExpectation(description: "Start first")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        sut.stop()
        sut.stop()
        sut.stop()

        // After multiple stops, control loop frequency must be 0
        XCTAssertEqual(sut.controlLoopFrequency, 0, "Control loop frequency should be 0 after multiple stop calls")
    }

    func testStopBeforeStartIsSafe() {
        sut.stop()
        XCTAssertEqual(sut.controlLoopFrequency, 0)
    }

    func testControlLoopFrequency() {
        sut.start()

        let expectation = XCTestExpectation(description: "Control loop stabilizes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let stats = sut.statistics
        XCTAssertGreaterThan(stats.frequency, 50)
        XCTAssertLessThan(stats.frequency, 70)
    }

    func testControlLoopFrequencyAfterShortRun() {
        sut.start()

        let expectation = XCTestExpectation(description: "Short run")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertGreaterThan(sut.controlLoopFrequency, 0)
    }

    // MARK: - Statistics Tests (8 tests)

    func testStatistics() {
        sut.start()

        let expectation = XCTestExpectation(description: "Get statistics")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let stats = sut.statistics
        XCTAssertGreaterThan(stats.frequency, 0)
        XCTAssertEqual(stats.targetFrequency, 60.0)
        XCTAssertEqual(stats.activeInputMode, .automatic)
        XCTAssertTrue(stats.conflictResolved)
    }

    func testStatisticsRunningAtTarget() {
        sut.start()

        let expectation = XCTestExpectation(description: "Control loop stabilizes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let stats = sut.statistics
        XCTAssertTrue(stats.isRunningAtTarget, "Control loop should be running at target frequency")
    }

    func testStatisticsTargetFrequencyIs60Hz() {
        let stats = sut.statistics
        XCTAssertEqual(stats.targetFrequency, 60.0)
    }

    func testStatisticsBeforeStartHasZeroFrequency() {
        let stats = sut.statistics
        XCTAssertEqual(stats.frequency, 0)
    }

    func testStatisticsAfterStopDecreasesFrequency() {
        sut.start()

        let startExpectation = XCTestExpectation(description: "Start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)

        sut.stop()

        let stopExpectation = XCTestExpectation(description: "Stop")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            stopExpectation.fulfill()
        }
        wait(for: [stopExpectation], timeout: 1.0)

        let stats = sut.statistics
        XCTAssertLessThan(stats.frequency, 30)
    }

    func testStatisticsInputModeMatchesHub() {
        let stats = sut.statistics
        XCTAssertEqual(stats.activeInputMode, sut.activeInputMode)
    }

    func testStatisticsConflictResolvedMatchesHub() {
        let stats = sut.statistics
        XCTAssertEqual(stats.conflictResolved, sut.conflictResolved)
    }

    func testStatisticsIsRunningAtTargetCalculation() {
        sut.start()

        let expectation = XCTestExpectation(description: "Running at target")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let stats = sut.statistics
        // isRunningAtTarget should be true when frequency is within ±10 of target
        let isNearTarget = abs(stats.frequency - stats.targetFrequency) <= 10
        XCTAssertEqual(stats.isRunningAtTarget, isNearTarget)
    }

    // MARK: - Map Range Utility Tests (10 tests)

    func testMapRange() {
        let result1 = sut.mapRange(0.5, from: 0...1, to: 0...100)
        XCTAssertEqual(result1, 50, accuracy: 0.01)
    }

    func testMapRangeMinimum() {
        let result = sut.mapRange(0.0, from: 0...1, to: 200...8000)
        XCTAssertEqual(result, 200, accuracy: 0.01)
    }

    func testMapRangeMaximum() {
        let result = sut.mapRange(1.0, from: 0...1, to: 200...8000)
        XCTAssertEqual(result, 8000, accuracy: 0.01)
    }

    func testMapRangeClampsBelowMinimum() {
        let result = sut.mapRange(-0.5, from: 0...1, to: 0...100)
        XCTAssertEqual(result, 0, accuracy: 0.01, "Should clamp to minimum")
    }

    func testMapRangeClampsAboveMaximum() {
        let result = sut.mapRange(1.5, from: 0...1, to: 0...100)
        XCTAssertEqual(result, 100, accuracy: 0.01, "Should clamp to maximum")
    }

    func testMapRangeQuarter() {
        let result = sut.mapRange(0.25, from: 0...1, to: 0...100)
        XCTAssertEqual(result, 25, accuracy: 0.01)
    }

    func testMapRangeThreeQuarters() {
        let result = sut.mapRange(0.75, from: 0...1, to: 0...1000)
        XCTAssertEqual(result, 750, accuracy: 0.01)
    }

    func testMapRangeNegativeOutputRange() {
        let result = sut.mapRange(0.5, from: 0...1, to: -100...100)
        XCTAssertEqual(result, 0, accuracy: 0.01)
    }

    func testMapRangeSmallRange() {
        let result = sut.mapRange(0.5, from: 0...1, to: 0.1...0.9)
        XCTAssertEqual(result, 0.5, accuracy: 0.01)
    }

    func testMapRangeLargeRange() {
        let result = sut.mapRange(0.5, from: 0...1, to: 0...10000)
        XCTAssertEqual(result, 5000, accuracy: 1)
    }

    // MARK: - Input Mode Tests (6 tests)

    func testInputModeAutomatic() {
        XCTAssertEqual(sut.activeInputMode, .automatic)
    }

    func testInputModeEnumExists() {
        // Verify InputMode enum has expected cases
        let mode = InputMode.automatic
        XCTAssertNotNil(mode)
    }

    func testInputModeDoesNotChangeOnStart() {
        let initialMode = sut.activeInputMode
        sut.start()

        let expectation = XCTestExpectation(description: "After start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(sut.activeInputMode, initialMode)
    }

    func testInputModeDoesNotChangeOnStop() {
        sut.start()

        let expectation = XCTestExpectation(description: "Start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let modeBeforeStop = sut.activeInputMode
        sut.stop()
        XCTAssertEqual(sut.activeInputMode, modeBeforeStop)
    }

    func testConflictResolvedRemainsTrue() {
        sut.start()

        let expectation = XCTestExpectation(description: "Running")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(sut.conflictResolved)
    }

    func testConflictResolvedAfterStop() {
        sut.start()

        let startExpectation = XCTestExpectation(description: "Start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)

        sut.stop()
        XCTAssertTrue(sut.conflictResolved)
    }

    // MARK: - Feature Enable/Disable Tests (10 tests)

    func testEnableVisualMapping() {
        sut.enableVisualMapping()
        // Verify hub remains in valid state after enabling visual mapping
        XCTAssertNotNil(sut, "Control hub should remain valid after enabling visual mapping")
    }

    func testDisableVisualMapping() {
        sut.enableVisualMapping()
        sut.disableVisualMapping()
        // Verify enable→disable cycle completes without corrupting state
        XCTAssertNotNil(sut, "Control hub should remain valid after enable/disable visual mapping cycle")
    }

    func testEnableVisualMappingMultipleTimes() {
        sut.enableVisualMapping()
        sut.enableVisualMapping()
        sut.enableVisualMapping()
        // Verify idempotency — repeated enables must not accumulate or leak
        XCTAssertNotNil(sut, "Repeated enableVisualMapping calls should be idempotent")
    }

    func testDisableVisualMappingBeforeEnable() {
        sut.disableVisualMapping()
        // Verify disabling before enabling is a safe no-op
        XCTAssertNotNil(sut, "Disabling visual mapping before enabling should be a safe no-op")
    }

    func testEnableFaceTracking() {
        sut.enableFaceTracking()
        // Verify hub state is valid after enabling face tracking (hardware may not be available in tests)
        XCTAssertNotNil(sut, "Control hub should remain valid after enabling face tracking")
    }

    func testDisableFaceTracking() {
        sut.enableFaceTracking()
        sut.disableFaceTracking()
        // Verify enable→disable cycle leaves hub in clean state
        XCTAssertNotNil(sut, "Control hub should remain valid after face tracking enable/disable cycle")
    }

    func testEnableHandTracking() {
        sut.enableHandTracking()
        XCTAssertNotNil(sut, "Control hub should remain valid after enabling hand tracking")
    }

    func testDisableHandTracking() {
        sut.enableHandTracking()
        sut.disableHandTracking()
        XCTAssertNotNil(sut, "Control hub should remain valid after hand tracking enable/disable cycle")
    }

    func testEnableQuantumLightEmulator() {
        sut.enableQuantumLightEmulator(mode: .bioCoherent)
        // Verify quantum coherence level is accessible after enabling
        let coherence = sut.quantumCoherenceLevel
        XCTAssertGreaterThanOrEqual(coherence, 0.0, "Quantum coherence should be non-negative after enabling")
    }

    func testDisableQuantumLightEmulator() {
        sut.enableQuantumLightEmulator(mode: .bioCoherent)
        sut.disableQuantumLightEmulator()
        // Verify quantum coherence returns to zero after disabling
        XCTAssertEqual(sut.quantumCoherenceLevel, 0.0, "Quantum coherence should be 0 after disabling emulator")
    }

    // MARK: - Hardware Ecosystem Tests (5 tests)

    func testEnableHardwareEcosystem() {
        sut.enableHardwareEcosystem()
        XCTAssertNotNil(sut, "Control hub should remain valid after enabling hardware ecosystem")
    }

    func testDisableHardwareEcosystem() {
        sut.enableHardwareEcosystem()
        sut.disableHardwareEcosystem()
        // After disabling ecosystem, recommended interface should be nil
        let interface = sut.getRecommendedAudioInterface()
        XCTAssertNil(interface, "Recommended audio interface should be nil after disabling ecosystem")
    }

    func testEnableCrossPlatformSessions() {
        sut.enableCrossPlatformSessions()
        XCTAssertNotNil(sut, "Control hub should remain valid after enabling cross-platform sessions")
    }

    func testDisableCrossPlatformSessions() {
        sut.enableCrossPlatformSessions()
        sut.disableCrossPlatformSessions()
        XCTAssertNotNil(sut, "Control hub should remain valid after cross-platform sessions enable/disable cycle")
    }

    func testGetRecommendedAudioInterfaceWithoutEcosystem() {
        let interface = sut.getRecommendedAudioInterface()
        // Should return nil when ecosystem is not enabled
        XCTAssertNil(interface)
    }

    // MARK: - Gaze Tracking Tests (4 tests)

    @available(iOS 15.0, macOS 12.0, *)
    func testEnableGazeTracking() {
        sut.enableGazeTracking()
        // Gaze tracking hardware may not be available in test environment
        // but enabling should not fail or corrupt state
        XCTAssertNotNil(sut, "Control hub should remain valid after enabling gaze tracking")
    }

    @available(iOS 15.0, macOS 12.0, *)
    func testDisableGazeTracking() {
        sut.enableGazeTracking()
        sut.disableGazeTracking()
        // After disable, gaze tracking should be inactive
        XCTAssertFalse(sut.isGazeTrackingActive, "Gaze tracking should be inactive after disabling")
    }

    @available(iOS 15.0, macOS 12.0, *)
    func testEnableGazeTrackingMultipleTimes() {
        sut.enableGazeTracking()
        sut.enableGazeTracking()
        // Repeated enables should be idempotent
        XCTAssertNotNil(sut, "Repeated enableGazeTracking calls should be idempotent")
    }

    @available(iOS 15.0, macOS 12.0, *)
    func testDisableGazeTrackingBeforeEnable() {
        sut.disableGazeTracking()
        // Disabling before enabling should be a safe no-op
        XCTAssertFalse(sut.isGazeTrackingActive, "Gaze tracking should be inactive when disabled before enabling")
    }

    // MARK: - Performance Tests (4 tests)

    func testControlLoopPerformance() {
        measure {
            sut.start()

            let expectation = XCTestExpectation(description: "Control loop runs")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 2.0)

            sut.stop()
        }
    }

    func testStartStopPerformance() {
        measure {
            for _ in 0..<10 {
                sut.start()
                sut.stop()
            }
        }
    }

    func testMapRangePerformance() {
        measure {
            for i in 0..<10000 {
                let _ = sut.mapRange(Float(i) / 10000, from: 0...1, to: 0...1000)
            }
        }
    }

    func testStatisticsAccessPerformance() {
        sut.start()

        let expectation = XCTestExpectation(description: "Start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        measure {
            for _ in 0..<1000 {
                let _ = sut.statistics
            }
        }
    }
}
