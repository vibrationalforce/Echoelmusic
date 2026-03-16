#if canImport(AVFoundation)
// AdvancedEffectsTests.swift
// Echoelmusic — Phase 3 Test Coverage: Advanced DSP Effects
//
// Tests for AnalogConsole (ClassicAnalogEmulations),
// and SynthesisEngineType / SynthesisCategory.

import XCTest
@testable import Echoelmusic

// MARK: - AnalogConsole Tests

final class AnalogConsoleTests: XCTestCase {

    func testInit() {
        let console = AnalogConsole()
        XCTAssertEqual(console.character, 50.0)
        XCTAssertEqual(console.output, 50.0)
        XCTAssertEqual(console.mix, 100.0)
        XCTAssertFalse(console.bypassed)
    }

    func testAllHardwareStyles() {
        let styles = AnalogConsole.HardwareStyle.allCases
        XCTAssertEqual(styles.count, 8)
        XCTAssertTrue(styles.contains(.ssl))
        XCTAssertTrue(styles.contains(.api))
        XCTAssertTrue(styles.contains(.neve))
        XCTAssertTrue(styles.contains(.pultec))
        XCTAssertTrue(styles.contains(.fairchild))
        XCTAssertTrue(styles.contains(.la2a))
        XCTAssertTrue(styles.contains(.urei1176))
        XCTAssertTrue(styles.contains(.manley))
    }

    func testHardwareStyleProperties() {
        for style in AnalogConsole.HardwareStyle.allCases {
            XCTAssertFalse(style.fullName.isEmpty, "\(style) missing fullName")
            XCTAssertFalse(style.color.isEmpty, "\(style) missing color")
            // category is a Category enum, not String — just verify it's accessible
            _ = style.category
        }
    }

    func testProcessAllStyles() {
        let console = AnalogConsole()
        let input: [Float] = Array(repeating: 0.5, count: 256)

        for style in AnalogConsole.HardwareStyle.allCases {
            console.currentStyle = style
            let output = console.process(input)
            XCTAssertEqual(output.count, input.count, "\(style) changed output count")
            for sample in output {
                XCTAssertFalse(sample.isNaN, "NaN in \(style)")
                XCTAssertFalse(sample.isInfinite, "Inf in \(style)")
            }
        }
    }

    func testBypass() {
        let console = AnalogConsole()
        console.bypassed = true
        let input: [Float] = [0.1, 0.2, 0.3]
        let output = console.process(input)
        XCTAssertEqual(output, input)
    }

    func testGainReduction() {
        let console = AnalogConsole()
        console.currentStyle = .ssl
        console.character = 80.0
        let input: [Float] = Array(repeating: 0.9, count: 256)
        _ = console.process(input)
        let gr = console.getGainReduction()
        XCTAssertGreaterThanOrEqual(gr, 0)
    }

    func testStyleSwitching() {
        let console = AnalogConsole()
        console.currentStyle = .neve
        XCTAssertEqual(console.currentStyle, .neve)
        console.currentStyle = .ssl
        XCTAssertEqual(console.currentStyle, .ssl)
    }

    // MARK: - Silence Input Tests

    func testProcessSilence_AllStyles() {
        let console = AnalogConsole()
        let silence: [Float] = Array(repeating: 0.0, count: 256)

        for style in AnalogConsole.HardwareStyle.allCases {
            console.currentStyle = style
            let output = console.process(silence)
            XCTAssertEqual(output.count, silence.count, "\(style) changed output count for silence")
            for sample in output {
                XCTAssertFalse(sample.isNaN, "NaN in \(style) silence output")
                XCTAssertFalse(sample.isInfinite, "Inf in \(style) silence output")
                // Silence in should produce near-silence out
                XCTAssertEqual(sample, 0.0, accuracy: 0.01,
                    "Silence input should yield near-zero output for \(style)")
            }
        }
    }

    // MARK: - Loud Input / Clipping Tests

    func testProcessLoudInput_NoClipping() {
        let console = AnalogConsole()
        let loud: [Float] = Array(repeating: 0.95, count: 512)

        for style in AnalogConsole.HardwareStyle.allCases {
            console.currentStyle = style
            console.character = 100.0
            let output = console.process(loud)
            for sample in output {
                XCTAssertFalse(sample.isNaN, "NaN in loud \(style)")
                XCTAssertFalse(sample.isInfinite, "Inf in loud \(style)")
            }
        }
    }

    func testProcessNegativeLoudInput() {
        let console = AnalogConsole()
        let loud: [Float] = Array(repeating: -0.95, count: 512)

        for style in AnalogConsole.HardwareStyle.allCases {
            console.currentStyle = style
            let output = console.process(loud)
            XCTAssertEqual(output.count, loud.count)
            for sample in output {
                XCTAssertFalse(sample.isNaN, "NaN in negative loud \(style)")
                XCTAssertFalse(sample.isInfinite, "Inf in negative loud \(style)")
            }
        }
    }

    // MARK: - Character Parameter Range

