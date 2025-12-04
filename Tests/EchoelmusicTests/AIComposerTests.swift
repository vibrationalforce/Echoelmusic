import XCTest
@testable import Echoelmusic

/// Comprehensive tests for AI Composer functionality
final class AIComposerTests: XCTestCase {

    var composer: AIComposer!

    @MainActor
    override func setUp() async throws {
        composer = AIComposer()
    }

    override func tearDown() {
        composer = nil
    }

    // MARK: - Melody Generation Tests

    @MainActor
    func testMelodyGenerationProducesNotes() async {
        let melody = await composer.generateMelody(key: "C", scale: "major", bars: 4)

        XCTAssertFalse(melody.isEmpty, "Melody should not be empty")
        XCTAssertEqual(melody.count, 16, "4 bars with 4 notes each should produce 16 notes")
    }

    @MainActor
    func testMelodyNotesAreInValidRange() async {
        let melody = await composer.generateMelody(key: "C", scale: "major", bars: 4)

        for note in melody {
            XCTAssertGreaterThanOrEqual(note.pitch, 48, "Note pitch should be >= C3 (48)")
            XCTAssertLessThanOrEqual(note.pitch, 84, "Note pitch should be <= C6 (84)")
            XCTAssertGreaterThanOrEqual(note.velocity, 1, "Velocity should be >= 1")
            XCTAssertLessThanOrEqual(note.velocity, 127, "Velocity should be <= 127")
            XCTAssertGreaterThan(note.duration, 0, "Duration should be positive")
        }
    }

    @MainActor
    func testMelodyGenerationWithDifferentKeys() async {
        let keys = ["C", "D", "E", "F", "G", "A", "B", "C#", "F#"]

        for key in keys {
            let melody = await composer.generateMelody(key: key, scale: "major", bars: 2)
            XCTAssertEqual(melody.count, 8, "Should generate 8 notes for 2 bars in key \(key)")
        }
    }

    @MainActor
    func testMelodyGenerationWithDifferentScales() async {
        let scales = ["major", "minor", "dorian", "mixolydian", "pentatonic", "blues"]

        for scale in scales {
            let melody = await composer.generateMelody(key: "C", scale: scale, bars: 2)
            XCTAssertEqual(melody.count, 8, "Should generate 8 notes for scale \(scale)")
        }
    }

    // MARK: - Chord Progression Tests

    @MainActor
    func testChordProgressionGeneration() async {
        let chords = await composer.suggestChordProgression(key: "C", mood: "happy")

        XCTAssertFalse(chords.isEmpty, "Should generate chord progression")
        XCTAssertGreaterThanOrEqual(chords.count, 4, "Should have at least 4 chords")
    }

    @MainActor
    func testChordProgressionByMood() async {
        let moods = ["happy", "sad", "energetic", "calm", "tense"]

        for mood in moods {
            let chords = await composer.suggestChordProgression(key: "C", mood: mood)
            XCTAssertFalse(chords.isEmpty, "Should generate chords for mood: \(mood)")
        }
    }

    @MainActor
    func testChordHasValidMidiNotes() async {
        let chords = await composer.suggestChordProgression(key: "C", mood: "happy")

        for chord in chords {
            let midiNotes = chord.midiNotes
            XCTAssertGreaterThanOrEqual(midiNotes.count, 3, "Chord should have at least 3 notes")

            for note in midiNotes {
                XCTAssertGreaterThanOrEqual(note, 0, "MIDI note should be >= 0")
                XCTAssertLessThanOrEqual(note, 127, "MIDI note should be <= 127")
            }
        }
    }

    // MARK: - Drum Pattern Tests

    @MainActor
    func testDrumPatternGeneration() async {
        let pattern = await composer.generateDrumPattern(style: .house, bars: 4, bpm: 120)

        XCTAssertEqual(pattern.kicks.count, 64, "4 bars * 16 steps = 64 kick samples")
        XCTAssertEqual(pattern.snares.count, 64, "4 bars * 16 steps = 64 snare samples")
        XCTAssertEqual(pattern.hiHats.count, 64, "4 bars * 16 steps = 64 hi-hat samples")
        XCTAssertEqual(pattern.bpm, 120, "BPM should match input")
    }

    @MainActor
    func testDrumPatternStyles() async {
        let styles: [DrumStyle] = [.house, .techno, .hiphop, .dnb, .ambient]

        for style in styles {
            let pattern = await composer.generateDrumPattern(style: style, bars: 2, bpm: 128)
            XCTAssertEqual(pattern.kicks.count, 32, "Should generate 32 kick samples for \(style)")
        }
    }

    // MARK: - Bio-Data Mapping Tests

    @MainActor
    func testBioDataToCalmStyle() {
        // High coherence, low heart rate = calm
        let style = composer.mapBioToMusicStyle(hrv: 80, coherence: 85, heartRate: 55)
        XCTAssertEqual(style, .calm, "High coherence + low HR should map to calm")
    }

    @MainActor
    func testBioDataToEnergeticStyle() {
        // High heart rate = energetic
        let style = composer.mapBioToMusicStyle(hrv: 50, coherence: 60, heartRate: 110)
        XCTAssertEqual(style, .energetic, "High HR should map to energetic")
    }

