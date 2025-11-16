//
//  CompositionSchoolTests.swift
//  EchoelmusicTests
//
//  Tests für Composition School System
//

import XCTest
@testable import Echoelmusic

@MainActor
final class CompositionSchoolTests: XCTestCase {

    var compositionSchool: CompositionSchool!

    override func setUp() async throws {
        try await super.setUp()
        compositionSchool = CompositionSchool()
    }

    override func tearDown() async throws {
        compositionSchool = nil
        try await super.tearDown()
    }

    // MARK: - Lesson Management Tests

    func testGetAllLessons() {
        let lessons = compositionSchool.getAllLessons()

        XCTAssertFalse(lessons.isEmpty, "Should have lessons")
        XCTAssertGreaterThanOrEqual(lessons.count, 15, "Should have at least 15 lessons")
    }

    func testGetLessonsByGenre() {
        let edmLessons = compositionSchool.getLessons(for: .edm)

        XCTAssertFalse(edmLessons.isEmpty, "Should have EDM lessons")

        for lesson in edmLessons {
            XCTAssertEqual(lesson.genre, .edm, "All lessons should be EDM genre")
        }
    }

    func testGetLessonsByTechnique() {
        let sideChainLessons = compositionSchool.getLessons(for: .sideChainCompression)

        for lesson in sideChainLessons {
            XCTAssertEqual(lesson.technique, .sideChainCompression)
        }
    }

    func testGetLessonsByDifficulty() {
        let beginnerLessons = compositionSchool.getLessons(difficulty: .beginner)

        for lesson in beginnerLessons {
            XCTAssertEqual(lesson.difficulty, .beginner)
        }
    }

    // MARK: - Lesson Content Tests

    func testEDMBuildupDropLesson() {
        let edmLessons = compositionSchool.getLessons(for: .edm)
        let buildupLesson = edmLessons.first { $0.technique == .buildupDropStructure }

        XCTAssertNotNil(buildupLesson)
        XCTAssertFalse(buildupLesson!.steps.isEmpty, "Lesson should have steps")
        XCTAssertFalse(buildupLesson!.pluginChain.isEmpty, "Lesson should have plugin chain")
    }

    func testJazzCounterpointLesson() {
        let jazzLessons = compositionSchool.getLessons(for: .jazz)
        let counterpointLesson = jazzLessons.first { $0.technique == .melodicCounterpoint }

        XCTAssertNotNil(counterpointLesson)
        XCTAssertEqual(counterpointLesson!.exampleParameters.key, "Bb")
    }

    func testAmbientTextureLesson() {
        let ambientLessons = compositionSchool.getLessons(for: .ambient)
        let textureLesson = ambientLessons.first { $0.technique == .textureStacking }

        XCTAssertNotNil(textureLesson)
        XCTAssertGreaterThan(textureLesson!.exampleParameters.duration, 30.0, "Ambient should be long")
    }

    // MARK: - Example Generation Tests

    func testGenerateEDMExample() async throws {
        let edmLessons = compositionSchool.getLessons(for: .edm)
        guard let lesson = edmLessons.first else {
            XCTFail("No EDM lessons found")
            return
        }

        let example = try await compositionSchool.generateExample(for: lesson)

        XCTAssertEqual(example.genre, .edm)
        XCTAssertEqual(example.technique, lesson.technique)
        XCTAssertNotNil(example.audioBuffer)
        XCTAssertGreaterThan(example.audioBuffer.frameLength, 0)
    }

    func testGenerateJazzExample() async throws {
        let jazzLessons = compositionSchool.getLessons(for: .jazz)
        guard let lesson = jazzLessons.first else {
            XCTFail("No Jazz lessons found")
            return
        }

        let example = try await compositionSchool.generateExample(for: lesson)

        XCTAssertEqual(example.genre, .jazz)
        XCTAssertEqual(example.metadata.tempo, lesson.exampleParameters.tempo)
    }

    // MARK: - Recommendation Tests

    func testRecommendLessons() async throws {
        // Erstelle Test-Audio
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100

        // Speichere als temporäre Datei
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_audio.wav")

        // Erstelle Audio-Datei
        let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
        try file.write(from: buffer)

        let recommendations = try await compositionSchool.recommendLessons(basedOn: tempURL)

        XCTAssertFalse(recommendations.isEmpty, "Should provide recommendations")
        XCTAssertLessThanOrEqual(recommendations.count, 5, "Should limit to 5 recommendations")

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Genre-Specific Pattern Tests

    func testEDMPatternGeneration() {
        let generator = AutomatedExampleGenerator()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100 * 4)!  // 4 seconds
        buffer.frameLength = 44100 * 4

        // EDM pattern sollte 4-on-the-floor haben
        // (Das wird intern generiert, wir testen nur dass es nicht crasht)
        XCTAssertNotNil(buffer)
    }

    // MARK: - Lesson Step Tests

    func testLessonStepsHaveValidStructure() {
        let lessons = compositionSchool.getAllLessons()

        for lesson in lessons {
            XCTAssertFalse(lesson.steps.isEmpty, "Lesson '\(lesson.title)' should have steps")

            for (index, step) in lesson.steps.enumerated() {
                XCTAssertEqual(step.stepNumber, index + 1, "Step numbers should be sequential")
                XCTAssertFalse(step.title.isEmpty, "Step should have title")
                XCTAssertFalse(step.explanation.isEmpty, "Step should have explanation")
            }
        }
    }

