import XCTest
@testable import Blab

/// Unit tests for Wavetable Oscillator
/// Validates band-limiting, interpolation accuracy, and wavetable morphing
final class WavetableOscillatorTests: XCTestCase {

    var oscillator: WavetableOscillator!
    let sampleRate: Float = 48000.0

    override func setUp() {
        super.setUp()
        oscillator = WavetableOscillator(frequency: 440.0, sampleRate: sampleRate)
    }

    override func tearDown() {
        oscillator = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDefaultValues() {
        XCTAssertEqual(oscillator.waveform, .sine)
        XCTAssertEqual(oscillator.frequency, 440.0, accuracy: 0.1)
        XCTAssertEqual(oscillator.amplitude, 1.0, accuracy: 0.01)
        XCTAssertEqual(oscillator.interpolation, .hermite)
    }

    func testParameterClamping() {
        oscillator.frequency = -100.0
        XCTAssertGreaterThanOrEqual(oscillator.frequency, 20.0)

        oscillator.frequency = 30000.0
        XCTAssertLessThanOrEqual(oscillator.frequency, 20000.0)

        oscillator.amplitude = -0.5
        XCTAssertGreaterThanOrEqual(oscillator.amplitude, 0.0)

        oscillator.amplitude = 2.0
        XCTAssertLessThanOrEqual(oscillator.amplitude, 1.0)
    }

    // MARK: - Waveform Generation Tests

    func testSineWaveform() {
        oscillator.waveform = .sine
        oscillator.frequency = 1000.0
        oscillator.interpolation = .hermite

        var samples: [Float] = []
        for _ in 0..<4800 { // 100ms @ 48kHz
            samples.append(oscillator.process())
        }

        // Sine wave should be periodic
        XCTAssertTrue(samples.contains(where: { $0 > 0.9 }))
        XCTAssertTrue(samples.contains(where: { $0 < -0.9 }))

        // Check zero crossings (should have approximately 100 zero crossings in 100ms at 1000 Hz)
        var zeroCrossings = 0
        for i in 1..<samples.count {
            if (samples[i-1] < 0 && samples[i] >= 0) || (samples[i-1] >= 0 && samples[i] < 0) {
                zeroCrossings += 1
            }
        }
        XCTAssertGreaterThan(zeroCrossings, 180, "Should have ~200 zero crossings")
        XCTAssertLessThan(zeroCrossings, 220)
    }

    func testTriangleWaveform() {
        oscillator.waveform = .triangle
        oscillator.frequency = 440.0

        var samples: [Float] = []
        for _ in 0..<480 {
            samples.append(oscillator.process())
        }

        // Triangle should have peaks and valleys
        XCTAssertTrue(samples.contains(where: { $0 > 0.5 }))
        XCTAssertTrue(samples.contains(where: { $0 < -0.5 }))
    }

    func testSawtoothWaveform() {
        oscillator.waveform = .sawtooth
        oscillator.frequency = 440.0

        var samples: [Float] = []
        for _ in 0..<480 {
            samples.append(oscillator.process())
        }

        // Sawtooth should have full range
        XCTAssertTrue(samples.contains(where: { $0 > 0.3 }))
        XCTAssertTrue(samples.contains(where: { $0 < -0.3 }))
    }

    func testSquareWaveform() {
        oscillator.waveform = .square
        oscillator.frequency = 440.0

        var samples: [Float] = []
        for _ in 0..<480 {
            samples.append(oscillator.process())
        }

        // Square should have distinct positive and negative regions
        XCTAssertTrue(samples.contains(where: { $0 > 0.3 }))
        XCTAssertTrue(samples.contains(where: { $0 < -0.3 }))
    }

    func testPulseWaveforms() {
        let pulseWaveforms: [WavetableOscillator.Waveform] = [.pulse25, .pulse10]

        for waveform in pulseWaveforms {
            oscillator.waveform = waveform
            oscillator.frequency = 440.0

            var samples: [Float] = []
            for _ in 0..<480 {
                samples.append(oscillator.process())
            }

            XCTAssertTrue(samples.contains(where: { $0 != 0.0 }), "\(waveform) should produce non-zero output")
        }
    }

    func testHarmonicWaveforms() {
        let harmonicWaveforms: [WavetableOscillator.Waveform] = [
            .harmonicSeries, .evenHarmonics, .oddHarmonics, .formant
        ]

        for waveform in harmonicWaveforms {
            oscillator.waveform = waveform
            oscillator.frequency = 440.0

            var samples: [Float] = []
            for _ in 0..<480 {
                samples.append(oscillator.process())
            }

            XCTAssertTrue(samples.contains(where: { abs($0) > 0.1 }), "\(waveform) should produce significant output")
        }
    }

    // MARK: - Interpolation Tests

    func testNoInterpolation() {
        oscillator.waveform = .sine
        oscillator.frequency = 440.0
        oscillator.interpolation = .none

        let sample = oscillator.process()
        XCTAssertTrue(abs(sample) <= 1.0)
    }

    func testLinearInterpolation() {
        oscillator.waveform = .sine
        oscillator.frequency = 440.0
        oscillator.interpolation = .linear

        var samples: [Float] = []
        for _ in 0..<100 {
            samples.append(oscillator.process())
        }

        // Linear interpolation should produce smooth output
        var maxDelta: Float = 0.0
        for i in 1..<samples.count {
            maxDelta = max(maxDelta, abs(samples[i] - samples[i-1]))
        }

        XCTAssertLessThan(maxDelta, 0.5, "Linear interpolation should be smooth")
    }

    func testHermiteInterpolation() {
        oscillator.waveform = .sine
        oscillator.frequency = 440.0
        oscillator.interpolation = .hermite

        var samples: [Float] = []
        for _ in 0..<100 {
            samples.append(oscillator.process())
        }

        // Hermite should be smoother than linear
        var maxDelta: Float = 0.0
        for i in 1..<samples.count {
            maxDelta = max(maxDelta, abs(samples[i] - samples[i-1]))
        }

        XCTAssertLessThan(maxDelta, 0.3, "Hermite interpolation should be very smooth")
    }

    func testLagrangeInterpolation() {
        oscillator.waveform = .sine
        oscillator.frequency = 440.0
        oscillator.interpolation = .lagrange

        var samples: [Float] = []
        for _ in 0..<100 {
            samples.append(oscillator.process())
        }

        // Lagrange should produce smooth, high-quality output
        var maxDelta: Float = 0.0
        for i in 1..<samples.count {
            maxDelta = max(maxDelta, abs(samples[i] - samples[i-1]))
        }

        XCTAssertLessThan(maxDelta, 0.3, "Lagrange interpolation should be very smooth")
    }

    func testInterpolationComparison() {
        oscillator.waveform = .sine
        oscillator.frequency = 440.0

        // Generate samples with different interpolation methods
        oscillator.interpolation = .none
        oscillator.resetPhase()
        var noInterp: [Float] = []
        for _ in 0..<100 { noInterp.append(oscillator.process()) }

        oscillator.interpolation = .linear
        oscillator.resetPhase()
        var linearInterp: [Float] = []
        for _ in 0..<100 { linearInterp.append(oscillator.process()) }

        oscillator.interpolation = .hermite
        oscillator.resetPhase()
        var hermiteInterp: [Float] = []
        for _ in 0..<100 { hermiteInterp.append(oscillator.process()) }

        // Hermite should be closer to ideal sine than no interpolation
        // (This is a qualitative test - hermite should have smoother transitions)
        XCTAssertNotEqual(noInterp, hermiteInterp)
        XCTAssertNotEqual(linearInterp, hermiteInterp)
    }

    // MARK: - Frequency Tests

    func testFrequencyAccuracy() {
        oscillator.waveform = .sine
        oscillator.frequency = 1000.0
        oscillator.interpolation = .hermite

        // Count zero crossings in 1 second
        var zeroCrossings = 0
        var lastSample: Float = 0.0

        for _ in 0..<Int(sampleRate) {
            let sample = oscillator.process()
            if (lastSample < 0 && sample >= 0) || (lastSample >= 0 && sample < 0) {
                zeroCrossings += 1
            }
            lastSample = sample
        }

        // 1000 Hz should have ~2000 zero crossings per second
        let measuredFrequency = Float(zeroCrossings) / 2.0
        XCTAssertEqual(measuredFrequency, 1000.0, accuracy: 10.0, "Frequency should be accurate")
    }

    func testFrequencyRange() {
        let frequencies: [Float] = [20.0, 100.0, 440.0, 1000.0, 5000.0, 10000.0]

        for freq in frequencies {
            oscillator.frequency = freq

            var samples: [Float] = []
            for _ in 0..<480 {
                samples.append(oscillator.process())
            }

            XCTAssertTrue(samples.contains(where: { $0 != 0.0 }), "Frequency \(freq) Hz should produce output")
        }
    }

    // MARK: - Amplitude Tests

    func testAmplitude() {
        oscillator.waveform = .sine
        oscillator.frequency = 440.0
        oscillator.interpolation = .hermite

        oscillator.amplitude = 0.5
        var samples05: [Float] = []
        for _ in 0..<480 {
            samples05.append(oscillator.process())
        }

        oscillator.resetPhase()
        oscillator.amplitude = 1.0
        var samples10: [Float] = []
        for _ in 0..<480 {
            samples10.append(oscillator.process())
        }

        // Max amplitude at 0.5 should be roughly half of max at 1.0
        let max05 = samples05.max() ?? 0.0
        let max10 = samples10.max() ?? 0.0

        XCTAssertEqual(max05, max10 * 0.5, accuracy: 0.1)
    }

    func testZeroAmplitude() {
        oscillator.amplitude = 0.0

        for _ in 0..<100 {
            let sample = oscillator.process()
            XCTAssertEqual(sample, 0.0, accuracy: 0.001)
        }
    }

    // MARK: - Phase Reset Tests

    func testPhaseReset() {
        oscillator.waveform = .sine
        oscillator.frequency = 440.0

        // Generate first cycle
        oscillator.resetPhase()
        let sample1 = oscillator.process()

        // Advance phase
        for _ in 0..<1000 {
            _ = oscillator.process()
        }

        // Reset and compare
        oscillator.resetPhase()
        let sample2 = oscillator.process()

        XCTAssertEqual(sample1, sample2, accuracy: 0.001, "Phase reset should produce identical output")
    }

    // MARK: - Wavetable Morphing Tests

    func testWavetableMorphing() {
        oscillator.waveform = .sine
        oscillator.morphTarget = .square
        oscillator.morphPosition = 0.0

        // At morph position 0.0, should be pure sine
        oscillator.resetPhase()
        let sineSample = oscillator.process()

        // At morph position 1.0, should be pure square
        oscillator.morphPosition = 1.0
        oscillator.resetPhase()
        let squareSample = oscillator.process()

        // At morph position 0.5, should be halfway between
        oscillator.morphPosition = 0.5
        oscillator.resetPhase()
        let morphedSample = oscillator.process()

        XCTAssertNotEqual(sineSample, squareSample)
        // Morphed sample should be between sine and square (approximately)
        // This is a rough test - exact value depends on phase
    }

    func testMorphPosition() {
        oscillator.waveform = .sine
        oscillator.morphTarget = .triangle

        oscillator.morphPosition = -0.5
        XCTAssertGreaterThanOrEqual(oscillator.morphPosition, 0.0)

        oscillator.morphPosition = 1.5
        XCTAssertLessThanOrEqual(oscillator.morphPosition, 1.0)
    }

    // MARK: - Custom Wavetable Tests

    func testCustomWavetable() {
        // Create simple custom wavetable (half sine cycle)
        var customTable = [Float](repeating: 0.0, count: 2048)
        for i in 0..<2048 {
            customTable[i] = sin(Float(i) / 2048.0 * .pi)
        }

        oscillator.loadCustomWavetable(customTable)
        XCTAssertEqual(oscillator.waveform, .custom)

        let sample = oscillator.process()
        XCTAssertGreaterThanOrEqual(sample, 0.0, "Custom half-sine should be non-negative")
    }

    func testCustomWavetableResampling() {
        // Create small custom table (should be resampled to 2048)
        let smallTable = [Float](repeating: 0.5, count: 100)

        oscillator.loadCustomWavetable(smallTable)

        var samples: [Float] = []
        for _ in 0..<100 {
            samples.append(oscillator.process())
        }

        // Should produce output close to 0.5
        let avg = samples.reduce(0.0, +) / Float(samples.count)
        XCTAssertEqual(avg, 0.5, accuracy: 0.1)
    }

    // MARK: - Bio-feedback Integration Tests

    func testCoherenceModulation() {
        // Low coherence should select harsh waveforms
        oscillator.modulateWaveformWithCoherence(20.0)
        let lowCoherenceWaveform = oscillator.waveform
        XCTAssertTrue([.sawtooth].contains(lowCoherenceWaveform))

        // High coherence should select smooth waveforms
        oscillator.modulateWaveformWithCoherence(90.0)
        let highCoherenceWaveform = oscillator.waveform
        XCTAssertTrue([.sine, .triangle].contains(highCoherenceWaveform))
    }

    func testBreathingPhaseMorphing() {
        // Inhale phase (0.0-0.5)
        oscillator.morphWithBreathingPhase(0.25)
        XCTAssertEqual(oscillator.waveform, .sine)
        XCTAssertEqual(oscillator.morphTarget, .triangle)
        XCTAssertGreaterThan(oscillator.morphPosition, 0.0)

        // Exhale phase (0.5-1.0)
        oscillator.morphWithBreathingPhase(0.75)
        XCTAssertEqual(oscillator.waveform, .triangle)
        XCTAssertEqual(oscillator.morphTarget, .sine)
        XCTAssertGreaterThan(oscillator.morphPosition, 0.0)
    }

    // MARK: - Buffer Processing Tests

    func testProcessBuffer() {
        var buffer = [Float](repeating: 0.0, count: 1024)
        oscillator.waveform = .sine
        oscillator.frequency = 440.0
        oscillator.amplitude = 0.8

        buffer.withUnsafeMutableBufferPointer { ptr in
            oscillator.processBuffer(ptr.baseAddress!, frameCount: 1024)
        }

        // Buffer should be filled with non-zero values
        XCTAssertTrue(buffer.contains(where: { $0 != 0.0 }))
        XCTAssertTrue(buffer.allSatisfy { abs($0) <= 1.0 })
    }

    // MARK: - Band-limiting Tests

    func testBandLimiting_HighFrequency() {
        // At high frequencies, wavetable should not alias
        oscillator.waveform = .sawtooth
        oscillator.frequency = 15000.0 // Near Nyquist (24000 Hz at 48kHz)

        var samples: [Float] = []
        for _ in 0..<480 {
            samples.append(oscillator.process())
        }

        // Should not produce extreme discontinuities (sign of aliasing)
        var maxJump: Float = 0.0
        for i in 1..<samples.count {
            maxJump = max(maxJump, abs(samples[i] - samples[i-1]))
        }

        XCTAssertLessThan(maxJump, 1.5, "Band-limiting should prevent severe aliasing")
    }

    // MARK: - Performance Tests

    func testProcessing_Performance() {
        oscillator.waveform = .sine
        oscillator.frequency = 440.0
        oscillator.interpolation = .hermite

        measure {
            for _ in 0..<48000 { // 1 second @ 48kHz
                _ = oscillator.process()
            }
        }
    }

    func testHermiteInterpolation_Performance() {
        oscillator.waveform = .sawtooth
        oscillator.frequency = 1000.0
        oscillator.interpolation = .hermite

        measure {
            for _ in 0..<48000 {
                _ = oscillator.process()
            }
        }
    }

    func testWavetableMorphing_Performance() {
        oscillator.waveform = .sine
        oscillator.morphTarget = .square
        oscillator.morphPosition = 0.5

        measure {
            for _ in 0..<48000 {
                _ = oscillator.process()
            }
        }
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        oscillator.waveform = .triangle
        oscillator.frequency = 880.0
        oscillator.amplitude = 0.7
        oscillator.interpolation = .lagrange
        oscillator.morphTarget = .sawtooth
        oscillator.morphPosition = 0.3

        let encoder = JSONEncoder()
        let data = try encoder.encode(oscillator)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WavetableOscillator.self, from: data)

        XCTAssertEqual(decoded.waveform, .triangle)
        XCTAssertEqual(decoded.frequency, 880.0, accuracy: 0.1)
        XCTAssertEqual(decoded.amplitude, 0.7, accuracy: 0.01)
        XCTAssertEqual(decoded.interpolation, .lagrange)
        XCTAssertEqual(decoded.morphTarget, .sawtooth)
        XCTAssertEqual(decoded.morphPosition, 0.3, accuracy: 0.01)
    }

