#if canImport(SwiftUI)
// SequencerTests.swift
// Echoelmusic — Visual Step Sequencer Tests
//
// Tests for SequencerPattern, BioModulationState, SequencerPreset,
// and VisualStepSequencer core logic.
// Pure computation tests — no audio/timing required.

import XCTest
@testable import Echoelmusic

// MARK: - SequencerPattern Tests

final class SequencerPatternTests: XCTestCase {

    func testInit_allStepsInactive() {
        let pattern = SequencerPattern()
        for channel in VisualStepSequencer.Channel.allCases {
            for step in 0..<VisualStepSequencer.stepCount {
                XCTAssertFalse(pattern.isActive(channel: channel, step: step))
            }
        }
    }

    func testInit_defaultVelocity() {
        let pattern = SequencerPattern()
        for channel in VisualStepSequencer.Channel.allCases {
            for step in 0..<VisualStepSequencer.stepCount {
                XCTAssertEqual(pattern.velocity(channel: channel, step: step), 1.0)
            }
        }
    }

    func testToggle_activatesStep() {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        XCTAssertTrue(pattern.isActive(channel: .visual1, step: 0))
    }

    func testToggle_deactivatesStep() {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        pattern.toggle(channel: .visual1, step: 0)
        XCTAssertFalse(pattern.isActive(channel: .visual1, step: 0))
    }

    func testToggle_independentChannels() {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        pattern.toggle(channel: .lighting, step: 0)
        XCTAssertTrue(pattern.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(pattern.isActive(channel: .lighting, step: 0))
        XCTAssertFalse(pattern.isActive(channel: .visual2, step: 0))
    }

    func testToggle_outOfBounds() {
        var pattern = SequencerPattern()
        // Should not crash
        pattern.toggle(channel: .visual1, step: 99)
        XCTAssertFalse(pattern.isActive(channel: .visual1, step: 99))
    }

    func testSetVelocity() {
        var pattern = SequencerPattern()
        pattern.setVelocity(channel: .visual1, step: 0, velocity: 0.5)
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 0.5)
    }

    func testSetVelocity_clampsToRange() {
        var pattern = SequencerPattern()
        pattern.setVelocity(channel: .visual1, step: 0, velocity: 2.0)
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 0), 1.0)

        pattern.setVelocity(channel: .visual1, step: 1, velocity: -0.5)
        XCTAssertEqual(pattern.velocity(channel: .visual1, step: 1), 0.0)
    }

    func testSetVelocity_outOfBounds() {
        var pattern = SequencerPattern()
        // Should not crash
        pattern.setVelocity(channel: .visual1, step: 99, velocity: 0.5)
    }

    func testClearChannel() {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        pattern.toggle(channel: .visual1, step: 4)
        pattern.toggle(channel: .visual1, step: 8)
        pattern.setVelocity(channel: .visual1, step: 4, velocity: 0.3)

        pattern.clearChannel(.visual1)

        for step in 0..<VisualStepSequencer.stepCount {
            XCTAssertFalse(pattern.isActive(channel: .visual1, step: step))
            XCTAssertEqual(pattern.velocity(channel: .visual1, step: step), 1.0)
        }
    }

    func testClearChannel_doesNotAffectOthers() {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        pattern.toggle(channel: .visual2, step: 0)

        pattern.clearChannel(.visual1)

        XCTAssertFalse(pattern.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(pattern.isActive(channel: .visual2, step: 0))
    }

    func testCodable_roundTrip() {
        var pattern = SequencerPattern()
        pattern.toggle(channel: .visual1, step: 0)
        pattern.toggle(channel: .lighting, step: 8)
        pattern.setVelocity(channel: .visual1, step: 0, velocity: 0.7)

        let data = try? JSONEncoder().encode(pattern)
        XCTAssertNotNil(data)

        if let data = data {
            let decoded = try? JSONDecoder().decode(SequencerPattern.self, from: data)
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded, pattern)
        }
    }

    func testEquatable() {
        let p1 = SequencerPattern()
        let p2 = SequencerPattern()
        XCTAssertEqual(p1, p2)

        var p3 = SequencerPattern()
        p3.toggle(channel: .visual1, step: 0)
        XCTAssertNotEqual(p1, p3)
    }
}

// MARK: - Channel Tests

final class SequencerChannelTests: XCTestCase {

    func testAllCases_count() {
        XCTAssertEqual(VisualStepSequencer.Channel.allCases.count, 8)
    }

    func testChannel_names() {
        XCTAssertEqual(VisualStepSequencer.Channel.visual1.name, "Visual A")
        XCTAssertEqual(VisualStepSequencer.Channel.lighting.name, "Lighting")
        XCTAssertEqual(VisualStepSequencer.Channel.bioTrigger.name, "Bio Trigger")
    }

    func testChannel_rawValues() {
        XCTAssertEqual(VisualStepSequencer.Channel.visual1.rawValue, 0)
        XCTAssertEqual(VisualStepSequencer.Channel.bioTrigger.rawValue, 7)
    }

    func testChannel_identifiable() {
        for channel in VisualStepSequencer.Channel.allCases {
            XCTAssertEqual(channel.id, channel.rawValue)
        }
    }
}

// MARK: - BioModulationState Tests

final class BioModulationStateTests: XCTestCase {

