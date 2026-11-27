import XCTest
@testable import EchoelCore

final class ChordSuggestTests: XCTestCase {
    private let cMajor = MusicalContext(root: 0, scale: .major)
    private let aMinor = MusicalContext(root: 9, scale: .minor)

    func testTheScaleGivesOneTriadPerDegreeThenTheBorrowedOnes() {
        let chords = ChordSuggest.candidates(in: cMajor)
        XCTAssertEqual(chords.filter { !$0.borrowed }.map(\.name), ["C", "Dm", "Em", "F", "G", "Am", "B°"])
        XCTAssertEqual(chords.filter(\.borrowed).map(\.name), ["Fm", "A♭", "B♭"], "iv, ♭VI, ♭VII from the parallel minor")
        XCTAssertEqual(ChordSuggest.candidates(in: aMinor).filter(\.borrowed).map(\.name), ["E", "A", "B♭"],
                       "V, the Picardy tonic and the Neapolitan")
        XCTAssertTrue(ChordSuggest.candidates(in: MusicalContext()).isEmpty, "a song without a key has no chords")
    }

    func testFunctionOutranksSmoothnessAndTheCadenceResolves() throws {
        let g = try XCTUnwrap(ChordSuggest.candidates(in: cMajor).first { $0.name == "G" })
        let after = ChordSuggest.ranked(after: g, sounding: [55, 59, 62], in: cMajor)
        XCTAssertEqual(after.first?.function, .tonic, "after the dominant a tonic comes first")
        XCTAssertEqual(Array(after.prefix(3)).map(\.function), [.tonic, .tonic, .tonic])
        let opening = ChordSuggest.ranked(after: nil, sounding: [], in: cMajor)
        XCTAssertEqual(opening.first?.name, "C", "the tonic opens")
        for previous in ChordSuggest.candidates(in: cMajor) {
            XCTAssertEqual(ChordSuggest.ranked(after: previous, sounding: [], in: cMajor).first?.borrowed, false,
                           "a borrowed chord never ranks first")
        }
    }

