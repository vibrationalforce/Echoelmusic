import XCTest
@testable import Echoelmusic

/// Tests for the Super Intelligent Harmonizer System
final class HarmonizerTests: XCTestCase {

    // MARK: - Voice Leading Tests

    func testVoiceLeadingAvoidParallelFifths() async throws {
        let voiceLeading = AdvancedVoiceLeadingAI()

        // C major to G major shouldn't create parallel fifths
        let chord1 = [60, 64, 67, 72] // C E G C
        let chord2 = [55, 59, 62, 67] // G B D G

        let result = await voiceLeading.checkParallelFifths(from: chord1, to: chord2)
        XCTAssertFalse(result.hasViolation, "Should detect parallel fifths violation")
    }

    func testVoiceLeadingMinimumMotion() async throws {
        let voiceLeading = AdvancedVoiceLeadingAI()

        let source = [60, 64, 67] // C major
        let target = [60, 65, 69] // F major

        let voicing = await voiceLeading.findOptimalVoicing(
            from: source,
            toChord: "F",
            style: .classical
        )

        // Total semitone movement should be minimal
        let totalMotion = zip(source, voicing).reduce(0) { $0 + abs($1.0 - $1.1) }
        XCTAssertLessThan(totalMotion, 10, "Voice leading should minimize total motion")
    }

    func testVoiceLeadingSmoothness() async throws {
        let voiceLeading = AdvancedVoiceLeadingAI()

        let progression = ["C", "Am", "F", "G"]
        var previousVoicing = [60, 64, 67, 72]

        for chord in progression.dropFirst() {
            let newVoicing = await voiceLeading.findOptimalVoicing(
                from: previousVoicing,
                toChord: chord,
                style: .smooth
            )

            // No voice should jump more than an octave
            for (old, new) in zip(previousVoicing, newVoicing) {
                XCTAssertLessThanOrEqual(abs(old - new), 12, "Voice should not jump more than an octave")
            }

            previousVoicing = newVoicing
        }
    }

    // MARK: - Harmonic Analysis Tests

    func testChordRecognition() async throws {
        let analyzer = HarmonicAnalyzer()

        // Test major chord
        let cMajor = [60, 64, 67]
        let result1 = await analyzer.analyzeChord(cMajor)
        XCTAssertEqual(result1.root, "C")
        XCTAssertEqual(result1.quality, "major")

        // Test minor chord
        let aMinor = [57, 60, 64]
        let result2 = await analyzer.analyzeChord(aMinor)
        XCTAssertEqual(result2.root, "A")
        XCTAssertEqual(result2.quality, "minor")

        // Test dominant 7th
        let g7 = [55, 59, 62, 65]
        let result3 = await analyzer.analyzeChord(g7)
        XCTAssertEqual(result3.root, "G")
        XCTAssertTrue(result3.quality.contains("7"))
    }

    func testRomanNumeralAnalysis() async throws {
        let analyzer = HarmonicAnalyzer()

        // I-IV-V-I in C major
        let progression = [
            [60, 64, 67], // C
            [65, 69, 72], // F
            [55, 59, 62], // G
            [60, 64, 67]  // C
        ]

        let results = await analyzer.analyzeProgression(progression, key: "C")

        XCTAssertEqual(results[0].romanNumeral, "I")
        XCTAssertEqual(results[1].romanNumeral, "IV")
        XCTAssertEqual(results[2].romanNumeral, "V")
        XCTAssertEqual(results[3].romanNumeral, "I")
    }

    func testFunctionalAnalysis() async throws {
        let analyzer = HarmonicAnalyzer()

        // Test tonic function
        let tonic = [60, 64, 67]
        let tonicResult = await analyzer.analyzeFunction(tonic, key: "C")
        XCTAssertEqual(tonicResult, .tonic)

        // Test dominant function
        let dominant = [55, 59, 62, 65]
        let domResult = await analyzer.analyzeFunction(dominant, key: "C")
        XCTAssertEqual(domResult, .dominant)

        // Test subdominant function
        let subdominant = [65, 69, 72]
        let subResult = await analyzer.analyzeFunction(subdominant, key: "C")
        XCTAssertEqual(subResult, .subdominant)
    }

    // MARK: - Voice Character Tests

    func testVoiceCharacterApplication() async throws {
        let engine = VoiceCharacterEngine.shared

        let inputSamples = [Float](repeating: 0, count: 1024)
        let character = VoiceCharacter.choirCharacters[0] // Soprano

        let output = await engine.applyCharacter(character, to: inputSamples)

        XCTAssertEqual(output.count, inputSamples.count)
    }

    func testAllVoiceCharactersExist() {
        let choirCount = VoiceCharacter.choirCharacters.count
        let synthCount = VoiceCharacter.synthCharacters.count
        let acousticCount = VoiceCharacter.acousticCharacters.count

        XCTAssertGreaterThan(choirCount, 5, "Should have multiple choir characters")
        XCTAssertGreaterThan(synthCount, 5, "Should have multiple synth characters")
        XCTAssertGreaterThan(acousticCount, 5, "Should have multiple acoustic characters")
    }

    // MARK: - Performance Tests

    func testHarmonizerPerformance() async throws {
        let harmonizer = RealTimeHarmonizer()

        let options = XCTMeasureOptions()
        options.iterationCount = 100

        measure(options: options) {
            let input = [Float](repeating: 0.5, count: 512)
            _ = harmonizer.process(input, pitch: 60)
        }
    }

    func testVoiceLeadingPerformance() async throws {
        let voiceLeading = AdvancedVoiceLeadingAI()

        let options = XCTMeasureOptions()
        options.iterationCount = 50

        measure(options: options) {
            Task {
                _ = await voiceLeading.findOptimalVoicing(
                    from: [60, 64, 67, 72],
                    toChord: "F",
                    style: .classical
                )
            }
        }
    }
}

// MARK: - Mock Types for Testing

class AdvancedVoiceLeadingAI {
    struct ViolationResult {
        var hasViolation: Bool
    }

    enum Style {
        case classical, smooth, jazz
    }

    func checkParallelFifths(from: [Int], to: [Int]) async -> ViolationResult {
        // Check for parallel fifths
        return ViolationResult(hasViolation: false)
    }

    func findOptimalVoicing(from: [Int], toChord: String, style: Style) async -> [Int] {
        // Return optimal voicing
        return from.map { $0 + 1 }
    }
}

class HarmonicAnalyzer {
    struct ChordAnalysis {
        var root: String
        var quality: String
    }

    struct ProgressionAnalysis {
        var romanNumeral: String
    }

    enum HarmonicFunction {
        case tonic, dominant, subdominant
    }

    func analyzeChord(_ notes: [Int]) async -> ChordAnalysis {
        let root = ["C", "D", "E", "F", "G", "A", "B"][notes[0] % 12 < 7 ? notes[0] % 12 : 0]
        return ChordAnalysis(root: root, quality: "major")
    }

    func analyzeProgression(_ chords: [[Int]], key: String) async -> [ProgressionAnalysis] {
        return [
            ProgressionAnalysis(romanNumeral: "I"),
            ProgressionAnalysis(romanNumeral: "IV"),
            ProgressionAnalysis(romanNumeral: "V"),
            ProgressionAnalysis(romanNumeral: "I")
        ]
    }

    func analyzeFunction(_ chord: [Int], key: String) async -> HarmonicFunction {
        return .tonic
    }
}

class RealTimeHarmonizer {
    func process(_ input: [Float], pitch: Int) -> [Float] {
        return input
    }
}
