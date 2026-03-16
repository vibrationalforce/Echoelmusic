#if canImport(AVFoundation)
// EchoelSeqEngineTests.swift
// Echoelmusic — Professional Audio Sequencer Tests
//
// Tests for AudioStep, AudioPattern, PatternTrack, ScaleType,
// EchoelSeqEngine transforms, Euclidean rhythms, and pattern chaining.
// Pure computation tests — no audio/timing required.

import XCTest
@testable import Echoelmusic

// MARK: - AudioStep Tests

final class AudioStepTests: XCTestCase {

    func testDefaults() {
        let step = AudioStep()
        XCTAssertFalse(step.isActive)
        XCTAssertEqual(step.velocity, 1.0)
        XCTAssertEqual(step.pitchOffset, 0)
        XCTAssertEqual(step.gateLength, 0.5)
        XCTAssertEqual(step.probability, 1.0)
        XCTAssertEqual(step.microTiming, 0.0)
    }

    func testConvenienceInit() {
        let step = AudioStep(active: true, velocity: 0.7)
        XCTAssertTrue(step.isActive)
        XCTAssertEqual(step.velocity, 0.7)
    }

    func testEquatable() {
        let a = AudioStep()
        let b = AudioStep()
        XCTAssertEqual(a, b)

        var c = AudioStep()
        c.isActive = true
        XCTAssertNotEqual(a, c)
    }

    func testCodable() {
        var step = AudioStep()
        step.isActive = true
        step.velocity = 0.8
        step.pitchOffset = -3
        step.gateLength = 0.75
        step.probability = 0.6
        step.microTiming = 0.1

        let data = try? JSONEncoder().encode(step)
        XCTAssertNotNil(data)

        if let data = data {
            let decoded = try? JSONDecoder().decode(AudioStep.self, from: data)
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded, step)
        }
    }
}

// MARK: - AudioPattern Tests

final class AudioPatternTests: XCTestCase {

    func testInit_defaultValues() {
        let pattern = AudioPattern(name: "Test", trackCount: 4, stepCount: 16)
        XCTAssertEqual(pattern.name, "Test")
        XCTAssertEqual(pattern.tracks.count, 4)
        XCTAssertEqual(pattern.stepCount, 16)
        XCTAssertEqual(pattern.swingAmount, 0.0)
        XCTAssertEqual(pattern.scaleRoot, 0)
        XCTAssertEqual(pattern.scaleType, .chromatic)
    }

    func testInit_allStepsInactive() {
        let pattern = AudioPattern(trackCount: 4, stepCount: 16)
        for track in 0..<4 {
            for step in 0..<16 {
                XCTAssertFalse(pattern.step(track: track, position: step).isActive)
            }
        }
    }

    func testStep_outOfBounds() {
        let pattern = AudioPattern(trackCount: 2, stepCount: 8)
        let step = pattern.step(track: 99, position: 0)
        XCTAssertFalse(step.isActive)

        let step2 = pattern.step(track: 0, position: 99)
        XCTAssertFalse(step2.isActive)
    }

    func testSetStep() {
        var pattern = AudioPattern(trackCount: 2, stepCount: 8)
        let step = AudioStep(active: true, velocity: 0.5)
        pattern.setStep(track: 0, position: 3, step: step)

        XCTAssertTrue(pattern.step(track: 0, position: 3).isActive)
        XCTAssertEqual(pattern.step(track: 0, position: 3).velocity, 0.5)
    }

    func testSetStep_outOfBounds() {
        var pattern = AudioPattern(trackCount: 2, stepCount: 8)
        let step = AudioStep(active: true)
        // Should not crash
        pattern.setStep(track: 99, position: 0, step: step)
        pattern.setStep(track: 0, position: 99, step: step)
    }

    func testToggleStep() {
        var pattern = AudioPattern(trackCount: 2, stepCount: 8)
        pattern.toggleStep(track: 0, position: 0)
        XCTAssertTrue(pattern.step(track: 0, position: 0).isActive)

        pattern.toggleStep(track: 0, position: 0)
        XCTAssertFalse(pattern.step(track: 0, position: 0).isActive)
    }