    func testCharacterRange_BoundaryValues() {
        let console = AnalogConsole()
        let input: [Float] = Array(repeating: 0.5, count: 256)

        let values: [Float] = [0.0, 1.0, 25.0, 50.0, 75.0, 99.0, 100.0]
        for value in values {
            console.character = value
            XCTAssertEqual(console.character, value, "Character should be \(value)")
            let output = console.process(input)
            for sample in output {
                XCTAssertFalse(sample.isNaN, "NaN at character \(value)")
                XCTAssertFalse(sample.isInfinite, "Inf at character \(value)")
            }
        }
    }

    func testCharacterZero_MinimalProcessing() {
        let console = AnalogConsole()
        console.character = 0.0
        let input: [Float] = Array(repeating: 0.3, count: 256)
        let output = console.process(input)
        XCTAssertEqual(output.count, input.count)
        // With minimum character, output should still be valid
        for sample in output {
            XCTAssertFalse(sample.isNaN)
        }
    }

    func testCharacterMax_HeavyProcessing() {
        let console = AnalogConsole()
        console.character = 100.0
        let input: [Float] = Array(repeating: 0.3, count: 256)
        let output = console.process(input)
        XCTAssertEqual(output.count, input.count)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
            XCTAssertFalse(sample.isInfinite)
        }
    }

    // MARK: - Output Parameter Range

    func testOutputRange_BoundaryValues() {
        let console = AnalogConsole()
        let input: [Float] = Array(repeating: 0.5, count: 256)

        let values: [Float] = [0.0, 25.0, 50.0, 75.0, 100.0]
        for value in values {
            console.output = value
            XCTAssertEqual(console.output, value, "Output should be \(value)")
            let output = console.process(input)
            for sample in output {
                XCTAssertFalse(sample.isNaN, "NaN at output \(value)")
                XCTAssertFalse(sample.isInfinite, "Inf at output \(value)")
            }
        }
    }

    func testOutputZero_ReducedLevel() {
        let console = AnalogConsole()
        console.output = 0.0
        let input: [Float] = Array(repeating: 0.5, count: 256)
        let output = console.process(input)
        // Output at 0 should reduce level significantly
        let maxOut = output.map { abs($0) }.max() ?? 0
        let maxIn = input.map { abs($0) }.max() ?? 0
        XCTAssertLessThan(maxOut, maxIn, "Output=0 should reduce level")
    }

    // MARK: - Mix Parameter Range

    func testMixRange_BoundaryValues() {
        let console = AnalogConsole()
        let input: [Float] = Array(repeating: 0.5, count: 256)

        let values: [Float] = [0.0, 25.0, 50.0, 75.0, 100.0]
        for value in values {
            console.mix = value
            XCTAssertEqual(console.mix, value, "Mix should be \(value)")
            let output = console.process(input)
            for sample in output {
                XCTAssertFalse(sample.isNaN, "NaN at mix \(value)")
                XCTAssertFalse(sample.isInfinite, "Inf at mix \(value)")
            }
        }
    }

    func testMixZero_DrySignalOnly() {
        let console = AnalogConsole()
        console.mix = 0.0
        console.output = 50.0
        let input: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let output = console.process(input)
        // Mix 0 = 100% dry, so output should equal input
        for (i, sample) in output.enumerated() {
            XCTAssertEqual(sample, input[i], accuracy: 0.001,
                "Mix=0 should pass dry signal, index \(i)")
        }
    }

    // MARK: - Style Differentiation

    func testDifferentStylesProduceDifferentOutput() {
        let input: [Float] = (0..<512).map { i in
            0.5 * sin(2.0 * .pi * 440.0 * Float(i) / 48000.0)
        }
        var outputs: [AnalogConsole.HardwareStyle: [Float]] = [:]

        for style in AnalogConsole.HardwareStyle.allCases {
            let console = AnalogConsole()
            console.currentStyle = style
            console.character = 70.0
            outputs[style] = console.process(input)
        }

        // At least some styles should produce different outputs
        let ssl = outputs[.ssl]!
        let neve = outputs[.neve]!
        let fairchild = outputs[.fairchild]!

        var sslNeveMatch = true
        var sslFairchildMatch = true
        for i in 0..<ssl.count {
            if abs(ssl[i] - neve[i]) > 0.001 { sslNeveMatch = false }
            if abs(ssl[i] - fairchild[i]) > 0.001 { sslFairchildMatch = false }
        }
        XCTAssertFalse(sslNeveMatch, "SSL and Neve should produce different output")
        XCTAssertFalse(sslFairchildMatch, "SSL and Fairchild should produce different output")
    }

    // MARK: - Gain Reduction per Style

    func testGainReduction_AllStyles() {
        let input: [Float] = Array(repeating: 0.9, count: 512)

        for style in AnalogConsole.HardwareStyle.allCases {
            let console = AnalogConsole()
            console.currentStyle = style
            console.character = 80.0
            _ = console.process(input)
            let gr = console.getGainReduction()
            // GR should be finite
            XCTAssertFalse(gr.isNaN, "GR NaN for \(style)")
            XCTAssertFalse(gr.isInfinite, "GR Inf for \(style)")
            // GR should be non-positive (reduction) or zero
            XCTAssertLessThanOrEqual(gr, 0.0, "GR should be <= 0 for \(style)")
        }
    }

    func testGainReduction_PultecIsZero() {
        let console = AnalogConsole()
        console.currentStyle = .pultec
        let input: [Float] = Array(repeating: 0.9, count: 256)
        _ = console.process(input)
        let gr = console.getGainReduction()
        XCTAssertEqual(gr, 0.0, "Pultec EQ should have zero gain reduction")
    }

    // MARK: - Hardware Style Category

    func testHardwareStyleCategories() {
        // Most styles are compressors
        XCTAssertEqual(AnalogConsole.HardwareStyle.ssl.category, .compressor)
        XCTAssertEqual(AnalogConsole.HardwareStyle.api.category, .compressor)
        XCTAssertEqual(AnalogConsole.HardwareStyle.neve.category, .compressor)
        XCTAssertEqual(AnalogConsole.HardwareStyle.fairchild.category, .compressor)
        XCTAssertEqual(AnalogConsole.HardwareStyle.la2a.category, .compressor)
        XCTAssertEqual(AnalogConsole.HardwareStyle.urei1176.category, .compressor)
        XCTAssertEqual(AnalogConsole.HardwareStyle.manley.category, .compressor)
        // Pultec is equalizer
        XCTAssertEqual(AnalogConsole.HardwareStyle.pultec.category, .equalizer)
    }

    // MARK: - Multiple Process Calls Stability

    func testMultipleProcessCalls_NoAccumulation() {
        let console = AnalogConsole()
        console.currentStyle = .ssl
        console.character = 60.0
        let input: [Float] = Array(repeating: 0.5, count: 256)

        // Process many times to check for state accumulation issues
        for _ in 0..<100 {
            let output = console.process(input)
            for sample in output {
                XCTAssertFalse(sample.isNaN)
                XCTAssertFalse(sample.isInfinite)
            }
        }
    }

    // MARK: - Init with Custom Sample Rate

    func testInitWithCustomSampleRate() {
        let console = AnalogConsole(sampleRate: 44100)
        let input: [Float] = Array(repeating: 0.5, count: 256)
        let output = console.process(input)
        XCTAssertEqual(output.count, input.count)
    }

    func testInitWithHighSampleRate() {
        let console = AnalogConsole(sampleRate: 96000)
        let input: [Float] = Array(repeating: 0.5, count: 256)
        let output = console.process(input)
        XCTAssertEqual(output.count, input.count)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
        }
    }

    // MARK: - Empty Input

    func testProcessEmptyInput() {
        let console = AnalogConsole()
        let input: [Float] = []
        let output = console.process(input)
        XCTAssertTrue(output.isEmpty, "Empty input should produce empty output")
    }

    // MARK: - Single Sample

    func testProcessSingleSample() {
        let console = AnalogConsole()
        let input: [Float] = [0.5]
        let output = console.process(input)
        XCTAssertEqual(output.count, 1)
        XCTAssertFalse(output[0].isNaN)
    }
}

