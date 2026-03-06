import XCTest
import Foundation
@testable import Echoelmusic

// MARK: - BreathDetector Tests

final class BreathDetectorTests: XCTestCase {

    // MARK: - DetectionMode

    func testDetectionModeCaseCount() {
        XCTAssertEqual(BreathDetector.DetectionMode.allCases.count, 4)
    }

    func testDetectionModeRawValues() {
        XCTAssertEqual(BreathDetector.DetectionMode.detect.rawValue, "detect")
        XCTAssertEqual(BreathDetector.DetectionMode.reduce.rawValue, "reduce")
        XCTAssertEqual(BreathDetector.DetectionMode.remove.rawValue, "remove")
        XCTAssertEqual(BreathDetector.DetectionMode.replace.rawValue, "replace")
    }

    func testDetectionModeCodable() throws {
        let mode = BreathDetector.DetectionMode.reduce
        let data = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(BreathDetector.DetectionMode.self, from: data)
        XCTAssertEqual(decoded, mode)
    }

    // MARK: - Configuration

    func testConfigurationDefaults() {
        let config = BreathDetector.Configuration()
        XCTAssertEqual(config.sensitivity, 0.5)
        XCTAssertEqual(config.minimumDuration, 0.1)
        XCTAssertEqual(config.maximumDuration, 2.0)
        XCTAssertEqual(config.reductionGain, 0.0)
        XCTAssertEqual(config.crossfadeDuration, 0.01)
        XCTAssertEqual(config.mode, .remove)
    }

    func testConfigurationGentlePreset() {
        let config = BreathDetector.Configuration.gentle
        XCTAssertEqual(config.sensitivity, 0.3)
        XCTAssertEqual(config.reductionGain, 0.3)
        XCTAssertEqual(config.crossfadeDuration, 0.02)
    }

    func testConfigurationAggressivePreset() {
        let config = BreathDetector.Configuration.aggressive
        XCTAssertEqual(config.sensitivity, 0.8)
        XCTAssertEqual(config.reductionGain, 0.0)
        XCTAssertEqual(config.crossfadeDuration, 0.005)
    }

    func testConfigurationCodable() throws {
        let config = BreathDetector.Configuration.gentle
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(BreathDetector.Configuration.self, from: data)
        XCTAssertEqual(decoded.sensitivity, config.sensitivity)
        XCTAssertEqual(decoded.reductionGain, config.reductionGain)
        XCTAssertEqual(decoded.mode, config.mode)
    }

    // MARK: - BreathRegion

    func testBreathRegionDurationSamples() {
        let region = BreathDetector.BreathRegion(
            startSample: 1000,
            endSample: 5000,
            confidence: 0.8,
            peakEnergy: 0.1
        )
        XCTAssertEqual(region.durationSamples, 4000)
    }

    func testBreathRegionDurationAtSampleRate() {
        let region = BreathDetector.BreathRegion(
            startSample: 0,
            endSample: 48000,
            confidence: 0.9,
            peakEnergy: 0.05
        )
        let duration = region.duration(atSampleRate: 48000.0)
        XCTAssertEqual(duration, 1.0, accuracy: 0.001)
    }

    func testBreathRegionDurationAtDifferentSampleRate() {
        let region = BreathDetector.BreathRegion(
            startSample: 0,
            endSample: 22050,
            confidence: 0.7,
            peakEnergy: 0.02
        )
        let duration = region.duration(atSampleRate: 44100.0)
        XCTAssertEqual(duration, 0.5, accuracy: 0.001)
    }

    // MARK: - BreathDetector Initialization

    func testBreathDetectorInit() {
        let detector = BreathDetector(sampleRate: 44100, fftSize: 1024)
        XCTAssertNotNil(detector)
    }

    func testAnalyzeEmptyBuffer() {
        let detector = BreathDetector(sampleRate: 48000, fftSize: 2048)
        let regions = detector.analyzeBuffer([])
        XCTAssertTrue(regions.isEmpty)
    }

    func testAnalyzeSilentBuffer() {
        let detector = BreathDetector(sampleRate: 48000, fftSize: 2048)
        let silentBuffer = [Float](repeating: 0.0, count: 48000)
        let regions = detector.analyzeBuffer(silentBuffer)
        // Silent buffer should not detect breaths
        XCTAssertTrue(regions.isEmpty)
    }

    func testProcessBufferDetectModeReturnsOriginal() {
        var config = BreathDetector.Configuration()
        config.mode = .detect
        let detector = BreathDetector(sampleRate: 48000, fftSize: 2048, configuration: config)
        let buffer = [Float](repeating: 0.5, count: 4096)
        let result = detector.processBuffer(buffer)
        XCTAssertEqual(result.count, buffer.count)
    }

    func testReset() {
        let detector = BreathDetector()
        detector.reset()
        // Should not crash, state should be clean
        let regions = detector.analyzeBuffer([Float](repeating: 0, count: 4096))
        XCTAssertTrue(regions.isEmpty)
    }
}

// MARK: - PhaseVocoder Tests

final class PhaseVocoderTests: XCTestCase {

