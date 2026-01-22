// QuantumMIDIOutTests.swift
// Echoelmusic - Super Intelligent Quantum MIDI Out Tests
// λ∞ Ralph Wiggum Apple Ökosystem Environment Lambda Loop Mode
//
// "I bent my MIDI!" - Ralph Wiggum, Music Technologist
//
// Created 2026-01-21 - Phase 10000.3 SUPER INTELLIGENT QUANTUM MIDI

import XCTest
@testable import Echoelmusic

/// Comprehensive tests for the Super Intelligent Quantum MIDI Out Engine
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class QuantumMIDIOutTests: XCTestCase {

    // MARK: - Test Lifecycle

    @MainActor
    override func setUp() async throws {
        // Fresh state for each test
    }

    @MainActor
    override func tearDown() async throws {
        // Cleanup
    }

    // MARK: - Initialization Tests

    @MainActor
    func testDefaultInitialization() async throws {
        let midiOut = QuantumMIDIOut()

        XCTAssertFalse(midiOut.isActive)
        XCTAssertEqual(midiOut.polyphony, 16)
        XCTAssertEqual(midiOut.intelligenceMode, .superIntelligent)
        XCTAssertEqual(midiOut.voiceCount, 0)
        XCTAssertEqual(midiOut.activeVoices.count, 0)
    }

    @MainActor
    func testCustomPolyphonyInitialization() async throws {
        let midiOut = QuantumMIDIOut(polyphony: 32)

        XCTAssertEqual(midiOut.polyphony, 32)
    }

    @MainActor
    func testMaxPolyphonyClamping() async throws {
        let midiOut = QuantumMIDIOut(polyphony: 128)

        XCTAssertLessThanOrEqual(midiOut.polyphony, QuantumMIDIConstants.maxPolyphony)
    }

    // MARK: - Quantum MIDI Voice Tests

    func testVoiceCreation() {
        let voice = QuantumMIDIVoice()

        XCTAssertEqual(voice.midiNote, 60)
        XCTAssertEqual(voice.velocity, 0.75)
        XCTAssertEqual(voice.pitchBend, 0)
        XCTAssertFalse(voice.isActive)
        XCTAssertEqual(voice.instrumentTarget, .piano)
    }

    func testVoiceQuantumState() {
        let state = QuantumMIDIVoice.QuantumVoiceState(
            coherence: 0.8,
            phase: 1.5,
            entangledVoiceId: UUID(),
            superposition: 1.0,
            waveformCollapse: false
        )

        XCTAssertEqual(state.coherence, 0.8)
        XCTAssertEqual(state.phase, 1.5)
        XCTAssertNotNil(state.entangledVoiceId)
        XCTAssertEqual(state.superposition, 1.0)
        XCTAssertFalse(state.waveformCollapse)
    }

    // MARK: - Instrument Target Tests

    func testInstrumentTargetMIDIChannels() {
        // Orchestral strings on channel 0-1
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.violins.midiChannel, 0)
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.cellos.midiChannel, 1)

        // Brass on channel 2
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.trumpets.midiChannel, 2)
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.frenchHorns.midiChannel, 2)

        // Synths on channel 8
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.subtractive.midiChannel, 8)

        // Quantum on channel 15
        XCTAssertEqual(QuantumMIDIVoice.InstrumentTarget.quantumField.midiChannel, 15)
    }

    func testInstrumentNoteRanges() {
        // Violins: G3-G7
        let violinRange = QuantumMIDIVoice.InstrumentTarget.violins.noteRange
        XCTAssertEqual(violinRange.lowerBound, 55)
        XCTAssertEqual(violinRange.upperBound, 103)

        // Piano: Full range
        let pianoRange = QuantumMIDIVoice.InstrumentTarget.piano.noteRange
        XCTAssertEqual(pianoRange.lowerBound, 21)
        XCTAssertEqual(pianoRange.upperBound, 108)

        // TR-808: Drum map
        let tr808Range = QuantumMIDIVoice.InstrumentTarget.tr808.noteRange
        XCTAssertEqual(tr808Range.lowerBound, 36)
        XCTAssertEqual(tr808Range.upperBound, 51)
    }

    func testAllInstrumentTargets() {
        // Ensure all instruments have valid channel and range
        for instrument in QuantumMIDIVoice.InstrumentTarget.allCases {
            XCTAssertLessThanOrEqual(instrument.midiChannel, 15, "Channel out of range for \(instrument)")
            XCTAssertLessThan(instrument.noteRange.lowerBound, instrument.noteRange.upperBound,
                            "Invalid note range for \(instrument)")
        }
    }

    // MARK: - Routing Tests

    func testDefaultRouting() {
        let routing = QuantumMIDIRouting()

        XCTAssertEqual(routing.enabledInstruments.count, QuantumMIDIVoice.InstrumentTarget.allCases.count)
        XCTAssertTrue(routing.orchestralEnabled)
        XCTAssertTrue(routing.synthesizersEnabled)
        XCTAssertTrue(routing.mpeEnabled)
        XCTAssertTrue(routing.midi2Enabled)
    }

    func testEnableOrchestral() {
        var routing = QuantumMIDIRouting()
        routing.enabledInstruments.removeAll()
        routing.enableOrchestral()

        XCTAssertTrue(routing.enabledInstruments.contains(.violins))
        XCTAssertTrue(routing.enabledInstruments.contains(.piano))
        XCTAssertTrue(routing.enabledInstruments.contains(.timpani))
    }

    func testEnableSynthesizers() {
        var routing = QuantumMIDIRouting()
        routing.enabledInstruments.removeAll()
        routing.enableSynthesizers()

        XCTAssertTrue(routing.enabledInstruments.contains(.subtractive))
        XCTAssertTrue(routing.enabledInstruments.contains(.fm))
        XCTAssertTrue(routing.enabledInstruments.contains(.genetic))
    }

    // MARK: - Intelligence Mode Tests

    func testIntelligenceModes() {
        for mode in QuantumIntelligenceMode.allCases {
            XCTAssertFalse(mode.rawValue.isEmpty)
            XCTAssertNotNil(mode.voiceAllocationStrategy)
        }
    }

    func testVoiceAllocationStrategies() {
        XCTAssertEqual(QuantumIntelligenceMode.classical.voiceAllocationStrategy, .roundRobin)
        XCTAssertEqual(QuantumIntelligenceMode.superIntelligent.voiceAllocationStrategy, .adaptive)
        XCTAssertEqual(QuantumIntelligenceMode.lambdaTranscendent.voiceAllocationStrategy, .quantum)
    }

    // MARK: - Bio Input Tests

    func testDefaultBioInput() {
        let bioInput = QuantumBioInput()

        XCTAssertEqual(bioInput.heartRate, 70.0)
        XCTAssertEqual(bioInput.coherence, 0.5)
        XCTAssertEqual(bioInput.lambdaState, .aware)
    }

    func testQuantumVelocityCalculation() {
        var bioInput = QuantumBioInput()

        // Low coherence
        bioInput.coherence = 0.0
        bioInput.breathPhase = 0.0
        let lowVelocity = bioInput.quantumVelocity
        XCTAssertGreaterThan(lowVelocity, 0)

        // High coherence
        bioInput.coherence = 1.0
        bioInput.breathPhase = 0.5
        let highVelocity = bioInput.quantumVelocity
        XCTAssertGreaterThan(highVelocity, lowVelocity)
    }

    func testLambdaStateExpressionMultiplier() {
        XCTAssertEqual(QuantumBioInput.LambdaState.dormant.expressionMultiplier, 1.0 / 8.0)
        XCTAssertEqual(QuantumBioInput.LambdaState.lambdaInfinity.expressionMultiplier, 8.0 / 8.0)
    }

    func testLambdaStateHarmonyComplexity() {
        XCTAssertEqual(QuantumBioInput.LambdaState.dormant.harmonyComplexity, 2)
        XCTAssertEqual(QuantumBioInput.LambdaState.lambdaInfinity.harmonyComplexity, 5)
    }

    // MARK: - Quantum Chord Tests

    func testChordIntervals() {
        // Basic triads
        XCTAssertEqual(QuantumChordType.majorTriad.intervals(for: .classical), [0, 4, 7])
        XCTAssertEqual(QuantumChordType.minorTriad.intervals(for: .classical), [0, 3, 7])

        // Seventh chords
        XCTAssertEqual(QuantumChordType.major7.intervals(for: .classical), [0, 4, 7, 11])
        XCTAssertEqual(QuantumChordType.dominant7.intervals(for: .classical), [0, 4, 7, 10])

        // Quantum chords
        let fibonacciIntervals = QuantumChordType.fibonacci.intervals(for: .superIntelligent)
        XCTAssertGreaterThan(fibonacciIntervals.count, 3)

        // Superposition chord changes based on mode
        let superpositionClassical = QuantumChordType.quantumSuperposition.intervals(for: .classical)
        let superpositionTranscendent = QuantumChordType.quantumSuperposition.intervals(for: .lambdaTranscendent)
        XCTAssertLessThan(superpositionClassical.count, superpositionTranscendent.count)
    }

    func testAllChordTypes() {
        for chord in QuantumChordType.allCases {
            for mode in QuantumIntelligenceMode.allCases {
                let intervals = chord.intervals(for: mode)
                XCTAssertGreaterThan(intervals.count, 0, "Empty intervals for \(chord) in \(mode)")
            }
        }
    }

    // MARK: - Constants Tests

    func testQuantumMIDIConstants() {
        XCTAssertEqual(QuantumMIDIConstants.maxPolyphony, 64)
        XCTAssertEqual(QuantumMIDIConstants.mpeVoices, 15)
        XCTAssertEqual(QuantumMIDIConstants.updateHz, 120.0)
        XCTAssertEqual(QuantumMIDIConstants.phi, 1.618033988749895)
    }

    func testSchumannFrequencies() {
        XCTAssertEqual(QuantumMIDIConstants.schumannHz.count, 5)
        XCTAssertEqual(QuantumMIDIConstants.schumannHz[0], 7.83)
    }

    // MARK: - Preset Tests

    @MainActor
    func testMeditationPreset() async throws {
        let midiOut = QuantumMIDIOut()
        midiOut.loadMeditationPreset()

        XCTAssertEqual(midiOut.intelligenceMode, .bioCoherent)
        XCTAssertEqual(midiOut.polyphony, 8)
        XCTAssertTrue(midiOut.routing.mpeEnabled)
    }

    @MainActor
    func testOrchestralPreset() async throws {
        let midiOut = QuantumMIDIOut()
        midiOut.loadOrchestralPreset()

        XCTAssertEqual(midiOut.intelligenceMode, .superIntelligent)
        XCTAssertEqual(midiOut.polyphony, 32)
    }

    @MainActor
    func testQuantumTranscendentPreset() async throws {
        let midiOut = QuantumMIDIOut()
        midiOut.loadQuantumTranscendentPreset()

        XCTAssertEqual(midiOut.intelligenceMode, .lambdaTranscendent)
        XCTAssertEqual(midiOut.polyphony, 64)
        XCTAssertTrue(midiOut.routing.midi2Enabled)
    }

    @MainActor
    func testSacredGeometryPreset() async throws {
        let midiOut = QuantumMIDIOut()
        midiOut.loadSacredGeometryPreset()

        XCTAssertEqual(midiOut.intelligenceMode, .sacredGeometry)
        XCTAssertEqual(midiOut.polyphony, 16)
    }

    // MARK: - Bio Input Update Tests

    @MainActor
    func testBioInputUpdate() async throws {
        let midiOut = QuantumMIDIOut()

        midiOut.updateBioInput(
            heartRate: 80.0,
            hrv: 60.0,
            coherence: 0.75,
            breathingRate: 10.0,
            breathPhase: 0.25,
            lambdaState: .coherent
        )

        XCTAssertEqual(midiOut.bioInput.heartRate, 80.0)
        XCTAssertEqual(midiOut.bioInput.hrvMs, 60.0)
        XCTAssertEqual(midiOut.bioInput.coherence, 0.75)
        XCTAssertEqual(midiOut.bioInput.breathingRate, 10.0)
        XCTAssertEqual(midiOut.bioInput.breathPhase, 0.25)
        XCTAssertEqual(midiOut.bioInput.lambdaState, .coherent)
    }

    @MainActor
    func testPartialBioInputUpdate() async throws {
        let midiOut = QuantumMIDIOut()
        let originalHeartRate = midiOut.bioInput.heartRate

        midiOut.updateBioInput(coherence: 0.9)

        XCTAssertEqual(midiOut.bioInput.coherence, 0.9)
        XCTAssertEqual(midiOut.bioInput.heartRate, originalHeartRate)  // Unchanged
    }

    // MARK: - Performance Tests

    @MainActor
    func testVoiceAllocationPerformance() async throws {
        let midiOut = QuantumMIDIOut(polyphony: 64)

        measure {
            // Create many voices rapidly
            for _ in 0..<1000 {
                _ = QuantumMIDIVoice(
                    midiNote: UInt8.random(in: 36...96),
                    velocity: Float.random(in: 0.5...1.0),
                    instrumentTarget: QuantumMIDIVoice.InstrumentTarget.allCases.randomElement()!
                )
            }
        }
    }

    @MainActor
    func testChordIntervalCalculationPerformance() {
        measure {
            for _ in 0..<10000 {
                for chord in QuantumChordType.allCases {
                    _ = chord.intervals(for: .lambdaTranscendent)
                }
            }
        }
    }

    @MainActor
    func testBioInputCalculationPerformance() {
        var bioInput = QuantumBioInput()

        measure {
            for _ in 0..<100000 {
                bioInput.coherence = Float.random(in: 0...1)
                bioInput.breathPhase = Float.random(in: 0...1)
                _ = bioInput.quantumVelocity
                _ = bioInput.hrvExpression
                _ = bioInput.phaseModulation
            }
        }
    }

    // MARK: - Edge Case Tests

    func testEmptyInstrumentSet() {
        var routing = QuantumMIDIRouting()
        routing.enabledInstruments.removeAll()

        XCTAssertEqual(routing.enabledInstruments.count, 0)
    }

    func testExtremeCoherenceValues() {
        var bioInput = QuantumBioInput()

        // Zero coherence
        bioInput.coherence = 0.0
        XCTAssertGreaterThanOrEqual(bioInput.quantumVelocity, 0)
        XCTAssertLessThanOrEqual(bioInput.quantumVelocity, 1)

        // Max coherence
        bioInput.coherence = 1.0
        XCTAssertGreaterThanOrEqual(bioInput.quantumVelocity, 0)
        XCTAssertLessThanOrEqual(bioInput.quantumVelocity, 1)
    }

    func testExtremeBreathPhaseValues() {
        var bioInput = QuantumBioInput()

        // Start of breath
        bioInput.breathPhase = 0.0
        XCTAssertEqual(bioInput.dynamicEnvelope, 0.0, accuracy: 0.01)

        // Peak of breath
        bioInput.breathPhase = 0.5
        XCTAssertEqual(bioInput.dynamicEnvelope, 1.0, accuracy: 0.01)

        // End of breath
        bioInput.breathPhase = 1.0
        XCTAssertEqual(bioInput.dynamicEnvelope, 0.0, accuracy: 0.01)
    }

    // MARK: - Thread Safety Tests

    @MainActor
    func testConcurrentBioInputUpdates() async throws {
        let midiOut = QuantumMIDIOut()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask { @MainActor in
                    midiOut.updateBioInput(
                        heartRate: Double(60 + i % 40),
                        coherence: Float(i % 100) / 100.0
                    )
                }
            }
        }

        // Should not crash and values should be valid
        XCTAssertGreaterThanOrEqual(midiOut.bioInput.heartRate, 60)
        XCTAssertLessThanOrEqual(midiOut.bioInput.heartRate, 99)
    }

    // MARK: - Integration Tests

    @MainActor
    func testFullWorkflow() async throws {
        let midiOut = QuantumMIDIOut(polyphony: 16)

        // Configure
        midiOut.loadQuantumTranscendentPreset()
        XCTAssertEqual(midiOut.intelligenceMode, .lambdaTranscendent)

        // Update bio input
        midiOut.updateBioInput(
            heartRate: 72.0,
            coherence: 0.85,
            lambdaState: .transcendent
        )

        // Verify state
        XCTAssertEqual(midiOut.bioInput.heartRate, 72.0)
        XCTAssertEqual(midiOut.bioInput.coherence, 0.85)
        XCTAssertEqual(midiOut.bioInput.lambdaState, .transcendent)
    }
}

// MARK: - Helper Extensions for Tests

extension QuantumBioInput {
    /// Dynamic envelope from breath phase (for testing)
    var dynamicEnvelope: Float {
        sin(breathPhase * Float.pi)
    }
}