// MARK: - Individual Processor Tests

final class SSLBusCompressorTests: XCTestCase {

    func testInit() {
        let ssl = SSLBusCompressor()
        XCTAssertEqual(ssl.threshold, -15.0)
        XCTAssertEqual(ssl.ratio, 4.0)
        XCTAssertEqual(ssl.attack, 10.0)
        XCTAssertEqual(ssl.release, 300.0)
        XCTAssertEqual(ssl.makeupGain, 0.0)
        XCTAssertFalse(ssl.autoRelease)
        XCTAssertEqual(ssl.gainReduction, 0.0)
    }

    func testProcessSilence() {
        let ssl = SSLBusCompressor()
        let silence: [Float] = Array(repeating: 0.0, count: 256)
        let output = ssl.process(silence)
        for sample in output {
            XCTAssertEqual(sample, 0.0, accuracy: 0.001)
        }
    }

    func testProcessSignal() {
        let ssl = SSLBusCompressor()
        ssl.threshold = -10.0
        ssl.ratio = 4.0
        let input: [Float] = Array(repeating: 0.8, count: 512)
        let output = ssl.process(input)
        XCTAssertEqual(output.count, input.count)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
            XCTAssertFalse(sample.isInfinite)
        }
    }

    func testAutoRelease() {
        let ssl = SSLBusCompressor()
        ssl.autoRelease = true
        let input: [Float] = Array(repeating: 0.7, count: 256)
        let output = ssl.process(input)
        XCTAssertEqual(output.count, input.count)
    }

    func testGainReductionAfterLoudSignal() {
        let ssl = SSLBusCompressor()
        ssl.threshold = -20.0
        ssl.ratio = 10.0
        let input: [Float] = Array(repeating: 0.9, count: 512)
        _ = ssl.process(input)
        XCTAssertLessThanOrEqual(ssl.gainReduction, 0.0)
    }
}

final class APIBusCompressorTests: XCTestCase {

    func testInit() {
        let api = APIBusCompressor()
        XCTAssertEqual(api.threshold, -10.0)
        XCTAssertEqual(api.ratio, 4.0)
        XCTAssertTrue(api.thrust)
        XCTAssertEqual(api.tone, 50.0)
        XCTAssertTrue(api.hardKnee)
        XCTAssertTrue(api.feedForward)
    }