    // MARK: - Edge Case Tests

    func testVeryLowFrequency() {
        oscillator.frequency = 20.0 // Minimum audible frequency

        var samples: [Float] = []
        for _ in 0..<4800 { // 100ms
            samples.append(oscillator.process())
        }

        XCTAssertTrue(samples.contains(where: { $0 != 0.0 }))
    }

    func testVeryHighFrequency() {
        oscillator.frequency = 20000.0 // Near maximum

        var samples: [Float] = []
        for _ in 0..<480 {
            samples.append(oscillator.process())
        }

        XCTAssertTrue(samples.contains(where: { $0 != 0.0 }))
    }

    func testAllWaveforms() {
        for waveform in WavetableOscillator.Waveform.allCases {
            oscillator.waveform = waveform
            oscillator.frequency = 440.0

            // Should not crash
            for _ in 0..<100 {
                _ = oscillator.process()
            }
        }
    }

    func testAllInterpolationTypes() {
        let interpolations: [WavetableOscillator.InterpolationType] = [.none, .linear, .hermite, .lagrange]

        for interpolation in interpolations {
            oscillator.interpolation = interpolation
            oscillator.waveform = .sine
            oscillator.frequency = 440.0

            var samples: [Float] = []
            for _ in 0..<100 {
                samples.append(oscillator.process())
            }

            XCTAssertTrue(samples.contains(where: { $0 != 0.0 }), "\(interpolation) should produce output")
        }
    }
}
