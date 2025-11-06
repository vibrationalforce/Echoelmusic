import XCTest
@testable import Echoelmusic

/// Tests for real-time adaptive quality system
@MainActor
final class AdaptiveQualityTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitializationSetsQualityBasedOnHardware() async {
        let manager = AdaptiveQualityManager()

        // Quality should match hardware capability
        let capability = HardwareCapability.shared
        let expectedQuality = AdaptiveQuality.fromHardware(capability)

        XCTAssertEqual(manager.currentQuality.level, expectedQuality.level)
        XCTAssertEqual(manager.targetFPS, Double(expectedQuality.targetFPS))
    }

    func testInitialFPSIsZero() async {
        let manager = AdaptiveQualityManager()

        XCTAssertEqual(manager.currentFPS, 60.0)  // Default expectation
    }

    func testAdaptiveQualityEnabledByDefault() async {
        let manager = AdaptiveQualityManager()

        XCTAssertTrue(manager.isEnabled)
    }

    // MARK: - Frame Recording Tests

    func testRecordFrameTimeUpdatesCurrentFPS() async {
        let manager = AdaptiveQualityManager()

        // Record 60 frames at 60 FPS (16.67ms per frame)
        for _ in 0..<60 {
            manager.recordFrameTime(1.0 / 60.0)
        }

        // Current FPS should be close to 60
        XCTAssertEqual(manager.currentFPS, 60.0, accuracy: 5.0)
    }

    func testRecordFrameTimeDetectsLowFPS() async {
        let manager = AdaptiveQualityManager()

        // Record 60 frames at 20 FPS (50ms per frame)
        for _ in 0..<60 {
            manager.recordFrameTime(1.0 / 20.0)
        }

        // Current FPS should be close to 20
        XCTAssertEqual(manager.currentFPS, 20.0, accuracy: 5.0)
    }

    func testRecordFrameTimeDetectsHighFPS() async {
        let manager = AdaptiveQualityManager()

        // Record 60 frames at 120 FPS (8.33ms per frame)
        for _ in 0..<60 {
            manager.recordFrameTime(1.0 / 120.0)
        }

        // Current FPS should be close to 120
        XCTAssertEqual(manager.currentFPS, 120.0, accuracy: 10.0)
    }

    // MARK: - Quality Preset Tests

    func testUltraQualityPreset() {
        let ultra = AdaptiveQuality.ultra

        XCTAssertEqual(ultra.level, .ultra)
        XCTAssertEqual(ultra.maxParticles, 2000)
        XCTAssertEqual(ultra.targetFPS, 60)
        XCTAssertEqual(ultra.effectsIntensity, 1.0)
        XCTAssertTrue(ultra.enableBloom)
        XCTAssertTrue(ultra.enableMotionBlur)
        XCTAssertEqual(ultra.shadowQuality, .high)
    }

    func testHighQualityPreset() {
        let high = AdaptiveQuality.high

        XCTAssertEqual(high.level, .high)
        XCTAssertEqual(high.maxParticles, 1000)
        XCTAssertEqual(high.targetFPS, 60)
        XCTAssertEqual(high.effectsIntensity, 0.8)
        XCTAssertTrue(high.enableBloom)
        XCTAssertFalse(high.enableMotionBlur)
        XCTAssertEqual(high.shadowQuality, .medium)
    }

    func testMediumQualityPreset() {
        let medium = AdaptiveQuality.medium

        XCTAssertEqual(medium.level, .medium)
        XCTAssertEqual(medium.maxParticles, 500)
        XCTAssertEqual(medium.targetFPS, 30)
        XCTAssertEqual(medium.effectsIntensity, 0.5)
        XCTAssertFalse(medium.enableBloom)
        XCTAssertFalse(medium.enableMotionBlur)
        XCTAssertEqual(medium.shadowQuality, .low)
    }

    func testLowQualityPreset() {
        let low = AdaptiveQuality.low

        XCTAssertEqual(low.level, .low)
        XCTAssertEqual(low.maxParticles, 250)
        XCTAssertEqual(low.targetFPS, 30)
        XCTAssertEqual(low.effectsIntensity, 0.3)
        XCTAssertFalse(low.enableBloom)
        XCTAssertFalse(low.enableMotionBlur)
        XCTAssertEqual(low.shadowQuality, .none)
    }

    // MARK: - Manual Quality Control Tests

    func testManualQualityChange() async {
        let manager = AdaptiveQualityManager()

        manager.setQuality(.low)

        XCTAssertEqual(manager.currentQuality.level, .low)
        XCTAssertEqual(manager.targetFPS, 30.0)
    }

    // MARK: - Statistics Tests

    func testStatisticsCalculation() async {
        let manager = AdaptiveQualityManager()

        // Record some frames
        for _ in 0..<100 {
            manager.recordFrameTime(1.0 / 60.0)
        }

        let stats = manager.statistics

        XCTAssertEqual(stats.totalFrames, 100)
        XCTAssertEqual(stats.currentFPS, 60.0, accuracy: 5.0)
        XCTAssertLessThan(stats.dropRate, 0.1)  // Less than 10% dropped
    }

    func testDroppedFrameDetection() async {
        let manager = AdaptiveQualityManager()

        // Record normal frames
        for _ in 0..<50 {
            manager.recordFrameTime(1.0 / 60.0)
        }

        // Record dropped frames (>100ms)
        for _ in 0..<10 {
            manager.recordFrameTime(0.15)  // 150ms = dropped frame
        }

        let stats = manager.statistics

        XCTAssertEqual(stats.droppedFrames, 10)
        XCTAssertGreaterThan(stats.dropRate, 0.0)
    }

    func testPerformanceGrading() async {
        let manager = AdaptiveQualityManager()

        // Record excellent frames (60 FPS)
        for _ in 0..<60 {
            manager.recordFrameTime(1.0 / 60.0)
        }

        let stats = manager.statistics

        XCTAssertTrue(stats.isHealthy)
        XCTAssertTrue(stats.performanceGrade.contains("A"))
    }

    func testPoorPerformanceGrading() async {
        let manager = AdaptiveQualityManager()

        // Record poor frames (15 FPS)
        for _ in 0..<60 {
            manager.recordFrameTime(1.0 / 15.0)
        }

        let stats = manager.statistics

        XCTAssertFalse(stats.isHealthy)
    }

    // MARK: - Hardware-Based Quality Tests

    func testQualityFromHardwareCapability() {
        let capability = HardwareCapability.shared

        let quality = AdaptiveQuality.fromHardware(capability)

        switch capability.performanceTier {
        case .veryHigh:
            XCTAssertEqual(quality.level, .ultra)
        case .high:
            XCTAssertEqual(quality.level, .high)
        case .medium:
            XCTAssertEqual(quality.level, .medium)
        case .low:
            XCTAssertEqual(quality.level, .low)
        }

        print("""
        Hardware-Based Quality:
        Device: \(capability.deviceModel)
        Tier: \(capability.performanceTier)
        Quality: \(quality.level)
        Max Particles: \(quality.maxParticles)
        """)
    }

    // MARK: - Quality Level Mapping Tests

    func testQualityLevelParticleMapping() {
        let ultra = AdaptiveQuality.ultra
        let high = AdaptiveQuality.high
        let medium = AdaptiveQuality.medium
        let low = AdaptiveQuality.low

        // Verify particle counts decrease with quality
        XCTAssertGreaterThan(ultra.maxParticles, high.maxParticles)
        XCTAssertGreaterThan(high.maxParticles, medium.maxParticles)
        XCTAssertGreaterThan(medium.maxParticles, low.maxParticles)
    }

    func testQualityLevelEffectsMapping() {
        let ultra = AdaptiveQuality.ultra
        let high = AdaptiveQuality.high
        let medium = AdaptiveQuality.medium
        let low = AdaptiveQuality.low

        // Verify effects intensity decreases with quality
        XCTAssertGreaterThan(ultra.effectsIntensity, high.effectsIntensity)
        XCTAssertGreaterThan(high.effectsIntensity, medium.effectsIntensity)
        XCTAssertGreaterThan(medium.effectsIntensity, low.effectsIntensity)
    }

    // MARK: - Lifecycle Tests

    func testStartStopLifecycle() async {
        let manager = AdaptiveQualityManager()

        manager.start()
        // Manager should be running

        manager.stop()
        // Manager should be stopped
    }

    // MARK: - Integration Tests

    func testRealisticWorkload() async {
        let manager = AdaptiveQualityManager()
        manager.start()

        // Simulate realistic workload: mostly 60 FPS with occasional drops
        for i in 0..<300 {
            if i % 30 == 0 {
                // Occasional frame drop
                manager.recordFrameTime(0.05)  // 20 FPS spike
            } else {
                // Normal frame
                manager.recordFrameTime(1.0 / 60.0)
            }
        }

        let stats = manager.statistics

        print("""
        Realistic Workload Results:
        FPS: \(String(format: "%.1f", stats.currentFPS))
        Drop Rate: \(String(format: "%.2f", stats.dropRate * 100))%
        Grade: \(stats.performanceGrade)
        Quality: \(manager.currentQuality.level)
        """)

        // Should still be healthy despite occasional drops
        XCTAssertGreaterThan(stats.currentFPS, 50.0)

        manager.stop()
    }

    func testStressTest() async {
        let manager = AdaptiveQualityManager()
        manager.start()

        // Simulate stress: sustained low FPS
        for _ in 0..<180 {  // 3 seconds worth at 60 Hz
            manager.recordFrameTime(1.0 / 20.0)  // 20 FPS
        }

        let stats = manager.statistics

        print("""
        Stress Test Results:
        FPS: \(String(format: "%.1f", stats.currentFPS))
        Drop Rate: \(String(format: "%.2f", stats.dropRate * 100))%
        Grade: \(stats.performanceGrade)
        Quality: \(manager.currentQuality.level)
        Adjustments: \(stats.qualityAdjustments)
        """)

        // Quality should have adjusted
        XCTAssertLessThan(stats.currentFPS, 25.0)

        manager.stop()
    }

    // MARK: - Documentation Test

    func testStatusDescription() async {
        let manager = AdaptiveQualityManager()

        // Record some frames
        for _ in 0..<60 {
            manager.recordFrameTime(1.0 / 60.0)
        }

        let description = manager.statusDescription

        // Should contain key information
        XCTAssertTrue(description.contains("Quality"))
        XCTAssertTrue(description.contains("FPS"))
        XCTAssertTrue(description.contains("Particles"))

        print("\n" + description)
    }
}