    func testPhaseVocoderConfigurationDefaults() {
        let config = PhaseVocoder.Configuration()
        XCTAssertEqual(config.fftSize, 4096)
        XCTAssertEqual(config.hopSize, 1024)
        XCTAssertEqual(config.sampleRate, 48000.0)
        XCTAssertTrue(config.preserveFormants)
        XCTAssertTrue(config.preserveTransients)
        XCTAssertEqual(config.formantEnvelopeOrder, 30)
    }

    func testPhaseVocoderOverlapFactor() {
        let config = PhaseVocoder.Configuration(fftSize: 4096, hopSize: 1024)
        XCTAssertEqual(config.overlapFactor, 4)

        let config2 = PhaseVocoder.Configuration(fftSize: 2048, hopSize: 512)
        XCTAssertEqual(config2.overlapFactor, 4)

        let config3 = PhaseVocoder.Configuration(fftSize: 4096, hopSize: 2048)
        XCTAssertEqual(config3.overlapFactor, 2)
    }

    func testPhaseVocoderFrameStruct() {
        let frame = PhaseVocoderFrame(
            magnitudes: [1.0, 2.0, 3.0],
            phases: [0.0, 0.5, 1.0],
            instantaneousFrequencies: [440.0, 880.0, 1320.0],
            isTransient: false,
            rmsEnergy: 0.5
        )
        XCTAssertEqual(frame.magnitudes.count, 3)
        XCTAssertFalse(frame.isTransient)
        XCTAssertEqual(frame.rmsEnergy, 0.5)
    }

    func testDetectTransientWithEmptyFrame() {
        let vocoder = PhaseVocoder()
        let result = vocoder.detectTransient([])
        XCTAssertFalse(result)
    }

    func testDetectTransientWithSingleSample() {
        let vocoder = PhaseVocoder()
        let result = vocoder.detectTransient([1.0])
        XCTAssertFalse(result)
    }
}

// MARK: - RealTimePitchCorrector Tests

final class RealTimePitchCorrectorTests: XCTestCase {

    // MARK: - ScaleType

    func testScaleTypeCaseCount() {
        XCTAssertEqual(RealTimePitchCorrector.ScaleType.allCases.count, 19)
    }

    func testScaleTypeRawValues() {
        XCTAssertEqual(RealTimePitchCorrector.ScaleType.chromatic.rawValue, "Chromatic")
        XCTAssertEqual(RealTimePitchCorrector.ScaleType.major.rawValue, "Major")
        XCTAssertEqual(RealTimePitchCorrector.ScaleType.naturalMinor.rawValue, "Natural Minor")
        XCTAssertEqual(RealTimePitchCorrector.ScaleType.blues.rawValue, "Blues")
        XCTAssertEqual(RealTimePitchCorrector.ScaleType.japanese.rawValue, "Japanese")
        XCTAssertEqual(RealTimePitchCorrector.ScaleType.hungarian.rawValue, "Hungarian Minor")
    }

    func testScaleTypeIdentifiable() {
        let scale = RealTimePitchCorrector.ScaleType.major
        XCTAssertEqual(scale.id, "Major")
    }

    func testScaleTypeCodable() throws {
        let scale = RealTimePitchCorrector.ScaleType.pentatonicMinor
        let data = try JSONEncoder().encode(scale)
        let decoded = try JSONDecoder().decode(RealTimePitchCorrector.ScaleType.self, from: data)
        XCTAssertEqual(decoded, scale)
    }

    func testChromaticScaleHas12Intervals() {
        let intervals = RealTimePitchCorrector.ScaleType.chromatic.intervals
        XCTAssertEqual(intervals.count, 12)
        XCTAssertEqual(intervals, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
    }

    func testMajorScaleIntervals() {
        let intervals = RealTimePitchCorrector.ScaleType.major.intervals
        XCTAssertEqual(intervals, [0, 2, 4, 5, 7, 9, 11])
    }

    func testPentatonicMajorScaleHas5Notes() {
        let intervals = RealTimePitchCorrector.ScaleType.pentatonicMajor.intervals
        XCTAssertEqual(intervals.count, 5)
        XCTAssertEqual(intervals, [0, 2, 4, 7, 9])
    }

    func testBluesScaleIntervals() {
        let intervals = RealTimePitchCorrector.ScaleType.blues.intervals
        XCTAssertEqual(intervals.count, 6)
        XCTAssertEqual(intervals, [0, 3, 5, 6, 7, 10])
    }

    func testAllScaleIntervalsStartAtZero() {
        for scale in RealTimePitchCorrector.ScaleType.allCases {
            XCTAssertEqual(scale.intervals.first, 0,
                           "\(scale.rawValue) should start at 0")
        }
    }

    func testAllScaleIntervalsWithinOctave() {
        for scale in RealTimePitchCorrector.ScaleType.allCases {
            for interval in scale.intervals {
                XCTAssertGreaterThanOrEqual(interval, 0)
                XCTAssertLessThanOrEqual(interval, 11,
                    "\(scale.rawValue) has interval \(interval) out of range")
            }
        }
    }

    // MARK: - Static Utility Methods

    func testMidiToNoteNameA4() {
        XCTAssertEqual(RealTimePitchCorrector.midiToNoteName(69), "A4")
    }

    func testMidiToNoteNameC4() {
        XCTAssertEqual(RealTimePitchCorrector.midiToNoteName(60), "C4")
    }

    func testMidiToNoteNameMiddleCSharp() {
        XCTAssertEqual(RealTimePitchCorrector.midiToNoteName(61), "C#4")
    }

    func testFrequencyToMidiA4() {
        let midi = RealTimePitchCorrector.frequencyToMidi(440.0)
        XCTAssertEqual(midi, 69.0, accuracy: 0.01)
    }

    func testFrequencyToMidiC4() {
        // C4 = MIDI 60, ~261.63 Hz
        let midi = RealTimePitchCorrector.frequencyToMidi(261.63)
        XCTAssertEqual(midi, 60.0, accuracy: 0.1)
    }

    func testFrequencyToMidiZero() {
        let midi = RealTimePitchCorrector.frequencyToMidi(0)
        XCTAssertEqual(midi, 0)
    }

    func testMidiToFrequencyA4() {
        let freq = RealTimePitchCorrector.midiToFrequency(69.0)
        XCTAssertEqual(freq, 440.0, accuracy: 0.01)
    }

    func testMidiToFrequencyOctaveRelationship() {
        let freqA4 = RealTimePitchCorrector.midiToFrequency(69.0)
        let freqA5 = RealTimePitchCorrector.midiToFrequency(81.0)
        XCTAssertEqual(freqA5, freqA4 * 2.0, accuracy: 0.01)
    }

    func testMidiToFrequencyRoundTrip() {
        let originalFreq: Float = 440.0
        let midi = RealTimePitchCorrector.frequencyToMidi(originalFreq)
        let roundTripped = RealTimePitchCorrector.midiToFrequency(midi)
        XCTAssertEqual(roundTripped, originalFreq, accuracy: 0.01)
    }
}

// MARK: - VibratoEngine Tests

final class VibratoEngineTests: XCTestCase {

