import XCTest
@testable import Echoelmusic

/// Tests for AIComposer music generation and bio-reactive composition
final class AIComposerTests: XCTestCase {

    // MARK: - Note Tests

    func testNoteCreation() {
        let note = Note(pitch: 60, duration: 1.0, velocity: 100)

        XCTAssertEqual(note.pitch, 60)
        XCTAssertEqual(note.duration, 1.0)
        XCTAssertEqual(note.velocity, 100)
    }

    func testNoteNameMiddleC() {
        let note = Note(pitch: 60, duration: 1.0, velocity: 80)
        XCTAssertEqual(note.noteName, "C4")
    }

    func testNoteNameOctaves() {
        let c3 = Note(pitch: 48, duration: 1.0, velocity: 80)
        XCTAssertEqual(c3.noteName, "C3")

        let c5 = Note(pitch: 72, duration: 1.0, velocity: 80)
        XCTAssertEqual(c5.noteName, "C5")

        let a4 = Note(pitch: 69, duration: 1.0, velocity: 80)
        XCTAssertEqual(a4.noteName, "A4")
    }

    func testNoteNameSharps() {
        let cSharp4 = Note(pitch: 61, duration: 1.0, velocity: 80)
        XCTAssertEqual(cSharp4.noteName, "C#4")

        let fSharp4 = Note(pitch: 66, duration: 1.0, velocity: 80)
        XCTAssertEqual(fSharp4.noteName, "F#4")
    }

    func testNoteEquatable() {
        let note1 = Note(pitch: 60, duration: 1.0, velocity: 80)
        let note2 = Note(pitch: 60, duration: 1.0, velocity: 80)

        // Notes are Equatable but have unique IDs
        XCTAssertNotEqual(note1.id, note2.id)
    }

    // MARK: - Chord Tests

    func testChordCreation() {
        let chord = Chord(root: "C", type: .major)

        XCTAssertEqual(chord.root, "C")
        XCTAssertEqual(chord.type, .major)
    }

    func testChordDisplayName() {
        XCTAssertEqual(Chord(root: "C", type: .major).displayName, "Cmaj")
        XCTAssertEqual(Chord(root: "Am", type: .minor).displayName, "Ammin")
        XCTAssertEqual(Chord(root: "G", type: .dominant7).displayName, "G7")
        XCTAssertEqual(Chord(root: "D", type: .major7).displayName, "Dmaj7")
    }

    func testChordMidiNotesMajor() {
        let cMajor = Chord(root: "C", type: .major)
        XCTAssertEqual(cMajor.midiNotes, [60, 64, 67]) // C, E, G
    }

    func testChordMidiNotesMinor() {
        let aMinor = Chord(root: "A", type: .minor)
        XCTAssertEqual(aMinor.midiNotes, [69, 72, 76]) // A, C, E
    }

    func testChordMidiNotesDominant7() {
        let g7 = Chord(root: "G", type: .dominant7)
        XCTAssertEqual(g7.midiNotes, [67, 71, 74, 77]) // G, B, D, F
    }

    func testChordMidiNotesMajor7() {
        let cMaj7 = Chord(root: "C", type: .major7)
        XCTAssertEqual(cMaj7.midiNotes, [60, 64, 67, 71]) // C, E, G, B
    }

    func testChordMidiNotesMinor7() {
        let eMin7 = Chord(root: "E", type: .minor7)
        XCTAssertEqual(eMin7.midiNotes, [64, 67, 71, 74]) // E, G, B, D
    }

    func testChordMidiNotesDiminished() {
        let bDim = Chord(root: "B", type: .diminished)
        XCTAssertEqual(bDim.midiNotes, [71, 74, 77]) // B, D, F
    }

    func testChordMidiNotesAugmented() {
        let cAug = Chord(root: "C", type: .augmented)
        XCTAssertEqual(cAug.midiNotes, [60, 64, 68]) // C, E, G#
    }

    func testChordMidiNotesSus2() {
        let dSus2 = Chord(root: "D", type: .sus2)
        XCTAssertEqual(dSus2.midiNotes, [62, 64, 69]) // D, E, A
    }

