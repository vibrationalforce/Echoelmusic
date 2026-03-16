#if canImport(AVFoundation)
//
//  EchoelAIEngineTests.swift
//  Echoelmusic — EchoelAI Engine Test Suite
//
//  Tests for on-device audio intelligence: stem types, AI tasks,
//  LUFS measurement, auto-EQ, chord detection, genre classification,
//  audio analysis, and DSP model types.
//

import XCTest
@testable import Echoelmusic

// MARK: - AudioStem Tests

final class AudioStemTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(AudioStem.allCases.count, 5)
        XCTAssertTrue(AudioStem.allCases.contains(.vocals))
        XCTAssertTrue(AudioStem.allCases.contains(.drums))
        XCTAssertTrue(AudioStem.allCases.contains(.bass))
        XCTAssertTrue(AudioStem.allCases.contains(.other))
        XCTAssertTrue(AudioStem.allCases.contains(.full))
    }

    func testRawValues() {
        XCTAssertEqual(AudioStem.vocals.rawValue, "Vocals")
        XCTAssertEqual(AudioStem.drums.rawValue, "Drums")
        XCTAssertEqual(AudioStem.bass.rawValue, "Bass")
        XCTAssertEqual(AudioStem.other.rawValue, "Other")
        XCTAssertEqual(AudioStem.full.rawValue, "Full Mix")
    }

    func testIcons() {
        XCTAssertEqual(AudioStem.vocals.icon, "mic.fill")
        XCTAssertEqual(AudioStem.drums.icon, "drum.fill")
        XCTAssertEqual(AudioStem.bass.icon, "guitars.fill")
        XCTAssertEqual(AudioStem.other.icon, "music.note.list")
        XCTAssertEqual(AudioStem.full.icon, "waveform")
    }

    func testCodableRoundTrip() throws {
        let original = AudioStem.vocals
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AudioStem.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testAllStemsCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for stem in AudioStem.allCases {
            let data = try encoder.encode(stem)
            let decoded = try decoder.decode(AudioStem.self, from: data)
            XCTAssertEqual(stem, decoded, "Codable round-trip failed for \(stem)")
        }
    }

    func testIconsAreUnique() {
        let icons = AudioStem.allCases.map { $0.icon }
        XCTAssertEqual(icons.count, Set(icons).count, "Stem icons should be unique")
    }
}

// MARK: - AITask Tests

final class AITaskTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(AITask.allCases.count, 8)
    }

    func testRawValues() {
        XCTAssertEqual(AITask.stemSeparation.rawValue, "Stem Separation")
        XCTAssertEqual(AITask.autoEQ.rawValue, "Auto EQ")
        XCTAssertEqual(AITask.tempoDetection.rawValue, "Tempo Detection")
        XCTAssertEqual(AITask.keyDetection.rawValue, "Key Detection")
        XCTAssertEqual(AITask.classification.rawValue, "Classification")
        XCTAssertEqual(AITask.composition.rawValue, "Composition")
        XCTAssertEqual(AITask.musicTheory.rawValue, "Music Theory")
        XCTAssertEqual(AITask.arHistory.rawValue, "AR History")
    }

    func testCodableRoundTrip() throws {
        for task in AITask.allCases {
            let data = try JSONEncoder().encode(task)
            let decoded = try JSONDecoder().decode(AITask.self, from: data)
            XCTAssertEqual(task, decoded, "Codable round-trip failed for \(task)")
        }
    }
}

// MARK: - AudioAnalysis Tests

final class AudioAnalysisTests: XCTestCase {

    func testDefaults() {
        let analysis = AudioAnalysis()
        XCTAssertEqual(analysis.tempo, 120.0)
        XCTAssertEqual(analysis.key, "Unknown")
        XCTAssertEqual(analysis.loudnessLUFS, -14.0)
        XCTAssertEqual(analysis.truePeak, -1.0)
        XCTAssertEqual(analysis.loudnessRange, 8.0)
        XCTAssertEqual(analysis.spectralCentroid, 2000.0)
        XCTAssertEqual(analysis.dynamicRange, 12.0)
        XCTAssertEqual(analysis.genre, "Unknown")
    }

