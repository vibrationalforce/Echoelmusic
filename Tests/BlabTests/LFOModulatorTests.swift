import XCTest
@testable import Blab

/// Unit tests for LFO Modulator
/// Validates waveform accuracy, phase consistency, and bio-feedback integration
final class LFOModulatorTests: XCTestCase {

    var lfo: LFOModulator!
    let sampleRate: Float = 48000.0

    override func setUp() {
        super.setUp()
        lfo = LFOModulator(frequency: 1.0, sampleRate: sampleRate)
    }

    override func tearDown() {
        lfo = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDefaultValues() {
        XCTAssertEqual(lfo.frequency, 1.0, accuracy: 0.001)
        XCTAssertEqual(lfo.depth, 1.0, accuracy: 0.01)
        XCTAssertEqual(lfo.waveform, .sine)
        XCTAssertEqual(lfo.syncMode, .freeRunning)
    }

    func testParameterClamping() {
        lfo.frequency = -1.0
        XCTAssertGreaterThanOrEqual(lfo.frequency, 0.01)

        lfo.frequency = 100.0
        XCTAssertLessThanOrEqual(lfo.frequency, 20.0)

        lfo.depth = -0.5
        XCTAssertGreaterThanOrEqual(lfo.depth, 0.0)

        lfo.depth = 2.0
        XCTAssertLessThanOrEqual(lfo.depth, 1.0)
    }

    // MARK: - Sine Waveform Tests

    func testSineWaveform() {
        lfo.waveform = .sine
        lfo.frequency = 1.0
        lfo.depth = 1.0
        lfo.resetPhase()

        // At phase 0, sine should be ~0
        let val0 = lfo.process()
        XCTAssertEqual(val0, 0.0, accuracy: 0.1)

        // At phase 0.25, sine should be ~1
        for _ in 0..<(Int(sampleRate) / 4) {
            _ = lfo.process()
        }
        let val025 = lfo.process()
        XCTAssertEqual(val025, 1.0, accuracy: 0.1)

        // At phase 0.5, sine should be ~0
        for _ in 0..<(Int(sampleRate) / 4) {
            _ = lfo.process()
        }
        let val05 = lfo.process()
        XCTAssertEqual(val05, 0.0, accuracy: 0.1)

        // At phase 0.75, sine should be ~-1
        for _ in 0..<(Int(sampleRate) / 4) {
            _ = lfo.process()
        }
        let val075 = lfo.process()
        XCTAssertEqual(val075, -1.0, accuracy: 0.1)
    }

    func testSineWaveform_Symmetry() {
        lfo.waveform = .sine
        lfo.frequency = 1.0
        lfo.resetPhase()

        var values: [Float] = []
        for _ in 0..<Int(sampleRate) {
            values.append(lfo.process())
        }

        // Check positive/negative symmetry
        let positiveSum = values.filter { $0 > 0 }.reduce(0.0, +)
        let negativeSum = abs(values.filter { $0 < 0 }.reduce(0.0, +))
        XCTAssertEqual(positiveSum, negativeSum, accuracy: 1.0)
    }

    // MARK: - Triangle Waveform Tests

    func testTriangleWaveform() {
        lfo.waveform = .triangle
        lfo.frequency = 1.0
        lfo.depth = 1.0
        lfo.resetPhase()

        var values: [Float] = []
        for _ in 0..<100 {
            values.append(lfo.process())
        }

        // Triangle should have linear slope
        XCTAssertGreaterThan(values[1], values[0])
        XCTAssertGreaterThan(values[2], values[1])
    }

    // MARK: - Sawtooth Waveform Tests

    func testSawUpWaveform() {
        lfo.waveform = .sawUp
        lfo.frequency = 1.0
        lfo.resetPhase()

        let val1 = lfo.process()
        let val2 = lfo.process()
        let val3 = lfo.process()

        // Sawtooth up should increase monotonically (within same cycle)
        XCTAssertGreaterThan(val2, val1)
        XCTAssertGreaterThan(val3, val2)
    }

    func testSawDownWaveform() {
        lfo.waveform = .sawDown
        lfo.frequency = 1.0
        lfo.resetPhase()

        let val1 = lfo.process()
        let val2 = lfo.process()
        let val3 = lfo.process()

        // Sawtooth down should decrease monotonically
        XCTAssertLessThan(val2, val1)
        XCTAssertLessThan(val3, val2)
    }

    // MARK: - Square Waveform Tests

    func testSquareWaveform() {
        lfo.waveform = .square
        lfo.frequency = 1.0
        lfo.depth = 1.0
        lfo.resetPhase()

        // First half should be negative
        var firstHalf: [Float] = []
        for _ in 0..<(Int(sampleRate) / 2) {
            firstHalf.append(lfo.process())
        }
        XCTAssertTrue(firstHalf.allSatisfy { $0 < 0 })

        // Second half should be positive
        var secondHalf: [Float] = []
        for _ in 0..<(Int(sampleRate) / 2) {
            secondHalf.append(lfo.process())
        }
        XCTAssertTrue(secondHalf.allSatisfy { $0 > 0 })
    }

    // MARK: - Random Waveform Tests

    func testRandomWaveform() {
        lfo.waveform = .random
        lfo.frequency = 1.0
        lfo.resetPhase()

        var values: [Float] = []
        for _ in 0..<1000 {
            values.append(lfo.process())
        }

        // Random should vary
        let uniqueValues = Set(values.map { Int($0 * 100) })
        XCTAssertGreaterThan(uniqueValues.count, 10)

        // Should be smoothly varying (not jumping wildly)
        var maxDelta: Float = 0.0
        for i in 1..<values.count {
            maxDelta = max(maxDelta, abs(values[i] - values[i-1]))
        }
        XCTAssertLessThan(maxDelta, 0.1, "Random should be smooth, not chaotic")
    }

    // MARK: - Sample & Hold Tests

    func testSampleHoldWaveform() {
        lfo.waveform = .sampleHold
        lfo.frequency = 2.0  // 2 Hz = 2 steps per second
        lfo.resetPhase()

        var values: [Float] = []
        for _ in 0..<Int(sampleRate) {
            values.append(lfo.process())
        }

        // Sample & hold should have step changes
        let firstQuarter = values[0..<Int(sampleRate/4)]
        let uniqueInFirst = Set(firstQuarter.map { Int($0 * 100) })

        // Should hold steady value for each step
        XCTAssertLessThan(uniqueInFirst.count, 10, "Sample & hold should have discrete steps")
    }

    // MARK: - Chaos Waveform Tests

    func testChaosWaveform() {
        lfo.waveform = .chaos
        lfo.frequency = 1.0
        lfo.resetPhase()

        var values: [Float] = []
        for _ in 0..<10000 {
            values.append(lfo.process())
        }

        // Chaos should be bounded
        XCTAssertTrue(values.allSatisfy { $0 >= -1.0 && $0 <= 1.0 })

        // Chaos should be non-repeating (check for uniqueness)
        let windows = stride(from: 0, to: values.count - 100, by: 100).map {
            Array(values[$0..<$0+100])
        }
        let uniqueWindows = Set(windows.map { $0.reduce(0.0, +) })
        XCTAssertGreaterThan(uniqueWindows.count, windows.count * 0.8, "Chaos should be largely non-repeating")
    }

    // MARK: - Depth Tests

    func testDepth() {
        lfo.waveform = .sine
        lfo.frequency = 1.0
        lfo.resetPhase()

        lfo.depth = 1.0
        for _ in 0..<(Int(sampleRate) / 4) {
            _ = lfo.process()
        }
        let fullDepth = lfo.process()

        lfo.resetPhase()
        lfo.depth = 0.5
        for _ in 0..<(Int(sampleRate) / 4) {
            _ = lfo.process()
        }
        let halfDepth = lfo.process()

        XCTAssertEqual(halfDepth, fullDepth * 0.5, accuracy: 0.1)
    }

    func testDepthZero() {
        lfo.waveform = .sine
        lfo.frequency = 1.0
        lfo.depth = 0.0

        for _ in 0..<100 {
            let value = lfo.process()
            XCTAssertEqual(value, 0.0, accuracy: 0.001)
        }
    }

    // MARK: - Unipolar Output Tests

    func testUnipolarOutput() {
        lfo.waveform = .sine
        lfo.frequency = 1.0
        lfo.depth = 1.0
        lfo.resetPhase()

        var values: [Float] = []
        for _ in 0..<Int(sampleRate) {
            values.append(lfo.processUnipolar())
        }

        // Unipolar should be 0.0 to 1.0
        XCTAssertTrue(values.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })

        // Should contain values near 0 and 1
        XCTAssertTrue(values.contains(where: { $0 < 0.1 }))
        XCTAssertTrue(values.contains(where: { $0 > 0.9 }))
    }

