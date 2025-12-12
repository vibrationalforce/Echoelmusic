import XCTest
@testable import Echoelmusic

/// Tests for Core Improvements
///
/// Tests the improvements made to:
/// - MIDI2Manager validation and error handling
/// - EchoelUniversalCore lifecycle management
/// - MIDIConstants validation helpers
/// - BioState energy calculation
/// - QuantumField collapse recording
///
@MainActor
final class CoreImprovementsTests: XCTestCase {

    // MARK: - MIDI Constants Tests

    func testMIDIChannelValidation() {
        // Valid channels 0-15
        for channel: UInt8 in 0...15 {
            XCTAssertTrue(MIDIConstants.isValidChannel(channel), "Channel \(channel) should be valid")
        }

        // Invalid channels
        XCTAssertFalse(MIDIConstants.isValidChannel(16), "Channel 16 should be invalid")
        XCTAssertFalse(MIDIConstants.isValidChannel(127), "Channel 127 should be invalid")
        XCTAssertFalse(MIDIConstants.isValidChannel(255), "Channel 255 should be invalid")
    }

    func testMIDINoteValidation() {
        // Valid notes 0-127
        XCTAssertTrue(MIDIConstants.isValidNote(0), "Note 0 should be valid")
        XCTAssertTrue(MIDIConstants.isValidNote(60), "Note 60 (Middle C) should be valid")
        XCTAssertTrue(MIDIConstants.isValidNote(127), "Note 127 should be valid")

        // Invalid notes
        XCTAssertFalse(MIDIConstants.isValidNote(128), "Note 128 should be invalid")
        XCTAssertFalse(MIDIConstants.isValidNote(255), "Note 255 should be invalid")
    }