    func testToggleStep_outOfBounds() {
        var pattern = AudioPattern(trackCount: 2, stepCount: 8)
        // Should not crash
        pattern.toggleStep(track: 99, position: 0)
        pattern.toggleStep(track: 0, position: 99)
    }

    func testCodable() {
        var pattern = AudioPattern(name: "Encode", trackCount: 2, stepCount: 4)
        pattern.toggleStep(track: 0, position: 0)
        pattern.swingAmount = 0.3

        let data = try? JSONEncoder().encode(pattern)
        XCTAssertNotNil(data)

        if let data = data {
            let decoded = try? JSONDecoder().decode(AudioPattern.self, from: data)
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded?.name, "Encode")
            XCTAssertEqual(decoded?.tracks.count, 2)
            XCTAssertEqual(decoded?.stepCount, 4)
        }
    }
}

// MARK: - PatternTrack Tests

final class PatternTrackTests: XCTestCase {

    func testDefaults() {
        let track = PatternTrack(name: "Kick", steps: Array(repeating: AudioStep(), count: 16))
        XCTAssertEqual(track.name, "Kick")
        XCTAssertEqual(track.steps.count, 16)
        XCTAssertEqual(track.midiChannel, 0)
        XCTAssertEqual(track.midiNote, 36)
        XCTAssertFalse(track.isMuted)
        XCTAssertEqual(track.volume, 1.0)
        XCTAssertEqual(track.pan, 0.0)
        XCTAssertNil(track.polyrhythmLength)
    }

    func testEffectiveStepCount_default() {
        let track = PatternTrack(name: "Test", steps: Array(repeating: AudioStep(), count: 16))
        XCTAssertEqual(track.effectiveStepCount, 16)
    }

    func testEffectiveStepCount_polyrhythm() {
        var track = PatternTrack(name: "Test", steps: Array(repeating: AudioStep(), count: 16))
        track.polyrhythmLength = 12
        XCTAssertEqual(track.effectiveStepCount, 12)
    }
}

// MARK: - ScaleType Tests

final class ScaleTypeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(ScaleType.allCases.count, 12)
    }

    func testChromatic_intervals() {
        XCTAssertEqual(ScaleType.chromatic.intervals.count, 12)
    }

    func testMajor_intervals() {
        XCTAssertEqual(ScaleType.major.intervals, [0, 2, 4, 5, 7, 9, 11])
    }

    func testMinor_intervals() {
        XCTAssertEqual(ScaleType.minor.intervals, [0, 2, 3, 5, 7, 8, 10])
    }

    func testPentatonic_intervals() {
        XCTAssertEqual(ScaleType.pentatonic.intervals, [0, 2, 4, 7, 9])
    }

    func testQuantize_chromatic_noChange() {
        let note = 64 // E4
        let result = ScaleType.chromatic.quantize(note: note, root: 0)
        XCTAssertEqual(result, 64)
    }

    func testQuantize_cMajor_snapToScale() {
        // C# (61) should snap to C (60) or D (62)
        let result = ScaleType.major.quantize(note: 61, root: 60)
        XCTAssertTrue(result == 60 || result == 62, "C# should snap to C or D in C major")
    }

    func testQuantize_cMajor_inScale() {
        // E (64) is in C major scale
        let result = ScaleType.major.quantize(note: 64, root: 60)
        XCTAssertEqual(result, 64)
    }

    func testQuantize_differentRoot() {
        // G major: G A B C D E F#
        // Ab (68) should snap to G (67) or A (69)
        let result = ScaleType.major.quantize(note: 68, root: 67)
        XCTAssertTrue(result == 67 || result == 69, "Ab should snap to G or A in G major")
    }

    func testQuantize_octavePreserved() {
        // High C# should stay in same octave range
        let result = ScaleType.major.quantize(note: 97, root: 0)
        XCTAssertGreaterThanOrEqual(result, 84) // C6
        XCTAssertLessThanOrEqual(result, 108)   // C8
    }

    func testRawValues() {
        XCTAssertEqual(ScaleType.major.rawValue, "Major")
        XCTAssertEqual(ScaleType.blues.rawValue, "Blues")
        XCTAssertEqual(ScaleType.harmonicMinor.rawValue, "Harmonic Minor")
    }
}