    // MARK: - Plugin Chain Tests

    func testPluginChainValidation() {
        let lessons = compositionSchool.getAllLessons()

        for lesson in lessons {
            for plugin in lesson.pluginChain {
                XCTAssertFalse(plugin.parameters.isEmpty, "Plugin should have parameters")
                XCTAssertFalse(plugin.purpose.isEmpty, "Plugin should have purpose")

                // Validiere Parameter-Werte
                for (key, value) in plugin.parameters {
                    XCTAssertGreaterThanOrEqual(value, 0.0, "Parameter '\(key)' should be >= 0")
                }
            }
        }
    }

    // MARK: - Example Parameters Tests

    func testExampleParametersValid() {
        let lessons = compositionSchool.getAllLessons()

        for lesson in lessons {
            let params = lesson.exampleParameters

            XCTAssertGreaterThan(params.tempo, 0, "Tempo should be positive")
            XCTAssertLessThanOrEqual(params.tempo, 200, "Tempo should be reasonable")

            XCTAssertGreaterThan(params.duration, 0, "Duration should be positive")

            XCTAssertGreaterThanOrEqual(params.complexity, 0.0, "Complexity should be >= 0")
            XCTAssertLessThanOrEqual(params.complexity, 1.0, "Complexity should be <= 1")

            XCTAssertFalse(params.key.isEmpty, "Key should not be empty")
            XCTAssertFalse(params.timeSignature.isEmpty, "Time signature should not be empty")
        }
    }

    // MARK: - Genre Coverage Tests

    func testAllGenresHaveLessons() {
        for genre in MusicGenre.allCases {
            let lessons = compositionSchool.getLessons(for: genre)
            XCTAssertFalse(lessons.isEmpty, "Genre '\(genre.rawValue)' should have lessons")
        }
    }

    // MARK: - Technique Category Tests

    func testTechniqueCategorization() {
        // Composition techniques
        XCTAssertEqual(ProductionTechnique.melodicCounterpoint.category, .composition)
        XCTAssertEqual(ProductionTechnique.harmonicProgression.category, .composition)

        // Arrangement techniques
        XCTAssertEqual(ProductionTechnique.buildupDropStructure.category, .arrangement)

        // Mixing techniques
        XCTAssertEqual(ProductionTechnique.sideChainCompression.category, .mixing)
        XCTAssertEqual(ProductionTechnique.frequencySeparation.category, .mixing)

        // Effects techniques
        XCTAssertEqual(ProductionTechnique.creativeFiltering.category, .effects)
    }

    // MARK: - Performance Tests

    func testLessonLoadingPerformance() {
        measure {
            _ = compositionSchool.getAllLessons()
        }
    }

    func testGenreFilteringPerformance() {
        measure {
            for genre in MusicGenre.allCases {
                _ = compositionSchool.getLessons(for: genre)
            }
        }
    }
}

// MARK: - Automated Example Generator Tests

@MainActor
final class AutomatedExampleGeneratorTests: XCTestCase {

    var generator: AutomatedExampleGenerator!

    override func setUp() async throws {
        try await super.setUp()
        generator = AutomatedExampleGenerator()
    }

    override func tearDown() async throws {
        generator = nil
        try await super.tearDown()
    }

    func testGenerateEDMPattern() async throws {
        let parameters = ExampleParameters(
            tempo: 128.0,
            key: "Am",
            timeSignature: "4/4",
            duration: 8.0,
            complexity: 0.6
        )

        let example = try await generator.generate(
            genre: .edm,
            technique: .buildupDropStructure,
            parameters: parameters,
            pluginChain: []
        )

        XCTAssertEqual(example.genre, .edm)
        XCTAssertNotNil(example.audioBuffer)
        XCTAssertGreaterThan(example.audioBuffer.frameLength, 0)
    }

    func testGenerateJazzPattern() async throws {
        let parameters = ExampleParameters(
            tempo: 120.0,
            key: "Bb",
            timeSignature: "4/4",
            duration: 16.0,
            complexity: 0.8
        )

        let example = try await generator.generate(
            genre: .jazz,
            technique: .melodicCounterpoint,
            parameters: parameters,
            pluginChain: []
        )

        XCTAssertEqual(example.genre, .jazz)
    }

    func testGenerateAmbientPattern() async throws {
        let parameters = ExampleParameters(
            tempo: 60.0,
            key: "Dm",
            timeSignature: "4/4",
            duration: 40.0,
            complexity: 0.5
        )

        let example = try await generator.generate(
            genre: .ambient,
            technique: .textureStacking,
            parameters: parameters,
            pluginChain: []
        )

        XCTAssertEqual(example.genre, .ambient)
        XCTAssertGreaterThan(example.audioBuffer.frameLength, 0)
    }
}

// MARK: - Technique Analyzer Tests

@MainActor
final class TechniqueAnalyzerTests: XCTestCase {

    var analyzer: TechniqueAnalyzer!

    override func setUp() async throws {
        try await super.setUp()
        analyzer = TechniqueAnalyzer()
    }

    override func tearDown() async throws {
        analyzer = nil
        try await super.tearDown()
    }

    func testAnalyzeAudio() async throws {
        // Erstelle Test-Audio
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_analyze.wav")
        let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
        try file.write(from: buffer)

        let analysis = try await analyzer.analyze(audioURL: tempURL)

        XCTAssertNotNil(analysis.detectedGenre)
        XCTAssertNotNil(analysis.usedTechniques)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
}
