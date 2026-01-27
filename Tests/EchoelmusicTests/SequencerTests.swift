// SequencerTests.swift
// Tests for VisualStepSequencer and related components
//
// Copyright 2026 Echoelmusic. MIT License.

import XCTest
@testable import Echoelmusic

/// Comprehensive tests for the Visual Step Sequencer
/// Coverage: Playback, patterns, channels, bio-modulation, presets
final class SequencerTests: XCTestCase {

    // MARK: - Sequencer Constants Tests

    func testSequencerStepCount() {
        XCTAssertEqual(VisualStepSequencer.stepCount, 16)
    }

    func testSequencerChannelCount() {
        XCTAssertEqual(VisualStepSequencer.channelCount, 8)
    }

    func testSequencerBPMRange() {
        XCTAssertEqual(VisualStepSequencer.bpmRange.lowerBound, 60)
        XCTAssertEqual(VisualStepSequencer.bpmRange.upperBound, 180)
    }

    // MARK: - Channel Tests

    func testChannelCount() {
        XCTAssertEqual(VisualStepSequencer.Channel.allCases.count, 8)
    }

    func testChannelRawValues() {
        XCTAssertEqual(VisualStepSequencer.Channel.visual1.rawValue, 0)
        XCTAssertEqual(VisualStepSequencer.Channel.visual2.rawValue, 1)
        XCTAssertEqual(VisualStepSequencer.Channel.visual3.rawValue, 2)
        XCTAssertEqual(VisualStepSequencer.Channel.visual4.rawValue, 3)
        XCTAssertEqual(VisualStepSequencer.Channel.lighting.rawValue, 4)
        XCTAssertEqual(VisualStepSequencer.Channel.effect1.rawValue, 5)
        XCTAssertEqual(VisualStepSequencer.Channel.effect2.rawValue, 6)
        XCTAssertEqual(VisualStepSequencer.Channel.bioTrigger.rawValue, 7)
    }

    func testChannelNames() {
        XCTAssertEqual(VisualStepSequencer.Channel.visual1.name, "Visual A")
        XCTAssertEqual(VisualStepSequencer.Channel.visual2.name, "Visual B")
        XCTAssertEqual(VisualStepSequencer.Channel.visual3.name, "Visual C")
        XCTAssertEqual(VisualStepSequencer.Channel.visual4.name, "Visual D")
        XCTAssertEqual(VisualStepSequencer.Channel.lighting.name, "Lighting")
        XCTAssertEqual(VisualStepSequencer.Channel.effect1.name, "Effect 1")
        XCTAssertEqual(VisualStepSequencer.Channel.effect2.name, "Effect 2")
        XCTAssertEqual(VisualStepSequencer.Channel.bioTrigger.name, "Bio Trigger")
    }

    func testChannelIdentifiable() {
        for channel in VisualStepSequencer.Channel.allCases {
            XCTAssertEqual(channel.id, channel.rawValue)
        }
    }

    func testChannelColors() {
        // Each channel should have a unique color
        var colors = Set<String>()
        for channel in VisualStepSequencer.Channel.allCases {
            let colorDescription = "\(channel.color)"
            colors.insert(colorDescription)
        }
        XCTAssertEqual(colors.count, 8, "Each channel should have a unique color")
    }

    // MARK: - SequencerPattern Tests

    func testPatternInitialization() {
        let pattern = SequencerPattern()

        // All steps should be inactive by default
        for channel in VisualStepSequencer.Channel.allCases {
            for step in 0..<16 {
                XCTAssertFalse(pattern.isActive(channel: channel, step: step))
            }
        }
    }

    func testPatternToggle() {
        var pattern = SequencerPattern()

        XCTAssertFalse(pattern.isActive(channel: .visual1, step: 0))

        pattern.toggle(channel: .visual1, step: 0)
        XCTAssertTrue(pattern.isActive(channel: .visual1, step: 0))

        pattern.toggle(channel: .visual1, step: 0)
        XCTAssertFalse(pattern.isActive(channel: .visual1, step: 0))
    }

    func testPatternVelocity() {
        var pattern = SequencerPattern()

        // Default velocity
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 1.0, accuracy: 0.001)