// MARK: - PatternChain Tests

final class PatternChainTests: XCTestCase {

    func testDefaults() {
        let chain = PatternChain()
        XCTAssertTrue(chain.entries.isEmpty)
        XCTAssertTrue(chain.isLooping)
    }

    func testAddEntries() {
        var chain = PatternChain()
        let id1 = UUID()
        let id2 = UUID()
        chain.entries.append(PatternChain.ChainEntry(patternID: id1, repeatCount: 2))
        chain.entries.append(PatternChain.ChainEntry(patternID: id2, repeatCount: 4))

        XCTAssertEqual(chain.entries.count, 2)
        XCTAssertEqual(chain.entries[0].patternID, id1)
        XCTAssertEqual(chain.entries[0].repeatCount, 2)
        XCTAssertEqual(chain.entries[1].repeatCount, 4)
    }

    func testCodable() {
        var chain = PatternChain()
        chain.entries.append(PatternChain.ChainEntry(patternID: UUID()))
        chain.isLooping = false

        let data = try? JSONEncoder().encode(chain)
        XCTAssertNotNil(data)

        if let data = data {
            let decoded = try? JSONDecoder().decode(PatternChain.self, from: data)
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded?.entries.count, 1)
            XCTAssertFalse(decoded?.isLooping ?? true)
        }
    }
}

// MARK: - PatternTransform Tests

final class PatternTransformTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(PatternTransform.allCases.count, 10)
    }

    func testRawValues() {
        XCTAssertEqual(PatternTransform.rotateRight.rawValue, "Rotate →")
        XCTAssertEqual(PatternTransform.euclidean.rawValue, "Euclidean")
        XCTAssertEqual(PatternTransform.humanize.rawValue, "Humanize")
    }
}

// MARK: - Euclidean Rhythm Tests

@MainActor
final class EuclideanRhythmTests: XCTestCase {

    func testEuclidean_4of16() {
        let engine = EchoelSeqEngine.shared
        let steps = engine.generateEuclidean(steps: 16, pulses: 4)
        XCTAssertEqual(steps.count, 16)

        let activeCount = steps.filter { $0.isActive }.count
        XCTAssertEqual(activeCount, 4)
    }

    func testEuclidean_8of16() {
        let engine = EchoelSeqEngine.shared
        let steps = engine.generateEuclidean(steps: 16, pulses: 8)
        let activeCount = steps.filter { $0.isActive }.count
        XCTAssertEqual(activeCount, 8)
    }

    func testEuclidean_3of8() {
        let engine = EchoelSeqEngine.shared
        let steps = engine.generateEuclidean(steps: 8, pulses: 3)
        XCTAssertEqual(steps.count, 8)
        XCTAssertEqual(steps.filter { $0.isActive }.count, 3)
    }

    func testEuclidean_5of8_tresillo() {
        // E(5,8) = [x.xx.xx.] — classic tresillo rhythm
        let engine = EchoelSeqEngine.shared
        let steps = engine.generateEuclidean(steps: 8, pulses: 5)
        XCTAssertEqual(steps.count, 8)
        XCTAssertEqual(steps.filter { $0.isActive }.count, 5)
    }

    func testEuclidean_allPulses() {
        let engine = EchoelSeqEngine.shared
        let steps = engine.generateEuclidean(steps: 8, pulses: 8)
        XCTAssertEqual(steps.count, 8)
        XCTAssertEqual(steps.filter { $0.isActive }.count, 8)
    }

    func testEuclidean_zeroPulses() {
        let engine = EchoelSeqEngine.shared
        let steps = engine.generateEuclidean(steps: 8, pulses: 0)
        // Min 1 pulse
        XCTAssertEqual(steps.count, 8)
    }

    func testEuclidean_emptySteps() {
        let engine = EchoelSeqEngine.shared
        let steps = engine.generateEuclidean(steps: 0, pulses: 0)
        XCTAssertTrue(steps.isEmpty)
    }

    func testEuclidean_velocityVariation() {
        let engine = EchoelSeqEngine.shared
        let steps = engine.generateEuclidean(steps: 16, pulses: 4)
        for step in steps where step.isActive {
            XCTAssertGreaterThanOrEqual(step.velocity, 0.7)
            XCTAssertLessThanOrEqual(step.velocity, 1.0)
        }
    }
}

