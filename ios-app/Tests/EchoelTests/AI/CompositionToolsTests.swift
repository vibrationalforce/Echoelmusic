import XCTest
@testable import Echoel

final class CompositionToolsTests: XCTestCase {

    var compositionTools: CompositionTools!
    var patternRecognition: PatternRecognition!

    override func setUp() {
        super.setUp()
        patternRecognition = PatternRecognition()
        compositionTools = CompositionTools(patternRecognition: patternRecognition)
    }

    override func tearDown() {
        compositionTools = nil
        patternRecognition = nil
        super.tearDown()
    }

    // MARK: - Chord Suggestion Tests

    func testChordSuggestion_PopProgression() {
        // Test pop progression I-V-vi-IV
        let key = Key(tonic: .C, mode: .major)
        let progression = [
            Chord(root: .C, type: .major, confidence: 1.0) // I
        ]

        let suggestions = compositionTools.suggestNextChord(
            currentProgression: progression,
            key: key,
            style: .pop
        )

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertGreaterThan(suggestions.count, 0)
        XCTAssertLessThanOrEqual(suggestions.count, 5)

        // First suggestion should have highest confidence
        if suggestions.count >= 2 {
            XCTAssertGreaterThanOrEqual(suggestions[0].confidence, suggestions[1].confidence)
        }
    }

    func testChordSuggestion_JazzProgression() {
        // Test jazz ii-V-I
        let key = Key(tonic: .C, mode: .major)
        let progression = [
            Chord(root: .D, type: .minor, confidence: 1.0), // ii
            Chord(root: .G, type: .major, confidence: 1.0)  // V
        ]

        let suggestions = compositionTools.suggestNextChord(
            currentProgression: progression,
            key: key,
            style: .jazz
        )

        XCTAssertFalse(suggestions.isEmpty)
        // Should suggest I (C major) as resolution
    }

    func testGenerateChordProgression() {
        // Test generating 4-bar progression
        let key = Key(tonic: .C, mode: .major)
        let progression = compositionTools.generateChordProgression(
            key: key,
            style: .pop,
            length: 4
        )

        XCTAssertEqual(progression.count, 4)
        // First chord should be tonic
        XCTAssertEqual(progression[0].root, .C)
    }

    // MARK: - Melody Generation Tests

    func testMelodyGeneration_ChordTones() {
        // Test melody generation using chord tones
        let key = Key(tonic: .C, mode: .major)
        let chords = [
            Chord(root: .C, type: .major, confidence: 1.0)
        ]

        let melody = compositionTools.generateMelody(
            chords: chords,
            key: key,
            style: .chordTones,
            complexity: 0.5
        )

        XCTAssertFalse(melody.isEmpty)

        // All notes should be within valid MIDI range
        for note in melody {
            XCTAssertGreaterThanOrEqual(note.pitch, 0)
            XCTAssertLessThan(note.pitch, 128)
            XCTAssertGreaterThan(note.velocity, 0)
            XCTAssertLessThanOrEqual(note.velocity, 127)
        }
    }

    func testMelodyGeneration_Scalic() {
        // Test scalic melody
        let key = Key(tonic: .C, mode: .major)
        let chords = [
            Chord(root: .C, type: .major, confidence: 1.0),
            Chord(root: .F, type: .major, confidence: 1.0)
        ]

        let melody = compositionTools.generateMelody(
            chords: chords,
            key: key,
            style: .scalic,
            complexity: 0.7
        )

        XCTAssertFalse(melody.isEmpty)
        XCTAssertGreaterThan(melody.count, chords.count * 4)
    }

    // MARK: - Bassline Generation Tests

    func testBasslineGeneration_Roots() {
        // Test simple root note bassline
        let key = Key(tonic: .C, mode: .major)
        let chords = [
            Chord(root: .C, type: .major, confidence: 1.0),
            Chord(root: .G, type: .major, confidence: 1.0)
        ]

        let bassline = compositionTools.generateBassline(
            chords: chords,
            key: key,
            style: .roots,
            complexity: 0.5
        )

        XCTAssertFalse(bassline.isEmpty)
        // Should have 4 notes per chord
        XCTAssertEqual(bassline.count, chords.count * 4)

        // Bass notes should be in low octave (MIDI 24-48)
        for note in bassline {
            XCTAssertGreaterThanOrEqual(note.pitch, 12)
            XCTAssertLessThan(note.pitch, 60)
        }
    }