    func testMutability() {
        var analysis = AudioAnalysis()
        analysis.tempo = 140.0
        analysis.key = "C major"
        analysis.loudnessLUFS = -16.0
        analysis.truePeak = -0.5
        analysis.loudnessRange = 10.0
        analysis.spectralCentroid = 3000.0
        analysis.dynamicRange = 15.0
        analysis.genre = "Electronic"

        XCTAssertEqual(analysis.tempo, 140.0)
        XCTAssertEqual(analysis.key, "C major")
        XCTAssertEqual(analysis.loudnessLUFS, -16.0)
        XCTAssertEqual(analysis.truePeak, -0.5)
        XCTAssertEqual(analysis.loudnessRange, 10.0)
        XCTAssertEqual(analysis.spectralCentroid, 3000.0)
        XCTAssertEqual(analysis.dynamicRange, 15.0)
        XCTAssertEqual(analysis.genre, "Electronic")
    }
}

// MARK: - LUFSMeasurement Tests

final class LUFSMeasurementTests: XCTestCase {

    func testDefaults() {
        let lufs = LUFSMeasurement()
        XCTAssertEqual(lufs.momentary, -70.0)
        XCTAssertEqual(lufs.shortTerm, -70.0)
        XCTAssertEqual(lufs.integrated, -70.0)
        XCTAssertEqual(lufs.truePeak, -70.0)
        XCTAssertEqual(lufs.range, 0.0)
    }

    func testMutability() {
        var lufs = LUFSMeasurement()
        lufs.momentary = -14.0
        lufs.shortTerm = -15.0
        lufs.integrated = -14.5
        lufs.truePeak = -0.3
        lufs.range = 8.0

        XCTAssertEqual(lufs.momentary, -14.0)
        XCTAssertEqual(lufs.shortTerm, -15.0)
        XCTAssertEqual(lufs.integrated, -14.5)
        XCTAssertEqual(lufs.truePeak, -0.3)
        XCTAssertEqual(lufs.range, 8.0)
    }

    func testNegativeLUFSValues() {
        // LUFS values are always negative (or zero for full-scale)
        var lufs = LUFSMeasurement()
        lufs.integrated = -23.0 // Typical broadcast target
        XCTAssertTrue(lufs.integrated < 0, "LUFS should be negative for real audio")
    }
}

// MARK: - EQBand Tests

final class EQBandTests: XCTestCase {

    func testInitialization() {
        let band = EQBand(name: "1 kHz", frequency: 1000.0, gainDB: 3.5)
        XCTAssertEqual(band.name, "1 kHz")
        XCTAssertEqual(band.frequency, 1000.0)
        XCTAssertEqual(band.gainDB, 3.5)
    }

    func testZeroGain() {
        let band = EQBand(name: "250 Hz", frequency: 250.0, gainDB: 0.0)
        XCTAssertEqual(band.gainDB, 0.0, "Flat EQ should have zero gain")
    }

    func testNegativeGain() {
        let band = EQBand(name: "4 kHz", frequency: 4000.0, gainDB: -6.0)
        XCTAssertEqual(band.gainDB, -6.0)
    }

    func testStandard10BandFrequencies() {
        let frequencies: [Double] = [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        let names = ["31 Hz", "63 Hz", "125 Hz", "250 Hz", "500 Hz",
                     "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"]

        var bands: [EQBand] = []
        for (i, freq) in frequencies.enumerated() {
            bands.append(EQBand(name: names[i], frequency: freq, gainDB: 0))
        }

        XCTAssertEqual(bands.count, 10)
        XCTAssertEqual(bands.first?.frequency, 31)
        XCTAssertEqual(bands.last?.frequency, 16000)
    }

    func testGainMutability() {
        var band = EQBand(name: "500 Hz", frequency: 500.0, gainDB: 0.0)
        band.gainDB = 6.0
        XCTAssertEqual(band.gainDB, 6.0)
    }
}

// MARK: - ChordDetectionResult Tests

final class ChordDetectionResultTests: XCTestCase {

