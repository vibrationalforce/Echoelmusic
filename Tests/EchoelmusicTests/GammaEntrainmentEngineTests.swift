// GammaEntrainmentEngineTests.swift
// Tests for GammaEntrainmentEngine — 40 Hz Gamma Entrainment

import XCTest
@testable import Echoelmusic

final class GammaEntrainmentEngineTests: XCTestCase {

    // MARK: - Init

    func testDefaultInit() {
        let engine = GammaEntrainmentEngine()
        XCTAssertEqual(engine.sampleRate, 48000)
        XCTAssertEqual(engine.gammaFrequency, 40.0)
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertFalse(engine.isActive)
    }

    func testCustomSampleRate() {
        let engine = GammaEntrainmentEngine(sampleRate: 44100)
        XCTAssertEqual(engine.sampleRate, 44100)
    }

    // MARK: - Session Lifecycle

    func testStartSession() {
        let engine = GammaEntrainmentEngine()
        engine.startSession()
        XCTAssertEqual(engine.phase, .rampUp)
        XCTAssertTrue(engine.isActive)
    }

    func testStopSessionTriggersRampDown() {
        let engine = GammaEntrainmentEngine()
        engine.startSession()

        // Render enough to enter entrainment phase
        var buffer = [Float](repeating: 0, count: 256)
        for _ in 0..<6000 { // 6000 * 256 / 48000 = ~32s (past 30s ramp)
            engine.renderMono(buffer: &buffer, frameCount: 256)
        }
        XCTAssertEqual(engine.phase, .entrainment)

        engine.stopSession()
        XCTAssertEqual(engine.phase, .rampDown)
    }

    func testReset() {
        let engine = GammaEntrainmentEngine()
        engine.startSession()
        engine.reset()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertFalse(engine.isActive)
    }

    // MARK: - Mono Rendering

    func testIdleRendersSilence() {
        let engine = GammaEntrainmentEngine()
        var buffer = [Float](repeating: 1.0, count: 256)
        engine.renderMono(buffer: &buffer, frameCount: 256)
        for val in buffer {
            XCTAssertEqual(val, 0, accuracy: 0.0001)
        }
    }

    func testRampUpProducesAudio() {
        let engine = GammaEntrainmentEngine()
        engine.startSession()

        var buffer = [Float](repeating: 0, count: 256)
        // Render a few blocks to get past zero-crossing
        for _ in 0..<10 {
            engine.renderMono(buffer: &buffer, frameCount: 256)
        }

        let hasAudio = buffer.contains { abs($0) > 0.001 }
        XCTAssertTrue(hasAudio, "Expected audio during ramp-up")
    }

    func testRenderNoNaNOrInf() {
        let engine = GammaEntrainmentEngine()
        engine.startSession()

        var buffer = [Float](repeating: 0, count: 512)
        for _ in 0..<100 {
            engine.renderMono(buffer: &buffer, frameCount: 512)
            for val in buffer {
                XCTAssertFalse(val.isNaN, "NaN in gamma output")
                XCTAssertFalse(val.isInfinite, "Inf in gamma output")
            }
        }
    }

    // MARK: - Stereo Rendering

    func testStereoIsochronicSameChannels() {
        let engine = GammaEntrainmentEngine()
        engine.mode = .isochronic
        engine.startSession()

        var left = [Float](repeating: 0, count: 256)
        var right = [Float](repeating: 0, count: 256)

        for _ in 0..<10 {
            engine.renderStereo(left: &left, right: &right, frameCount: 256)
        }

        // Isochronic: L and R should be identical
        for i in 0..<256 {
            XCTAssertEqual(left[i], right[i], accuracy: 0.0001)
        }
    }

    func testStereoBinauralDifferentChannels() {
        let engine = GammaEntrainmentEngine()
        engine.mode = .binaural
        engine.startSession()

        var left = [Float](repeating: 0, count: 256)
        var right = [Float](repeating: 0, count: 256)

        for _ in 0..<10 {
            engine.renderStereo(left: &left, right: &right, frameCount: 256)
        }

        // Binaural: L and R should differ (different frequencies)
        var hasDifference = false
        for i in 0..<256 {
            if abs(left[i] - right[i]) > 0.001 {
                hasDifference = true
                break
            }
        }
        XCTAssertTrue(hasDifference, "Binaural mode should have different L/R signals")
    }

    // MARK: - Bio-Reactive

    func testBioCoherenceAdaptsFrequency() {
        let engine = GammaEntrainmentEngine()

        engine.updateBio(coherence: 0.0)
        XCTAssertGreaterThanOrEqual(engine.gammaFrequency, 38.0)
        XCTAssertLessThanOrEqual(engine.gammaFrequency, 42.0)

        engine.updateBio(coherence: 1.0)
        XCTAssertGreaterThanOrEqual(engine.gammaFrequency, 38.0)
        XCTAssertLessThanOrEqual(engine.gammaFrequency, 42.0)
    }

    func testGammaStaysNarrowBand() {
        let engine = GammaEntrainmentEngine()
        // Test extreme coherence values
        for c in stride(from: Float(0), through: 1.0, by: 0.1) {
            engine.updateBio(coherence: c)
            XCTAssertGreaterThanOrEqual(engine.gammaFrequency, 38.0)
            XCTAssertLessThanOrEqual(engine.gammaFrequency, 42.0)
        }
    }

    // MARK: - Phase Transitions

    func testPhaseProgression() {
        let engine = GammaEntrainmentEngine()
        engine.rampDuration = 0.1  // 100ms ramp for fast testing
        engine.sessionDuration = 0.5  // 500ms total
        engine.startSession()

        XCTAssertEqual(engine.phase, .rampUp)

        var buffer = [Float](repeating: 0, count: 256)
        // Render through ramp-up (0.1s = 4800 samples = ~19 blocks of 256)
        for _ in 0..<25 {
            engine.renderMono(buffer: &buffer, frameCount: 256)
        }
        XCTAssertEqual(engine.phase, .entrainment)

        // Render through entrainment (0.3s = 14400 samples = ~56 blocks)
        for _ in 0..<60 {
            engine.renderMono(buffer: &buffer, frameCount: 256)
        }
        XCTAssertEqual(engine.phase, .rampDown)

        // Render through ramp-down
        for _ in 0..<25 {
            engine.renderMono(buffer: &buffer, frameCount: 256)
        }
        XCTAssertEqual(engine.phase, .complete)
        XCTAssertFalse(engine.isActive)
    }

    // MARK: - Progress

    func testProgressIncreases() {
        let engine = GammaEntrainmentEngine()
        engine.startSession()
        XCTAssertEqual(engine.progress, 0, accuracy: 0.01)

        var buffer = [Float](repeating: 0, count: 256)
        for _ in 0..<100 {
            engine.renderMono(buffer: &buffer, frameCount: 256)
        }
        XCTAssertGreaterThan(engine.progress, 0)
    }

    // MARK: - Modes

    func testAllModesRenderWithoutCrash() {
        for mode in GammaEntrainmentEngine.Mode.allCases {
            let engine = GammaEntrainmentEngine()
            engine.mode = mode
            engine.startSession()

            var left = [Float](repeating: 0, count: 256)
            var right = [Float](repeating: 0, count: 256)

            for _ in 0..<20 {
                engine.renderStereo(left: &left, right: &right, frameCount: 256)
            }
        }
    }
}