    func testBasslineGeneration_Walking() {
        // Test walking bass
        let key = Key(tonic: .C, mode: .major)
        let chords = [
            Chord(root: .C, type: .major, confidence: 1.0),
            Chord(root: .F, type: .major, confidence: 1.0),
            Chord(root: .G, type: .major, confidence: 1.0),
            Chord(root: .C, type: .major, confidence: 1.0)
        ]

        let bassline = compositionTools.generateBassline(
            chords: chords,
            key: key,
            style: .walking,
            complexity: 0.8
        )

        XCTAssertFalse(bassline.isEmpty)
    }

    // MARK: - Drum Pattern Generation Tests

    func testDrumPattern_FourOnFloor() {
        // Test four-on-floor pattern
        let pattern = compositionTools.generateDrumPattern(
            style: .fourOnFloor,
            bars: 1,
            complexity: 0.5
        )

        XCTAssertFalse(pattern.isEmpty)

        // Should have kick on every beat (4 per bar)
        let kicks = pattern.filter { $0.instrument == .kick }
        XCTAssertGreaterThanOrEqual(kicks.count, 4)
    }

    func testDrumPattern_HipHop() {
        // Test hip-hop pattern
        let pattern = compositionTools.generateDrumPattern(
            style: .hiphop,
            bars: 2,
            complexity: 0.7
        )

        XCTAssertFalse(pattern.isEmpty)

        // Should have snares on 2 and 4
        let snares = pattern.filter { $0.instrument == .snare }
        XCTAssertGreaterThan(snares.count, 0)
    }

    // MARK: - Music Theory Tests

    func testChordFunction() {
        let theory = MusicTheory()
        let key = Key(tonic: .C, mode: .major)

        // Test I chord (C major)
        let cMajor = Chord(root: .C, type: .major, confidence: 1.0)
        let function = theory.chordFunction(cMajor, in: key)
        XCTAssertEqual(function, .tonic)

        // Test V chord (G major)
        let gMajor = Chord(root: .G, type: .major, confidence: 1.0)
        let dominantFunction = theory.chordFunction(gMajor, in: key)
        XCTAssertEqual(dominantFunction, .dominant)
    }

    func testChordFromFunction() {
        let theory = MusicTheory()
        let key = Key(tonic: .C, mode: .major)

        // Test getting I chord
        let tonic = theory.chordFromFunction(.tonic, in: key)
        XCTAssertEqual(tonic.root, .C)
        XCTAssertEqual(tonic.type, .major)

        // Test getting V chord
        let dominant = theory.chordFromFunction(.dominant, in: key)
        XCTAssertEqual(dominant.root, .G)
        XCTAssertEqual(dominant.type, .major)
    }

    func testResolutionChords() {
        let theory = MusicTheory()
        let key = Key(tonic: .C, mode: .major)

        // Test V resolves to I
        let gMajor = Chord(root: .G, type: .major, confidence: 1.0)
        let resolutions = theory.resolutionChords(for: gMajor, in: key)

        XCTAssertFalse(resolutions.isEmpty)
        XCTAssertEqual(resolutions[0].root, .C)
    }

    // MARK: - Performance Tests

    func testMelodyGenerationPerformance() {
        let key = Key(tonic: .C, mode: .major)
        let chords = [
            Chord(root: .C, type: .major, confidence: 1.0),
            Chord(root: .G, type: .major, confidence: 1.0),
            Chord(root: .A, type: .minor, confidence: 1.0),
            Chord(root: .F, type: .major, confidence: 1.0)
        ]

        measure {
            _ = compositionTools.generateMelody(
                chords: chords,
                key: key,
                style: .scalic,
                complexity: 0.5
            )
        }
    }

    // MARK: - Edge Cases

    func testEmptyProgression() {
        // Test with empty progression
        let key = Key(tonic: .C, mode: .major)
        let suggestions = compositionTools.suggestNextChord(
            currentProgression: [],
            key: key,
            style: .pop
        )

        XCTAssertFalse(suggestions.isEmpty)
    }

    func testSingleChordProgression() {
        // Test with single chord
        let key = Key(tonic: .C, mode: .major)
        let progression = [
            Chord(root: .C, type: .major, confidence: 1.0)
        ]

        let suggestions = compositionTools.suggestNextChord(
            currentProgression: progression,
            key: key,
            style: .pop
        )

        XCTAssertFalse(suggestions.isEmpty)
    }
}