    func testThrustCircuit() {
        let api = APIBusCompressor()
        api.thrust = true
        let input: [Float] = Array(repeating: 0.7, count: 512)
        let withThrust = api.process(input)

        let api2 = APIBusCompressor()
        api2.thrust = false
        let withoutThrust = api2.process(input)

        // Thrust should alter the output
        var different = false
        for i in 0..<withThrust.count {
            if abs(withThrust[i] - withoutThrust[i]) > 0.0001 {
                different = true
                break
            }
        }
        XCTAssertTrue(different, "Thrust circuit should alter output")
    }

    func testSoftKnee() {
        let api = APIBusCompressor()
        api.hardKnee = false
        let input: [Float] = Array(repeating: 0.8, count: 256)
        let output = api.process(input)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
            XCTAssertFalse(sample.isInfinite)
        }
    }
}

final class PultecEQP1ATests: XCTestCase {

    func testInit() {
        let eq = PultecEQP1A()
        XCTAssertEqual(eq.lowFreq, 60.0)
        XCTAssertEqual(eq.lowBoost, 0.0)
        XCTAssertEqual(eq.lowAtten, 0.0)
        XCTAssertEqual(eq.highFreq, 12000.0)
        XCTAssertEqual(eq.highBoost, 0.0)
        XCTAssertEqual(eq.highAtten, 0.0)
        XCTAssertEqual(eq.tubeOutput, 5.0)
    }

    func testProcessFlat() {
        let eq = PultecEQP1A()
        // All boosts at zero - should be near pass-through
        let input: [Float] = Array(repeating: 0.5, count: 256)
        let output = eq.process(input)
        XCTAssertEqual(output.count, input.count)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
        }
    }

    func testLowBoost() {
        let eq = PultecEQP1A()
        eq.lowBoost = 8.0
        let input: [Float] = Array(repeating: 0.3, count: 512)
        let output = eq.process(input)
        XCTAssertEqual(output.count, input.count)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
            XCTAssertFalse(sample.isInfinite)
        }
    }

    func testHighBoost() {
        let eq = PultecEQP1A()
        eq.highBoost = 7.0
        let input: [Float] = (0..<512).map { i in
            0.3 * sin(2.0 * .pi * 10000.0 * Float(i) / 48000.0)
        }
        let output = eq.process(input)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
            XCTAssertFalse(sample.isInfinite)
        }
    }

    func testPultecTrick_SimultaneousBoostAndCut() {
        let eq = PultecEQP1A()
        eq.lowBoost = 7.0
        eq.lowAtten = 5.0
        let input: [Float] = Array(repeating: 0.4, count: 512)
        let output = eq.process(input)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
            XCTAssertFalse(sample.isInfinite)
        }
    }

    func testTubeSaturation() {
        let eq = PultecEQP1A()
        eq.tubeOutput = 10.0
        let input: [Float] = Array(repeating: 0.5, count: 256)
        let output = eq.process(input)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
        }
    }
}

final class FairchildLimiterTests: XCTestCase {

    func testInit() {
        let fc = FairchildLimiter()
        XCTAssertEqual(fc.inputGain, 5.0)
        XCTAssertEqual(fc.threshold, 10.0)
        XCTAssertEqual(fc.timeConstant, 3)
    }

    func testAllTimeConstants() {
        let input: [Float] = Array(repeating: 0.7, count: 512)
        for tc in 1...6 {
            let fc = FairchildLimiter()
            fc.timeConstant = tc
            let output = fc.process(input)
            XCTAssertEqual(output.count, input.count)
            for sample in output {
                XCTAssertFalse(sample.isNaN, "NaN at TC \(tc)")
                XCTAssertFalse(sample.isInfinite, "Inf at TC \(tc)")
            }
        }
    }

    func testGainReduction() {
        let fc = FairchildLimiter()
        fc.inputGain = 9.0
        let input: [Float] = Array(repeating: 0.8, count: 512)
        _ = fc.process(input)
        XCTAssertLessThanOrEqual(fc.gainReduction, 0.0)
    }
}

final class LA2ACompressorTests: XCTestCase {

    func testInit() {
        let la2a = LA2ACompressor()
        XCTAssertEqual(la2a.peakReduction, 50.0)
        XCTAssertEqual(la2a.gain, 50.0)
        XCTAssertFalse(la2a.limitMode)
    }

    func testCompressMode() {
        let la2a = LA2ACompressor()
        la2a.limitMode = false
        la2a.peakReduction = 70.0
        let input: [Float] = Array(repeating: 0.7, count: 512)
        let output = la2a.process(input)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
            XCTAssertFalse(sample.isInfinite)
        }
    }

    func testLimitMode() {
        let la2a = LA2ACompressor()
        la2a.limitMode = true
        la2a.peakReduction = 80.0
        let input: [Float] = Array(repeating: 0.8, count: 512)
        let output = la2a.process(input)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
            XCTAssertFalse(sample.isInfinite)
        }
    }
}

final class UREI1176LimiterTests: XCTestCase {

    func testInit() {
        let urei = UREI1176Limiter()
        XCTAssertEqual(urei.inputDrive, 30.0)
        XCTAssertEqual(urei.outputLevel, 30.0)
        XCTAssertEqual(urei.attack, 4.0)
        XCTAssertEqual(urei.release, 4.0)
        XCTAssertEqual(urei.ratio, 4.0)
    }

