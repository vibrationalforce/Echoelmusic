//
//  CoreMLIntegrationTests.swift
//  EchoelmusicTests
//
//  Tests für CoreML Model Integration
//

import XCTest
import CoreML
import AVFoundation
@testable import Echoelmusic

@MainActor
final class CoreMLIntegrationTests: XCTestCase {

    var modelManager: CoreMLModelManager!

    override func setUp() async throws {
        try await super.setUp()
        modelManager = CoreMLModelManager.shared
    }

    // MARK: - Model Manager Tests

    func testModelManagerSingleton() {
        let manager1 = CoreMLModelManager.shared
        let manager2 = CoreMLModelManager.shared

        XCTAssertTrue(manager1 === manager2, "Should be singleton")
    }

    func testModelStatusesInitialized() {
        XCTAssertFalse(modelManager.modelStatuses.isEmpty, "Model statuses should be initialized")

        let expectedModels = ["GenreClassifier", "TechniqueRecognizer", "PatternGenerator", "MixAnalyzer"]
        for modelName in expectedModels {
            XCTAssertNotNil(modelManager.modelStatuses[modelName], "\(modelName) status should exist")
        }
    }

    // MARK: - Genre Classifier Tests

    func testGenreClassifierAvailable() {
        let classifier = modelManager.getGenreClassifier()
        XCTAssertNotNil(classifier)
    }

    func testGenreClassificationEDM() {
        let classifier = modelManager.getGenreClassifier()

        let features = AudioFeatures(
            tempo: 128.0,
            spectralCentroid: 0.7,
            spectralRolloff: 0.65,
            zeroCrossingRate: 0.5,
            mfcc: Array(repeating: 0.5, count: 13),
            chroma: Array(repeating: 0.4, count: 12),
            rms: 0.6,
            spectralFlux: 0.5,
            spectralContrast: 0.6
        )

        let result = classifier.classify(audioFeatures: features)

        XCTAssertNotNil(result.primaryGenre)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
    }

    func testGenreClassificationJazz() {
        let classifier = modelManager.getGenreClassifier()

        let features = AudioFeatures(
            tempo: 120.0,
            spectralCentroid: 0.5,
            spectralRolloff: 0.5,
            zeroCrossingRate: 0.3,
            mfcc: Array(repeating: 0.6, count: 13),
            chroma: Array(repeating: 0.7, count: 12),  // Complex harmony
            rms: 0.5,
            spectralFlux: 0.4,
            spectralContrast: 0.5
        )

        let result = classifier.classify(audioFeatures: features)

        XCTAssertNotNil(result.primaryGenre)
    }

    func testGenreClassificationAmbient() {
        let classifier = modelManager.getGenreClassifier()

        let features = AudioFeatures(
            tempo: 60.0,  // Slow
            spectralCentroid: 0.4,
            spectralRolloff: 0.3,
            zeroCrossingRate: 0.2,
            mfcc: Array(repeating: 0.3, count: 13),
            chroma: Array(repeating: 0.5, count: 12),
            rms: 0.3,
            spectralFlux: 0.2,  // Low flux
            spectralContrast: 0.3  // Low contrast
        )

        let result = classifier.classify(audioFeatures: features)

        // Should likely detect ambient or similar slow genre
        XCTAssertNotNil(result.primaryGenre)
    }

    // MARK: - Technique Recognizer Tests

    func testTechniqueRecognizerAvailable() {
        let recognizer = modelManager.getTechniqueRecognizer()
        XCTAssertNotNil(recognizer)
    }

    func testTechniqueRecognition() {
        let recognizer = modelManager.getTechniqueRecognizer()

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100

        // Fill with test data
        if let channelData = buffer.floatChannelData {
            for frame in 0..<Int(buffer.frameLength) {
                channelData[0][frame] = Float(sin(Double(frame) * 0.01))
                channelData[1][frame] = Float(sin(Double(frame) * 0.01))
            }
        }

        let techniques = recognizer.recognize(audioBuffer: buffer)

        XCTAssertNotNil(techniques)
        // Kann leer sein wenn keine Techniken erkannt werden
    }

    // MARK: - Pattern Generator Tests

    func testPatternGeneratorAvailable() {
        let generator = modelManager.getPatternGenerator()
        XCTAssertNotNil(generator)
    }