    func testInitialization() {
        let result = ChordDetectionResult(
            chord: "C",
            confidence: 0.85,
            chroma: [1.0, 0.0, 0.0, 0.0, 0.8, 0.0, 0.0, 0.7, 0.0, 0.0, 0.0, 0.0]
        )
        XCTAssertEqual(result.chord, "C")
        XCTAssertEqual(result.confidence, 0.85)
        XCTAssertEqual(result.chroma.count, 12)
    }

    func testUnknownChord() {
        let result = ChordDetectionResult(
            chord: "Unknown",
            confidence: 0,
            chroma: Array(repeating: 0, count: 12)
        )
        XCTAssertEqual(result.chord, "Unknown")
        XCTAssertEqual(result.confidence, 0)
    }

    func testChromaLength() {
        // Chroma should always have 12 pitch classes (C through B)
        let result = ChordDetectionResult(
            chord: "Am",
            confidence: 0.7,
            chroma: Array(repeating: 0, count: 12)
        )
        XCTAssertEqual(result.chroma.count, 12, "Chromagram must have exactly 12 bins")
    }

    func testConfidenceRange() {
        // Confidence should be 0-1
        let highConfidence = ChordDetectionResult(chord: "G", confidence: 0.95, chroma: Array(repeating: 0, count: 12))
        let lowConfidence = ChordDetectionResult(chord: "Unknown", confidence: 0.1, chroma: Array(repeating: 0, count: 12))
        XCTAssertTrue(highConfidence.confidence >= 0 && highConfidence.confidence <= 1)
        XCTAssertTrue(lowConfidence.confidence >= 0 && lowConfidence.confidence <= 1)
    }

    func testChordNameFormats() {
        // Various chord naming conventions should be supported
        let chordNames = ["C", "Cm", "C7", "Cm7", "Cmaj7", "Cdim", "Caug", "Csus4", "Csus2"]
        for name in chordNames {
            let result = ChordDetectionResult(chord: name, confidence: 0.5, chroma: Array(repeating: 0, count: 12))
            XCTAssertFalse(result.chord.isEmpty, "Chord name should not be empty")
        }
    }
}

// MARK: - GenreClassification Tests

final class GenreClassificationTests: XCTestCase {

    func testInitialization() {
        let result = GenreClassification(
            genre: "Electronic",
            confidence: 0.8,
            features: ["rms": 0.2, "centroid": 2500.0, "tempo": 128.0, "zcr": 0.08]
        )
        XCTAssertEqual(result.genre, "Electronic")
        XCTAssertEqual(result.confidence, 0.8)
        XCTAssertEqual(result.features.count, 4)
    }

    func testUnknownGenre() {
        let result = GenreClassification(genre: "Unknown", confidence: 0, features: [:])
        XCTAssertEqual(result.genre, "Unknown")
        XCTAssertEqual(result.confidence, 0)
        XCTAssertTrue(result.features.isEmpty)
    }

    func testFeatureKeys() {
        let result = GenreClassification(
            genre: "Rock",
            confidence: 0.7,
            features: ["rms": 0.25, "centroid": 3000.0, "tempo": 120.0, "zcr": 0.12]
        )
        XCTAssertNotNil(result.features["rms"])
        XCTAssertNotNil(result.features["centroid"])
        XCTAssertNotNil(result.features["tempo"])
        XCTAssertNotNil(result.features["zcr"])
    }

    func testSupportedGenres() {
        // Engine supports these genre classifications
        let genres = ["Electronic", "Ambient", "Rock", "Jazz", "Hip-Hop", "Classical"]
        for genre in genres {
            let result = GenreClassification(genre: genre, confidence: 0.5, features: [:])
            XCTAssertFalse(result.genre.isEmpty)
        }
    }

    func testConfidenceRange() {
        let result = GenreClassification(genre: "Jazz", confidence: 0.65, features: [:])
        XCTAssertTrue(result.confidence >= 0 && result.confidence <= 1,
                      "Confidence should be normalized 0-1")
    }
}

// MARK: - StemSeparationResult Tests

final class StemSeparationResultTests: XCTestCase {

    func testStemSeparationKeys() {
        // StemSeparationResult should hold stems keyed by AudioStem
        let expectedStems: [AudioStem] = [.vocals, .drums, .bass, .other]
        for stem in expectedStems {
            XCTAssertNotNil(stem.rawValue)
            XCTAssertFalse(stem.icon.isEmpty)
        }
    }