    func testTheRankingIsDeterministic() {
        let a = ChordSuggest.ranked(after: nil, sounding: [60, 64, 67], in: aMinor)
        let b = ChordSuggest.ranked(after: nil, sounding: [60, 64, 67], in: aMinor)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, ChordSuggest.candidates(in: aMinor).count)
    }

    func testABorrowedChordSaysWhatLiesOutsideTheScale() throws {
        let flatSeven = try XCTUnwrap(ChordSuggest.candidates(in: cMajor).first { $0.name == "B♭" })
        XCTAssertEqual(ChordSuggest.outside(flatSeven, in: cMajor), [10])
        let f = try XCTUnwrap(ChordSuggest.candidates(in: cMajor).first { $0.name == "F" })
        XCTAssertTrue(ChordSuggest.outside(f, in: cMajor).isEmpty)
    }

    func testTheChordBeforeIsRecognisedFromItsNotes() {
        XCTAssertEqual(ChordSuggest.recognize([57, 60, 64], in: cMajor)?.name, "Am")
        XCTAssertEqual(ChordSuggest.recognize([64, 67, 72], in: cMajor)?.name, "C", "an inversion is the same chord")
        XCTAssertNil(ChordSuggest.recognize([61], in: cMajor))
        XCTAssertNil(ChordSuggest.recognize([], in: cMajor))
    }

    func testAPickLandsAfterTheLastNoteCloseToTheChordBefore() throws {
        var clip = Clip(name: "Keys", length: 2 * 3_840)
        XCTAssertEqual(ChordSuggest.position(in: clip, context: cMajor).start, 0)
        clip.notes = [60, 64, 67].map { Note(pitch: $0, velocity: 100, start: 0, length: 3_840) }
        let f = try XCTUnwrap(ChordSuggest.candidates(in: cMajor).first { $0.name == "F" })
        let command = try XCTUnwrap(ChordSuggest.insert(f, in: clip, context: cMajor, length: 3_840))
        guard case let .addNotes(id, notes) = command else { return XCTFail("\(command)") }
        XCTAssertEqual(id, clip.id)
        XCTAssertEqual(notes.map(\.start), [3_840, 3_840, 3_840])
        XCTAssertEqual(notes.map(\.pitch), [60, 65, 69], "C stays, E moves to F, G to A")
        XCTAssertTrue(notes.allSatisfy { $0.start + $0.length <= clip.length })
        clip.notes.append(contentsOf: notes)
        let full = ChordSuggest.insert(f, in: clip, context: cMajor, length: 3_840)
        XCTAssertNil(full, "no room after the last note")
    }

    // MARK: The chords of every scale (TH-5)

    /// The names of the scale's own chords on `root`, in the scale's order.
    private func row(_ scale: Scale, root: Int = 0) -> [String] {
        ChordSuggest.candidates(in: MusicalContext(root: root, scale: scale)).filter { !$0.borrowed }.map(\.name)
    }

    /// The pitch classes of the third-stack on `degree`: the scale's tones two and four steps above it.
    private func thirdStack(_ degree: Int, of scale: Scale, root: Int) -> [Int] {
        let steps = scale.intervals.sorted()
        return [0, 2, 4].map { (offset: Int) -> Int in ChordSuggest.pitchClass(root + steps[(degree + offset) % steps.count]) }
    }

    /// A seven-note scale keeps, on every degree whose third-stack the vocabulary names, that chord:
    /// the scale's own third and fifth above the degree, as before. In the church modes and in
    /// harmonic and melodic minor that is every degree, on every root. Harmonic major's E is Em, not
    /// the E major its A♭ would also allow; a degree whose third-stack has no name takes the first
    /// triad the scale holds there, or none — Hungarian minor has none on D (D-F♯-A♭) and on F♯.
    func testASevenNoteScaleKeepsTheThirdStackOfEveryDegreeItNames() {
        for scale in [Scale.major, .minor, .dorian, .phrygian, .lydian, .mixolydian, .locrian, .harmonicMinor, .melodicMinor] {
            for root in MusicalContext.rootRange {
                let chords = ChordSuggest.candidates(in: MusicalContext(root: root, scale: scale)).filter { !$0.borrowed }
                XCTAssertEqual(chords.map(\.rootDegree), Array(0..<7), "\(scale) on \(root)")
                XCTAssertEqual(chords.map(\.pitchClasses), (0..<7).map { (degree: Int) -> [Int] in
                    thirdStack(degree, of: scale, root: root)
                }, "\(scale) on \(root)")
            }
        }
        for scale in Scale.allCases where scale.intervals.count == 7 {
            for root in MusicalContext.rootRange {
                let chords = ChordSuggest.candidates(in: MusicalContext(root: root, scale: scale)).filter { !$0.borrowed }
                for degree in 0..<7 {
                    let stack = thirdStack(degree, of: scale, root: root)
                    let named = ChordSuggest.Quality.triads.contains { (quality: ChordSuggest.Quality) -> Bool in
                        quality.intervals == stack.map { (tone: Int) -> Int in ChordSuggest.pitchClass(tone - stack[0]) }
                    }
                    guard named else { continue }
                    XCTAssertEqual(chords.first { $0.rootDegree == degree }?.pitchClasses, stack, "\(scale) on \(root), degree \(degree)")
                }
            }
        }
        XCTAssertEqual(row(.harmonicMajor), ["C", "D°", "Em", "Fm", "G", "A♭+", "B°"])
        XCTAssertEqual(row(.hungarianMinor), ["Cm", "E♭+", "G", "A♭", "Bm"])
        XCTAssertEqual(row(.phrygianDominant, root: 4), ["E", "F", "G♯°", "Am", "B°", "C+", "Dm"],
                       "E Phrygian Dominant; its third is written G♯, as the key writes it")
    }

    /// A scale of another size takes, on each degree, the first triad of the vocabulary — major,
    /// minor, diminished, augmented, suspended second, suspended fourth — whose tones it holds: every
    /// other step of a pentatonic scale is no third, and its third-stacks (C-E-A) have no name. C
    /// major pentatonic is C, Dsus2, Gsus2, Am, and its E has no chord; C blues is Cm, E♭, Fsus2,
    /// B♭sus2; the whole-tone scale has an augmented triad on every degree.
    func testAScaleOfAnotherSizeTakesTheFirstTriadEachDegreeHolds() {
        XCTAssertEqual(row(.majorPentatonic), ["C", "Dsus2", "Gsus2", "Am"])
        XCTAssertEqual(row(.minorPentatonic), ["Cm", "E♭", "Fsus2", "B♭sus2"])
        XCTAssertEqual(row(.blues), ["Cm", "E♭", "Fsus2", "B♭sus2"])
        XCTAssertEqual(row(.wholeTone), ["C+", "D+", "E+", "F♯+", "A♭+", "B♭+"])
        XCTAssertEqual(row(.bebopDominant), ["C", "Dm", "Em", "F", "G", "Am", "B♭", "B°"])
        XCTAssertEqual(row(.hirajoshi, root: 9), ["Am", "Esus4", "F"], "A Hirajoshi: A B C E F")
        XCTAssertEqual(row(.yo, root: 2), ["Dsus2", "Em", "G", "Asus2"])
        for scale in Scale.allCases where scale != .chromatic && scale.intervals.count != 7 {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let steps = scale.intervals.sorted()
                let chords = ChordSuggest.candidates(in: context).filter { !$0.borrowed }
                for degree in steps.indices {
                    let held = ChordSuggest.Quality.triads.first { (quality: ChordSuggest.Quality) -> Bool in
                        quality.intervals.allSatisfy { context.contains(root + steps[degree] + $0) }
                    }
                    let chord = chords.first { $0.rootDegree == degree }
                    XCTAssertEqual(chord?.quality, held, "\(context.title), degree \(degree)")
                }
            }
        }
    }

    /// The vocabulary is every chord of the asked qualities that the scale holds, root by root in the
    /// scale's order and, on one root, quality by quality: C major's sevenths are its seven diatonic
    /// ones and the four seventh-suspended-fourth chords its tones allow; C major pentatonic holds
    /// three sevenths; A harmonic minor holds the minor-major seventh on A and the diminished seventh
    /// on its leading tone. A song without a key has none.
    func testTheVocabularyIsEveryChordTheScaleHolds() {
        let sevenths = ChordSuggest.Quality.sevenths
        XCTAssertEqual(ChordSuggest.vocabulary(in: cMajor, qualities: sevenths).map(\.name),
                       ["Cmaj7", "Dm7", "D7sus4", "Em7", "E7sus4", "Fmaj7", "G7", "G7sus4", "Am7", "A7sus4", "Bø7"])
        XCTAssertEqual(ChordSuggest.vocabulary(in: MusicalContext(root: 0, scale: .majorPentatonic), qualities: sevenths)
            .map(\.name), ["D7sus4", "Am7", "A7sus4"])
        let harmonic = ChordSuggest.vocabulary(in: MusicalContext(root: 9, scale: .harmonicMinor), qualities: sevenths).map(\.name)
        for name in ["Am(maj7)", "Bø7", "C+maj7", "Dm7", "E7", "Fmaj7", "G♯°7"] {
            XCTAssertTrue(harmonic.contains(name), "\(name) in \(harmonic)")
        }
        XCTAssertEqual(ChordSuggest.vocabulary(in: cMajor, qualities: [.major, .major]).map(\.name), ["C", "F", "G"],
                       "a quality asked twice is offered once")
        XCTAssertTrue(ChordSuggest.vocabulary(in: MusicalContext()).isEmpty, "a song without a key has no chords")

        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let steps = scale.intervals.sorted()
                let chords = ChordSuggest.vocabulary(in: context)
                XCTAssertFalse(chords.isEmpty, context.title)
                XCTAssertEqual(chords.map(\.rootDegree), chords.map(\.rootDegree).sorted(), context.title)
                for chord in chords {
                    let label = "\(context.title) \(chord.name)"
                    let quality = chord.quality
                    XCTAssertNotNil(quality, label)
                    XCTAssertFalse(chord.borrowed, label)
                    XCTAssertTrue(chord.alterations.allSatisfy { $0 == 0 }, label)
                    XCTAssertTrue(ChordSuggest.outside(chord, in: context).isEmpty, label)
                    XCTAssertEqual(chord.pitchClasses.first, ChordSuggest.pitchClass(root + steps[chord.rootDegree]), label)
                    XCTAssertEqual(chord.pitchClasses.count, quality?.intervals.count, label)
                }
                let triads = ChordSuggest.vocabulary(in: context, qualities: ChordSuggest.Quality.triads)
                XCTAssertEqual(Set(triads.map(\.pitchClasses)).count, triads.count, "\(context.title): no chord twice")
            }
        }
    }

    /// A borrowed chord brings at least one tone from outside the scale, and no chord is offered
    /// twice: a chord the scale holds is never offered again as borrowed, in any scale on any root.
    func testABorrowedChordAlwaysBringsAToneFromOutside() {
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let chords = ChordSuggest.candidates(in: context)
                XCTAssertEqual(Set(chords.map(\.pitchClasses)).count, chords.count, "\(context.title): no chord twice")
                for chord in chords {
                    XCTAssertEqual(ChordSuggest.outside(chord, in: context).isEmpty, !chord.borrowed, "\(context.title) \(chord.name)")
                    XCTAssertNotNil(chord.quality, "\(context.title) \(chord.name)")
                }
            }
        }
    }

    /// Each quality is its tones above the root, the root first and rising; each writes and says its
    /// own name, in plain words a screen reader speaks.
    func testEveryQualityHasItsOwnToneSymbolAndWords() {
        let qualities = ChordSuggest.Quality.allCases
        XCTAssertEqual(ChordSuggest.Quality.triads + ChordSuggest.Quality.sevenths, qualities)
        XCTAssertTrue(ChordSuggest.Quality.triads.allSatisfy { $0.intervals.count == 3 })
        XCTAssertTrue(ChordSuggest.Quality.sevenths.allSatisfy { $0.intervals.count == 4 })
        XCTAssertEqual(Set(qualities.map(\.intervals)).count, qualities.count)
        XCTAssertEqual(Set(qualities.map(\.symbol)).count, qualities.count)
        XCTAssertEqual(Set(qualities.map(\.spokenName)).count, qualities.count)
        for quality in qualities {
            XCTAssertEqual(quality.intervals.first, 0, "\(quality)")
            XCTAssertEqual(quality.intervals, quality.intervals.sorted(), "\(quality)")
            XCTAssertEqual(Set(quality.intervals).count, quality.intervals.count, "\(quality)")
            XCTAssertTrue(quality.intervals.allSatisfy { (0...11).contains($0) }, "\(quality)")
            XCTAssertFalse(quality.spokenName.contains("♯") || quality.spokenName.contains("♭"), "\(quality)")
            let words = Set(quality.spokenName.split(whereSeparator: { !$0.isLetter }).map(String.init))
            XCTAssertTrue(words.isDisjoint(with: LearnGuideTests.forbiddenWords), quality.spokenName)
        }
        XCTAssertEqual(ChordSuggest.Quality.major.symbol, "", "a major chord is its root alone")
    }

    func testEveryScaleWithAKeyRanksWithoutTrapping() {
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let ranked = ChordSuggest.ranked(after: ChordSuggest.candidates(in: context).last, sounding: [0, 127], in: context)
                XCTAssertFalse(ranked.isEmpty, "\(scale)")
                for chord in ranked {
                    XCTAssertTrue(ChordSuggest.voicing(of: chord, after: [127]).allSatisfy(Note.pitchRange.contains))
                    XCTAssertTrue(ChordSuggest.voicing(of: chord, after: [0]).allSatisfy(Note.pitchRange.contains))
                }
            }
        }
    }
}