    func testAllButtonsMode() {
        let urei = UREI1176Limiter()
        urei.ratio = 100.0  // "all buttons" mode
        urei.inputDrive = 50.0
        let input: [Float] = Array(repeating: 0.8, count: 512)
        let output = urei.process(input)
        for sample in output {
            XCTAssertFalse(sample.isNaN, "NaN in all-buttons mode")
            XCTAssertFalse(sample.isInfinite, "Inf in all-buttons mode")
        }
    }

    func testAllAttackReleaseValues() {
        let input: [Float] = Array(repeating: 0.6, count: 256)
        for attack in 1...7 {
            for release in 1...7 {
                let urei = UREI1176Limiter()
                urei.attack = Float(attack)
                urei.release = Float(release)
                let output = urei.process(input)
                for sample in output {
                    XCTAssertFalse(sample.isNaN, "NaN at A\(attack)/R\(release)")
                }
            }
        }
    }
}

final class ManleyVariMuTests: XCTestCase {

    func testInit() {
        let manley = ManleyVariMu()
        XCTAssertEqual(manley.threshold, -10.0)
        XCTAssertEqual(manley.compression, 50.0)
        XCTAssertTrue(manley.hpfEnabled)
        XCTAssertEqual(manley.hpfFreq, 100.0)
        XCTAssertTrue(manley.linked)
    }

    func testHPFSidechain() {
        let input: [Float] = Array(repeating: 0.7, count: 512)

        let manleyHPF = ManleyVariMu()
        manleyHPF.hpfEnabled = true
        let outputHPF = manleyHPF.process(input)

        let manleyNoHPF = ManleyVariMu()
        manleyNoHPF.hpfEnabled = false
        let outputNoHPF = manleyNoHPF.process(input)

        // Both should produce valid output
        for sample in outputHPF {
            XCTAssertFalse(sample.isNaN)
        }
        for sample in outputNoHPF {
            XCTAssertFalse(sample.isNaN)
        }
    }

    func testMaxCompression() {
        let manley = ManleyVariMu()
        manley.compression = 100.0
        manley.threshold = -20.0
        let input: [Float] = Array(repeating: 0.9, count: 512)
        let output = manley.process(input)
        for sample in output {
            XCTAssertFalse(sample.isNaN)
            XCTAssertFalse(sample.isInfinite)
        }
        XCTAssertLessThanOrEqual(manley.gainReduction, 0.0)
    }
}

// MARK: - BreakbeatChopper Tests

final class BreakbeatChopperStructTests: XCTestCase {

    // MARK: - BreakSlice Tests

    func testBreakSliceInit() {
        let slice = BreakSlice(start: 0, end: 1000, index: 0)
        XCTAssertEqual(slice.startSample, 0)
        XCTAssertEqual(slice.endSample, 1000)
        XCTAssertEqual(slice.originalIndex, 0)
        XCTAssertEqual(slice.pitch, 0.0)
        XCTAssertEqual(slice.gain, 1.0)
        XCTAssertEqual(slice.pan, 0.0)
        XCTAssertFalse(slice.reverse)
        XCTAssertFalse(slice.mute)
        XCTAssertEqual(slice.stretchFactor, 1.0)
    }

    func testBreakSliceLengthSamples() {
        let slice = BreakSlice(start: 100, end: 500, index: 1)
        XCTAssertEqual(slice.lengthSamples, 400)
    }

    func testBreakSliceEquatable() {
        let slice1 = BreakSlice(start: 0, end: 100, index: 0)
        var slice2 = slice1
        XCTAssertEqual(slice1, slice2)
        slice2.pitch = 5.0
        XCTAssertNotEqual(slice1, slice2)
    }

    // MARK: - ChopperPatternStep Tests

    func testPatternStepInit() {
        let step = ChopperPatternStep(sliceIndex: 3, velocity: 0.8)
        XCTAssertEqual(step.sliceIndex, 3)
        XCTAssertEqual(step.velocity, 0.8)
        XCTAssertEqual(step.pitch, 0)
        XCTAssertFalse(step.reverse)
        XCTAssertNil(step.roll)
        XCTAssertEqual(step.probability, 1.0)
    }

    func testPatternStepRest() {
        let rest = ChopperPatternStep.rest()
        XCTAssertNil(rest.sliceIndex)
        XCTAssertEqual(rest.velocity, 0)
    }

    func testRollTypeDivisions() {
        XCTAssertEqual(ChopperPatternStep.RollType.none.divisions, 1)
        XCTAssertEqual(ChopperPatternStep.RollType.r2.divisions, 2)
        XCTAssertEqual(ChopperPatternStep.RollType.r3.divisions, 3)
        XCTAssertEqual(ChopperPatternStep.RollType.r4.divisions, 4)
        XCTAssertEqual(ChopperPatternStep.RollType.r6.divisions, 6)
        XCTAssertEqual(ChopperPatternStep.RollType.r8.divisions, 8)
    }

    func testRollTypeAllCases() {
        let cases = ChopperPatternStep.RollType.allCases
        XCTAssertEqual(cases.count, 6)
    }

    // MARK: - ChopPattern Tests

    func testChopPatternInit() {
        let pattern = ChopPattern(name: "Test", length: 8)
        XCTAssertEqual(pattern.name, "Test")
        XCTAssertEqual(pattern.length, 8)
        XCTAssertEqual(pattern.steps.count, 8)
        XCTAssertEqual(pattern.stepsPerBar, 16)
        XCTAssertEqual(pattern.swing, 0.0)
    }

