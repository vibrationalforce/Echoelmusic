// EchoelDDSPTests.swift
// Tests for enhanced DDSP engine — vectorized synthesis, bio-reactive, morphing, timbre

import XCTest
@testable import Echoelmusic

final class EchoelDDSPTests: XCTestCase {

    // MARK: - Init & Configuration

    func testDDSPInit() {
        let ddsp = EchoelDDSP()
        XCTAssertEqual(ddsp.harmonicCount, 64)
        XCTAssertEqual(ddsp.noiseBandCount, 65)
        XCTAssertEqual(ddsp.sampleRate, 48000)
        XCTAssertEqual(ddsp.amplitude, 0)
        XCTAssertFalse(ddsp.isPlaying)
    }

    func testDDSPCustomInit() {
        let ddsp = EchoelDDSP(harmonicCount: 32, noiseBandCount: 33, sampleRate: 44100)
        XCTAssertEqual(ddsp.harmonicCount, 32)
        XCTAssertEqual(ddsp.noiseBandCount, 33)
        XCTAssertEqual(ddsp.sampleRate, 44100)
    }

    // MARK: - Note On/Off

    func testNoteOnSetsFrequencyAndPlaying() {
        let ddsp = EchoelDDSP()
        ddsp.noteOn(frequency: 440.0)

        XCTAssertEqual(ddsp.frequency, 440.0)
        XCTAssertTrue(ddsp.isPlaying)
        XCTAssertGreaterThan(ddsp.amplitude, 0)
    }

    func testNoteOffStopsPlaying() {
        let ddsp = EchoelDDSP()
        ddsp.noteOn(frequency: 440.0)
        ddsp.noteOff()

        // Note off triggers release, but doesn't immediately zero amplitude
        // isPlaying goes false
        XCTAssertFalse(ddsp.isPlaying)
    }

    // MARK: - Render

    func testRenderProducesAudio() {
        let ddsp = EchoelDDSP()
        ddsp.noteOn(frequency: 440.0)

        var buffer = [Float](repeating: 0, count: 256)
        ddsp.render(buffer: &buffer, frameCount: 256)

        // Buffer should contain non-zero samples
        let maxVal = buffer.max() ?? 0
        XCTAssertGreaterThan(maxVal, 0, "Render should produce non-zero audio")
    }

    func testRenderSilentWhenNoNote() {
        let ddsp = EchoelDDSP()
        var buffer = [Float](repeating: 0, count: 256)
        ddsp.render(buffer: &buffer, frameCount: 256)

        let maxVal = buffer.map { abs($0) }.max() ?? 0
        XCTAssertEqual(maxVal, 0, "Should be silent with no note playing")
    }

    func testRenderDoesNotClip() {
        let ddsp = EchoelDDSP()
        ddsp.noteOn(frequency: 440.0)
        ddsp.harmonicity = 1.0
        ddsp.brightness = 1.0

        var buffer = [Float](repeating: 0, count: 1024)
        ddsp.render(buffer: &buffer, frameCount: 1024)

        let maxAbs = buffer.map { abs($0) }.max() ?? 0
        XCTAssertLessThanOrEqual(maxAbs, 1.0, "Output should not clip above 1.0")
    }

    // MARK: - Spectral Shapes

    func testSpectralShapeChange() {
        let ddsp = EchoelDDSP()
        ddsp.noteOn(frequency: 220.0)

        // Render with default shape (sawtooth)
        var bufSaw = [Float](repeating: 0, count: 512)
        ddsp.render(buffer: &bufSaw, frameCount: 512)

        // Switch to square
        ddsp.spectralShape = .square
        var bufSquare = [Float](repeating: 0, count: 512)
        ddsp.render(buffer: &bufSquare, frameCount: 512)

        // The two renders should differ
        var different = false
        for i in 0..<512 {
            if abs(bufSaw[i] - bufSquare[i]) > 0.001 {
                different = true
                break
            }
        }
        XCTAssertTrue(different, "Different spectral shapes should produce different output")
    }

    // MARK: - Bio-Reactive

    func testBioReactiveMappings() {
        let ddsp = EchoelDDSP()

        // Apply bio-reactive with high coherence → high harmonicity
        ddsp.applyBioReactive(
            coherence: 0.9,
            hrvVariability: 0.3,
            heartRate: 0.5,
            breathPhase: 0.7,
            breathDepth: 0.6,
            lfHfRatio: 0.4,
            coherenceTrend: 0.2
        )

        XCTAssertGreaterThan(ddsp.harmonicity, 0.5, "High coherence should increase harmonicity")
    }

    func testBioReactiveLegacy() {
        let ddsp = EchoelDDSP()

        // Legacy 3-parameter call should still work
        ddsp.applyBioReactiveLegacy(coherence: 0.7, hrvVariability: 0.4, breathPhase: 0.6)

        XCTAssertGreaterThan(ddsp.harmonicity, 0, "Legacy API should still set harmonicity")
    }

    // MARK: - Spectral Morphing