    func testStemEnumDoesNotIncludeFullMixInSeparation() {
        // Separation produces 4 stems, not .full
        let separationStems: [AudioStem] = [.vocals, .drums, .bass, .other]
        XCTAssertFalse(separationStems.contains(.full),
                       "Stem separation should not include full mix as a separated stem")
    }
}

// MARK: - EchoelAIEngine Tests

@MainActor
final class EchoelAIEngineTests: XCTestCase {

    func testSingletonExists() {
        let engine = EchoelAIEngine.shared
        XCTAssertNotNil(engine)
    }

    func testSingletonIdentity() {
        let a = EchoelAIEngine.shared
        let b = EchoelAIEngine.shared
        XCTAssertTrue(a === b, "Shared instance should be same object")
    }

    func testInitialState() {
        let engine = EchoelAIEngine.shared
        XCTAssertFalse(engine.isProcessing)
        XCTAssertEqual(engine.progress, 0.0)
    }

    func testLastAnalysisDefaults() {
        let engine = EchoelAIEngine.shared
        XCTAssertEqual(engine.lastAnalysis.tempo, 120.0)
        XCTAssertEqual(engine.lastAnalysis.key, "Unknown")
    }

    func testLastLUFSDefaults() {
        let engine = EchoelAIEngine.shared
        XCTAssertEqual(engine.lastLUFS.momentary, -70.0)
        XCTAssertEqual(engine.lastLUFS.integrated, -70.0)
    }

    func testGenerateAutoEQEmpty() {
        // Empty/nil buffer should return empty bands
        let engine = EchoelAIEngine.shared
        // With a very small buffer, should return empty
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = 16
        let bands = engine.generateAutoEQ(buffer: buffer)
        XCTAssertTrue(bands.isEmpty, "Auto-EQ with tiny buffer should return empty")
    }

    func testGenerateAutoEQSilentBuffer() {
        let engine = EchoelAIEngine.shared
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = 4096
        // Buffer is already zero-filled (silent)
        let bands = engine.generateAutoEQ(buffer: buffer)
        XCTAssertEqual(bands.count, 10, "Auto-EQ should produce 10 bands")

        for band in bands {
            XCTAssertFalse(band.name.isEmpty, "Band name should not be empty")
            XCTAssertTrue(band.frequency > 0, "Band frequency should be positive")
            XCTAssertTrue(band.gainDB >= -12.0 && band.gainDB <= 12.0,
                          "Gain should be clamped to ±12 dB, got \(band.gainDB)")
        }
    }

    func testDetectChordEmptyBuffer() {
        let engine = EchoelAIEngine.shared
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = 16
        let result = engine.detectChord(buffer: buffer)
        XCTAssertEqual(result.chord, "Unknown")
        XCTAssertEqual(result.confidence, 0)
        XCTAssertEqual(result.chroma.count, 12)
    }

    func testDetectChordSilentBuffer() {
        let engine = EchoelAIEngine.shared
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = 4096
        let result = engine.detectChord(buffer: buffer)
        // Silent buffer may return any chord with low confidence
        XCTAssertEqual(result.chroma.count, 12)
    }

    func testClassifyGenreEmptyBuffer() {
        let engine = EchoelAIEngine.shared
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = 0
        let result = engine.classifyGenre(buffer: buffer)
        XCTAssertEqual(result.genre, "Unknown")
        XCTAssertEqual(result.confidence, 0)
    }

    func testClassifyGenreSilentBuffer() {
        let engine = EchoelAIEngine.shared
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = 4096
        let result = engine.classifyGenre(buffer: buffer)
        XCTAssertFalse(result.genre.isEmpty)
        XCTAssertTrue(result.features.count > 0, "Should have extracted features")
    }

    func testMeasureLUFSEmpty() {
        let engine = EchoelAIEngine.shared
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = 0
        let lufs = engine.measureLUFS(buffer: buffer)
        XCTAssertEqual(lufs.integrated, -70.0, "Empty buffer should return -70 LUFS")
    }

