import XCTest
@testable import EchoelCore

/// The key finder over a clip's notes: the major or minor key whose Krumhansl–Kessler profile the
/// clip's sounding durations fit best, the runner-up and the lead between them, and that key as the
/// commands the musician may take — never taken by the finder.
final class KeyFinderTests: XCTestCase {
    private typealias Step = (pitches: [Int], quarters: Int64)

    private let quarter = MusicalTime.ticksPerQuarter

    /// A clip that plays `steps` one after another, each step's pitches together for its quarters,
    /// and ends where the last step ends.
    private func clip(_ steps: [Step]) -> Clip {
        var notes: [Note] = []
        var start: Tick = 0
        for step in steps {
            let length = step.quarters * quarter
            for pitch in step.pitches {
                notes.append(Note(pitch: pitch, start: start, length: length))
            }
            start += length
        }
        return Clip(name: "Notes", length: start, notes: notes)
    }

    /// One pitch per step, a quarter each.
    private func line(_ pitches: [Int]) -> [Step] {
        pitches.map { (pitch: Int) -> Step in ([pitch], 1) }
    }

    /// C4 up to C5, then IV, V7 and a held I.
    private var cMajorScaleAndCadence: Clip {
        let cadence: [Step] = [([53, 57, 60], 2), ([55, 59, 62, 65], 2), ([48, 52, 55, 60], 4)]
        return clip(line([60, 62, 64, 65, 67, 69, 71, 72]) + cadence)
    }

    /// A3 up to A4 and down to B3, then A3 again and a held A minor chord.
    private var aNaturalMinor: Clip {
        let ending: [Step] = [([57], 2), ([57, 60, 64], 4)]
        return clip(line([57, 59, 60, 62, 64, 65, 67, 69, 67, 65, 64, 62, 60, 59]) + ending)
    }

    /// G B D B, C A F♯ A, G D, and a held G.
    private var gMajorMelody: Clip {
        let ending: [Step] = [([67], 2), ([62], 2), ([67], 4)]
        return clip(line([67, 71, 74, 71, 72, 69, 66, 69]) + ending)
    }

    private func key(_ root: Int, _ scale: Scale) -> KeyFinder.Key {
        KeyFinder.Key(root: root, scale: scale)
    }

    // MARK: Keys

    func testACMajorScaleAndCadenceIsCMajorWellAheadOfItsRelativeMinor() throws {
        let finding = try XCTUnwrap(KeyFinder.find(in: cMajorScaleAndCadence))
        XCTAssertEqual(finding.best.key, key(0, .major))
        XCTAssertEqual(finding.best.key.title, "C Major")
        XCTAssertEqual(finding.runnerUp.key, key(9, .minor), "the relative minor shares every note")
        XCTAssertGreaterThan(finding.best.correlation, 0.9)
        XCTAssertGreaterThan(finding.margin, 0.3)
        XCTAssertEqual(finding.margin, finding.best.correlation - finding.runnerUp.correlation)
        XCTAssertFalse(finding.isAmbiguous)
        XCTAssertFalse(finding.isWeak)
        XCTAssertFalse(finding.isUnsure)
        XCTAssertEqual(finding.commands, [.setKeyRoot(0), .setScale(.major)])
    }

    func testANaturalMinorEndingOnItsTonicIsAMinorWithCMajorNext() throws {
        let finding = try XCTUnwrap(KeyFinder.find(in: aNaturalMinor))
        XCTAssertEqual(finding.best.key, key(9, .minor))
        XCTAssertEqual(finding.best.key.title, "A Minor")
        XCTAssertEqual(finding.runnerUp.key, key(0, .major), "the relative major shares every note")
        XCTAssertFalse(finding.isUnsure)
        XCTAssertEqual(finding.commands, [.setKeyRoot(9), .setScale(.minor)])
    }