    // MARK: - VibratoShape

    func testVibratoShapeCaseCount() {
        XCTAssertEqual(VibratoEngine.VibratoShape.allCases.count, 9)
    }

    func testVibratoShapeRawValues() {
        XCTAssertEqual(VibratoEngine.VibratoShape.sine.rawValue, "Sine")
        XCTAssertEqual(VibratoEngine.VibratoShape.triangle.rawValue, "Triangle")
        XCTAssertEqual(VibratoEngine.VibratoShape.rampUp.rawValue, "Ramp Up")
        XCTAssertEqual(VibratoEngine.VibratoShape.rampDown.rawValue, "Ramp Down")
        XCTAssertEqual(VibratoEngine.VibratoShape.human.rawValue, "Human")
        XCTAssertEqual(VibratoEngine.VibratoShape.operatic.rawValue, "Operatic")
        XCTAssertEqual(VibratoEngine.VibratoShape.gospel.rawValue, "Gospel")
        XCTAssertEqual(VibratoEngine.VibratoShape.trill.rawValue, "Trill")
        XCTAssertEqual(VibratoEngine.VibratoShape.none.rawValue, "None")
    }

    func testVibratoShapeIdentifiable() {
        let shape = VibratoEngine.VibratoShape.operatic
        XCTAssertEqual(shape.id, "Operatic")
    }

    func testVibratoShapeCodable() throws {
        let shape = VibratoEngine.VibratoShape.gospel
        let data = try JSONEncoder().encode(shape)
        let decoded = try JSONDecoder().decode(VibratoEngine.VibratoShape.self, from: data)
        XCTAssertEqual(decoded, shape)
    }

    // MARK: - VibratoParameters

    func testVibratoParametersDefault() {
        let params = VibratoEngine.VibratoParameters.default()
        XCTAssertTrue(params.enabled)
        XCTAssertEqual(params.rate, 5.5)
        XCTAssertEqual(params.depth, 40.0)
        XCTAssertEqual(params.shape, .sine)
        XCTAssertEqual(params.onsetDelay, 0.2)
        XCTAssertEqual(params.fadeInTime, 0.3)
        XCTAssertEqual(params.fadeOutTime, 0.1)
        XCTAssertEqual(params.rateVariation, 0.1)
        XCTAssertEqual(params.depthVariation, 0.1)
        XCTAssertEqual(params.phaseOffset, 0.0)
        XCTAssertEqual(params.asymmetry, 0.0)
    }

    func testVibratoParametersOperatic() {
        let params = VibratoEngine.VibratoParameters.operatic()
        XCTAssertEqual(params.rate, 5.0)
        XCTAssertEqual(params.depth, 80.0)
        XCTAssertEqual(params.shape, .operatic)
        XCTAssertEqual(params.onsetDelay, 0.3)
        XCTAssertEqual(params.fadeInTime, 0.5)
    }

    func testVibratoParametersPop() {
        let params = VibratoEngine.VibratoParameters.pop()
        XCTAssertEqual(params.rate, 6.0)
        XCTAssertEqual(params.depth, 30.0)
        XCTAssertEqual(params.shape, .sine)
        XCTAssertEqual(params.onsetDelay, 0.15)
    }

    func testVibratoParametersGospel() {
        let params = VibratoEngine.VibratoParameters.gospel()
        XCTAssertEqual(params.rate, 6.5)
        XCTAssertEqual(params.depth, 60.0)
        XCTAssertEqual(params.shape, .gospel)
        XCTAssertEqual(params.rateVariation, 0.2)
    }