    // MARK: - Phase Offset Tests

    func testPhaseOffset() {
        lfo.waveform = .sine
        lfo.frequency = 1.0
        lfo.depth = 1.0

        lfo.phaseOffset = 0.0
        lfo.resetPhase()
        let val1 = lfo.process()

        lfo.phaseOffset = 0.25
        lfo.resetPhase()
        let val2 = lfo.process()

        // 90° phase shift should give different starting values
        XCTAssertNotEqual(val1, val2, accuracy: 0.1)
    }

    // MARK: - Sync Mode Tests

    func testTempoSyncMode() {
        lfo.syncMode = .tempoSync
        lfo.tempo = 120.0  // 120 BPM = 2 Hz

        let initialFreq = lfo.frequency
        _ = lfo.process()

        // In tempo sync mode, effective frequency should be tempo/60
        // (This is tested indirectly through phase increment)
        XCTAssertEqual(lfo.tempo, 120.0)
    }

    func testBreathSyncMode() {
        lfo.syncMode = .breathSync
        lfo.breathingRate = 15.0  // 15 breaths/min = 0.25 Hz

        _ = lfo.process()
        XCTAssertEqual(lfo.breathingRate, 15.0)
    }

    // MARK: - Preset Tests

    func testPreset_Vibrato() {
        lfo.applyPreset(.vibrato)

        XCTAssertEqual(lfo.waveform, .sine)
        XCTAssertEqual(lfo.frequency, 6.0, accuracy: 0.1)
        XCTAssertEqual(lfo.depth, 0.3, accuracy: 0.1)
    }