    func testChordMidiNotesSus4() {
        let aSus4 = Chord(root: "A", type: .sus4)
        XCTAssertEqual(aSus4.midiNotes, [69, 74, 76]) // A, D, E
    }

    func testChordTypeAllCases() {
        let types = Chord.ChordType.allCases
        XCTAssertEqual(types.count, 9)
    }

    // MARK: - DrumHit Tests

    func testDrumHitCreation() {
        let kick = DrumHit(instrument: .kick, time: 0.0, velocity: 100)

        XCTAssertEqual(kick.instrument, .kick)
        XCTAssertEqual(kick.time, 0.0)
        XCTAssertEqual(kick.velocity, 100)
    }

    func testDrumInstrumentMidiNotes() {
        XCTAssertEqual(DrumHit.DrumInstrument.kick.rawValue, 36)
        XCTAssertEqual(DrumHit.DrumInstrument.snare.rawValue, 38)
        XCTAssertEqual(DrumHit.DrumInstrument.closedHat.rawValue, 42)
        XCTAssertEqual(DrumHit.DrumInstrument.openHat.rawValue, 46)
        XCTAssertEqual(DrumHit.DrumInstrument.crash.rawValue, 49)
        XCTAssertEqual(DrumHit.DrumInstrument.ride.rawValue, 51)
    }

    func testDrumInstrumentNames() {
        XCTAssertEqual(DrumHit.DrumInstrument.kick.name, "Kick")
        XCTAssertEqual(DrumHit.DrumInstrument.snare.name, "Snare")
        XCTAssertEqual(DrumHit.DrumInstrument.closedHat.name, "Hi-Hat")
        XCTAssertEqual(DrumHit.DrumInstrument.openHat.name, "Open Hat")
    }

    func testDrumInstrumentAllCases() {
        let instruments = DrumHit.DrumInstrument.allCases
        XCTAssertEqual(instruments.count, 9)
    }

    // MARK: - MusicStyle Tests

    func testMusicStyleRawValues() {
        XCTAssertEqual(MusicStyle.calm.rawValue, "Calm")
        XCTAssertEqual(MusicStyle.energetic.rawValue, "Energetic")
        XCTAssertEqual(MusicStyle.tense.rawValue, "Tense")
        XCTAssertEqual(MusicStyle.balanced.rawValue, "Balanced")
        XCTAssertEqual(MusicStyle.meditative.rawValue, "Meditative")
        XCTAssertEqual(MusicStyle.uplifting.rawValue, "Uplifting")
    }

    func testMusicStyleSuggestedTempo() {
        XCTAssertTrue(MusicStyle.calm.suggestedTempo.contains(70))
        XCTAssertTrue(MusicStyle.energetic.suggestedTempo.contains(130))
        XCTAssertTrue(MusicStyle.meditative.suggestedTempo.contains(60))
    }

    func testMusicStyleSuggestedScale() {
        XCTAssertEqual(MusicStyle.calm.suggestedScale, "major")
        XCTAssertEqual(MusicStyle.tense.suggestedScale, "minor")
        XCTAssertEqual(MusicStyle.meditative.suggestedScale, "pentatonic")
        XCTAssertEqual(MusicStyle.energetic.suggestedScale, "mixolydian")
    }

    func testMusicStyleAllCases() {
        let styles = MusicStyle.allCases
        XCTAssertEqual(styles.count, 6)
    }

    // MARK: - AIComposer Tests

    @MainActor
    func testAIComposerInitialization() async {
        let composer = AIComposer()

        XCTAssertFalse(composer.isGenerating)
        XCTAssertTrue(composer.generatedMelody.isEmpty)
        XCTAssertTrue(composer.suggestedChords.isEmpty)
        XCTAssertTrue(composer.generatedDrumPattern.isEmpty)
    }

    @MainActor
    func testBioToMusicStyleHighCoherence() async {
        let composer = AIComposer()

        let style = composer.mapBioToMusicStyle(hrv: 50, coherence: 0.85, heartRate: 70)
        XCTAssertEqual(style, .meditative)
    }

    @MainActor
    func testBioToMusicStyleMediumCoherence() async {
        let composer = AIComposer()

        let style = composer.mapBioToMusicStyle(hrv: 50, coherence: 0.65, heartRate: 70)
        XCTAssertEqual(style, .calm)
    }