    func testVibratoParametersStraight() {
        let params = VibratoEngine.VibratoParameters.straight()
        XCTAssertFalse(params.enabled)
        XCTAssertEqual(params.depth, 0)
        XCTAssertEqual(params.shape, .none)
    }

    func testVibratoParametersCodable() throws {
        let params = VibratoEngine.VibratoParameters.operatic()
        let data = try JSONEncoder().encode(params)
        let decoded = try JSONDecoder().decode(VibratoEngine.VibratoParameters.self, from: data)
        XCTAssertEqual(decoded.rate, params.rate)
        XCTAssertEqual(decoded.depth, params.depth)
        XCTAssertEqual(decoded.shape, params.shape)
    }
}

// MARK: - VocalDoublingEngine Tests

final class VocalDoublingEngineTests: XCTestCase {

    // MARK: - DoublingStyle

    func testDoublingStyleCaseCount() {
        XCTAssertEqual(VocalDoublingEngine.DoublingStyle.allCases.count, 5)
    }

    func testDoublingStyleRawValues() {
        XCTAssertEqual(VocalDoublingEngine.DoublingStyle.natural.rawValue, "natural")
        XCTAssertEqual(VocalDoublingEngine.DoublingStyle.tight.rawValue, "tight")
        XCTAssertEqual(VocalDoublingEngine.DoublingStyle.wide.rawValue, "wide")
        XCTAssertEqual(VocalDoublingEngine.DoublingStyle.chorus.rawValue, "chorus")
        XCTAssertEqual(VocalDoublingEngine.DoublingStyle.slap.rawValue, "slap")
    }

    func testDoublingStyleCodable() throws {
        let style = VocalDoublingEngine.DoublingStyle.chorus
        let data = try JSONEncoder().encode(style)
        let decoded = try JSONDecoder().decode(VocalDoublingEngine.DoublingStyle.self, from: data)
        XCTAssertEqual(decoded, style)
    }

    // MARK: - DoublingVoice

    func testDoublingVoiceDefaults() {
        let voice = VocalDoublingEngine.DoublingVoice()
        XCTAssertEqual(voice.detuningCents, 7.0)
        XCTAssertEqual(voice.delayMs, 15.0)
        XCTAssertEqual(voice.gain, 0.7)
        XCTAssertEqual(voice.pan, 0.0)
        XCTAssertEqual(voice.formantShift, 0.0)
        XCTAssertTrue(voice.enabled)
        XCTAssertEqual(voice.pitchModRate, 0.5)
        XCTAssertEqual(voice.pitchModDepth, 2.0)
        XCTAssertEqual(voice.delayModRate, 0.3)
        XCTAssertEqual(voice.delayModDepth, 2.0)
    }

    func testDoublingVoiceCodable() throws {
        let voice = VocalDoublingEngine.DoublingVoice(
            detuningCents: 10.0, delayMs: 20.0, gain: 0.5, pan: -0.5
        )
        let data = try JSONEncoder().encode(voice)
        let decoded = try JSONDecoder().decode(VocalDoublingEngine.DoublingVoice.self, from: data)
        XCTAssertEqual(decoded.detuningCents, 10.0)
        XCTAssertEqual(decoded.delayMs, 20.0)
        XCTAssertEqual(decoded.pan, -0.5)
    }

    // MARK: - Configuration Presets

    func testNaturalConfigurationHasTwoVoices() {
        let config = VocalDoublingEngine.Configuration.natural
        XCTAssertEqual(config.voices.count, 2)
        XCTAssertEqual(config.style, .natural)
    }

    func testTightConfigurationHasTwoVoices() {
        let config = VocalDoublingEngine.Configuration.tight
        XCTAssertEqual(config.voices.count, 2)
        XCTAssertEqual(config.style, .tight)
    }

    func testWideConfigurationFullWidth() {
        let config = VocalDoublingEngine.Configuration.wide
        XCTAssertEqual(config.stereoWidth, 1.0)
    }

    func testChorusConfigurationHasThreeVoices() {
        let config = VocalDoublingEngine.Configuration.chorus
        XCTAssertEqual(config.voices.count, 3)
    }

    func testSlapConfigurationZeroDetune() {
        let config = VocalDoublingEngine.Configuration.slap
        for voice in config.voices {
            XCTAssertEqual(voice.detuningCents, 0.0)
        }
    }
}

// MARK: - VocalHarmonyGenerator Tests

final class VocalHarmonyGeneratorTests: XCTestCase {

    // MARK: - HarmonyMode

    func testHarmonyModeCaseCount() {
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyMode.allCases.count, 4)
    }