        // Set velocity
        pattern.setVelocity(channel: .visual1, step: 0, velocity: 0.5)
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 0.5, accuracy: 0.001)
    }

    func testPatternVelocityClamping() {
        var pattern = SequencerPattern()

        // Test clamping to 0-1 range
        pattern.setVelocity(channel: .visual1, step: 0, velocity: 1.5)
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 1.0, accuracy: 0.001)

        pattern.setVelocity(channel: .visual1, step: 0, velocity: -0.5)
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 0.0, accuracy: 0.001)
    }

    func testPatternClearChannel() {
        var pattern = SequencerPattern()

        // Activate several steps
        pattern.toggle(channel: .visual1, step: 0)
        pattern.toggle(channel: .visual1, step: 5)
        pattern.toggle(channel: .visual1, step: 10)

        XCTAssertTrue(pattern.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(pattern.isActive(channel: .visual1, step: 5))

        // Clear channel
        pattern.clearChannel(.visual1)

        for step in 0..<16 {
            XCTAssertFalse(pattern.isActive(channel: .visual1, step: step))
        }
    }

    func testPatternOutOfBoundsAccess() {
        let pattern = SequencerPattern()

        // Should handle out of bounds gracefully
        XCTAssertFalse(pattern.isActive(channel: .visual1, step: 100))
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 100), 0, accuracy: 0.001)
    }

    func testPatternEquatable() {
        let pattern1 = SequencerPattern()
        let pattern2 = SequencerPattern()

        XCTAssertEqual(pattern1, pattern2)

        var pattern3 = SequencerPattern()
        pattern3.toggle(channel: .visual1, step: 0)

        XCTAssertNotEqual(pattern1, pattern3)
    }

    func testPatternCodable() throws {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        pattern.toggle(channel: .lighting, step: 8)
        pattern.setVelocity(channel: .visual1, step: 0, velocity: 0.7)

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(pattern)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SequencerPattern.self, from: data)

        XCTAssertEqual(pattern, decoded)
        XCTAssertTrue(decoded.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(decoded.isActive(channel: .lighting, step: 8))
        XCTAssertEqual(decoded.velocity(channel: .visual1, step: 0), 0.7, accuracy: 0.001)
    }

    // MARK: - BioModulationState Tests

    func testBioModulationStateDefaults() {
        let state = BioModulationState()

        XCTAssertEqual(state.coherence, 0.5, accuracy: 0.001)
        XCTAssertEqual(state.heartRate, 70.0, accuracy: 0.001)
        XCTAssertEqual(state.hrvVariability, 0.5, accuracy: 0.001)
        XCTAssertEqual(state.skipProbability, 0.0, accuracy: 0.001)
        XCTAssertFalse(state.tempoLockEnabled)
    }

    func testBioModulationStateMutation() {
        var state = BioModulationState()

        state.coherence = 0.9
        state.heartRate = 120.0
        state.hrvVariability = 0.8
        state.skipProbability = 0.2
        state.tempoLockEnabled = true

        XCTAssertEqual(state.coherence, 0.9, accuracy: 0.001)
        XCTAssertEqual(state.heartRate, 120.0, accuracy: 0.001)
        XCTAssertEqual(state.hrvVariability, 0.8, accuracy: 0.001)
        XCTAssertEqual(state.skipProbability, 0.2, accuracy: 0.001)
        XCTAssertTrue(state.tempoLockEnabled)
    }

    // MARK: - SequencerPreset Tests

    func testPresetCount() {
        XCTAssertEqual(VisualStepSequencer.presets.count, 5)
    }

    func testFourOnFloorPreset() {
        let preset = SequencerPreset.fourOnFloor

        XCTAssertEqual(preset.id, "four_on_floor")
        XCTAssertEqual(preset.name, "Four on Floor")
        XCTAssertEqual(preset.bpm, 120)
        XCTAssertFalse(preset.description.isEmpty)

        // Should have kicks on beats 0, 4, 8, 12
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 4))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 8))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 12))
    }

    func testBreakbeatPreset() {
        let preset = SequencerPreset.breakbeat

        XCTAssertEqual(preset.id, "breakbeat")
        XCTAssertEqual(preset.name, "Breakbeat")
        XCTAssertEqual(preset.bpm, 90)

        // Check syncopated pattern
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 6))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 10))
    }

    func testAmbientPreset() {
        let preset = SequencerPreset.ambient

        XCTAssertEqual(preset.id, "ambient")
        XCTAssertEqual(preset.name, "Ambient")
        XCTAssertEqual(preset.bpm, 70)
    }

    func testBioReactivePreset() {
        let preset = SequencerPreset.bioReactive

        XCTAssertEqual(preset.id, "bio_reactive")
        XCTAssertEqual(preset.name, "Bio-Reactive")
        XCTAssertEqual(preset.bpm, 100)

        // Should have bio trigger channel active
        var bioTriggerCount = 0
        for step in 0..<16 {
            if preset.pattern.isActive(channel: .bioTrigger, step: step) {
                bioTriggerCount += 1
            }
        }
        XCTAssertGreaterThan(bioTriggerCount, 0)
    }

    func testMinimalPreset() {
        let preset = SequencerPreset.minimal

        XCTAssertEqual(preset.id, "minimal")
        XCTAssertEqual(preset.name, "Minimal")
        XCTAssertEqual(preset.bpm, 110)

        // Minimal should have very few active steps
        var activeCount = 0
        for channel in VisualStepSequencer.Channel.allCases {
            for step in 0..<16 {
                if preset.pattern.isActive(channel: channel, step: step) {
                    activeCount += 1
                }
            }
        }
        XCTAssertLessThanOrEqual(activeCount, 5, "Minimal preset should have few active steps")
    }

    func testPresetIdentifiable() {
        for preset in VisualStepSequencer.presets {
            XCTAssertFalse(preset.id.isEmpty)
        }
    }

    // MARK: - VisualStepSequencer Instance Tests

    @MainActor
    func testSequencerSharedInstance() {
        let sequencer1 = VisualStepSequencer.shared
        let sequencer2 = VisualStepSequencer.shared

        XCTAssertTrue(sequencer1 === sequencer2, "Should be singleton")
    }

    @MainActor
    func testSequencerInitialState() {
        let sequencer = VisualStepSequencer.shared
        sequencer.stop()  // Reset state

        XCTAssertFalse(sequencer.isPlaying)
        XCTAssertEqual(sequencer.currentStep, 0)
        XCTAssertEqual(sequencer.bpm, 120, accuracy: 0.001)
    }

    @MainActor
    func testSequencerPlayStop() {
        let sequencer = VisualStepSequencer.shared

        sequencer.stop()
        XCTAssertFalse(sequencer.isPlaying)

        sequencer.play()
        XCTAssertTrue(sequencer.isPlaying)

        sequencer.stop()
        XCTAssertFalse(sequencer.isPlaying)
        XCTAssertEqual(sequencer.currentStep, 0)
    }

    @MainActor
    func testSequencerPlayPause() {
        let sequencer = VisualStepSequencer.shared

        sequencer.stop()
        sequencer.play()
        XCTAssertTrue(sequencer.isPlaying)

        sequencer.pause()
        XCTAssertFalse(sequencer.isPlaying)
        // Current step should be preserved (not reset to 0)
    }

    @MainActor
    func testSequencerPlayWhenAlreadyPlaying() {
        let sequencer = VisualStepSequencer.shared

        sequencer.stop()
        sequencer.play()
        XCTAssertTrue(sequencer.isPlaying)

        // Playing again should not cause issues
        sequencer.play()
        XCTAssertTrue(sequencer.isPlaying)

        sequencer.stop()
    }

    @MainActor
    func testSequencerToggleStep() {
        let sequencer = VisualStepSequencer.shared

        // Toggle a step
        let initialState = sequencer.pattern.isActive(channel: .visual1, step: 5)
        sequencer.toggleStep(channel: .visual1, step: 5)
        XCTAssertNotEqual(sequencer.pattern.isActive(channel: .visual1, step: 5), initialState)

        // Toggle back
        sequencer.toggleStep(channel: .visual1, step: 5)
        XCTAssertEqual(sequencer.pattern.isActive(channel: .visual1, step: 5), initialState)
    }

    @MainActor
    func testSequencerSetVelocity() {
        let sequencer = VisualStepSequencer.shared

        sequencer.setVelocity(channel: .visual1, step: 3, velocity: 0.75)
        XCTAssertEqual(sequencer.pattern.velocity(channel: .visual1, step: 3), 0.75, accuracy: 0.001)
    }

    @MainActor
    func testSequencerClearChannel() {
        let sequencer = VisualStepSequencer.shared

        // Set up some steps
        sequencer.toggleStep(channel: .visual2, step: 0)
        sequencer.toggleStep(channel: .visual2, step: 4)

        sequencer.clearChannel(.visual2)

        for step in 0..<16 {
            XCTAssertFalse(sequencer.pattern.isActive(channel: .visual2, step: step))
        }
    }

    @MainActor
    func testSequencerClearAll() {
        let sequencer = VisualStepSequencer.shared

        // Set up some steps on different channels
        sequencer.toggleStep(channel: .visual1, step: 0)
        sequencer.toggleStep(channel: .lighting, step: 8)

        sequencer.clearAll()

        for channel in VisualStepSequencer.Channel.allCases {
            for step in 0..<16 {
                XCTAssertFalse(sequencer.pattern.isActive(channel: channel, step: step))
            }
        }
    }

    @MainActor
    func testSequencerLoadPreset() {
        let sequencer = VisualStepSequencer.shared

        sequencer.loadPreset(.fourOnFloor)

        XCTAssertEqual(sequencer.bpm, 120, accuracy: 0.001)
        XCTAssertTrue(sequencer.pattern.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(sequencer.pattern.isActive(channel: .visual1, step: 4))
    }

    @MainActor
    func testSequencerBioStateUpdate() {
        let sequencer = VisualStepSequencer.shared
        sequencer.stop()

        sequencer.updateBioState(coherence: 0.8, heartRate: 80.0, hrvVariability: 0.7)

        XCTAssertEqual(sequencer.bioModulation.coherence, 0.8, accuracy: 0.001)
        XCTAssertEqual(sequencer.bioModulation.heartRate, 80.0, accuracy: 0.001)
        XCTAssertEqual(sequencer.bioModulation.hrvVariability, 0.7, accuracy: 0.001)
    }

    @MainActor
    func testSequencerBioSkipProbability() {
        let sequencer = VisualStepSequencer.shared

        // High HRV variability = low skip probability
        sequencer.updateBioState(coherence: 0.5, heartRate: 70.0, hrvVariability: 1.0)
        XCTAssertEqual(sequencer.bioModulation.skipProbability, 0.0, accuracy: 0.001)

        // Low HRV variability = higher skip probability
        sequencer.updateBioState(coherence: 0.5, heartRate: 70.0, hrvVariability: 0.0)
        XCTAssertEqual(sequencer.bioModulation.skipProbability, 0.3, accuracy: 0.001)
    }

    @MainActor
    func testSequencerTempoLock() {
        let sequencer = VisualStepSequencer.shared
        sequencer.stop()
        sequencer.bpm = 120

        // Enable tempo lock
        sequencer.bioModulation.tempoLockEnabled = true

        // Update with heart rate
        sequencer.updateBioState(coherence: 0.5, heartRate: 80.0, hrvVariability: 0.5)

        // BPM should move toward heart rate (smoothed)
        // With 5% weight, new BPM = 120 * 0.95 + 80 * 0.05 = 114 + 4 = 118
        XCTAssertLessThan(sequencer.bpm, 120)

        sequencer.bioModulation.tempoLockEnabled = false
    }

    // MARK: - Notification Tests

    func testSequencerStepTriggeredNotificationName() {
        let expectedName = Notification.Name.sequencerStepTriggered
        XCTAssertEqual(expectedName.rawValue, "sequencerStepTriggered")
    }

    // MARK: - Clamped Extension Tests

    func testClampedExtension() {
        XCTAssertEqual(5.clamped(to: 0...10), 5)
        XCTAssertEqual((-5).clamped(to: 0...10), 0)
        XCTAssertEqual(15.clamped(to: 0...10), 10)

        XCTAssertEqual(0.5.clamped(to: 0.0...1.0), 0.5, accuracy: 0.001)
        XCTAssertEqual((-0.5).clamped(to: 0.0...1.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(1.5.clamped(to: 0.0...1.0), 1.0, accuracy: 0.001)
    }

    // MARK: - Performance Tests

    func testPatternTogglePerformance() {
        var pattern = SequencerPattern()

        measure {
            for _ in 0..<1000 {
                for channel in VisualStepSequencer.Channel.allCases {
                    for step in 0..<16 {
                        pattern.toggle(channel: channel, step: step)
                    }
                }
            }
        }
    }

    func testPatternAccessPerformance() {
        let pattern = SequencerPattern()

        measure {
            for _ in 0..<10000 {
                for channel in VisualStepSequencer.Channel.allCases {
                    for step in 0..<16 {
                        let _ = pattern.isActive(channel: channel, step: step)
                        let _ = pattern.velocity(channel: channel, step: step)
                    }
                }
            }
        }
    }

    // MARK: - Edge Cases

    func testPatternWithNegativeStep() {
        var pattern = SequencerPattern()

        // Should handle negative step gracefully via guard
        pattern.toggle(channel: .visual1, step: -1)  // Should be no-op
        // Verify no crash occurred
    }

    @MainActor
    func testSequencerBPMBoundary() {
        let sequencer = VisualStepSequencer.shared

        // Test boundary values
        sequencer.bpm = 60  // Minimum
        XCTAssertEqual(sequencer.bpm, 60, accuracy: 0.001)

        sequencer.bpm = 180  // Maximum
        XCTAssertEqual(sequencer.bpm, 180, accuracy: 0.001)

        // Reset
        sequencer.bpm = 120
    }
}