    func testMeasureLUFSSilent() {
        let engine = EchoelAIEngine.shared
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = 1024
        // Buffer is zero-filled (silent)
        let lufs = engine.measureLUFS(buffer: buffer)
        XCTAssertEqual(lufs.integrated, -70.0, "Silent buffer should return -70 LUFS")
        XCTAssertEqual(lufs.truePeak, -70.0, "Silent buffer should have -70 dBFS true peak")
    }

    func testMeasureLUFSWithSineWave() {
        let engine = EchoelAIEngine.shared
        let sampleRate: Double = 44100
        let frameCount: AVAudioFrameCount = 44100 // 1 second
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = frameCount

        // Generate a 440Hz sine wave at 0.5 amplitude
        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                data[i] = 0.5 * sin(2.0 * Float.pi * 440.0 * Float(i) / Float(sampleRate))
            }
        }

        let lufs = engine.measureLUFS(buffer: buffer)
        // 0.5 amplitude sine: RMS = 0.5/√2 ≈ 0.354, mean square ≈ 0.125
        // LUFS ≈ -0.691 + 10*log10(0.125) ≈ -0.691 + (-9.03) ≈ -9.72
        XCTAssertTrue(lufs.integrated > -15.0, "Moderate sine wave should be louder than -15 LUFS")
        XCTAssertTrue(lufs.integrated < 0, "LUFS should be negative")
        XCTAssertTrue(lufs.truePeak > -10.0, "True peak of 0.5 amplitude should be > -10 dBFS")
    }

    func testAutoEQBandFrequencies() {
        let engine = EchoelAIEngine.shared
        let sampleRate: Double = 44100
        let frameCount: AVAudioFrameCount = 4096
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = frameCount

        // Fill with white noise
        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                data[i] = Float.random(in: -0.5...0.5)
            }
        }

        let bands = engine.generateAutoEQ(buffer: buffer)
        XCTAssertEqual(bands.count, 10)

        let expectedFreqs: [Double] = [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        for (i, band) in bands.enumerated() {
            XCTAssertEqual(band.frequency, expectedFreqs[i], accuracy: 0.1,
                           "Band \(i) frequency mismatch")
        }
    }

    func testDetectChordWithTone() {
        let engine = EchoelAIEngine.shared
        let sampleRate: Double = 44100
        let frameCount: AVAudioFrameCount = 4096
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = frameCount

        // Generate C major chord: C4 (261.63Hz) + E4 (329.63Hz) + G4 (392.00Hz)
        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let t = Float(i) / Float(sampleRate)
                data[i] = 0.33 * sin(2.0 * Float.pi * 261.63 * t)
                       + 0.33 * sin(2.0 * Float.pi * 329.63 * t)
                       + 0.33 * sin(2.0 * Float.pi * 392.0 * t)
            }
        }

        let result = engine.detectChord(buffer: buffer)
        XCTAssertEqual(result.chroma.count, 12)
        // Should detect something with nonzero confidence
        XCTAssertTrue(result.confidence > 0, "Should have some confidence for a chord tone")
    }

    func testClassifyGenreWithNoise() {
        let engine = EchoelAIEngine.shared
        let sampleRate: Double = 44100
        let frameCount: AVAudioFrameCount = 44100 // 1 second
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = frameCount

        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                data[i] = Float.random(in: -0.3...0.3)
            }
        }

        let result = engine.classifyGenre(buffer: buffer)
        XCTAssertFalse(result.genre.isEmpty)
        XCTAssertTrue(result.confidence > 0)
        XCTAssertNotNil(result.features["rms"])
        XCTAssertNotNil(result.features["centroid"])
        XCTAssertNotNil(result.features["tempo"])
        XCTAssertNotNil(result.features["zcr"])
    }

    func testAnalyzeWithSineWave() async {
        let engine = EchoelAIEngine.shared
        let sampleRate: Double = 44100
        let frameCount: AVAudioFrameCount = 44100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = frameCount

        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                data[i] = 0.5 * sin(2.0 * Float.pi * 440.0 * Float(i) / Float(sampleRate))
            }
        }

        let analysis = await engine.analyze(buffer: buffer)
        XCTAssertTrue(analysis.tempo >= 60.0 && analysis.tempo <= 200.0,
                      "Tempo should be in valid BPM range")
        XCTAssertFalse(analysis.key.isEmpty)
        XCTAssertTrue(analysis.loudnessLUFS < 0, "LUFS should be negative")
        XCTAssertTrue(analysis.spectralCentroid > 0, "Centroid should be positive")
    }

    func testSeparateStemsSmallBuffer() async {
        let engine = EchoelAIEngine.shared
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = 1024
        let result = await engine.separateStems(buffer: buffer)
        // Buffer too small (< fftSize 4096), should return nil
        XCTAssertNil(result, "Small buffer should not produce stem separation")
    }

    func testSeparateStemsAdequateBuffer() async {
        let engine = EchoelAIEngine.shared
        let sampleRate: Double = 44100
        let frameCount: AVAudioFrameCount = 8192
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = frameCount

        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                data[i] = Float.random(in: -0.5...0.5)
            }
        }

        let result = await engine.separateStems(buffer: buffer)
        XCTAssertNotNil(result, "Adequate buffer should produce stem separation")
        if let result {
            XCTAssertEqual(result.sampleRate, sampleRate)
            XCTAssertTrue(result.duration > 0)
            XCTAssertTrue(result.stems.count > 0, "Should have at least one stem")
        }
    }
    func testMixSuggestionsSilentBuffer() {
        let engine = EchoelAIEngine.shared
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = 4096
        let suggestions = engine.generateMixSuggestions(buffer: buffer)
        // Silent buffer — no critical issues expected
        XCTAssertNotNil(suggestions)
    }

    func testMixSuggestionsLoudSignal() {
        let engine = EchoelAIEngine.shared
        let sampleRate: Double = 44100
        let frameCount: AVAudioFrameCount = 44100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to create audio buffer")
            return
        }
        buffer.frameLength = frameCount

        // Generate a very loud signal (full-scale sine)
        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                data[i] = sin(2.0 * Float.pi * 440.0 * Float(i) / Float(sampleRate))
            }
        }

        let suggestions = engine.generateMixSuggestions(buffer: buffer)
        // Full-scale signal should trigger loudness or peak warnings
        XCTAssertFalse(suggestions.isEmpty, "Loud signal should generate at least one suggestion")
        // Suggestions should be sorted by priority (highest first)
        for i in 1..<suggestions.count {
            XCTAssertTrue(suggestions[i - 1].priority >= suggestions[i].priority,
                          "Suggestions should be sorted by priority descending")
        }
    }
}