    func testHarmonyModeRawValues() {
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyMode.diatonic.rawValue, "diatonic")
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyMode.chromatic.rawValue, "chromatic")
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyMode.midi.rawValue, "midi")
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyMode.intelligent.rawValue, "intelligent")
    }

    func testHarmonyModeCodable() throws {
        let mode = VocalHarmonyGenerator.HarmonyMode.diatonic
        let data = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(VocalHarmonyGenerator.HarmonyMode.self, from: data)
        XCTAssertEqual(decoded, mode)
    }

    // MARK: - HarmonyInterval

    func testHarmonyIntervalCaseCount() {
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.allCases.count, 13)
    }

    func testHarmonyIntervalRawValues() {
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.unison.rawValue, 0)
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.minorThird.rawValue, 3)
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.majorThird.rawValue, 4)
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.perfectFourth.rawValue, 5)
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.tritone.rawValue, 6)
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.perfectFifth.rawValue, 7)
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.octave.rawValue, 12)
    }

    func testHarmonyIntervalNames() {
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.unison.name, "Unison")
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.majorThird.name, "Major 3rd")
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.perfectFifth.name, "Perfect 5th")
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.octave.name, "Octave")
        XCTAssertEqual(VocalHarmonyGenerator.HarmonyInterval.tritone.name, "Tritone")
    }

    func testHarmonyIntervalCodable() throws {
        let interval = VocalHarmonyGenerator.HarmonyInterval.perfectFifth
        let data = try JSONEncoder().encode(interval)
        let decoded = try JSONDecoder().decode(VocalHarmonyGenerator.HarmonyInterval.self, from: data)
        XCTAssertEqual(decoded, interval)
    }

    // MARK: - HarmonyVoice

    func testHarmonyVoiceDefaults() {
        let voice = VocalHarmonyGenerator.HarmonyVoice()
        XCTAssertEqual(voice.interval, .majorThird)
        XCTAssertEqual(voice.customSemitones, 0.0)
        XCTAssertEqual(voice.gain, 0.7)
        XCTAssertEqual(voice.pan, 0.0)
        XCTAssertEqual(voice.formantShift, 0.0)
        XCTAssertEqual(voice.delay, 0.0)
        XCTAssertTrue(voice.enabled)
    }

    // MARK: - ScaleType

    func testHarmonyScaleTypeCaseCount() {
        XCTAssertEqual(VocalHarmonyGenerator.ScaleType.allCases.count, 13)
    }

    func testHarmonyScaleMajorIntervals() {
        XCTAssertEqual(VocalHarmonyGenerator.ScaleType.major.intervals, [0, 2, 4, 5, 7, 9, 11])
    }

    func testHarmonyScaleMinorIntervals() {
        XCTAssertEqual(VocalHarmonyGenerator.ScaleType.minor.intervals, [0, 2, 3, 5, 7, 8, 10])
    }

    func testHarmonyScaleBluesIntervals() {
        XCTAssertEqual(VocalHarmonyGenerator.ScaleType.blues.intervals, [0, 3, 5, 6, 7, 10])
    }

    func testHarmonyScalePentatonicMajorHas5Notes() {
        XCTAssertEqual(VocalHarmonyGenerator.ScaleType.pentatonicMajor.intervals.count, 5)
    }

    // MARK: - Configuration Presets

    func testDefaultConfigurationHasTwoVoices() {
        let config = VocalHarmonyGenerator.Configuration.default
        XCTAssertEqual(config.voices.count, 2)
        XCTAssertEqual(config.mode, .diatonic)
        XCTAssertEqual(config.dryWet, 0.5)
    }

    func testOctavesConfigurationHasTwoVoices() {
        let config = VocalHarmonyGenerator.Configuration.octaves
        XCTAssertEqual(config.voices.count, 2)
    }

    func testChoirStackConfigurationHasThreeVoices() {
        let config = VocalHarmonyGenerator.Configuration.choirStack
        XCTAssertEqual(config.voices.count, 3)
    }
}

// MARK: - NodeType Tests

final class NodeTypeTests: XCTestCase {

    func testNodeTypeRawValues() {
        XCTAssertEqual(NodeType.generator.rawValue, "generator")
        XCTAssertEqual(NodeType.effect.rawValue, "effect")
        XCTAssertEqual(NodeType.analyzer.rawValue, "analyzer")
        XCTAssertEqual(NodeType.mixer.rawValue, "mixer")
        XCTAssertEqual(NodeType.utility.rawValue, "utility")
        XCTAssertEqual(NodeType.output.rawValue, "output")
        XCTAssertEqual(NodeType.input.rawValue, "input")
        XCTAssertEqual(NodeType.reverb.rawValue, "reverb")
        XCTAssertEqual(NodeType.delay.rawValue, "delay")
        XCTAssertEqual(NodeType.filter.rawValue, "filter")
    }

    func testNodeTypeCodable() throws {
        let type = NodeType.effect
        let data = try JSONEncoder().encode(type)
        let decoded = try JSONDecoder().decode(NodeType.self, from: data)
        XCTAssertEqual(decoded, type)
    }
}

// MARK: - BioSignal Tests

final class BioSignalTests: XCTestCase {

    func testBioSignalDefaultInit() {
        let signal = BioSignal()
        XCTAssertEqual(signal.hrv, 0)
        XCTAssertEqual(signal.heartRate, 60)
        XCTAssertEqual(signal.coherence, 50)
        XCTAssertNil(signal.respiratoryRate)
        XCTAssertEqual(signal.audioLevel, 0)
        XCTAssertEqual(signal.voicePitch, 0)
        XCTAssertTrue(signal.customData.isEmpty)
    }