    func testChopPatternFromIndices() {
        let indices: [Int?] = [0, 1, nil, 3, 0, nil, 2, 7]
        let pattern = ChopPattern.fromIndices(indices, name: "Custom")
        XCTAssertEqual(pattern.name, "Custom")
        XCTAssertEqual(pattern.steps.count, indices.count)
        XCTAssertNil(pattern.steps[2].sliceIndex)
        XCTAssertEqual(pattern.steps[0].sliceIndex, 0)
        XCTAssertEqual(pattern.steps[7].sliceIndex, 7)
    }

    // MARK: - StretchAlgorithm Tests

    func testStretchAlgorithmAllCases() {
        let algorithms = StretchAlgorithm.allCases
        XCTAssertEqual(algorithms.count, 5)
        XCTAssertTrue(algorithms.contains(.resample))
        XCTAssertTrue(algorithms.contains(.repitch))
        XCTAssertTrue(algorithms.contains(.granular))
        XCTAssertTrue(algorithms.contains(.phaseVocoder))
        XCTAssertTrue(algorithms.contains(.elastique))
    }

    func testStretchAlgorithmDescriptions() {
        for algo in StretchAlgorithm.allCases {
            XCTAssertFalse(algo.description.isEmpty, "\(algo) missing description")
        }
    }

    func testStretchAlgorithmRawValues() {
        XCTAssertEqual(StretchAlgorithm.resample.rawValue, "Resample")
        XCTAssertEqual(StretchAlgorithm.granular.rawValue, "Granular")
        XCTAssertEqual(StretchAlgorithm.phaseVocoder.rawValue, "Phase Vocoder")
        XCTAssertEqual(StretchAlgorithm.elastique.rawValue, "Élastique")
    }

    // MARK: - ShuffleAlgorithm Tests

    func testShuffleAlgorithmAllCases() {
        let algorithms = ShuffleAlgorithm.allCases
        XCTAssertEqual(algorithms.count, 8)
    }

    func testShuffleReverse() {
        let input = [0, 1, 2, 3, 4, 5, 6, 7]
        let result = ShuffleAlgorithm.reverse.apply(to: input)
        XCTAssertEqual(result, [7, 6, 5, 4, 3, 2, 1, 0])
    }

    func testShuffleEveryOther() {
        let input = [0, 1, 2, 3, 4, 5, 6, 7]
        let result = ShuffleAlgorithm.everyOther.apply(to: input)
        XCTAssertEqual(result, [1, 0, 3, 2, 5, 4, 7, 6])
    }

    func testShuffleThirds() {
        let input = [0, 1, 2, 3, 4, 5]
        let result = ShuffleAlgorithm.thirds.apply(to: input)
        // ABC -> BCA for each group of 3
        XCTAssertEqual(result, [1, 2, 0, 4, 5, 3])
    }

    func testShuffleMirror() {
        let input = [0, 1, 2, 3]
        let result = ShuffleAlgorithm.mirror.apply(to: input)
        // ABCD -> ABCDDCBA, prefix(4)
        XCTAssertEqual(result, [0, 1, 2, 3])
    }

    func testShuffleStutter() {
        let input = [0, 1, 2, 3]
        let result = ShuffleAlgorithm.stutter.apply(to: input)
        // ABCD -> AABBCCDD prefix(4)
        XCTAssertEqual(result, [0, 0, 1, 1])
    }

    func testShufflePreservesCount() {
        let input = [0, 1, 2, 3, 4, 5, 6, 7]
        for algo in ShuffleAlgorithm.allCases {
            let result = algo.apply(to: input)
            XCTAssertEqual(result.count, input.count,
                "\(algo.rawValue) changed count")
        }
    }

    func testShuffleEmptyInput() {
        let input: [Int] = []
        for algo in ShuffleAlgorithm.allCases {
            let result = algo.apply(to: input)
            XCTAssertTrue(result.isEmpty, "\(algo.rawValue) should handle empty input")
        }
    }

    func testShuffleSingleElement() {
        let input = [42]
        for algo in ShuffleAlgorithm.allCases {
            let result = algo.apply(to: input)
            XCTAssertEqual(result.count, 1,
                "\(algo.rawValue) should handle single element")
        }
    }

    // MARK: - Classic Break Presets

    func testClassicPatternsExist() {
        XCTAssertGreaterThan(BreakbeatChopper.classicPatterns.count, 0)
        XCTAssertEqual(BreakbeatChopper.classicPatterns.count, 8)
    }

    func testClassicPatternsHaveNames() {
        for preset in BreakbeatChopper.classicPatterns {
            XCTAssertFalse(preset.name.isEmpty)
        }
    }

    func testClassicPatternsHaveIndices() {
        for preset in BreakbeatChopper.classicPatterns {
            XCTAssertGreaterThan(preset.indices.count, 0)
        }
    }
}

// MARK: - SynthEngineType Tests

final class SynthEngineTypeTests: XCTestCase {