    @MainActor
    func testBioDataToTenseStyle() {
        // Low HRV, low coherence = tense
        let style = composer.mapBioToMusicStyle(hrv: 20, coherence: 25, heartRate: 85)
        XCTAssertEqual(style, .tense, "Low HRV + low coherence should map to tense")
    }

    @MainActor
    func testBioDataToFlowStyle() {
        // High coherence + moderate HR = flow
        let style = composer.mapBioToMusicStyle(hrv: 70, coherence: 90, heartRate: 70)
        XCTAssertEqual(style, .flow, "High coherence + moderate HR should map to flow")
    }

    // MARK: - Music Theory Engine Tests

    func testMusicTheoryScaleNotes() {
        let engine = MusicTheoryEngine()

        let cMajor = engine.getScaleNotes(key: "C", scale: "major")
        XCTAssertTrue(cMajor.contains(60), "C major should contain C4 (60)")
        XCTAssertTrue(cMajor.contains(64), "C major should contain E4 (64)")
        XCTAssertTrue(cMajor.contains(67), "C major should contain G4 (67)")

        let aMinor = engine.getScaleNotes(key: "A", scale: "minor")
        XCTAssertTrue(aMinor.contains(69), "A minor should contain A4 (69)")
    }

    // MARK: - Note Struct Tests

    func testNoteFrequencyConversion() {
        let a4 = Note(pitch: 69, duration: 1.0, velocity: 100)
        XCTAssertEqual(a4.frequencyHz, 440.0, accuracy: 0.01, "A4 should be 440 Hz")

        let c4 = Note(pitch: 60, duration: 1.0, velocity: 100)
        XCTAssertEqual(c4.frequencyHz, 261.63, accuracy: 0.1, "C4 should be ~261.63 Hz")
    }

    func testNoteNameConversion() {
        let c4 = Note(pitch: 60, duration: 1.0, velocity: 100)
        XCTAssertEqual(c4.noteName, "C4", "MIDI 60 should be C4")

        let a4 = Note(pitch: 69, duration: 1.0, velocity: 100)
        XCTAssertEqual(a4.noteName, "A4", "MIDI 69 should be A4")

        let fSharp5 = Note(pitch: 78, duration: 1.0, velocity: 100)
        XCTAssertEqual(fSharp5.noteName, "F#5", "MIDI 78 should be F#5")
    }

    // MARK: - Chord Tests

    func testChordMidiNotes() {
        let cMajor = Chord(root: "C", type: .major)
        XCTAssertEqual(cMajor.midiNotes, [60, 64, 67], "C major should be C-E-G")

        let aMinor = Chord(root: "A", type: .minor)
        XCTAssertEqual(aMinor.midiNotes, [69, 72, 76], "A minor should be A-C-E")

        let g7 = Chord(root: "G", type: .dominant7)
        XCTAssertEqual(g7.midiNotes, [67, 71, 74, 77], "G7 should be G-B-D-F")
    }

    func testChordDisplayName() {
        let cMajor = Chord(root: "C", type: .major)
        XCTAssertEqual(cMajor.displayName, "Cmaj")

        let aMinor = Chord(root: "A", type: .minor)
        XCTAssertEqual(aMinor.displayName, "Amin")

        let fMaj7 = Chord(root: "F", type: .major7)
        XCTAssertEqual(fMaj7.displayName, "Fmaj7")
    }

    // MARK: - Performance Tests

    @MainActor
    func testMelodyGenerationPerformance() async {
        measure {
            let expectation = XCTestExpectation(description: "Melody generation")

            Task { @MainActor in
                _ = await composer.generateMelody(key: "C", scale: "major", bars: 8)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    @MainActor
    func testDrumPatternPerformance() async {
        measure {
            let expectation = XCTestExpectation(description: "Drum pattern generation")

            Task { @MainActor in
                _ = await composer.generateDrumPattern(style: .techno, bars: 16, bpm: 140)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }
}

// MARK: - Markov Generator Tests

final class MarkovMelodyGeneratorTests: XCTestCase {

    var generator: MarkovMelodyGenerator!

    override func setUp() {
        generator = MarkovMelodyGenerator()
        generator.trainOnMusicTheory()
    }

    func testMarkovProducesValidIntervals() {
        let scaleNotes = [60, 62, 64, 65, 67, 69, 71]  // C major

        for _ in 0..<100 {
            let nextNote = generator.getNextNote(
                previousNote: 60,
                previousInterval: 0,
                scaleNotes: scaleNotes,
                beatPosition: 0,
                style: .balanced
            )

            XCTAssertGreaterThanOrEqual(nextNote, 48)
            XCTAssertLessThanOrEqual(nextNote, 84)
        }
    }

    func testMarkovConfidenceIsValid() {
        let scaleNotes = [60, 62, 64, 65, 67, 69, 71]

        _ = generator.getNextNote(
            previousNote: 60,
            previousInterval: 2,
            scaleNotes: scaleNotes,
            beatPosition: 0,
            style: .balanced
        )

        XCTAssertGreaterThanOrEqual(generator.lastConfidence, 0)
        XCTAssertLessThanOrEqual(generator.lastConfidence, 1)
    }
}