    func testBioSignalCustomInit() {
        let signal = BioSignal(
            hrv: 65.0,
            heartRate: 72.0,
            coherence: 80.0,
            respiratoryRate: 16.0,
            audioLevel: 0.5,
            voicePitch: 220.0
        )
        XCTAssertEqual(signal.hrv, 65.0)
        XCTAssertEqual(signal.heartRate, 72.0)
        XCTAssertEqual(signal.coherence, 80.0)
        XCTAssertEqual(signal.respiratoryRate, 16.0)
        XCTAssertEqual(signal.audioLevel, 0.5)
        XCTAssertEqual(signal.voicePitch, 220.0)
    }
}

// MARK: - NodeParameter Tests

final class NodeParameterTests: XCTestCase {

    func testNodeParameterInit() {
        let param = NodeParameter(
            name: "cutoff",
            label: "Cutoff Frequency",
            value: 1000.0,
            min: 20.0,
            max: 20000.0,
            defaultValue: 1000.0,
            unit: "Hz",
            isAutomatable: true,
            type: .continuous
        )
        XCTAssertEqual(param.name, "cutoff")
        XCTAssertEqual(param.label, "Cutoff Frequency")
        XCTAssertEqual(param.value, 1000.0)
        XCTAssertEqual(param.min, 20.0)
        XCTAssertEqual(param.max, 20000.0)
        XCTAssertEqual(param.defaultValue, 1000.0)
        XCTAssertEqual(param.unit, "Hz")
        XCTAssertTrue(param.isAutomatable)
    }

    func testNodeParameterIdentifiable() {
        let param1 = NodeParameter(
            name: "a", label: "A", value: 0, min: 0, max: 1,
            defaultValue: 0, unit: nil, isAutomatable: false, type: .toggle
        )
        let param2 = NodeParameter(
            name: "b", label: "B", value: 0, min: 0, max: 1,
            defaultValue: 0, unit: nil, isAutomatable: false, type: .toggle
        )
        XCTAssertNotEqual(param1.id, param2.id)
    }
}

// MARK: - NodeManifest Tests

final class NodeManifestTests: XCTestCase {

    func testNodeManifestCodable() throws {
        let manifest = NodeManifest(
            id: "test-id",
            type: .effect,
            className: "FilterNode",
            version: "1.0",
            parameters: ["cutoff": 1000.0, "resonance": 0.707],
            isBypassed: false,
            metadata: ["author": "Echoel"]
        )
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(NodeManifest.self, from: data)
        XCTAssertEqual(decoded.id, "test-id")
        XCTAssertEqual(decoded.type, .effect)
        XCTAssertEqual(decoded.className, "FilterNode")
        XCTAssertEqual(decoded.version, "1.0")
        XCTAssertEqual(decoded.parameters["cutoff"], 1000.0)
        XCTAssertEqual(decoded.parameters["resonance"], 0.707)
        XCTAssertFalse(decoded.isBypassed)
        XCTAssertEqual(decoded.metadata?["author"], "Echoel")
    }
}

// MARK: - ProVocalChain Tests

final class ProVocalChainTests: XCTestCase {

    func testProcessingModeCaseCount() {
        XCTAssertEqual(ProVocalChain.ProcessingMode.allCases.count, 3)
    }

    func testProcessingModeRawValues() {
        XCTAssertEqual(ProVocalChain.ProcessingMode.live.rawValue, "Live")
        XCTAssertEqual(ProVocalChain.ProcessingMode.studio.rawValue, "Studio")
        XCTAssertEqual(ProVocalChain.ProcessingMode.bioReactive.rawValue, "Bio-Reactive")
    }

    func testProcessingModeIdentifiable() {
        let mode = ProVocalChain.ProcessingMode.live
        XCTAssertEqual(mode.id, "Live")
    }

    func testVocalPresetCaseCount() {
        XCTAssertEqual(ProVocalChain.VocalPreset.allCases.count, 8)
    }

    func testVocalPresetRawValues() {
        XCTAssertEqual(ProVocalChain.VocalPreset.natural.rawValue, "Natural")
        XCTAssertEqual(ProVocalChain.VocalPreset.pop.rawValue, "Pop")
        XCTAssertEqual(ProVocalChain.VocalPreset.autoTune.rawValue, "Auto-Tune")
        XCTAssertEqual(ProVocalChain.VocalPreset.hardTune.rawValue, "Hard Tune")
        XCTAssertEqual(ProVocalChain.VocalPreset.warmVintage.rawValue, "Warm Vintage")
        XCTAssertEqual(ProVocalChain.VocalPreset.operatic.rawValue, "Operatic")
        XCTAssertEqual(ProVocalChain.VocalPreset.meditation.rawValue, "Meditation")
        XCTAssertEqual(ProVocalChain.VocalPreset.bioReactivePerformance.rawValue, "Bio Performance")
    }

    func testProcessingStatsDefaults() {
        let stats = ProVocalChain.ProcessingStats()
        XCTAssertEqual(stats.latencyMs, 0)
        XCTAssertEqual(stats.cpuUsage, 0)
        XCTAssertEqual(stats.pitchDetectionConfidence, 0)
        XCTAssertEqual(stats.correctionApplied, 0)
        XCTAssertFalse(stats.bioModulationActive)
    }