    func testAllCases() {
        let cases = SynthEngineType.allCases
        XCTAssertEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.analog))
        XCTAssertTrue(cases.contains(.fm))
        XCTAssertTrue(cases.contains(.wavetable))
        XCTAssertTrue(cases.contains(.pluck))
        XCTAssertTrue(cases.contains(.pad))
    }

    func testRawValues() {
        XCTAssertEqual(SynthEngineType.analog.rawValue, "Analog")
        XCTAssertEqual(SynthEngineType.fm.rawValue, "FM")
        XCTAssertEqual(SynthEngineType.wavetable.rawValue, "Wavetable")
        XCTAssertEqual(SynthEngineType.pluck.rawValue, "Pluck")
        XCTAssertEqual(SynthEngineType.pad.rawValue, "Pad")
    }

    func testCodable() throws {
        for engine in SynthEngineType.allCases {
            let data = try JSONEncoder().encode(engine)
            let decoded = try JSONDecoder().decode(SynthEngineType.self, from: data)
            XCTAssertEqual(engine, decoded)
        }
    }

    func testDecodableFromString() throws {
        let json = "\"Analog\""
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SynthEngineType.self, from: data)
        XCTAssertEqual(decoded, .analog)
    }

    func testInvalidRawValueReturnsNil() {
        XCTAssertNil(SynthEngineType(rawValue: "InvalidEngine"))
        XCTAssertNil(SynthEngineType(rawValue: ""))
    }
}

// MARK: - SynthFilterMode Tests

final class SynthFilterModeTests: XCTestCase {

    func testAllCases() {
        let cases = SynthFilterMode.allCases
        XCTAssertEqual(cases.count, 3)
    }

    func testRawValues() {
        XCTAssertEqual(SynthFilterMode.lowpass.rawValue, "LP")
        XCTAssertEqual(SynthFilterMode.highpass.rawValue, "HP")
        XCTAssertEqual(SynthFilterMode.bandpass.rawValue, "BP")
    }

    func testCodable() throws {
        for mode in SynthFilterMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(SynthFilterMode.self, from: data)
            XCTAssertEqual(mode, decoded)
        }
    }
}

// MARK: - BassEngineType Tests

final class BassEngineTypeTests: XCTestCase {

    func testAllCases() {
        let cases = BassEngineType.allCases
        XCTAssertEqual(cases.count, 5)
        XCTAssertTrue(cases.contains(.sub808))
        XCTAssertTrue(cases.contains(.reese))
        XCTAssertTrue(cases.contains(.moog))
        XCTAssertTrue(cases.contains(.acid))
        XCTAssertTrue(cases.contains(.growl))
    }

    func testRawValues() {
        XCTAssertEqual(BassEngineType.sub808.rawValue, "808 Sub")
        XCTAssertEqual(BassEngineType.reese.rawValue, "Reese")
        XCTAssertEqual(BassEngineType.moog.rawValue, "Moog")
        XCTAssertEqual(BassEngineType.acid.rawValue, "Acid")
        XCTAssertEqual(BassEngineType.growl.rawValue, "Growl")
    }

    func testCodable() throws {
        for engine in BassEngineType.allCases {
            let data = try JSONEncoder().encode(engine)
            let decoded = try JSONDecoder().decode(BassEngineType.self, from: data)
            XCTAssertEqual(engine, decoded)
        }
    }

    func testInvalidRawValueReturnsNil() {
        XCTAssertNil(BassEngineType(rawValue: "NotAnEngine"))
    }
}

// MARK: - PresetEngine Tests

final class PresetEngineTests: XCTestCase {

    func testAllCases() {
        XCTAssertNotNil(PresetEngine(rawValue: "EchoelDDSP"))
        XCTAssertNotNil(PresetEngine(rawValue: "EchoelModalBank"))
        XCTAssertNotNil(PresetEngine(rawValue: "EchoelCellular"))
        XCTAssertNotNil(PresetEngine(rawValue: "EchoelQuant"))
        XCTAssertNotNil(PresetEngine(rawValue: "TR808BassSynth"))
        XCTAssertNotNil(PresetEngine(rawValue: "BreakbeatChopper"))
    }

    func testRawValues() {
        XCTAssertEqual(PresetEngine.ddsp.rawValue, "EchoelDDSP")
        XCTAssertEqual(PresetEngine.modalBank.rawValue, "EchoelModalBank")
        XCTAssertEqual(PresetEngine.cellular.rawValue, "EchoelCellular")
        XCTAssertEqual(PresetEngine.quant.rawValue, "EchoelQuant")
        XCTAssertEqual(PresetEngine.tr808.rawValue, "TR808BassSynth")
        XCTAssertEqual(PresetEngine.breakbeat.rawValue, "BreakbeatChopper")
    }

    func testCodable() throws {
        let engines: [PresetEngine] = [.ddsp, .modalBank, .cellular, .quant, .tr808, .breakbeat]
        for engine in engines {
            let data = try JSONEncoder().encode(engine)
            let decoded = try JSONDecoder().decode(PresetEngine.self, from: data)
            XCTAssertEqual(engine, decoded)
        }
    }
}

// MARK: - PresetCategory Tests

final class PresetCategoryTests: XCTestCase {

    func testAllCases() {
        let cases = PresetCategory.allCases
        XCTAssertEqual(cases.count, 7)
    }

