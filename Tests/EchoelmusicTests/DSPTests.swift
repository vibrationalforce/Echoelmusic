#if canImport(AVFoundation)
// DSPTests.swift
// Echoelmusic — Phase 2 Test Coverage: DSP Engine Tests
//
// Tests for EchoelDDSP, CrossfadeCurve, and CrossfadeRegion.

import XCTest
@testable import Echoelmusic

// MARK: - EchoelDDSP Tests

final class EchoelDDSPTests: XCTestCase {

    func testInitialization() {
        let ddsp = EchoelDDSP(harmonicCount: 32, noiseBandCount: 33, sampleRate: 48000, frameSize: 256)
        XCTAssertEqual(ddsp.harmonicCount, 32)
        XCTAssertEqual(ddsp.noiseBandCount, 33)
        XCTAssertEqual(ddsp.sampleRate, 48000)
        XCTAssertEqual(ddsp.frameSize, 256)
    }

    func testDefaultParameters() {
        let ddsp = EchoelDDSP()
        XCTAssertEqual(ddsp.harmonicCount, 64)
        XCTAssertEqual(ddsp.frequency, 220.0)
        XCTAssertEqual(ddsp.harmonicLevel, 0.8, accuracy: 0.01)
        XCTAssertEqual(ddsp.harmonicity, 0.7, accuracy: 0.01)
        XCTAssertEqual(ddsp.noiseLevel, 0.3, accuracy: 0.01)
        XCTAssertEqual(ddsp.amplitude, 0.8, accuracy: 0.01)
    }

    func testHarmonicAmplitudesCount() {
        let ddsp = EchoelDDSP(harmonicCount: 16)
        XCTAssertEqual(ddsp.harmonicAmplitudes.count, 16)
    }

    func testNoiseMagnitudesCount() {
        let ddsp = EchoelDDSP(noiseBandCount: 33)
        XCTAssertEqual(ddsp.noiseMagnitudes.count, 33)
    }

    func testNoiseColorCases() {
        let cases = EchoelDDSP.NoiseColor.allCases
        XCTAssertEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.white))
        XCTAssertTrue(cases.contains(.pink))
        XCTAssertTrue(cases.contains(.brown))
        XCTAssertTrue(cases.contains(.blue))
        XCTAssertTrue(cases.contains(.violet))
    }

    func testSpectralShapeCases() {
        let cases = EchoelDDSP.SpectralShape.allCases
        XCTAssertEqual(cases.count, 8)
        XCTAssertTrue(cases.contains(.natural))
        XCTAssertTrue(cases.contains(.bright))
        XCTAssertTrue(cases.contains(.dark))
        XCTAssertTrue(cases.contains(.formant))
        XCTAssertTrue(cases.contains(.metallic))
        XCTAssertTrue(cases.contains(.hollow))
        XCTAssertTrue(cases.contains(.bell))
        XCTAssertTrue(cases.contains(.flat))
    }

    func testEnvelopeCurveCases() {
        let cases = EchoelDDSP.EnvelopeCurve.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.linear))
        XCTAssertTrue(cases.contains(.exponential))
        XCTAssertTrue(cases.contains(.logarithmic))
    }

    func testFrequencyRange() {
        let ddsp = EchoelDDSP()
        ddsp.frequency = 440.0
        XCTAssertEqual(ddsp.frequency, 440.0)

        ddsp.frequency = 20.0
        XCTAssertEqual(ddsp.frequency, 20.0)

        ddsp.frequency = 20000.0
        XCTAssertEqual(ddsp.frequency, 20000.0)
    }

    func testADSRParameters() {
        let ddsp = EchoelDDSP()
        ddsp.attack = 0.05
        ddsp.decay = 0.2
        ddsp.sustain = 0.6
        ddsp.release = 0.5

        XCTAssertEqual(ddsp.attack, 0.05, accuracy: 0.001)
        XCTAssertEqual(ddsp.decay, 0.2, accuracy: 0.001)
        XCTAssertEqual(ddsp.sustain, 0.6, accuracy: 0.001)
        XCTAssertEqual(ddsp.release, 0.5, accuracy: 0.001)
    }

    func testVibratoParameters() {
        let ddsp = EchoelDDSP()
        ddsp.vibratoRate = 5.5
        ddsp.vibratoDepth = 0.3

        XCTAssertEqual(ddsp.vibratoRate, 5.5, accuracy: 0.01)
        XCTAssertEqual(ddsp.vibratoDepth, 0.3, accuracy: 0.01)
    }

    func testSpectralMorphing() {
        let ddsp = EchoelDDSP()
        XCTAssertNil(ddsp.morphTarget)
        XCTAssertEqual(ddsp.morphPosition, 0)

        ddsp.morphTarget = .metallic
        ddsp.morphPosition = 0.5
        XCTAssertEqual(ddsp.morphTarget, .metallic)
        XCTAssertEqual(ddsp.morphPosition, 0.5, accuracy: 0.01)
    }

    func testTimbreTransfer() {
        let ddsp = EchoelDDSP()
        XCTAssertNil(ddsp.timbreProfile)
        XCTAssertEqual(ddsp.timbreBlend, 0)

        let profile: [Float] = Array(repeating: 0.5, count: 64)
        ddsp.timbreProfile = profile
        ddsp.timbreBlend = 0.7
        XCTAssertNotNil(ddsp.timbreProfile)
        XCTAssertEqual(ddsp.timbreBlend, 0.7, accuracy: 0.01)
    }

    func testReverbParameters() {
        let ddsp = EchoelDDSP()
        XCTAssertEqual(ddsp.reverbMix, 0.0, accuracy: 0.001)
        ddsp.reverbMix = 0.4
        ddsp.reverbDecay = 2.5
        XCTAssertEqual(ddsp.reverbMix, 0.4, accuracy: 0.01)
        XCTAssertEqual(ddsp.reverbDecay, 2.5, accuracy: 0.01)
    }
}