    func testAGMajorMelodyIsGMajor() throws {
        let finding = try XCTUnwrap(KeyFinder.find(in: gMajorMelody))
        XCTAssertEqual(finding.best.key, key(7, .major))
        XCTAssertEqual(finding.best.key.title, "G Major")
        XCTAssertFalse(finding.isUnsure)
        XCTAssertEqual(finding.commands, [.setKeyRoot(7), .setScale(.major)])
    }

    /// The fits themselves, worked out from Krumhansl and Kessler's published ratings with exact
    /// fractions, to 16 digits. They hold the ratings: a mistyped rating can pass every other test
    /// here, and it moves at least one of these four.
    func testTheFitsAreTheCorrelationsWithKrumhanslAndKesslersRatings() throws {
        let major = try XCTUnwrap(KeyFinder.find(in: cMajorScaleAndCadence))
        XCTAssertEqual(major.best.correlation, 0.9827044046760743, accuracy: 1e-12, "C major")
        XCTAssertEqual(major.runnerUp.correlation, 0.6288880924891018, accuracy: 1e-12, "A minor")
        let minor = try XCTUnwrap(KeyFinder.find(in: aNaturalMinor))
        XCTAssertEqual(minor.best.correlation, 0.9746849061856258, accuracy: 1e-12, "A minor")
        XCTAssertEqual(minor.runnerUp.correlation, 0.6733768501870283, accuracy: 1e-12, "C major")
    }

    /// The same seven pitches, once each; only what is held after them differs. The finder weighs
    /// every note by how long it sounds, so the held chord decides between the two keys that share
    /// those seven — and played evenly, nothing decides, which the finding says.
    func testHowLongNotesSoundDecidesBetweenRelativeKeys() throws {
        let seven = line([57, 59, 60, 62, 64, 65, 67])
        let heldA: [Step] = [([57, 60, 64], 4)]
        let heldC: [Step] = [([60, 64, 67], 4)]
        let minor = try XCTUnwrap(KeyFinder.find(in: clip(seven + heldA)))
        XCTAssertEqual(minor.best.key, key(9, .minor))
        XCTAssertFalse(minor.isUnsure)
        let major = try XCTUnwrap(KeyFinder.find(in: clip(seven + heldC)))
        XCTAssertEqual(major.best.key, key(0, .major))
        XCTAssertFalse(major.isUnsure)
        let even = try XCTUnwrap(KeyFinder.find(in: clip(seven)))
        XCTAssertEqual(Set([even.best.key, even.runnerUp.key]), [key(0, .major), key(9, .minor)])
        XCTAssertTrue(even.isAmbiguous, "seven equal notes fit C major and A minor almost alike")
        XCTAssertTrue(even.isUnsure)
    }

    // MARK: Unsure

    func testNotesAllOnOnePitchNameTheirTonicButNotItsMode() throws {
        let finding = try XCTUnwrap(KeyFinder.find(in: clip(line(Array(repeating: 60, count: 8)))))
        XCTAssertEqual(finding.best.key.root, 0)
        XCTAssertEqual(finding.runnerUp.key.root, 0)
        XCTAssertNotEqual(finding.best.key.scale, finding.runnerUp.key.scale, "major and minor both start on C")
        XCTAssertLessThan(finding.margin, KeyFinder.marginFloor)
        XCTAssertTrue(finding.isAmbiguous)
        XCTAssertFalse(finding.isWeak, "the tonic alone fits either key well")
        XCTAssertTrue(finding.isUnsure)
    }

    func testAClusterOfNeighbouringSemitonesFitsNoKeyWellAndSaysSo() throws {
        let finding = try XCTUnwrap(KeyFinder.find(in: clip(line([60, 61, 62, 63]))))
        XCTAssertLessThan(finding.best.correlation, KeyFinder.correlationFloor)
        XCTAssertTrue(finding.isWeak)
        XCTAssertFalse(finding.isAmbiguous, "nothing else comes close, and still nothing fits well")
        XCTAssertTrue(finding.isUnsure)
    }

    /// SplitMix64 from a seed, so the drawn notes are the same in every run and on every platform.
    private struct Draws {
        var state: UInt64