    func testRawValues() {
        XCTAssertEqual(PresetCategory.drums.rawValue, "ECHOEL_DRUMS")
        XCTAssertEqual(PresetCategory.bass.rawValue, "ECHOEL_BASS")
        XCTAssertEqual(PresetCategory.melodic.rawValue, "ECHOEL_MELODIC")
        XCTAssertEqual(PresetCategory.jungle.rawValue, "ECHOEL_JUNGLE")
        XCTAssertEqual(PresetCategory.textures.rawValue, "ECHOEL_TEXTURES")
        XCTAssertEqual(PresetCategory.fx.rawValue, "ECHOEL_FX")
        XCTAssertEqual(PresetCategory.chords.rawValue, "ECHOEL_CHORDS")
    }

    func testCodable() throws {
        for category in PresetCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(PresetCategory.self, from: data)
            XCTAssertEqual(category, decoded)
        }
    }

    func testDecodableFromString() throws {
        let json = "\"ECHOEL_DRUMS\""
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PresetCategory.self, from: data)
        XCTAssertEqual(decoded, .drums)
    }
}

// MARK: - SynthPreset Tests

final class SynthPresetTests: XCTestCase {

    func testInit() {
        let preset = SynthPreset(name: "Test Kick", category: .drums, engine: .ddsp, tags: ["kick", "hard"])
        XCTAssertEqual(preset.name, "Test Kick")
        XCTAssertEqual(preset.category, .drums)
        XCTAssertEqual(preset.engine, .ddsp)
        XCTAssertEqual(preset.tags, ["kick", "hard"])
    }

    func testDefaultValues() {
        let preset = SynthPreset(name: "Default", category: .melodic, engine: .ddsp)
        XCTAssertEqual(preset.frequency, 440)
        XCTAssertEqual(preset.amplitude, 0.8)
        XCTAssertEqual(preset.attack, 0.005)
        XCTAssertEqual(preset.decay, 0.3)
        XCTAssertEqual(preset.sustain, 0.5)
        XCTAssertEqual(preset.release, 0.3)
        XCTAssertEqual(preset.duration, 2.0)
        XCTAssertEqual(preset.harmonicCount, 16)
        XCTAssertEqual(preset.harmonicity, 1.0)
        XCTAssertEqual(preset.noiseLevel, 0.1)
        XCTAssertEqual(preset.brightness, 0.5)
        XCTAssertEqual(preset.bpm, 170)
        XCTAssertTrue(preset.patternIndices.isEmpty)
    }

    func testCodableRoundTrip() throws {
        var preset = SynthPreset(name: "Acid Bass", category: .bass, engine: .tr808, tags: ["acid", "303"])
        preset.frequency = 110
        preset.amplitude = 0.9
        preset.attack = 0.001
        preset.bpm = 140
        preset.patternIndices = [0, 1, nil, 3]

        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: data)

        XCTAssertEqual(decoded.name, "Acid Bass")
        XCTAssertEqual(decoded.category, .bass)
        XCTAssertEqual(decoded.engine, .tr808)
        XCTAssertEqual(decoded.frequency, 110)
        XCTAssertEqual(decoded.amplitude, 0.9)
        XCTAssertEqual(decoded.bpm, 140)
    }

    func testIdentifiable() {
        let preset1 = SynthPreset(name: "A", category: .drums, engine: .ddsp)
        let preset2 = SynthPreset(name: "B", category: .drums, engine: .ddsp)
        XCTAssertNotEqual(preset1.id, preset2.id)
    }

    func testBioReactiveDefaults() {
        let preset = SynthPreset(name: "Bio", category: .melodic, engine: .ddsp)
        XCTAssertEqual(preset.bioCoherenceTarget, "harmonicity")
        XCTAssertEqual(preset.bioHrvTarget, "brightness")
        XCTAssertEqual(preset.bioBreathTarget, "amplitude")
    }
}

// MARK: - SamplerInterpolation Tests

final class SamplerInterpolationTests: XCTestCase {

    func testAllCases() {
        let cases = SamplerInterpolation.allCases
        XCTAssertEqual(cases.count, 3)
    }

    func testQuality() {
        XCTAssertEqual(SamplerInterpolation.linear.quality, 1)
        XCTAssertEqual(SamplerInterpolation.hermite.quality, 2)
        XCTAssertEqual(SamplerInterpolation.sinc.quality, 3)
    }

    func testRawValues() {
        XCTAssertEqual(SamplerInterpolation.linear.rawValue, "Linear")
        XCTAssertEqual(SamplerInterpolation.hermite.rawValue, "Hermite")
        XCTAssertEqual(SamplerInterpolation.sinc.rawValue, "Sinc")
    }
}

// MARK: - SamplerFilterType Tests

final class SamplerFilterTypeTests: XCTestCase {

    func testAllCases() {
        let cases = SamplerFilterType.allCases
        XCTAssertEqual(cases.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(SamplerFilterType.lowpass.rawValue, "Lowpass")
        XCTAssertEqual(SamplerFilterType.highpass.rawValue, "Highpass")
        XCTAssertEqual(SamplerFilterType.bandpass.rawValue, "Bandpass")
        XCTAssertEqual(SamplerFilterType.notch.rawValue, "Notch")
    }
}
#endif