    func testPatternGenerationEDM() async throws {
        let generator = modelManager.getPatternGenerator()

        let parameters = PatternParameters(
            tempo: 128.0,
            key: "Am",
            bars: 4,
            complexity: 0.6
        )

        let pattern = try await generator.generatePattern(
            genre: .edm,
            technique: .rhythmicLayering,
            parameters: parameters
        )

        XCTAssertEqual(pattern.metadata.genre, .edm)
        XCTAssertEqual(pattern.metadata.technique, .rhythmicLayering)
        XCTAssertFalse(pattern.midiNotes.isEmpty, "Should generate MIDI notes")
    }

    func testPatternGenerationJazz() async throws {
        let generator = modelManager.getPatternGenerator()

        let parameters = PatternParameters(
            tempo: 120.0,
            key: "Bb",
            bars: 4,
            complexity: 0.8
        )

        let pattern = try await generator.generatePattern(
            genre: .jazz,
            technique: .melodicCounterpoint,
            parameters: parameters
        )

        XCTAssertEqual(pattern.metadata.genre, .jazz)
        XCTAssertFalse(pattern.midiNotes.isEmpty)
    }

    func testPatternGenerationAmbient() async throws {
        let generator = modelManager.getPatternGenerator()

        let parameters = PatternParameters(
            tempo: 60.0,
            key: "Dm",
            bars: 8,
            complexity: 0.5
        )

        let pattern = try await generator.generatePattern(
            genre: .ambient,
            technique: .textureStacking,
            parameters: parameters
        )

        XCTAssertEqual(pattern.metadata.genre, .ambient)
    }

    func testMIDINoteValidation() async throws {
        let generator = modelManager.getPatternGenerator()

        let parameters = PatternParameters(
            tempo: 128.0,
            key: "C",
            bars: 4,
            complexity: 0.5
        )

        let pattern = try await generator.generatePattern(
            genre: .hiphop,
            technique: .rhythmicLayering,
            parameters: parameters
        )

        for note in pattern.midiNotes {
            XCTAssertGreaterThanOrEqual(note.pitch, 0, "Pitch should be >= 0")
            XCTAssertLessThanOrEqual(note.pitch, 127, "Pitch should be <= 127")

            XCTAssertGreaterThanOrEqual(note.velocity, 0, "Velocity should be >= 0")
            XCTAssertLessThanOrEqual(note.velocity, 127, "Velocity should be <= 127")

            XCTAssertGreaterThanOrEqual(note.startTime, 0, "Start time should be >= 0")
            XCTAssertGreaterThan(note.duration, 0, "Duration should be > 0")
        }
    }

    // MARK: - Mix Analyzer Tests

    func testMixAnalyzerAvailable() {
        let analyzer = modelManager.getMixAnalyzer()
        XCTAssertNotNil(analyzer)
    }

    func testMixAnalysis() {
        let analyzer = modelManager.getMixAnalyzer()

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100

        // Fill with test data
        if let channelData = buffer.floatChannelData {
            for frame in 0..<Int(buffer.frameLength) {
                let value = Float(sin(Double(frame) * 0.01)) * 0.5
                channelData[0][frame] = value
                channelData[1][frame] = value
            }
        }

        let analysis = analyzer.analyze(audioBuffer: buffer)

        // Validate frequency balance
        XCTAssertGreaterThanOrEqual(analysis.frequencyBalance.sub, 0.0)
        XCTAssertLessThanOrEqual(analysis.frequencyBalance.sub, 1.0)

        // Validate metrics
        XCTAssertGreaterThanOrEqual(analysis.dynamicRange, 0.0)
        XCTAssertGreaterThanOrEqual(analysis.stereoWidth, 0.0)
        XCTAssertLessThanOrEqual(analysis.stereoWidth, 1.0)

        XCTAssertGreaterThanOrEqual(analysis.peakLevel, 0.0)
        XCTAssertLessThanOrEqual(analysis.peakLevel, 1.0)

        XCTAssertGreaterThanOrEqual(analysis.rmsLevel, 0.0)
        XCTAssertLessThanOrEqual(analysis.rmsLevel, 1.0)

        XCTAssertNotNil(analysis.suggestions)
    }