    func testChainConfigurationPresets() {
        let lowLatency = ProVocalChain.ChainConfiguration.lowLatency
        XCTAssertEqual(lowLatency.blockSize, 256)
        XCTAssertEqual(lowLatency.fftSize, 2048)

        let balanced = ProVocalChain.ChainConfiguration.balanced
        XCTAssertEqual(balanced.blockSize, 512)
        XCTAssertEqual(balanced.fftSize, 4096)

        let highQuality = ProVocalChain.ChainConfiguration.highQuality
        XCTAssertEqual(highQuality.blockSize, 1024)
        XCTAssertEqual(highQuality.fftSize, 8192)
    }
}

// MARK: - VocalPostProcessor Tests

final class VocalPostProcessorTests: XCTestCase {

    // MARK: - VocalNote

    func testVocalNoteCreate() {
        let note = VocalPostProcessor.VocalNote.create(
            startTime: 1.0,
            endTime: 2.5,
            pitch: 440.0,
            midiNote: 69,
            contour: [440.0, 441.0, 439.0]
        )
        XCTAssertEqual(note.startTime, 1.0)
        XCTAssertEqual(note.endTime, 2.5)
        XCTAssertEqual(note.originalPitch, 440.0)
        XCTAssertEqual(note.editedPitch, 440.0)
        XCTAssertEqual(note.midiNote, 69)
        XCTAssertEqual(note.noteName, "A4")
        XCTAssertEqual(note.pitchCorrection, 0)
        XCTAssertEqual(note.transpose, 0)
        XCTAssertEqual(note.gain, 1.0)
        XCTAssertEqual(note.pan, 0)
        XCTAssertNil(note.editedPitchContour)
        XCTAssertEqual(note.pitchDriftStart, 0)
        XCTAssertEqual(note.pitchDriftEnd, 0)
        XCTAssertEqual(note.driftDuration, 0.05)
    }

    func testVocalNoteDuration() {
        let note = VocalPostProcessor.VocalNote.create(
            startTime: 1.0,
            endTime: 3.0,
            pitch: 440.0,
            midiNote: 69,
            contour: [440.0]
        )
        XCTAssertEqual(note.duration, 2.0)
    }

    func testVocalNoteCreateC4() {
        let note = VocalPostProcessor.VocalNote.create(
            startTime: 0,
            endTime: 1.0,
            pitch: 261.63,
            midiNote: 60,
            contour: [261.63]
        )
        XCTAssertEqual(note.noteName, "C4")
    }

    // MARK: - PitchPoint

    func testPitchPointInit() {
        let point = VocalPostProcessor.PitchPoint(time: 1.5, pitch: 440.0)
        XCTAssertEqual(point.time, 1.5)
        XCTAssertEqual(point.pitch, 440.0)
        XCTAssertFalse(point.isAnchor)
    }

    func testPitchPointAnchor() {
        let point = VocalPostProcessor.PitchPoint(time: 2.0, pitch: 880.0, isAnchor: true)
        XCTAssertTrue(point.isAnchor)
    }

    // MARK: - AutomationParameter

    func testAutomationParameterRanges() {
        let pitchRange = VocalPostProcessor.AutomationLane.AutomationParameter.pitchCorrection.range
        XCTAssertEqual(pitchRange.lowerBound, -100)
        XCTAssertEqual(pitchRange.upperBound, 100)

        let gainRange = VocalPostProcessor.AutomationLane.AutomationParameter.gain.range
        XCTAssertEqual(gainRange.lowerBound, 0)
        XCTAssertEqual(gainRange.upperBound, 2)

        let panRange = VocalPostProcessor.AutomationLane.AutomationParameter.pan.range
        XCTAssertEqual(panRange.lowerBound, -1)
        XCTAssertEqual(panRange.upperBound, 1)

        let breathRange = VocalPostProcessor.AutomationLane.AutomationParameter.breathiness.range
        XCTAssertEqual(breathRange.lowerBound, 0)
        XCTAssertEqual(breathRange.upperBound, 1)

        let vibratoDepthRange = VocalPostProcessor.AutomationLane.AutomationParameter.vibratoDepth.range
        XCTAssertEqual(vibratoDepthRange.lowerBound, 0)
        XCTAssertEqual(vibratoDepthRange.upperBound, 200)

        let formantRange = VocalPostProcessor.AutomationLane.AutomationParameter.formantShift.range
        XCTAssertEqual(formantRange.lowerBound, -12)
        XCTAssertEqual(formantRange.upperBound, 12)
    }

    func testAutomationParameterIdentifiable() {
        let param = VocalPostProcessor.AutomationLane.AutomationParameter.gain
        XCTAssertEqual(param.id, "Gain")
    }

    func testAutomationParameterCaseCount() {
        XCTAssertEqual(VocalPostProcessor.AutomationLane.AutomationParameter.allCases.count, 8)
    }

    // MARK: - AutomationPoint CurveType

    func testCurveTypeCaseCount() {
        XCTAssertEqual(VocalPostProcessor.AutomationLane.AutomationPoint.CurveType.allCases.count, 4)
    }

    func testCurveTypeRawValues() {
        XCTAssertEqual(VocalPostProcessor.AutomationLane.AutomationPoint.CurveType.linear.rawValue, "Linear")
        XCTAssertEqual(VocalPostProcessor.AutomationLane.AutomationPoint.CurveType.smooth.rawValue, "Smooth")
        XCTAssertEqual(VocalPostProcessor.AutomationLane.AutomationPoint.CurveType.stepBefore.rawValue, "Step")
        XCTAssertEqual(VocalPostProcessor.AutomationLane.AutomationPoint.CurveType.exponential.rawValue, "Exp")
    }

