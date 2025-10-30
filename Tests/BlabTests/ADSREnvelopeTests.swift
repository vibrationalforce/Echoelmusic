import XCTest
@testable import Blab

/// Unit tests for ADSR Envelope Generator
/// Validates psychoacoustic curve accuracy and timing precision
final class ADSREnvelopeTests: XCTestCase {

    var envelope: ADSREnvelope!
    let sampleRate: Float = 48000.0

    override func setUp() {
        super.setUp()
        envelope = ADSREnvelope(sampleRate: sampleRate)
    }

    override func tearDown() {
        envelope = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDefaultValues() {
        XCTAssertEqual(envelope.attackTime, 0.01, accuracy: 0.001)
        XCTAssertEqual(envelope.decayTime, 0.1, accuracy: 0.001)
        XCTAssertEqual(envelope.sustainLevel, 0.7, accuracy: 0.01)
        XCTAssertEqual(envelope.releaseTime, 0.3, accuracy: 0.001)
        XCTAssertEqual(envelope.state, .idle)
        XCTAssertEqual(envelope.currentLevel, 0.0)
        XCTAssertFalse(envelope.isActive)
    }

    func testParameterClamping() {
        envelope.attackTime = -1.0
        XCTAssertGreaterThanOrEqual(envelope.attackTime, 0.001)

        envelope.attackTime = 100.0
        XCTAssertLessThanOrEqual(envelope.attackTime, 5.0)

        envelope.sustainLevel = -0.5
        XCTAssertGreaterThanOrEqual(envelope.sustainLevel, 0.0)

        envelope.sustainLevel = 1.5
        XCTAssertLessThanOrEqual(envelope.sustainLevel, 1.0)
    }

    // MARK: - State Transition Tests

    func testTrigger() {
        envelope.trigger()
        XCTAssertEqual(envelope.state, .attack)
        XCTAssertTrue(envelope.isActive)
    }

    func testRelease() {
        envelope.trigger()
        envelope.release()
        XCTAssertEqual(envelope.state, .release)
    }

    func testReset() {
        envelope.trigger()
        envelope.reset()
        XCTAssertEqual(envelope.state, .idle)
        XCTAssertEqual(envelope.currentLevel, 0.0)
        XCTAssertFalse(envelope.isActive)
    }

    // MARK: - Attack Phase Tests

    func testAttackPhase_Linear() {
        envelope.attackTime = 0.1  // 100ms = 4800 samples
        envelope.attackCurve = .linear
        envelope.trigger()

        // Check start
        let level0 = envelope.process()
        XCTAssertGreaterThan(level0, 0.0)
        XCTAssertLessThan(level0, 0.1)

        // Process half attack time
        for _ in 0..<2400 {
            _ = envelope.process()
        }
        XCTAssertEqual(envelope.state, .attack)
        XCTAssertEqual(envelope.currentLevel, 0.5, accuracy: 0.1)

        // Process rest of attack
        for _ in 0..<2400 {
            _ = envelope.process()
        }
        XCTAssertEqual(envelope.state, .decay)
        XCTAssertEqual(envelope.currentLevel, 1.0, accuracy: 0.01)
    }

    func testAttackPhase_Exponential() {
        envelope.attackTime = 0.1
        envelope.attackCurve = .exponential
        envelope.trigger()

        var samples: [Float] = []
        for _ in 0..<4800 {
            samples.append(envelope.process())
        }

        // Exponential should start slow and accelerate
        let firstQuarter = samples[0..<1200].reduce(0.0, +) / 1200.0
        let lastQuarter = samples[3600..<4800].reduce(0.0, +) / 1200.0

        XCTAssertLessThan(firstQuarter, 0.3, "Exponential attack should start slowly")
        XCTAssertGreaterThan(lastQuarter, 0.6, "Exponential attack should accelerate")
    }

    func testAttackPhase_SCurve() {
        envelope.attackTime = 0.1
        envelope.attackCurve = .sCurve
        envelope.trigger()

        var samples: [Float] = []
        for _ in 0..<4800 {
            samples.append(envelope.process())
        }

        // S-curve should have smooth acceleration and deceleration
        let firstQuarter = samples[1200]
        let middle = samples[2400]
        let lastQuarter = samples[3600]

        XCTAssertLessThan(firstQuarter, middle)
        XCTAssertLessThan(middle, lastQuarter)
        XCTAssertLessThan(lastQuarter, 1.0)
    }

    // MARK: - Decay Phase Tests

    func testDecayPhase() {
        envelope.attackTime = 0.01
        envelope.decayTime = 0.1
        envelope.sustainLevel = 0.5
        envelope.trigger()

        // Skip attack phase
        for _ in 0..<480 {
            _ = envelope.process()
        }
        XCTAssertEqual(envelope.state, .decay)

        // Process decay phase
        for _ in 0..<4800 {
            _ = envelope.process()
        }

        XCTAssertEqual(envelope.state, .sustain)
        XCTAssertEqual(envelope.currentLevel, 0.5, accuracy: 0.05)
    }

    // MARK: - Sustain Phase Tests

    func testSustainPhase() {
        envelope.attackTime = 0.01
        envelope.decayTime = 0.01
        envelope.sustainLevel = 0.7
        envelope.trigger()

        // Skip to sustain
        for _ in 0..<960 {
            _ = envelope.process()
        }
        XCTAssertEqual(envelope.state, .sustain)

        // Verify sustain holds constant
        for _ in 0..<1000 {
            let level = envelope.process()
            XCTAssertEqual(level, 0.7, accuracy: 0.01)
        }
    }

    // MARK: - Release Phase Tests

    func testReleasePhase_Linear() {
        envelope.attackTime = 0.01
        envelope.decayTime = 0.01
        envelope.sustainLevel = 0.8
        envelope.releaseTime = 0.1
        envelope.releaseCurve = .linear
        envelope.trigger()

        // Skip to sustain
        for _ in 0..<960 {
            _ = envelope.process()
        }
        XCTAssertEqual(envelope.state, .sustain)

        envelope.release()
        XCTAssertEqual(envelope.state, .release)

        // Process release
        for _ in 0..<4800 {
            _ = envelope.process()
        }

        XCTAssertEqual(envelope.state, .idle)
        XCTAssertEqual(envelope.currentLevel, 0.0, accuracy: 0.01)
    }

    func testReleasePhase_Logarithmic() {
        envelope.attackTime = 0.01
        envelope.decayTime = 0.01
        envelope.sustainLevel = 1.0
        envelope.releaseTime = 0.1
        envelope.releaseCurve = .logarithmic
        envelope.trigger()

        // Skip to sustain
        for _ in 0..<960 {
            _ = envelope.process()
        }

        envelope.release()
        var samples: [Float] = []
        for _ in 0..<4800 {
            samples.append(envelope.process())
        }

        // Logarithmic release should start fast and slow down
        let firstQuarter = samples[0]
        let lastQuarter = samples[3600]

        XCTAssertGreaterThan(firstQuarter, lastQuarter * 2, "Logarithmic release should decay quickly at first")
    }

    // MARK: - Preset Tests

    func testPreset_Percussive() {
        envelope.applyPreset(.percussive)

        XCTAssertEqual(envelope.attackTime, 0.005, accuracy: 0.001)
        XCTAssertEqual(envelope.decayTime, 0.1, accuracy: 0.001)
        XCTAssertEqual(envelope.sustainLevel, 0.0, accuracy: 0.01)
        XCTAssertEqual(envelope.releaseTime, 0.05, accuracy: 0.001)
    }

    func testPreset_Breath() {
        envelope.applyPreset(.breath)

        // Breath preset should match typical breathing cycle (3-5s)
        XCTAssertGreaterThan(envelope.attackTime, 2.0)
        XCTAssertGreaterThan(envelope.releaseTime, 3.0)
        XCTAssertEqual(envelope.attackCurve, .sCurve)
        XCTAssertEqual(envelope.releaseCurve, .sCurve)
    }

    func testAllPresets() {
        let presets: [ADSREnvelope.Preset] = [.instant, .percussive, .plucked, .bowed, .pad, .breath]

        for preset in presets {
            envelope.applyPreset(preset)
            XCTAssertGreaterThan(envelope.attackTime, 0.0)
            XCTAssertGreaterThan(envelope.decayTime, 0.0)
            XCTAssertGreaterThanOrEqual(envelope.sustainLevel, 0.0)
            XCTAssertLessThanOrEqual(envelope.sustainLevel, 1.0)
            XCTAssertGreaterThan(envelope.releaseTime, 0.0)
        }
    }

    // MARK: - Buffer Processing Tests

    func testProcessBuffer() {
        var buffer = [Float](repeating: 1.0, count: 1024)
        envelope.attackTime = 0.01
        envelope.decayTime = 0.01
        envelope.sustainLevel = 0.5
        envelope.trigger()

        buffer.withUnsafeMutableBufferPointer { ptr in
            envelope.processBuffer(ptr.baseAddress!, frameCount: 1024)
        }

        // All samples should be scaled by envelope
        XCTAssertGreaterThan(buffer[0], 0.0)
        XCTAssertLessThan(buffer[0], 1.0)
        XCTAssertGreaterThan(buffer[1023], 0.0)
    }

    // MARK: - Bio-feedback Integration Tests

    func testCoherenceModulation() {
        envelope.modulateWithCoherence(0.0)
        let lowAttack = envelope.attackTime
        let lowRelease = envelope.releaseTime

        envelope.modulateWithCoherence(100.0)
        let highAttack = envelope.attackTime
        let highRelease = envelope.releaseTime

        XCTAssertGreaterThan(highAttack, lowAttack, "High coherence should lengthen attack")
        XCTAssertGreaterThan(highRelease, lowRelease, "High coherence should lengthen release")
    }

    func testCoherenceModulation_CurveChange() {
        envelope.modulateWithCoherence(30.0)
        let lowCurve = envelope.attackCurve

        envelope.modulateWithCoherence(80.0)
        let highCurve = envelope.attackCurve

        // High coherence should prefer smooth curves
        XCTAssertEqual(highCurve, .sCurve)
    }

    func testBreathingSynchronization_Inhale() {
        envelope.syncWithBreathingPhase(0.2)  // Inhalation
        XCTAssertTrue(envelope.isActive)
        XCTAssertEqual(envelope.state, .attack)
    }

    func testBreathingSynchronization_Exhale() {
        envelope.trigger()
        // Skip to sustain
        for _ in 0..<2000 {
            _ = envelope.process()
        }

        envelope.syncWithBreathingPhase(0.7)  // Exhalation
        XCTAssertEqual(envelope.state, .release)
    }

    func testBreathingSynchronization_FullCycle() {
        // Start idle
        XCTAssertEqual(envelope.state, .idle)

        // Inhale triggers
        envelope.syncWithBreathingPhase(0.1)
        XCTAssertTrue(envelope.isActive)

        // Process to sustain
        for _ in 0..<5000 {
            _ = envelope.process()
        }

        // Exhale releases
        envelope.syncWithBreathingPhase(0.8)
        XCTAssertEqual(envelope.state, .release)
    }

    // MARK: - Curve Accuracy Tests

    func testExponentialCurve_MonotonicIncrease() {
        envelope.attackTime = 0.1
        envelope.attackCurve = .exponential
        envelope.trigger()

        var previousLevel: Float = 0.0
        for _ in 0..<4800 {
            let level = envelope.process()
            XCTAssertGreaterThanOrEqual(level, previousLevel, "Exponential curve must be monotonically increasing")
            previousLevel = level
        }
    }

    func testLogarithmicCurve_SmoothDecay() {
        envelope.attackTime = 0.01
        envelope.decayTime = 0.01
        envelope.sustainLevel = 1.0
        envelope.releaseTime = 0.1
        envelope.releaseCurve = .logarithmic
        envelope.trigger()

        // Skip to release
        for _ in 0..<960 {
            _ = envelope.process()
        }
        envelope.release()

        var previousLevel: Float = 1.0
        for _ in 0..<4800 {
            let level = envelope.process()
            XCTAssertLessThanOrEqual(level, previousLevel, "Logarithmic release must be monotonically decreasing")
            previousLevel = level
        }
    }

    // MARK: - Performance Tests

    func testEnvelopeProcessing_Performance() {
        envelope.applyPreset(.plucked)
        envelope.trigger()

        measure {
            for _ in 0..<48000 {  // 1 second @ 48kHz
                _ = envelope.process()
            }
        }
    }

    func testBufferProcessing_Performance() {
        var buffer = [Float](repeating: 1.0, count: 4096)
        envelope.applyPreset(.pad)
        envelope.trigger()

        measure {
            for _ in 0..<100 {
                buffer.withUnsafeMutableBufferPointer { ptr in
                    envelope.processBuffer(ptr.baseAddress!, frameCount: 4096)
                }
            }
        }
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        envelope.attackTime = 0.5
        envelope.decayTime = 0.3
        envelope.sustainLevel = 0.6
        envelope.releaseTime = 1.0
        envelope.attackCurve = .sCurve
        envelope.decayCurve = .exponential
        envelope.releaseCurve = .logarithmic

        let encoder = JSONEncoder()
        let data = try encoder.encode(envelope)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ADSREnvelope.self, from: data)

        XCTAssertEqual(decoded.attackTime, 0.5, accuracy: 0.001)
        XCTAssertEqual(decoded.decayTime, 0.3, accuracy: 0.001)
        XCTAssertEqual(decoded.sustainLevel, 0.6, accuracy: 0.01)
        XCTAssertEqual(decoded.releaseTime, 1.0, accuracy: 0.001)
        XCTAssertEqual(decoded.attackCurve, .sCurve)
        XCTAssertEqual(decoded.decayCurve, .exponential)
        XCTAssertEqual(decoded.releaseCurve, .logarithmic)
    }