        mutating func pitchClass() -> Int {
            state &+= 0x9E37_79B9_7F4A_7C15
            var mixed = state
            mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
            mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
            return Int((mixed ^ (mixed >> 31)) % 12)
        }
    }

    /// What the floors do not do: notes whose pitch classes are drawn at random have no key, and
    /// still about half of them come out sure, as the doc of `Finding.isUnsure` says. A change that
    /// takes the share out of these bounds makes that doc wrong; change the two together.
    func testAboutHalfOfNotesDrawnAtRandomStillComeOutSure() {
        var draws = Draws(state: 20_261_127)
        for count in [8, 64] {
            var sure = 0
            for _ in 0..<2_000 {
                let pitches = (0..<count).map { (_: Int) -> Int in 60 + draws.pitchClass() }
                if let finding = KeyFinder.find(in: clip(line(pitches))), !finding.isUnsure {
                    sure += 1
                }
            }
            XCTAssertGreaterThan(sure, 800, "\(count) notes: \(sure) of 2000 sure")
            XCTAssertLessThan(sure, 1_200, "\(count) notes: \(sure) of 2000 sure")
        }
    }

    // MARK: Nothing to find

    func testAClipThatSoundsNothingFindsNoKey() {
        XCTAssertNil(KeyFinder.find(in: Clip(name: "Empty", length: 4 * quarter)))
        let pastTheEnd = [Note(pitch: 60, start: 4 * quarter, length: quarter),
                          Note(pitch: 64, start: 6 * quarter, length: quarter)]
        XCTAssertNil(KeyFinder.find(in: Clip(name: "Past the end", length: 4 * quarter, notes: pastTheEnd)))
        let refused = [Note(pitch: 128, start: 0, length: quarter),
                       Note(pitch: 60, start: -quarter, length: quarter),
                       Note(pitch: 62, start: 0, length: 0)]
        XCTAssertNil(KeyFinder.find(in: Clip(name: "Refused", length: 4 * quarter, notes: refused)),
                     "notes the door refuses sound nothing and weigh nothing")
    }

    func testEveryPitchClassSoundingAlikeFindsNoKey() {
        XCTAssertNil(KeyFinder.find(in: clip(line(Array(60...71)))), "every key fits a flat profile alike")
        XCTAssertNil(KeyFinder.find(weights: [Tick](repeating: 7, count: 12)))
    }