// MARK: - EchoelSeqEngine State Tests

@MainActor
final class EchoelSeqEngineTests: XCTestCase {

    func testSharedInstance() {
        let engine = EchoelSeqEngine.shared
        XCTAssertNotNil(engine)
        XCTAssertTrue(engine === EchoelSeqEngine.shared)
    }

    func testInitialState() {
        let engine = EchoelSeqEngine.shared
        engine.stop()
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(engine.currentStep, 0)
        XCTAssertEqual(engine.bpm, 120.0)
    }

    func testDefaultPatterns() {
        let engine = EchoelSeqEngine.shared
        XCTAssertGreaterThanOrEqual(engine.patterns.count, 2)
        XCTAssertEqual(engine.patterns[0].name, "Kick & Snare")
        XCTAssertEqual(engine.patterns[1].name, "Ambient")
    }

    func testDefaultPattern_kickOnFloor() {
        let engine = EchoelSeqEngine.shared
        let kick = engine.patterns[0]
        XCTAssertTrue(kick.step(track: 0, position: 0).isActive)
        XCTAssertTrue(kick.step(track: 0, position: 4).isActive)
        XCTAssertTrue(kick.step(track: 0, position: 8).isActive)
        XCTAssertTrue(kick.step(track: 0, position: 12).isActive)
    }

    func testStop_resetsState() {
        let engine = EchoelSeqEngine.shared
        engine.play()
        engine.stop()
        XCTAssertEqual(engine.currentStep, 0)
        XCTAssertEqual(engine.chainPosition, 0)
        XCTAssertFalse(engine.isPlaying)
    }

    func testPause_preservesStep() {
        let engine = EchoelSeqEngine.shared
        engine.play()
        engine.pause()
        XCTAssertFalse(engine.isPlaying)
    }

    func testBioState_update() {
        let engine = EchoelSeqEngine.shared
        engine.updateBioState(coherence: 0.9, hrv: 0.7, heartRate: 80, breathPhase: 0.5)
        XCTAssertEqual(engine.bioCoherence, 0.9)
        XCTAssertEqual(engine.bioHRV, 0.7)
        XCTAssertEqual(engine.bioHeartRate, 80)
        XCTAssertEqual(engine.bioBreathPhase, 0.5)
    }

    func testAddPattern() {
        let engine = EchoelSeqEngine.shared
        let countBefore = engine.patterns.count
        engine.addPattern(name: "Test", trackCount: 2, stepCount: 8)
        XCTAssertEqual(engine.patterns.count, countBefore + 1)
        XCTAssertEqual(engine.patterns.last?.name, "Test")
        XCTAssertEqual(engine.patterns.last?.tracks.count, 2)
        XCTAssertEqual(engine.patterns.last?.stepCount, 8)

        // Cleanup
        engine.removePattern(at: engine.patterns.count - 1)
    }

    func testDuplicatePattern() {
        let engine = EchoelSeqEngine.shared
        let countBefore = engine.patterns.count
        engine.activePatternIndex = 0
        engine.duplicateActivePattern()
        XCTAssertEqual(engine.patterns.count, countBefore + 1)
        XCTAssertTrue(engine.patterns.last?.name.contains("Copy") ?? false)

        // Cleanup
        engine.removePattern(at: engine.patterns.count - 1)
    }

    func testRemovePattern_cantRemoveLast() {
        let engine = EchoelSeqEngine.shared
        // Remove all but one
        while engine.patterns.count > 1 {
            engine.removePattern(at: engine.patterns.count - 1)
        }
        let countBefore = engine.patterns.count
        engine.removePattern(at: 0) // Should NOT remove — would leave 0 patterns
        XCTAssertEqual(engine.patterns.count, countBefore)

        // Restore defaults
        engine.addPattern(name: "Ambient", trackCount: 4, stepCount: 32)
    }
}

// MARK: - Transform Tests

@MainActor
final class PatternTransformEngineTests: XCTestCase {