    func testDefaults() {
        let state = BioModulationState()
        XCTAssertEqual(state.coherence, 0.5)
        XCTAssertEqual(state.heartRate, 70.0)
        XCTAssertEqual(state.hrvVariability, 0.5)
        XCTAssertEqual(state.skipProbability, 0.0)
        XCTAssertFalse(state.tempoLockEnabled)
    }

    func testMutation() {
        var state = BioModulationState()
        state.coherence = 0.9
        state.heartRate = 120.0
        state.tempoLockEnabled = true
        XCTAssertEqual(state.coherence, 0.9)
        XCTAssertEqual(state.heartRate, 120.0)
        XCTAssertTrue(state.tempoLockEnabled)
    }
}

// MARK: - SequencerPreset Tests

final class SequencerPresetTests: XCTestCase {

    func testFourOnFloor() {
        let preset = SequencerPreset.fourOnFloor
        XCTAssertEqual(preset.id, "four_on_floor")
        XCTAssertEqual(preset.bpm, 120)
        // Steps 0, 4, 8, 12 should be active on visual1
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 4))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 8))
        XCTAssertTrue(preset.pattern.isActive(channel: .visual1, step: 12))
        // Other steps should be inactive
        XCTAssertFalse(preset.pattern.isActive(channel: .visual1, step: 1))
        XCTAssertFalse(preset.pattern.isActive(channel: .visual1, step: 7))
    }

    func testPresetsArray() {
        let presets = VisualStepSequencer.presets
        XCTAssertEqual(presets.count, 5)
    }

    func testPresetIDs_unique() {
        let presets = VisualStepSequencer.presets
        let ids = Set(presets.map { $0.id })
        XCTAssertEqual(ids.count, presets.count, "All preset IDs must be unique")
    }
}

// MARK: - Constants Tests

final class SequencerConstantsTests: XCTestCase {

    func testStepCount() {
        XCTAssertEqual(VisualStepSequencer.stepCount, 16)
    }

    func testBPMRange() {
        XCTAssertEqual(VisualStepSequencer.bpmRange, 60...180)
    }

    func testChannelCount() {
        XCTAssertEqual(VisualStepSequencer.channelCount, 8)
        XCTAssertEqual(VisualStepSequencer.channelCount, VisualStepSequencer.Channel.allCases.count)
    }
}

// MARK: - VisualStepSequencer State Tests

@MainActor
final class VisualStepSequencerTests: XCTestCase {

    func testSharedInstance() {
        let seq = VisualStepSequencer.shared
        XCTAssertNotNil(seq)
        XCTAssertTrue(seq === VisualStepSequencer.shared)
    }

    func testInitialState() {
        let seq = VisualStepSequencer.shared
        // Reset state for test
        seq.stop()
        seq.clearAll()
        XCTAssertFalse(seq.isPlaying)
        XCTAssertEqual(seq.currentStep, 0)
    }

    func testToggleStep() {
        let seq = VisualStepSequencer.shared
        seq.clearAll()
        seq.toggleStep(channel: .visual1, step: 5)
        XCTAssertTrue(seq.pattern.isActive(channel: .visual1, step: 5))
    }

    func testClearAll() {
        let seq = VisualStepSequencer.shared
        seq.toggleStep(channel: .visual1, step: 0)
        seq.toggleStep(channel: .lighting, step: 4)
        seq.clearAll()

        for channel in VisualStepSequencer.Channel.allCases {
            for step in 0..<VisualStepSequencer.stepCount {
                XCTAssertFalse(seq.pattern.isActive(channel: channel, step: step))
            }
        }
    }

    func testLoadPreset() {
        let seq = VisualStepSequencer.shared
        let preset = SequencerPreset.fourOnFloor
        seq.loadPreset(preset)

        XCTAssertEqual(seq.bpm, 120)
        XCTAssertTrue(seq.pattern.isActive(channel: .visual1, step: 0))
        XCTAssertTrue(seq.pattern.isActive(channel: .visual1, step: 4))
    }

    func testUpdateBioState() {
        let seq = VisualStepSequencer.shared
        seq.updateBioState(coherence: 0.9, heartRate: 80.0, hrvVariability: 0.8)

        XCTAssertEqual(seq.bioModulation.coherence, 0.9)
        XCTAssertEqual(seq.bioModulation.heartRate, 80.0)
        XCTAssertEqual(seq.bioModulation.hrvVariability, 0.8)
    }

    func testUpdateBioState_skipProbability() {
        let seq = VisualStepSequencer.shared
        // High HRV variability → low skip probability
        seq.updateBioState(coherence: 0.5, heartRate: 70.0, hrvVariability: 1.0)
        XCTAssertEqual(seq.bioModulation.skipProbability, 0.0, accuracy: 0.001)

        // Low HRV variability → higher skip probability
        seq.updateBioState(coherence: 0.5, heartRate: 70.0, hrvVariability: 0.0)
        XCTAssertEqual(seq.bioModulation.skipProbability, 0.3, accuracy: 0.001)
    }

    func testStop_resetsStep() {
        let seq = VisualStepSequencer.shared
        seq.play()
        seq.stop()
        XCTAssertEqual(seq.currentStep, 0)
        XCTAssertFalse(seq.isPlaying)
    }

    func testPause_preservesStep() {
        let seq = VisualStepSequencer.shared
        seq.play()
        seq.pause()
        XCTAssertFalse(seq.isPlaying)
        // Step is preserved (not reset to 0)
    }
}
#endif