    func testWeightsThatAreNotTwelveDurationsFindNoKey() {
        let one: [Tick] = [960, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let negative: [Tick] = [960, -960, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        XCTAssertNil(KeyFinder.find(weights: []))
        XCTAssertNil(KeyFinder.find(weights: [Tick](repeating: 960, count: 11)))
        XCTAssertNil(KeyFinder.find(weights: negative))
        XCTAssertNil(KeyFinder.find(weights: [Tick](repeating: 0, count: 12)))
        XCTAssertNotNil(KeyFinder.find(weights: one))
    }

    // MARK: What weighs

    /// As `PlaybackPlan` plays a clip: a note sounds from its start to the clip's end at the
    /// latest, not at all from the end on, and two notes of one pitch never sound at once.
    func testOnlyWhatTheClipPlaysWeighs() {
        let notes = [
            Note(pitch: 60, start: 0, length: quarter),
            Note(pitch: 60, start: 0, length: quarter),                 // the same note again: once
            Note(pitch: 72, start: quarter, length: quarter),           // C an octave up: C again
            Note(pitch: 62, start: quarter, length: 2 * quarter),       // cut where the next D starts
            Note(pitch: 62, start: 2 * quarter, length: quarter / 2),
            Note(pitch: 64, start: 3 * quarter, length: 4 * quarter),   // cut at the clip's end
            Note(pitch: 67, start: 4 * quarter, length: quarter),       // starts at the end: silent
            Note(pitch: 67, start: 6 * quarter, length: quarter),
        ]
        let expected: [Tick] = [2 * quarter, 0, quarter + quarter / 2, 0, quarter, 0, 0, 0, 0, 0, 0, 0]
        XCTAssertEqual(KeyFinder.weights(of: Clip(name: "Heard", length: 4 * quarter, notes: notes)), expected)
    }

    // MARK: Determinism

    /// C4 up to B4, one note each, at lengths whose mean is no whole number of ticks: the finder's
    /// sums round here, and summed in pitch-class order the last bit of the fit would follow the
    /// transposition. The lengths were searched for to show exactly that.
    private var unevenPhrase: Clip {
        let lengths: [Tick] = [1908, 3783, 1482, 1018, 2864, 336, 1230, 2028, 2988, 1180, 300, 2097]
        var notes: [Note] = []
        var start: Tick = 0
        for (offset, length) in lengths.enumerated() {
            notes.append(Note(pitch: 60 + offset, start: start, length: length))
            start += length
        }
        return Clip(name: "Uneven", length: start, notes: notes)
    }

    private func transposed(_ clip: Clip, by shift: Int) -> Clip {
        var moved = clip
        moved.notes = moved.notes.map { (note: Note) -> Note in
            var copy = note
            copy.pitch += shift
            return copy
        }
        return moved
    }

    func testATransposedClipFindsTheTransposedKeyWithTheSameFitToTheLastBit() throws {
        for original in [cMajorScaleAndCadence, unevenPhrase] {
            let base = try XCTUnwrap(KeyFinder.find(in: original))
            let first = base.best.key, second = base.runnerUp.key
            for shift in 1...11 {
                let finding = try XCTUnwrap(KeyFinder.find(in: transposed(original, by: shift)))
                XCTAssertEqual(finding.best.key, key((first.root + shift) % 12, first.scale), "up \(shift)")
                XCTAssertEqual(finding.runnerUp.key, key((second.root + shift) % 12, second.scale), "up \(shift)")
                XCTAssertEqual(finding.best.correlation, base.best.correlation, "up \(shift)")
                XCTAssertEqual(finding.margin, base.margin, "up \(shift)")
            }
        }
    }

    func testTheOrderNotesAreStoredInDoesNotChangeTheFinding() throws {
        var backwards = cMajorScaleAndCadence
        backwards.notes = Array(backwards.notes.reversed())
        XCTAssertEqual(KeyFinder.find(in: backwards), KeyFinder.find(in: cMajorScaleAndCadence))
    }

    /// A whole-tone scale sounds the same moved by a whole tone, so the major keys on C, D, E, F♯,
    /// G♯ and A♯ fit it exactly alike. The fixed order decides: by root from C, major before minor.
    func testKeysThatFitExactlyAlikeTakeTheFixedOrder() throws {
        let finding = try XCTUnwrap(KeyFinder.find(in: clip(line([60, 62, 64, 66, 68, 70]))))
        XCTAssertEqual(finding.best.key, key(0, .major))
        XCTAssertEqual(finding.runnerUp.key, key(2, .major))
        XCTAssertEqual(finding.margin, 0)
        XCTAssertTrue(finding.isUnsure)
    }

    // MARK: A proposal

    func testTheFindingIsAProposalTheSongTakesAsOneUndoStep() async throws {
        let melody = gMajorMelody
        try await MainActor.run {
            let store = ProjectStore()
            let before = store.project
            let finding = try XCTUnwrap(KeyFinder.find(in: melody))
            XCTAssertEqual(store.project, before, "finding a key sets nothing")
            XCTAssertTrue(store.undoStack.isEmpty)

            try store.perform(finding.commands, title: "Set Key")
            XCTAssertEqual(store.project.context.root, 7)
            XCTAssertEqual(store.project.context.scale, .major)
            XCTAssertEqual(store.project.context.title, finding.best.key.title)
            XCTAssertEqual(store.undoStack.count, 1, "root and scale are one step")

            try store.perform(finding.commands, title: "Set Key")
            XCTAssertEqual(store.undoStack.count, 1, "a song already in the key takes no step")

            store.undo()
            XCTAssertEqual(store.project, before)
        }
    }
}