    func testVelocityClamping() {
        // Normal range
        XCTAssertEqual(MIDIConstants.clampVelocity(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(MIDIConstants.clampVelocity(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(MIDIConstants.clampVelocity(1.0), 1.0, accuracy: 0.001)

        // Out of range
        XCTAssertEqual(MIDIConstants.clampVelocity(-0.5), 0.0, accuracy: 0.001, "Negative velocity should clamp to 0")
        XCTAssertEqual(MIDIConstants.clampVelocity(1.5), 1.0, accuracy: 0.001, "Velocity > 1 should clamp to 1")
        XCTAssertEqual(MIDIConstants.clampVelocity(-100.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(MIDIConstants.clampVelocity(100.0), 1.0, accuracy: 0.001)
    }

    func testPitchBendClamping() {
        // Normal range
        XCTAssertEqual(MIDIConstants.clampPitchBend(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(MIDIConstants.clampPitchBend(-1.0), -1.0, accuracy: 0.001)
        XCTAssertEqual(MIDIConstants.clampPitchBend(1.0), 1.0, accuracy: 0.001)
        XCTAssertEqual(MIDIConstants.clampPitchBend(0.5), 0.5, accuracy: 0.001)

        // Out of range
        XCTAssertEqual(MIDIConstants.clampPitchBend(-2.0), -1.0, accuracy: 0.001, "Pitch bend < -1 should clamp")
        XCTAssertEqual(MIDIConstants.clampPitchBend(2.0), 1.0, accuracy: 0.001, "Pitch bend > 1 should clamp")
    }

    // MARK: - Float Clamping Extension Tests

    func testFloatClamping() {
        let value: Float = 0.5
        XCTAssertEqual(value.clamped(to: 0...1), 0.5, accuracy: 0.001)

        let lowValue: Float = -5.0
        XCTAssertEqual(lowValue.clamped(to: 0...1), 0.0, accuracy: 0.001)

        let highValue: Float = 10.0
        XCTAssertEqual(highValue.clamped(to: 0...1), 1.0, accuracy: 0.001)
    }

    func testDoubleClamping() {
        let value: Double = 0.5
        XCTAssertEqual(value.clamped(to: 0...1), 0.5, accuracy: 0.001)

        let lowValue: Double = -5.0
        XCTAssertEqual(lowValue.clamped(to: 0...1), 0.0, accuracy: 0.001)

        let highValue: Double = 10.0
        XCTAssertEqual(highValue.clamped(to: 0...1), 1.0, accuracy: 0.001)
    }

    // MARK: - BioState Tests

    func testBioStateEnergy() {
        // Test energy calculation at various heart rates
        var bioState = BioState()

        // Normal resting heart rate
        bioState.heartRate = 70
        bioState.hrv = 50
        let normalEnergy = bioState.energy
        XCTAssertGreaterThan(normalEnergy, 0, "Energy should be positive")
        XCTAssertLessThanOrEqual(normalEnergy, 1, "Energy should be <= 1")

        // Elevated heart rate
        bioState.heartRate = 120
        let elevatedEnergy = bioState.energy
        XCTAssertGreaterThan(elevatedEnergy, normalEnergy, "Higher HR should mean higher energy")

        // Low heart rate
        bioState.heartRate = 55
        let lowEnergy = bioState.energy
        XCTAssertLessThan(lowEnergy, normalEnergy, "Lower HR should mean lower energy")
    }

    func testBioStateDefaults() {
        let bioState = BioState()

        XCTAssertEqual(bioState.heartRate, 70, "Default HR should be 70")
        XCTAssertEqual(bioState.hrv, 50, "Default HRV should be 50")
        XCTAssertEqual(bioState.coherence, 0.5, "Default coherence should be 0.5")
        XCTAssertEqual(bioState.stress, 0.5, "Default stress should be 0.5")
        XCTAssertEqual(bioState.breathRate, 12, "Default breath rate should be 12")
    }

    // MARK: - QuantumField Tests

    func testQuantumFieldInitialization() {
        let field = QuantumField()

        XCTAssertEqual(field.amplitudes.count, 16, "Should have 16 amplitude vectors")
        XCTAssertEqual(field.superpositionStrength, 0.5, "Default superposition should be 0.5")
        XCTAssertEqual(field.creativity, 0.5, "Default creativity should be 0.5")
        XCTAssertEqual(field.collapseProbability, 0, "Initial collapse probability should be 0")
    }

    func testQuantumFieldUpdate() {
        var field = QuantumField()

        let initialSuperposition = field.superpositionStrength
        field.update(coherence: 0.8, energy: 0.7)

        // After update, values should change
        XCTAssertNotEqual(field.superpositionStrength, initialSuperposition, "Superposition should change after update")
        XCTAssertGreaterThan(field.collapseProbability, 0, "Collapse probability should increase with coherence")
    }

    func testQuantumFieldCollapse() {
        var field = QuantumField()

        // Simulate some updates to establish state
        for _ in 0..<10 {
            field.update(coherence: 0.5, energy: 0.5)
        }

        // Record a collapse
        field.recordCollapse(choice: 3)

        // After collapse, the chosen state should be strengthened
        let chosenAmplitude = field.amplitudes[3]
        let otherAmplitude = field.amplitudes[0]

        // Chosen state should be at maximum
        XCTAssertEqual(chosenAmplitude.x, 1.0, accuracy: 0.01, "Collapsed state should be at maximum")

        // Other states should be reduced
        XCTAssertLessThan(simd_length(otherAmplitude), simd_length(chosenAmplitude),
                         "Non-collapsed states should be weaker")

        // Collapse probability should reset
        XCTAssertEqual(field.collapseProbability, 0, "Collapse probability should reset after observation")
    }

    func testQuantumFieldReset() {
        var field = QuantumField()

        // Modify the field
        field.update(coherence: 0.9, energy: 0.9)
        field.recordCollapse(choice: 5)

        // Reset
        field.reset()

        // Should return to initial state
        XCTAssertEqual(field.superpositionStrength, 0.5, "Should reset to default superposition")
        XCTAssertEqual(field.creativity, 0.5, "Should reset to default creativity")
        XCTAssertEqual(field.collapseProbability, 0, "Should reset collapse probability")
    }

    func testQuantumFieldSampling() {
        let field = QuantumField()

        // Sample many times and verify distribution
        var samples = [Int: Int]()
        for _ in 0..<1000 {
            let choice = field.sampleCreativeChoice(options: 4)
            XCTAssertTrue(choice >= 0 && choice < 4, "Choice should be within range")
            samples[choice, default: 0] += 1
        }

        // All options should be sampled at least once with uniform initial distribution
        for i in 0..<4 {
            XCTAssertGreaterThan(samples[i] ?? 0, 0, "Option \(i) should be sampled at least once")
        }
    }

    func testQuantumFieldEdgeCases() {
        var field = QuantumField()

        // Test with zero options
        let zeroChoice = field.sampleCreativeChoice(options: 0)
        XCTAssertEqual(zeroChoice, 0, "Should return 0 for zero options")

        // Test collapse with invalid index (should not crash)
        field.recordCollapse(choice: -1)  // Should handle gracefully
        field.recordCollapse(choice: 100)  // Should handle gracefully
    }

    // MARK: - MIDI2Error Tests

    func testMIDI2ErrorDescriptions() {
        // Test all error cases have descriptions
        let errors: [MIDI2Error] = [
            .clientCreationFailed(123),
            .sourceCreationFailed(456),
            .portCreationFailed(789),
            .notInitialized,
            .invalidChannel(20),
            .invalidNote(200),
            .invalidVelocity(2.0),
            .noteNotActive(note: 60, channel: 5),
            .sendFailed(999)
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }

    func testMIDI2ErrorEquality() {
        let error1 = MIDI2Error.invalidChannel(5)
        let error2 = MIDI2Error.invalidChannel(5)
        let error3 = MIDI2Error.invalidChannel(6)

        XCTAssertEqual(error1, error2, "Same errors should be equal")
        XCTAssertNotEqual(error1, error3, "Different errors should not be equal")
    }

    // MARK: - Control Loop Constants Tests

    func testControlLoopIntervalCalculation() {
        // Test frequency to interval conversion
        let interval60Hz = ControlLoopConstants.interval(forFrequency: 60.0)
        XCTAssertEqual(interval60Hz, 1.0/60.0, accuracy: 0.0001, "60 Hz should be ~16.67ms")

        let interval120Hz = ControlLoopConstants.interval(forFrequency: 120.0)
        XCTAssertEqual(interval120Hz, 1.0/120.0, accuracy: 0.0001, "120 Hz should be ~8.33ms")

        let interval10Hz = ControlLoopConstants.interval(forFrequency: 10.0)
        XCTAssertEqual(interval10Hz, 0.1, accuracy: 0.0001, "10 Hz should be 100ms")
    }

    func testControlLoopConstantValues() {
        // Verify constant values are reasonable
        XCTAssertEqual(ControlLoopConstants.unifiedControlFrequency, 60.0, "UnifiedControlHub should run at 60 Hz")
        XCTAssertEqual(ControlLoopConstants.universalCoreFrequency, 120.0, "UniversalCore should run at 120 Hz")
        XCTAssertGreaterThan(ControlLoopConstants.frequencyTolerance, 0, "Tolerance should be positive")
    }

    // MARK: - Audio Constants Tests

    func testAudioConstantValues() {
        // Verify brainwave frequencies are scientifically accurate
        XCTAssertEqual(AudioConstants.Brainwave.alpha, 10.0, "Alpha should be 10 Hz")
        XCTAssertEqual(AudioConstants.Brainwave.theta, 6.0, "Theta should be 6 Hz")
        XCTAssertEqual(AudioConstants.Brainwave.delta, 2.0, "Delta should be 2 Hz")
        XCTAssertEqual(AudioConstants.Brainwave.beta, 20.0, "Beta should be 20 Hz")
        XCTAssertEqual(AudioConstants.Brainwave.gamma, 40.0, "Gamma should be 40 Hz")
    }

    func testHRVThresholds() {
        // Verify HRV thresholds are in correct order
        XCTAssertLessThan(AudioConstants.HRVThresholds.low, AudioConstants.HRVThresholds.medium)
        XCTAssertLessThan(AudioConstants.HRVThresholds.medium, AudioConstants.HRVThresholds.high)
    }

    // MARK: - System Constants Tests

    func testSystemConstantThresholds() {
        // CPU thresholds should be in correct order
        XCTAssertLessThan(SystemConstants.cpuDegradedThreshold, SystemConstants.cpuCriticalThreshold)

        // Memory thresholds should be in correct order
        XCTAssertLessThan(SystemConstants.memoryDegradedThreshold, SystemConstants.memoryCriticalThreshold)

        // Flow state thresholds should be in correct order
        XCTAssertLessThan(SystemConstants.optimalStreakForFlow, SystemConstants.optimalStreakForUltraFlow)
    }

    // MARK: - EchoelUniversalCore Tests

    func testEchoelUniversalCoreShutdown() async {
        // Get the shared instance
        let core = EchoelUniversalCore.shared

        // Verify it's running
        XCTAssertTrue(core.isRunning, "Core should be running after initialization")

        // Shutdown
        core.shutdown()

        // Verify it stopped
        XCTAssertFalse(core.isRunning, "Core should not be running after shutdown")

        // Verify state was reset
        XCTAssertEqual(core.globalCoherence, 0.5, "Coherence should reset to 0.5")
        XCTAssertEqual(core.systemEnergy, 0.5, "Energy should reset to 0.5")

        // Restart for other tests
        core.restart()
        XCTAssertTrue(core.isRunning, "Core should be running after restart")
    }

    func testEchoelUniversalCoreSystemStatus() {
        let core = EchoelUniversalCore.shared
        let status = core.getSystemStatus()

        XCTAssertNotNil(status.health, "Health should be available")
        XCTAssertGreaterThanOrEqual(status.coherence, 0, "Coherence should be non-negative")
        XCTAssertLessThanOrEqual(status.coherence, 1, "Coherence should be <= 1")
        XCTAssertGreaterThan(status.connectedModules, 0, "Should have connected modules")
    }

    // MARK: - CreativeDirection Tests

    func testCreativeDirectionCases() {
        let directions = EchoelUniversalCore.CreativeDirection.allCases

        XCTAssertEqual(directions.count, 4, "Should have 4 creative directions")
        XCTAssertTrue(directions.contains(.harmonic))
        XCTAssertTrue(directions.contains(.rhythmic))
        XCTAssertTrue(directions.contains(.textural))
        XCTAssertTrue(directions.contains(.structural))
    }
}

// MARK: - MIDI2Manager Tests

@MainActor
final class MIDI2ManagerTests: XCTestCase {

    var sut: MIDI2Manager!

    override func setUp() async throws {
        try await super.setUp()
        sut = MIDI2Manager()
    }

    override func tearDown() async throws {
        sut?.cleanup()
        sut = nil
        try await super.tearDown()
    }

    func testInitialState() {
        XCTAssertFalse(sut.isInitialized, "Should not be initialized on creation")
        XCTAssertTrue(sut.connectedEndpoints.isEmpty, "Should have no endpoints initially")
        XCTAssertNil(sut.errorMessage, "Should have no error initially")
    }

    func testNoteOnValidationBeforeInit() {
        // Should fail gracefully when not initialized
        let result = sut.sendNoteOnValidated(channel: 0, note: 60, velocity: 0.8)

        switch result {
        case .success:
            XCTFail("Should fail when not initialized")
        case .failure(let error):
            XCTAssertEqual(error, .notInitialized)
        }
    }

    func testInvalidChannelValidation() {
        let result = sut.sendNoteOnValidated(channel: 20, note: 60, velocity: 0.8)

        switch result {
        case .success:
            XCTFail("Should fail with invalid channel")
        case .failure(let error):
            XCTAssertEqual(error, .invalidChannel(20))
        }
    }

    func testInvalidNoteValidation() {
        let result = sut.sendNoteOnValidated(channel: 0, note: 200, velocity: 0.8)

        switch result {
        case .success:
            XCTFail("Should fail with invalid note")
        case .failure(let error):
            XCTAssertEqual(error, .invalidNote(200))
        }
    }

    func testVelocityClampingInNoteOn() {
        // When initialized, velocity should be clamped, not rejected
        // Testing the clamping logic indirectly
        let clampedVelocity = MIDIConstants.clampVelocity(1.5)
        XCTAssertEqual(clampedVelocity, 1.0, accuracy: 0.001)
    }

    func testActiveNoteTracking() {
        // Without initialization, can't test active notes
        XCTAssertEqual(sut.activeNoteCount, 0, "Should have no active notes")
        XCTAssertFalse(sut.isNoteActive(channel: 0, note: 60), "Note should not be active")
    }

    func testCleanup() {
        sut.cleanup()

        XCTAssertFalse(sut.isInitialized, "Should not be initialized after cleanup")
        XCTAssertEqual(sut.activeNoteCount, 0, "Should have no active notes after cleanup")
    }
}

// MARK: - BioReactiveProcessor Tests

final class BioReactiveProcessorTests: XCTestCase {

    func testUpdateFromHealthKit() {
        let processor = BioReactiveProcessor()

        processor.updateFromHealthKit(heartRate: 75, hrv: 60)

        XCTAssertEqual(processor.currentState.heartRate, 75, accuracy: 0.01)
        XCTAssertEqual(processor.currentState.hrv, 60, accuracy: 0.01)
        XCTAssertGreaterThan(processor.currentState.coherence, 0)
        XCTAssertLessThanOrEqual(processor.currentState.coherence, 1)
    }

    func testUpdateState() {
        let processor = BioReactiveProcessor()

        var newState = BioState()
        newState.heartRate = 80
        newState.hrv = 55
        newState.breathRate = 10

        processor.updateState(newState)

        XCTAssertEqual(processor.currentState.heartRate, 80, accuracy: 0.01)
        XCTAssertEqual(processor.currentState.hrv, 55, accuracy: 0.01)
        XCTAssertEqual(processor.currentState.breathRate, 10, accuracy: 0.01)
    }

    func testUpdateBreathPhase() {
        let processor = BioReactiveProcessor()

        processor.updateBreathPhase(0.5)
        XCTAssertEqual(processor.currentState.breathPhase, 0.5, accuracy: 0.01)

        // Test clamping
        processor.updateBreathPhase(-0.5)
        XCTAssertEqual(processor.currentState.breathPhase, 0.0, accuracy: 0.01)

        processor.updateBreathPhase(1.5)
        XCTAssertEqual(processor.currentState.breathPhase, 1.0, accuracy: 0.01)
    }

    func testCoherenceCalculation() {
        let processor = BioReactiveProcessor()

        // High HRV, normal heart rate = high coherence
        processor.updateFromHealthKit(heartRate: 60, hrv: 80)
        let highCoherence = processor.currentState.coherence

        // Low HRV = lower coherence
        processor.updateFromHealthKit(heartRate: 60, hrv: 20)
        let lowCoherence = processor.currentState.coherence

        XCTAssertGreaterThan(highCoherence, lowCoherence, "Higher HRV should produce higher coherence")
    }

    func testStressCalculation() {
        let processor = BioReactiveProcessor()

        processor.updateFromHealthKit(heartRate: 70, hrv: 60)

        // Stress should be inverse of coherence
        let expectedStress = 1.0 - processor.currentState.coherence
        XCTAssertEqual(processor.currentState.stress, expectedStress, accuracy: 0.01)
    }
}