// MARK: - CrossfadeCurve Tests

final class DSPCrossfadeCurveTests: XCTestCase {

    func testAllCurvesAtBoundaries() {
        for curve in CrossfadeCurve.allCases {
            // At position 0: fadeIn = 0, fadeOut = 1
            XCTAssertEqual(curve.fadeInGain(at: 0), 0.0, accuracy: 0.001, "\(curve) fadeIn at 0")
            XCTAssertEqual(curve.fadeOutGain(at: 0), 1.0, accuracy: 0.001, "\(curve) fadeOut at 0")

            // At position 1: fadeIn = 1, fadeOut = 0
            XCTAssertEqual(curve.fadeInGain(at: 1), 1.0, accuracy: 0.001, "\(curve) fadeIn at 1")
            XCTAssertEqual(curve.fadeOutGain(at: 1), 0.0, accuracy: 0.001, "\(curve) fadeOut at 1")
        }
    }

    func testEqualPowerConstantEnergy() {
        let curve = CrossfadeCurve.equalPower
        // At midpoint, sum of squares should be ~1 (constant power)
        let fadeIn = curve.fadeInGain(at: 0.5)
        let fadeOut = curve.fadeOutGain(at: 0.5)
        let sumOfSquares = fadeIn * fadeIn + fadeOut * fadeOut
        XCTAssertEqual(sumOfSquares, 1.0, accuracy: 0.01)
    }

    func testLinearMidpoint() {
        let curve = CrossfadeCurve.linear
        XCTAssertEqual(curve.fadeInGain(at: 0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(curve.fadeOutGain(at: 0.5), 0.5, accuracy: 0.001)
    }

    func testSCurveSmoothMidpoint() {
        let curve = CrossfadeCurve.sCurve
        let mid = curve.fadeInGain(at: 0.5)
        XCTAssertEqual(mid, 0.5, accuracy: 0.001)
    }

    func testMonotonicity() {
        // Fade in should be monotonically increasing
        for curve in CrossfadeCurve.allCases {
            var prev: Float = -1
            for i in stride(from: 0.0, through: 1.0, by: 0.05) {
                let val = curve.fadeInGain(at: Float(i))
                XCTAssertGreaterThanOrEqual(val, prev - 0.001, "\(curve) fadeIn not monotonic at \(i)")
                prev = val
            }
        }
    }

    func testClampsBeyondRange() {
        let curve = CrossfadeCurve.linear
        // Positions outside [0, 1] should clamp
        XCTAssertEqual(curve.fadeInGain(at: -0.5), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.fadeInGain(at: 1.5), 1.0, accuracy: 0.001)
    }

    func testAllCasesCount() {
        XCTAssertEqual(CrossfadeCurve.allCases.count, 6)
    }

    func testCodable() throws {
        let original = CrossfadeCurve.equalPower
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CrossfadeCurve.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - CrossfadeRegion Tests

final class DSPCrossfadeRegionTests: XCTestCase {

    func testDuration() {
        let region = CrossfadeRegion(
            id: UUID(),
            startSample: 0,
            lengthInSamples: 48000,
            curve: .equalPower,
            isSymmetric: true
        )
        XCTAssertEqual(region.duration(sampleRate: 48000.0), 1.0, accuracy: 0.001)
        XCTAssertEqual(region.duration(sampleRate: 44100.0), 48000.0 / 44100.0, accuracy: 0.001)
    }
}
#endif