    // MARK: - Edge Case Tests

    func testMinimumTimings() {
        envelope.attackTime = 0.001
        envelope.decayTime = 0.001
        envelope.releaseTime = 0.001
        envelope.trigger()

        var completed = false
        for _ in 0..<1000 {
            _ = envelope.process()
            if envelope.state == .idle && envelope.currentLevel == 0.0 {
                completed = true
                break
            }
        }

        XCTAssertTrue(completed, "Envelope with minimum timings should complete")
    }

    func testMaximumTimings() {
        envelope.attackTime = 5.0
        envelope.decayTime = 5.0
        envelope.releaseTime = 10.0
        envelope.trigger()

        // Should still be in attack after 1 second
        for _ in 0..<48000 {
            _ = envelope.process()
        }
        XCTAssertTrue(envelope.isActive)
    }

    func testZeroSustain() {
        envelope.sustainLevel = 0.0
        envelope.attackTime = 0.01
        envelope.decayTime = 0.01
        envelope.trigger()

        for _ in 0..<1000 {
            _ = envelope.process()
        }

        XCTAssertEqual(envelope.state, .sustain)
        XCTAssertEqual(envelope.currentLevel, 0.0, accuracy: 0.01)
    }

    func testReleaseFromAttack() {
        envelope.attackTime = 1.0
        envelope.trigger()

        // Release during attack
        for _ in 0..<1000 {
            _ = envelope.process()
        }
        envelope.release()

        XCTAssertEqual(envelope.state, .release)
        XCTAssertGreaterThan(envelope.currentLevel, 0.0)
    }
}