    func testSpectralMorphing() {
        let ddsp = EchoelDDSP()
        ddsp.noteOn(frequency: 440.0)
        ddsp.spectralShape = .sawtooth

        ddsp.startMorph(to: .triangle)
        XCTAssertNotNil(ddsp.morphTarget)

        ddsp.setMorphPosition(0.5)
        XCTAssertEqual(ddsp.morphPosition, 0.5, accuracy: 0.01)

        var buffer = [Float](repeating: 0, count: 256)
        ddsp.render(buffer: &buffer, frameCount: 256)

        // Should produce audio (morph in progress)
        let maxVal = buffer.map { abs($0) }.max() ?? 0
        XCTAssertGreaterThan(maxVal, 0)
    }

    // MARK: - Timbre Transfer

    func testTimbreTransferLoad() {
        let ddsp = EchoelDDSP()

        let violin = InstrumentTimbre.instrumentProfile(.violin)
        ddsp.loadTimbreProfile(violin)

        XCTAssertNotNil(ddsp.timbreProfile)
        XCTAssertEqual(ddsp.timbreBlend, 1.0)
    }

    func testTimbreTransferClear() {
        let ddsp = EchoelDDSP()

        ddsp.loadTimbreProfile(InstrumentTimbre.instrumentProfile(.flute))
        ddsp.clearTimbreProfile()

        XCTAssertNil(ddsp.timbreProfile)
        XCTAssertEqual(ddsp.timbreBlend, 0)
    }

    func testTimbreTransferAffectsOutput() {
        let ddsp = EchoelDDSP()
        ddsp.noteOn(frequency: 440.0)

        // Render without timbre
        var bufClean = [Float](repeating: 0, count: 512)
        ddsp.render(buffer: &bufClean, frameCount: 512)

        // Apply trumpet timbre
        ddsp.loadTimbreProfile(InstrumentTimbre.instrumentProfile(.trumpet))

        var bufTimbre = [Float](repeating: 0, count: 512)
        ddsp.render(buffer: &bufTimbre, frameCount: 512)

        // Should differ
        var different = false
        for i in 0..<512 {
            if abs(bufClean[i] - bufTimbre[i]) > 0.001 {
                different = true
                break
            }
        }
        XCTAssertTrue(different, "Timbre transfer should alter output")
    }

    // MARK: - Envelope

    func testADSREnvelope() {
        let ddsp = EchoelDDSP()
        ddsp.attackTime = 0.001
        ddsp.decayTime = 0.1
        ddsp.sustainLevel = 0.5
        ddsp.releaseTime = 0.2

        ddsp.noteOn(frequency: 440.0)

        // Render through attack
        var buffer = [Float](repeating: 0, count: 256)
        ddsp.render(buffer: &buffer, frameCount: 256)

        // Should produce audio
        let maxVal = buffer.map { abs($0) }.max() ?? 0
        XCTAssertGreaterThan(maxVal, 0)
    }

    func testExponentialEnvelopeCurve() {
        let ddsp = EchoelDDSP()
        ddsp.envelopeCurve = .exponential

        ddsp.noteOn(frequency: 440.0)
        var buffer = [Float](repeating: 0, count: 256)
        ddsp.render(buffer: &buffer, frameCount: 256)

        let maxVal = buffer.map { abs($0) }.max() ?? 0
        XCTAssertGreaterThan(maxVal, 0, "Exponential envelope should still produce audio")
    }

    // MARK: - Instrument Profiles

    func testAllInstrumentProfiles() {
        let instruments: [InstrumentTimbre.Instrument] = [.violin, .flute, .trumpet, .cello, .clarinet, .oboe]

        for instrument in instruments {
            let profile = InstrumentTimbre.instrumentProfile(instrument)
            XCTAssertFalse(profile.harmonicAmplitudes.isEmpty,
                           "\(instrument) should have harmonic amplitudes")
            XCTAssertGreaterThan(profile.harmonicAmplitudes[0], 0,
                                "\(instrument) fundamental should be non-zero")
        }
    }

    // MARK: - Noise

    func testNoiseColors() {
        let ddsp = EchoelDDSP()
        ddsp.noteOn(frequency: 440.0)
        ddsp.harmonicity = 0.0 // Pure noise

        let colors: [EchoelDDSP.NoiseColor] = [.white, .pink, .brown, .blue, .violet]
        for color in colors {
            ddsp.noiseColor = color
            var buffer = [Float](repeating: 0, count: 256)
            ddsp.render(buffer: &buffer, frameCount: 256)

            let maxVal = buffer.map { abs($0) }.max() ?? 0
            XCTAssertGreaterThan(maxVal, 0, "\(color) noise should produce output")
        }
    }

    // MARK: - Reset

    func testReset() {
        let ddsp = EchoelDDSP()
        ddsp.noteOn(frequency: 440.0)
        ddsp.harmonicity = 0.8
        ddsp.brightness = 0.7

        ddsp.reset()
        XCTAssertFalse(ddsp.isPlaying)
        XCTAssertEqual(ddsp.amplitude, 0)
    }
}