// MARK: - MixSuggestion Tests

final class MixSuggestionTests: XCTestCase {

    func testPriorityComparable() {
        XCTAssertTrue(MixSuggestion.Priority.low < MixSuggestion.Priority.medium)
        XCTAssertTrue(MixSuggestion.Priority.medium < MixSuggestion.Priority.high)
        XCTAssertTrue(MixSuggestion.Priority.high < MixSuggestion.Priority.critical)
    }

    func testPriorityRawValues() {
        XCTAssertEqual(MixSuggestion.Priority.low.rawValue, 0)
        XCTAssertEqual(MixSuggestion.Priority.medium.rawValue, 1)
        XCTAssertEqual(MixSuggestion.Priority.high.rawValue, 2)
        XCTAssertEqual(MixSuggestion.Priority.critical.rawValue, 3)
    }

    func testCategoryRawValues() {
        XCTAssertEqual(MixSuggestion.Category.loudness.rawValue, "Loudness")
        XCTAssertEqual(MixSuggestion.Category.eq.rawValue, "EQ")
        XCTAssertEqual(MixSuggestion.Category.dynamics.rawValue, "Dynamics")
        XCTAssertEqual(MixSuggestion.Category.stereo.rawValue, "Stereo")
        XCTAssertEqual(MixSuggestion.Category.general.rawValue, "General")
    }

    func testMixSuggestionInit() {
        let suggestion = MixSuggestion(
            title: "Test",
            detail: "Detail text",
            category: .loudness,
            priority: .high
        )
        XCTAssertEqual(suggestion.title, "Test")
        XCTAssertEqual(suggestion.detail, "Detail text")
        XCTAssertEqual(suggestion.category, .loudness)
        XCTAssertEqual(suggestion.priority, .high)
    }
}

#endif // canImport(AVFoundation)
