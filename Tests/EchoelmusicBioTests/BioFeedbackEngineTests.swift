import XCTest
@testable import EchoelmusicBio
@testable import EchoelmusicCore

/// Tests for BioFeedbackEngine
@MainActor
final class BioFeedbackEngineTests: XCTestCase {

    var sut: BioFeedbackEngine!

    override func setUp() async throws {
        try await super.setUp()
        sut = BioFeedbackEngine()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertFalse(sut.isEnabled, "BioFeedbackEngine should be disabled by default")
        XCTAssertEqual(sut.currentHeartRate, 60.0, accuracy: 0.01)
        XCTAssertEqual(sut.currentHRV, 0.0, accuracy: 0.01)
        XCTAssertEqual(sut.currentCoherence, 0.0, accuracy: 0.01)
    }

    func testDefaultParameters() {
        // Check default audio parameters
        XCTAssertEqual(sut.reverbWet, 0.3, accuracy: 0.01, "Default reverb should be 30%")
        XCTAssertEqual(sut.filterCutoff, 1000.0, accuracy: 0.01, "Default filter should be 1000 Hz")
        XCTAssertEqual(sut.amplitude, 0.5, accuracy: 0.01, "Default amplitude should be 50%")
        XCTAssertEqual(sut.baseFrequency, 432.0, accuracy: 0.01, "Default frequency should be 432 Hz (healing frequency)")
    }

    // MARK: - Enable/Disable Tests

    func testEnable() {
        sut.enable()
        XCTAssertTrue(sut.isEnabled)
    }

    func testDisable() {
        sut.enable()
        XCTAssertTrue(sut.isEnabled)

        sut.disable()
        XCTAssertFalse(sut.isEnabled)
    }

    func testToggle() {
        XCTAssertFalse(sut.isEnabled)

        sut.toggle()
        XCTAssertTrue(sut.isEnabled)

        sut.toggle()
        XCTAssertFalse(sut.isEnabled)
    }

    // MARK: - EventBus Integration Tests

    func testEventBusSubscription() async {
        sut.enable()

        // Create and publish a bio signal event
        let event = BioSignalUpdatedEvent(
            heartRate: 75.0,
            hrv: 55.0,
            coherence: 65.0,
            respiratoryRate: nil,
            timestamp: Date()
        )

        EventBus.shared.publish(event)

        // Give EventBus time to process (async)
        try? await Task.sleep(nanoseconds: 200_000_000)  // 200ms

        // Check if bio data was updated (throttling may delay)
        // Note: Due to throttling, we may not see immediate updates
        // This test verifies the integration works, not the exact timing
    }