    @MainActor
    func testBioToMusicStyleHighHeartRate() async {
        let composer = AIComposer()

        let style = composer.mapBioToMusicStyle(hrv: 50, coherence: 0.4, heartRate: 115)
        XCTAssertEqual(style, .energetic)
    }

    @MainActor
    func testBioToMusicStyleModerateHeartRate() async {
        let composer = AIComposer()

        let style = composer.mapBioToMusicStyle(hrv: 50, coherence: 0.4, heartRate: 95)
        XCTAssertEqual(style, .uplifting)
    }

    @MainActor
    func testBioToMusicStyleLowHRV() async {
        let composer = AIComposer()

        let style = composer.mapBioToMusicStyle(hrv: 20, coherence: 0.4, heartRate: 75)
        XCTAssertEqual(style, .tense)
    }

    @MainActor
    func testBioToMusicStyleBalanced() async {
        let composer = AIComposer()

        let style = composer.mapBioToMusicStyle(hrv: 50, coherence: 0.5, heartRate: 75)
        XCTAssertEqual(style, .balanced)
    }

    @MainActor
    func testMelodyGeneration() async {
        let composer = AIComposer()

        let melody = await composer.generateMelody(key: "C", scale: "major", bars: 2)

        XCTAssertFalse(melody.isEmpty)
        XCTAssertEqual(composer.generatedMelody, melody)

        // Check notes are in valid range
        for note in melody {
            XCTAssertGreaterThanOrEqual(note.pitch, 60)
            XCTAssertLessThanOrEqual(note.pitch, 84)
            XCTAssertGreaterThan(note.velocity, 0)
            XCTAssertLessThanOrEqual(note.velocity, 127)
        }
    }

    @MainActor
    func testMelodyGenerationDifferentScales() async {
        let composer = AIComposer()

        let majorMelody = await composer.generateMelody(key: "C", scale: "major", bars: 1)
        let minorMelody = await composer.generateMelody(key: "A", scale: "minor", bars: 1)
        let pentatonicMelody = await composer.generateMelody(key: "G", scale: "pentatonic", bars: 1)

        XCTAssertFalse(majorMelody.isEmpty)
        XCTAssertFalse(minorMelody.isEmpty)
        XCTAssertFalse(pentatonicMelody.isEmpty)
    }

    @MainActor
    func testChordProgression() async {
        let composer = AIComposer()

        let chords = await composer.suggestChordProgression(key: "C", mood: "happy")

        XCTAssertFalse(chords.isEmpty)
        XCTAssertEqual(composer.suggestedChords, chords)
    }

    @MainActor
    func testDrumPatternGeneration() async {
        let composer = AIComposer()

        let pattern = await composer.generateDrumPattern(style: .balanced, bars: 2)

        XCTAssertFalse(pattern.isEmpty)
        XCTAssertEqual(composer.generatedDrumPattern, pattern)

        // Check drum hits have valid timing
        for hit in pattern {
            XCTAssertGreaterThanOrEqual(hit.time, 0)
            XCTAssertLessThan(hit.time, 8.0) // 2 bars * 4 beats
            XCTAssertGreaterThan(hit.velocity, 0)
        }
    }

    @MainActor
    func testDrumPatternDifferentStyles() async {
        let composer = AIComposer()

        for style in MusicStyle.allCases {
            let pattern = await composer.generateDrumPattern(style: style, bars: 1)
            XCTAssertFalse(pattern.isEmpty, "Pattern for \(style.rawValue) should not be empty")
        }
    }

    @MainActor
    func testBioReactiveComposition() async {
        let composer = AIComposer()

        let result = await composer.composeBioReactivePiece(
            hrv: 60,
            coherence: 0.7,
            heartRate: 72,
            key: "G",
            bars: 4
        )

        XCTAssertFalse(result.melody.isEmpty)
        XCTAssertFalse(result.chords.isEmpty)
        XCTAssertFalse(result.drums.isEmpty)
    }

    @MainActor
    func testModelStatus() async {
        let composer = AIComposer()

        // Model status should be ready (either loaded or fallback)
        // Allow some time for async loading
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotEqual(composer.modelStatus, .notLoaded)
    }
}