    func testAutomationPointInit() {
        let point = VocalPostProcessor.AutomationLane.AutomationPoint(
            time: 1.0, value: 0.5, curveType: .smooth
        )
        XCTAssertEqual(point.time, 1.0)
        XCTAssertEqual(point.value, 0.5)
    }
}

// MARK: - NodeGraphError Tests

final class NodeGraphErrorTests: XCTestCase {

    func testNodeGraphErrorDescriptions() {
        let notFound = NodeGraph.NodeGraphError.nodeNotFound
        XCTAssertEqual(notFound.errorDescription, "Node not found in graph")

        let circular = NodeGraph.NodeGraphError.circularDependency
        XCTAssertEqual(circular.errorDescription, "Connection would create circular dependency")

        let invalid = NodeGraph.NodeGraphError.invalidConnection
        XCTAssertEqual(invalid.errorDescription, "Invalid node connection")
    }
}

// MARK: - DelayNode.MusicalSubdivision Tests

final class MusicalSubdivisionTests: XCTestCase {

    func testSubdivisionMultipliers() {
        XCTAssertEqual(DelayNode.MusicalSubdivision.whole.multiplier, 4.0)
        XCTAssertEqual(DelayNode.MusicalSubdivision.half.multiplier, 2.0)
        XCTAssertEqual(DelayNode.MusicalSubdivision.quarter.multiplier, 1.0)
        XCTAssertEqual(DelayNode.MusicalSubdivision.eighth.multiplier, 0.5)
        XCTAssertEqual(DelayNode.MusicalSubdivision.sixteenth.multiplier, 0.25)
        XCTAssertEqual(DelayNode.MusicalSubdivision.triplet.multiplier, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testSubdivisionRelationships() {
        let whole = DelayNode.MusicalSubdivision.whole.multiplier
        let half = DelayNode.MusicalSubdivision.half.multiplier
        let quarter = DelayNode.MusicalSubdivision.quarter.multiplier
        let eighth = DelayNode.MusicalSubdivision.eighth.multiplier
        let sixteenth = DelayNode.MusicalSubdivision.sixteenth.multiplier

        XCTAssertEqual(whole, half * 2)
        XCTAssertEqual(half, quarter * 2)
        XCTAssertEqual(quarter, eighth * 2)
        XCTAssertEqual(eighth, sixteenth * 2)
    }
}

// MARK: - CompressorNode.DetectionMode Tests

final class CompressorDetectionModeTests: XCTestCase {

    func testDetectionModeCaseCount() {
        XCTAssertEqual(CompressorNode.DetectionMode.allCases.count, 2)
    }

    func testDetectionModeRawValues() {
        XCTAssertEqual(CompressorNode.DetectionMode.peak.rawValue, "Peak")
        XCTAssertEqual(CompressorNode.DetectionMode.rms.rawValue, "RMS")
    }
}

// MARK: - FilterNode.FilterType Tests

final class FilterTypeTests: XCTestCase {

    func testFilterTypeCaseCount() {
        XCTAssertEqual(FilterNode.FilterType.allCases.count, 4)
    }

    func testFilterTypeRawValues() {
        XCTAssertEqual(FilterNode.FilterType.lowPass.rawValue, "Low Pass")
        XCTAssertEqual(FilterNode.FilterType.highPass.rawValue, "High Pass")
        XCTAssertEqual(FilterNode.FilterType.bandPass.rawValue, "Band Pass")
        XCTAssertEqual(FilterNode.FilterType.notch.rawValue, "Notch")
    }
}

// MARK: - NodeFactory Tests

final class NodeFactoryTests: XCTestCase {

    func testAvailableNodeClasses() {
        let classes = NodeFactory.availableNodeClasses
        XCTAssertEqual(classes.count, 4)
        XCTAssertTrue(classes.contains("FilterNode"))
        XCTAssertTrue(classes.contains("ReverbNode"))
        XCTAssertTrue(classes.contains("DelayNode"))
        XCTAssertTrue(classes.contains("CompressorNode"))
    }
}

// MARK: - EqualPowerPan Tests

final class EqualPowerPanTests: XCTestCase {

    func testCenterPanEqualGains() {
        let (left, right) = equalPowerPan(pan: 0.0, volume: 1.0)
        XCTAssertEqual(left, right, accuracy: 0.01)
    }

    func testFullLeftPan() {
        let (left, right) = equalPowerPan(pan: -1.0, volume: 1.0)
        XCTAssertGreaterThan(left, right)
        XCTAssertEqual(right, 0.0, accuracy: 0.01)
    }

    func testFullRightPan() {
        let (left, right) = equalPowerPan(pan: 1.0, volume: 1.0)
        XCTAssertGreaterThan(right, left)
        XCTAssertEqual(left, 0.0, accuracy: 0.01)
    }

    func testZeroVolume() {
        let (left, right) = equalPowerPan(pan: 0.5, volume: 0.0)
        XCTAssertEqual(left, 0.0, accuracy: 0.001)
        XCTAssertEqual(right, 0.0, accuracy: 0.001)
    }
}