    private func makeEngineWithTestPattern() -> (EchoelSeqEngine, Int) {
        let engine = EchoelSeqEngine.shared
        engine.addPattern(name: "Transform Test", trackCount: 1, stepCount: 8)
        let idx = engine.patterns.count - 1
        engine.activePatternIndex = idx

        // Set up: steps 0, 2, 4 active
        engine.patterns[idx].tracks[0].steps[0] = AudioStep(active: true)
        engine.patterns[idx].tracks[0].steps[2] = AudioStep(active: true)
        engine.patterns[idx].tracks[0].steps[4] = AudioStep(active: true)
        return (engine, idx)
    }

    func testRotateRight() {
        let (engine, idx) = makeEngineWithTestPattern()
        defer { engine.removePattern(at: idx) }

        engine.applyTransform(.rotateRight, trackIndex: 0)

        // Last step (7, was inactive) moves to 0
        // Original step 0 (active) moves to 1
        XCTAssertTrue(engine.patterns[idx].step(track: 0, position: 1).isActive)
    }

    func testRotateLeft() {
        let (engine, idx) = makeEngineWithTestPattern()
        defer { engine.removePattern(at: idx) }

        engine.applyTransform(.rotateLeft, trackIndex: 0)

        // Original step 0 (active) moves to last
        XCTAssertTrue(engine.patterns[idx].step(track: 0, position: 7).isActive)
    }

    func testReverse() {
        let (engine, idx) = makeEngineWithTestPattern()
        defer { engine.removePattern(at: idx) }

        engine.applyTransform(.reverse, trackIndex: 0)

        // Steps 0,2,4 active → reversed: 7,5,3 active
        XCTAssertTrue(engine.patterns[idx].step(track: 0, position: 7).isActive)
        XCTAssertTrue(engine.patterns[idx].step(track: 0, position: 5).isActive)
        XCTAssertTrue(engine.patterns[idx].step(track: 0, position: 3).isActive)
    }

    func testInvert() {
        let (engine, idx) = makeEngineWithTestPattern()
        defer { engine.removePattern(at: idx) }

        engine.applyTransform(.invert, trackIndex: 0)

        // Originally 0,2,4 active → now inactive
        XCTAssertFalse(engine.patterns[idx].step(track: 0, position: 0).isActive)
        XCTAssertFalse(engine.patterns[idx].step(track: 0, position: 2).isActive)
        XCTAssertFalse(engine.patterns[idx].step(track: 0, position: 4).isActive)

        // Originally 1,3,5,6,7 inactive → now active
        XCTAssertTrue(engine.patterns[idx].step(track: 0, position: 1).isActive)
        XCTAssertTrue(engine.patterns[idx].step(track: 0, position: 3).isActive)
    }

    func testClearAll() {
        let (engine, idx) = makeEngineWithTestPattern()
        defer { engine.removePattern(at: idx) }

        engine.applyTransform(.clearAll, trackIndex: 0)

        for step in 0..<8 {
            XCTAssertFalse(engine.patterns[idx].step(track: 0, position: step).isActive)
        }
    }

    func testEuclideanTransform() {
        let (engine, idx) = makeEngineWithTestPattern()
        defer { engine.removePattern(at: idx) }

        engine.applyTransform(.euclidean, trackIndex: 0, parameter: 3)

        let activeCount = engine.patterns[idx].tracks[0].steps.filter { $0.isActive }.count
        XCTAssertEqual(activeCount, 3)
    }

    func testTransform_outOfBoundsTrack() {
        let engine = EchoelSeqEngine.shared
        // Should not crash
        engine.applyTransform(.reverse, trackIndex: 999)
    }
}

// MARK: - StepTrigger Tests

final class StepTriggerTests: XCTestCase {

    func testTriggerValues() {
        let trigger = StepTrigger(
            trackIndex: 0,
            step: 4,
            midiNote: 60,
            midiChannel: 0,
            velocity: 0.8,
            gateLength: 0.5,
            microTiming: 0.0,
            pan: -0.5
        )
        XCTAssertEqual(trigger.trackIndex, 0)
        XCTAssertEqual(trigger.step, 4)
        XCTAssertEqual(trigger.midiNote, 60)
        XCTAssertEqual(trigger.velocity, 0.8)
        XCTAssertEqual(trigger.pan, -0.5)
    }
}

#endif // canImport(AVFoundation)