    func testMixAnalysisWithLoudAudio() {
        let analyzer = modelManager.getMixAnalyzer()

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100

        // Fill with loud data
        if let channelData = buffer.floatChannelData {
            for frame in 0..<Int(buffer.frameLength) {
                let value = Float(sin(Double(frame) * 0.01)) * 0.95  // Near clipping
                channelData[0][frame] = value
                channelData[1][frame] = value
            }
        }

        let analysis = analyzer.analyze(audioBuffer: buffer)

        XCTAssertGreaterThan(analysis.peakLevel, 0.9, "Should detect high peak level")
    }

    // MARK: - Audio Features Tests

    func testAudioFeaturesValidation() {
        let features = AudioFeatures(
            tempo: 120.0,
            spectralCentroid: 0.5,
            spectralRolloff: 0.6,
            zeroCrossingRate: 0.4,
            mfcc: Array(repeating: 0.5, count: 13),
            chroma: Array(repeating: 0.5, count: 12),
            rms: 0.5,
            spectralFlux: 0.4,
            spectralContrast: 0.5
        )

        XCTAssertEqual(features.mfcc.count, 13, "MFCC should have 13 coefficients")
        XCTAssertEqual(features.chroma.count, 12, "Chroma should have 12 bins")
    }

    // MARK: - Performance Tests

    func testGenreClassificationPerformance() {
        let classifier = modelManager.getGenreClassifier()

        let features = AudioFeatures(
            tempo: 120.0,
            spectralCentroid: 0.5,
            spectralRolloff: 0.5,
            zeroCrossingRate: 0.3,
            mfcc: Array(repeating: 0.5, count: 13),
            chroma: Array(repeating: 0.5, count: 12),
            rms: 0.5,
            spectralFlux: 0.4,
            spectralContrast: 0.5
        )

        measure {
            for _ in 0..<100 {
                _ = classifier.classify(audioFeatures: features)
            }
        }
    }

    func testPatternGenerationPerformance() async throws {
        let generator = modelManager.getPatternGenerator()

        let parameters = PatternParameters(
            tempo: 128.0,
            key: "C",
            bars: 4,
            complexity: 0.5
        )

        measure {
            Task {
                for _ in 0..<10 {
                    _ = try? await generator.generatePattern(
                        genre: .edm,
                        technique: .rhythmicLayering,
                        parameters: parameters
                    )
                }
            }
        }
    }
}

// MARK: - Rule-Based Fallback Tests

@MainActor
final class RuleBasedClassifierTests: XCTestCase {

    func testRuleBasedGenreClassifier() {
        let classifier = RuleBasedGenreClassifier()

        // EDM characteristics
        let edmFeatures = AudioFeatures(
            tempo: 128.0,
            spectralCentroid: 0.7,
            spectralRolloff: 0.7,
            zeroCrossingRate: 0.5,
            mfcc: Array(repeating: 0.5, count: 13),
            chroma: Array(repeating: 0.4, count: 12),
            rms: 0.6,
            spectralFlux: 0.5,
            spectralContrast: 0.6
        )

        let result = classifier.classify(audioFeatures: edmFeatures)

        XCTAssertNotNil(result.primaryGenre)
        XCTAssertGreaterThan(result.confidence, 0.0)
    }

    func testRuleBasedPatternGenerator() async throws {
        let generator = RuleBasedPatternGenerator()

        let parameters = PatternParameters(
            tempo: 128.0,
            key: "C",
            bars: 4,
            complexity: 0.5
        )

        let pattern = try await generator.generatePattern(
            genre: .edm,
            technique: .rhythmicLayering,
            parameters: parameters
        )

        XCTAssertFalse(pattern.midiNotes.isEmpty, "Should generate notes")

        // EDM should have kick drum notes
        let kickNotes = pattern.midiNotes.filter { $0.pitch == 36 }  // C1 kick
        XCTAssertFalse(kickNotes.isEmpty, "EDM should have kick drum")
    }

    func testAllGenresGeneratePatterns() async throws {
        let generator = RuleBasedPatternGenerator()

        let parameters = PatternParameters(
            tempo: 120.0,
            key: "C",
            bars: 4,
            complexity: 0.5
        )

        for genre in MusicGenre.allCases {
            let pattern = try await generator.generatePattern(
                genre: genre,
                technique: .rhythmicLayering,
                parameters: parameters
            )

            XCTAssertEqual(pattern.metadata.genre, genre)
        }
    }
}