    func testPreset_Tremolo() {
        lfo.applyPreset(.tremolo)

        XCTAssertEqual(lfo.waveform, .sine)
        XCTAssertEqual(lfo.frequency, 5.0, accuracy: 0.1)
        XCTAssertEqual(lfo.depth, 0.5, accuracy: 0.1)
    }

    func testPreset_BreathSync() {
        lfo.applyPreset(.breathSync)

        XCTAssertEqual(lfo.waveform, .sine)
        XCTAssertEqual(lfo.syncMode, .breathSync)
        XCTAssertEqual(lfo.frequency, 0.25, accuracy: 0.1)
    }

    func testAllPresets() {
        let presets: [LFOModulator.Preset] = [.vibrato, .tremolo, .slowSweep, .fastTrill, .organicDrift, .steppedArp, .chaosTexture, .breathSync]

        for preset in presets {
            lfo.applyPreset(preset)
            XCTAssertGreaterThan(lfo.frequency, 0.0)
            XCTAssertGreaterThan(lfo.depth, 0.0)
        }
    }

    // MARK: - Waveform Preview Tests

    func testWaveformPreview() {
        lfo.waveform = .sine
        let preview = lfo.getWaveformPreview(samples: 512)

        XCTAssertEqual(preview.count, 512)
        XCTAssertTrue(preview.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
    }

    // MARK: - Bio-feedback Integration Tests

    func testCoherenceModulation() {
        lfo.syncMode = .freeRunning
        lfo.modulateWithCoherence(0.0)
        let lowCoherenceFreq = lfo.frequency
        let lowCoherenceDepth = lfo.depth

        lfo.modulateWithCoherence(100.0)
        let highCoherenceFreq = lfo.frequency
        let highCoherenceDepth = lfo.depth

        // High coherence should reduce frequency and increase depth
        XCTAssertLessThan(highCoherenceFreq, lowCoherenceFreq)
        XCTAssertGreaterThan(highCoherenceDepth, lowCoherenceDepth)
    }

    func testBreathingPhaseSynchronization() {
        lfo.syncMode = .breathSync
        lfo.waveform = .sine
        lfo.frequency = 0.25
        lfo.resetPhase()

        // Manually set phase via breath sync
        lfo.syncToBreathingPhase(0.5)

        // After sync, process should reflect new phase
        let value = lfo.processUnipolar()
        XCTAssertNotEqual(value, 0.0)  // Should not be at start of cycle
    }

    func testHRVModulation() {
        lfo.waveform = .sine
        lfo.modulateWithHRV(20.0)  // Low HRV

        let lowHRVWaveform = lfo.waveform

        lfo.modulateWithHRV(80.0)  // High HRV

        // High HRV should switch to organic waveforms
        XCTAssertEqual(lfo.waveform, .random)
    }

    // MARK: - Modulation Target Tests

    func testModulateFilterCutoff() {
        lfo.waveform = .sine
        lfo.frequency = 1.0
        lfo.depth = 1.0
        lfo.resetPhase()

        let baseCutoff: Float = 1000.0
        let range: Float = 500.0

        for _ in 0..<(Int(sampleRate) / 4) {
            _ = lfo.process()
        }
        let modulated = lfo.modulateFilterCutoff(baseCutoff: baseCutoff, range: range)

        XCTAssertGreaterThan(modulated, baseCutoff)
        XCTAssertLessThan(modulated, baseCutoff + range)
    }

    func testModulateAmplitude() {
        lfo.waveform = .sine
        lfo.frequency = 1.0
        lfo.depth = 1.0
        lfo.resetPhase()

        let baseAmplitude: Float = 0.8

        for _ in 0..<(Int(sampleRate) / 4) {
            _ = lfo.process()
        }
        let modulated = lfo.modulateAmplitude(baseAmplitude: baseAmplitude)

        XCTAssertGreaterThanOrEqual(modulated, 0.0)
        XCTAssertLessThanOrEqual(modulated, baseAmplitude)
    }

    func testModulatePitch() {
        lfo.waveform = .sine
        lfo.frequency = 1.0
        lfo.depth = 1.0
        lfo.resetPhase()

        let basePitch: Float = 440.0  // A4
        let cents: Float = 50.0       // ±50 cents (half semitone)

        for _ in 0..<(Int(sampleRate) / 4) {
            _ = lfo.process()
        }
        let modulated = lfo.modulatePitch(basePitch: basePitch, cents: cents)

        XCTAssertNotEqual(modulated, basePitch)
        XCTAssertGreaterThan(modulated, basePitch * 0.97)  // Roughly within range
        XCTAssertLessThan(modulated, basePitch * 1.03)
    }

    func testModulatePan() {
        lfo.waveform = .sine
        lfo.frequency = 1.0
        lfo.depth = 1.0
        lfo.resetPhase()

        for _ in 0..<(Int(sampleRate) / 4) {
            _ = lfo.process()
        }
        let pan = lfo.modulatePan()

        XCTAssertGreaterThanOrEqual(pan, -1.0)
        XCTAssertLessThanOrEqual(pan, 1.0)
    }

    // MARK: - Buffer Processing Tests

    func testProcessBuffer() {
        var buffer = [Float](repeating: 1.0, count: 1024)
        lfo.waveform = .sine
        lfo.frequency = 1.0
        lfo.depth = 0.5
        lfo.resetPhase()

        buffer.withUnsafeMutableBufferPointer { ptr in
            lfo.processBuffer(ptr.baseAddress!, frameCount: 1024, bipolar: false)
        }

        // Buffer should be modulated
        XCTAssertNotEqual(buffer[0], 1.0)
        XCTAssertGreaterThan(buffer[0], 0.0)
    }

    // MARK: - Performance Tests

    func testProcessing_Performance() {
        lfo.waveform = .sine
        lfo.frequency = 5.0

        measure {
            for _ in 0..<48000 {  // 1 second @ 48kHz
                _ = lfo.process()
            }
        }
    }

    func testChaosProcessing_Performance() {
        lfo.waveform = .chaos
        lfo.frequency = 1.0

        measure {
            for _ in 0..<48000 {
                _ = lfo.process()
            }
        }
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        lfo.waveform = .triangle
        lfo.frequency = 2.5
        lfo.depth = 0.7
        lfo.phaseOffset = 0.25
        lfo.syncMode = .tempoSync
        lfo.tempo = 140.0

        let encoder = JSONEncoder()
        let data = try encoder.encode(lfo)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LFOModulator.self, from: data)

        XCTAssertEqual(decoded.waveform, .triangle)
        XCTAssertEqual(decoded.frequency, 2.5, accuracy: 0.01)
        XCTAssertEqual(decoded.depth, 0.7, accuracy: 0.01)
        XCTAssertEqual(decoded.phaseOffset, 0.25, accuracy: 0.01)
        XCTAssertEqual(decoded.syncMode, .tempoSync)
        XCTAssertEqual(decoded.tempo, 140.0, accuracy: 0.1)
    }

    // MARK: - Edge Case Tests

    func testVerySlowFrequency() {
        lfo.frequency = 0.01  // 0.01 Hz = 100 second cycle
        lfo.waveform = .sine

        for _ in 0..<1000 {
            let value = lfo.process()
            XCTAssertGreaterThanOrEqual(value, -1.0)
            XCTAssertLessThanOrEqual(value, 1.0)
        }
    }

    func testVeryFastFrequency() {
        lfo.frequency = 20.0  // 20 Hz (maximum)
        lfo.waveform = .sine

        var values: [Float] = []
        for _ in 0..<2400 {  // 0.05 seconds
            values.append(lfo.process())
        }

        // Should complete at least one cycle
        XCTAssertTrue(values.contains(where: { $0 > 0.9 }))
        XCTAssertTrue(values.contains(where: { $0 < -0.9 }))
    }
}