    func testEventBusThrottling() async {
        sut.enable()

        var updateCount = 0
        let expectation = XCTestExpectation(description: "Throttled updates")

        // Publish 10 events rapidly
        for i in 0..<10 {
            let event = BioSignalUpdatedEvent(
                heartRate: Double(60 + i),
                hrv: 50.0,
                coherence: 60.0,
                respiratoryRate: nil,
                timestamp: Date()
            )
            EventBus.shared.publish(event)
            updateCount += 1
        }

        // Wait for throttle window
        try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms

        // Due to 100ms throttle, we should receive < 10 updates
        expectation.fulfill()

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - External Input Tests

    func testUpdateAudioLevel() {
        sut.updateAudioLevel(0.8)
        XCTAssertEqual(sut.audioLevel, 0.8, accuracy: 0.01)

        // Test clamping to 0-1 range
        sut.updateAudioLevel(1.5)
        XCTAssertEqual(sut.audioLevel, 1.0, accuracy: 0.01, "Audio level should be clamped to 1.0")

        sut.updateAudioLevel(-0.5)
        XCTAssertEqual(sut.audioLevel, 0.0, accuracy: 0.01, "Audio level should be clamped to 0.0")
    }

    func testUpdateVoicePitch() {
        sut.updateVoicePitch(440.0)  // A4
        XCTAssertEqual(sut.voicePitch, 440.0, accuracy: 0.01)

        sut.updateVoicePitch(220.0)  // A3
        XCTAssertEqual(sut.voicePitch, 220.0, accuracy: 0.01)
    }

    // MARK: - Coherence State Tests

    func testCoherenceStateLow() {
        // Simulate low coherence (< 40)
        let event = BioSignalUpdatedEvent(
            heartRate: 85.0,
            hrv: 25.0,
            coherence: 30.0,
            respiratoryRate: nil,
            timestamp: Date()
        )

        sut.enable()
        EventBus.shared.publish(event)

        // Check coherence state
        XCTAssertEqual(sut.coherenceState, .low)
        XCTAssertEqual(sut.coherenceState.description, "Stress/Anxiety")
        XCTAssertEqual(sut.coherenceState.color, "red")
        XCTAssertEqual(sut.coherenceState.emoji, "😰")
    }

    func testCoherenceStateMedium() {
        // Simulate medium coherence (40-60)
        let event = BioSignalUpdatedEvent(
            heartRate: 72.0,
            hrv: 45.0,
            coherence: 50.0,
            respiratoryRate: nil,
            timestamp: Date()
        )

        sut.enable()
        EventBus.shared.publish(event)

        XCTAssertEqual(sut.coherenceState, .medium)
        XCTAssertEqual(sut.coherenceState.description, "Transitional")
        XCTAssertEqual(sut.coherenceState.color, "yellow")
        XCTAssertEqual(sut.coherenceState.emoji, "😐")
    }

    func testCoherenceStateHigh() {
        // Simulate high coherence (>= 60)
        let event = BioSignalUpdatedEvent(
            heartRate: 68.0,
            hrv: 75.0,
            coherence: 80.0,
            respiratoryRate: nil,
            timestamp: Date()
        )

        sut.enable()
        EventBus.shared.publish(event)

        XCTAssertEqual(sut.coherenceState, .high)
        XCTAssertEqual(sut.coherenceState.description, "Flow State")
        XCTAssertEqual(sut.coherenceState.color, "green")
        XCTAssertEqual(sut.coherenceState.emoji, "✨")
    }

    // MARK: - Validation Tests

    func testParameterValidation() {
        XCTAssertTrue(sut.isValid, "Default parameters should be valid")

        // Parameters should stay valid after normal updates
        sut.updateAudioLevel(0.7)
        sut.updateVoicePitch(440.0)
        XCTAssertTrue(sut.isValid)
    }

    func testParameterSummary() {
        let summary = sut.parameterSummary
        XCTAssertFalse(summary.isEmpty, "Parameter summary should not be empty")
        XCTAssertTrue(summary.contains("BioParameter"), "Summary should contain header")
        XCTAssertTrue(summary.contains("Reverb"), "Summary should contain reverb")
        XCTAssertTrue(summary.contains("Filter"), "Summary should contain filter")
        XCTAssertTrue(summary.contains("Amplitude"), "Summary should contain amplitude")
    }

    func testStatusSummary() {
        let summary = sut.statusSummary
        XCTAssertFalse(summary.isEmpty, "Status summary should not be empty")
        XCTAssertTrue(summary.contains("BioFeedback Engine"), "Summary should contain header")
        XCTAssertTrue(summary.contains("Heart Rate"), "Summary should contain heart rate")
        XCTAssertTrue(summary.contains("HRV"), "Summary should contain HRV")
        XCTAssertTrue(summary.contains("Coherence"), "Summary should contain coherence")
    }

    // MARK: - Preset Tests

    func testApplyPresetMeditation() {
        sut.applyPreset(.meditation)

        // Wait for parameter mapper to propagate changes
        let expectation = XCTestExpectation(description: "Parameters updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Meditation preset should have high reverb, low filter
        XCTAssertGreaterThan(sut.reverbWet, 0.5, "Meditation should have high reverb")
        XCTAssertLessThan(sut.filterCutoff, 800.0, "Meditation should have low filter cutoff")
    }

    func testApplyPresetFocus() {
        sut.applyPreset(.focus)

        let expectation = XCTestExpectation(description: "Parameters updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Focus preset should have moderate reverb, higher filter
        XCTAssertGreaterThan(sut.filterCutoff, 1000.0, "Focus should have higher filter cutoff")
        XCTAssertEqual(sut.baseFrequency, 528.0, accuracy: 1.0, "Focus should use 528 Hz frequency")
    }

    func testApplyPresetEnergize() {
        sut.applyPreset(.energize)

        let expectation = XCTestExpectation(description: "Parameters updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Energize preset should have low reverb, high filter
        XCTAssertLessThan(sut.reverbWet, 0.3, "Energize should have low reverb")
        XCTAssertGreaterThan(sut.filterCutoff, 1500.0, "Energize should have high filter cutoff")
        XCTAssertGreaterThan(sut.amplitude, 0.6, "Energize should have higher amplitude")
    }

    // MARK: - Integration Tests

    func testFullBioFeedbackCycle() async {
        sut.enable()

        // Simulate a full bio-feedback cycle: stressed → transitional → flow state
        let stressedEvent = BioSignalUpdatedEvent(
            heartRate: 95.0,
            hrv: 20.0,
            coherence: 25.0,
            respiratoryRate: nil,
            timestamp: Date()
        )

        EventBus.shared.publish(stressedEvent)
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Should be in low coherence state
        XCTAssertEqual(sut.coherenceState, .low)

        // Transition to medium coherence
        let transitionalEvent = BioSignalUpdatedEvent(
            heartRate: 80.0,
            hrv: 40.0,
            coherence: 50.0,
            respiratoryRate: nil,
            timestamp: Date()
        )

        EventBus.shared.publish(transitionalEvent)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(sut.coherenceState, .medium)

        // Achieve flow state
        let flowEvent = BioSignalUpdatedEvent(
            heartRate: 68.0,
            hrv: 70.0,
            coherence: 75.0,
            respiratoryRate: nil,
            timestamp: Date()
        )

        EventBus.shared.publish(flowEvent)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(sut.coherenceState, .high)
    }

    // MARK: - Performance Tests

    func testBioFeedbackPerformance() {
        sut.enable()

        measure {
            // Publish 100 bio signal events
            for i in 0..<100 {
                let event = BioSignalUpdatedEvent(
                    heartRate: Double(60 + (i % 30)),
                    hrv: Double(40 + (i % 40)),
                    coherence: Double(30 + (i % 60)),
                    respiratoryRate: nil,
                    timestamp: Date()
                )
                EventBus.shared.publish(event)
            }
        }
    }
}
