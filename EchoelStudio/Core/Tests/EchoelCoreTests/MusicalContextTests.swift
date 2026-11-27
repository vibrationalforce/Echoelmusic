import XCTest
@testable import EchoelCore

final class MusicalContextTests: XCTestCase {
    func testTheDefaultFramesNothing() {
        let context = MusicalContext()
        XCTAssertTrue((0...127).allSatisfy(context.contains), "chromatic keeps every pitch")
        XCTAssertEqual((0...127).map(context.nearest), Array(0...127))
        XCTAssertEqual(context.centsTable(), Array(repeating: 0, count: 12), "12 equal at 440 Hz retunes nothing")
    }

    func testAScaleKeepsItsPitchesAndSnapsOthersDownOnATie() {
        let cMajor = MusicalContext(scale: .major)
        XCTAssertEqual((60...71).filter(cMajor.contains), [60, 62, 64, 65, 67, 69, 71])
        XCTAssertEqual(cMajor.nearest(61), 60, "C♯ is between C and D: the lower wins")
        XCTAssertEqual(cMajor.nearest(66), 65)
        XCTAssertEqual(cMajor.nearest(64), 64)

        let dMajor = MusicalContext(root: 2, scale: .major)
        XCTAssertTrue(dMajor.contains(61), "C♯ is the seventh of D major")
        XCTAssertFalse(dMajor.contains(60))

        let pentatonic = MusicalContext(root: 9, scale: .minorPentatonic)
        XCTAssertEqual((57...68).filter(pentatonic.contains), [57, 60, 62, 64, 67])
    }

    // MARK: The key shown on a keyboard

    func testAKeyWearsItsPlaceInTheSongsKey() {
        let cMajor = MusicalContext(scale: .major)
        XCTAssertEqual(cMajor.keyMark(of: 60), .root)
        XCTAssertEqual(cMajor.keyMark(of: 72), .root, "every octave of the root")
        XCTAssertEqual(cMajor.keyMark(of: 62), .scaleTone)
        XCTAssertEqual(cMajor.keyMark(of: 61), KeyMark.unmarked, "C♯ is outside C major")

        let aMinor = MusicalContext(root: 9, scale: .minor)
        XCTAssertEqual(aMinor.keyMark(of: 57), .root)
        XCTAssertEqual(aMinor.keyMark(of: 60), .scaleTone, "C is the third of A minor")
        XCTAssertEqual(aMinor.keyMark(of: 61), KeyMark.unmarked)
    }

    func testAChromaticSongMarksNoKey() {
        let chromatic = MusicalContext()
        XCTAssertTrue((0...127).allSatisfy { (pitch: Int) -> Bool in chromatic.keyMark(of: pitch) == KeyMark.unmarked })
        let rooted = MusicalContext(root: 7, scale: .chromatic)
        XCTAssertEqual(rooted.keyMark(of: 67), KeyMark.unmarked, "a root alone frames nothing")
    }

    func testAPitchOutsideTheKeyboardWearsNothing() {
        let cMajor = MusicalContext(scale: .major)
        XCTAssertEqual(cMajor.keyMark(of: -12), KeyMark.unmarked)
        XCTAssertEqual(cMajor.keyMark(of: 128), KeyMark.unmarked)
        XCTAssertEqual(cMajor.keyMark(of: 0), .root)
        XCTAssertEqual(cMajor.keyMark(of: 127), .scaleTone, "G9 is the fifth of C")
    }

    /// In every scale and on every root, one octave shows one root and as many other marks as
    /// the scale has other tones — and a marked key is exactly a key the scale contains.
    func testAnOctaveShowsOneRootAndTheScalesOtherTones() {
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let marks: [KeyMark] = (60..<72).map { (pitch: Int) -> KeyMark in context.keyMark(of: pitch) }
                let roots = marks.filter { (mark: KeyMark) -> Bool in mark == .root }.count
                let tones = marks.filter { (mark: KeyMark) -> Bool in mark == .scaleTone }.count
                XCTAssertEqual(roots, 1, "\(context.title)")
                XCTAssertEqual(tones, scale.intervals.count - 1, "\(context.title)")
                for pitch in 60..<72 {
                    XCTAssertEqual(context.keyMark(of: pitch) != KeyMark.unmarked, context.contains(pitch), "\(context.title), pitch \(pitch)")
                }
            }
        }
    }

    func testTheFrameReadsAsKeyAndScale() throws {
        XCTAssertEqual(MusicalContext(root: 2, scale: .dorian).title, "D Dorian")
        XCTAssertEqual(MusicalContext(root: 10, scale: .harmonicMinor).title, "B♭ Harmonic Minor")
        XCTAssertEqual(MusicalContext().title, "Chromatic")
        XCTAssertEqual(MusicalContext(root: 7).title, "Chromatic", "chromatic has no key to name")
        var later = try JSONDecoder().decode(MusicalContext.self, from: Data(
            #"{"root":2,"scale":"bebop","tuning":"edo12","concertPitch":440,"swing":0}"#.utf8))
        XCTAssertEqual(later.title, "Chromatic", "a scale this build does not know frames nothing")
        later.scale = .minor
        XCTAssertEqual(later.title, "D Minor")
    }

    func testNearestStaysAMIDIPitch() {
        let cMajor = MusicalContext(scale: .major)
        XCTAssertEqual(cMajor.nearest(200), 127)
        XCTAssertEqual(cMajor.nearest(-5), 0)
        XCTAssertEqual(MusicalContext(root: 2, scale: .major).nearest(0), 1, "C is not in D major; C♯ is")
    }

    // MARK: Scales

    /// Every scale a song can store, in its stored order: the notes its name plays, the title the
    /// menu shows and the shelf it sits on. The first fourteen are the first build's; the 43 after
    /// them are the earlier app's other scales under its names and in its order (TH-4, 2026-11-27,
    /// from `Sources/Echoelmusic/Sequencer/MusicalKey.swift`), so a song that stores one of those
    /// names plays the notes the name stood for there. A changed set would retune every such song.
    private let everyScale: [(name: String, steps: [Int], title: String, shelf: Scale.Shelf)] = [
        ("chromatic", Array(0...11), "Chromatic", .symmetric),
        ("major", [0, 2, 4, 5, 7, 9, 11], "Major", .modes),
        ("minor", [0, 2, 3, 5, 7, 8, 10], "Minor", .modes),
        ("dorian", [0, 2, 3, 5, 7, 9, 10], "Dorian", .modes),
        ("phrygian", [0, 1, 3, 5, 7, 8, 10], "Phrygian", .modes),
        ("lydian", [0, 2, 4, 6, 7, 9, 11], "Lydian", .modes),
        ("mixolydian", [0, 2, 4, 5, 7, 9, 10], "Mixolydian", .modes),
        ("locrian", [0, 1, 3, 5, 6, 8, 10], "Locrian", .modes),
        ("harmonicMinor", [0, 2, 3, 5, 7, 8, 11], "Harmonic Minor", .minorAndAltered),
        ("melodicMinor", [0, 2, 3, 5, 7, 9, 11], "Melodic Minor", .minorAndAltered),
        ("majorPentatonic", [0, 2, 4, 7, 9], "Major Pentatonic", .pentatonicAndBlues),
        ("minorPentatonic", [0, 3, 5, 7, 10], "Minor Pentatonic", .pentatonicAndBlues),
        ("blues", [0, 3, 5, 6, 7, 10], "Blues", .pentatonicAndBlues),
        ("wholeTone", [0, 2, 4, 6, 8, 10], "Whole Tone", .symmetric),
        ("lydianDominant", [0, 2, 4, 6, 7, 9, 10], "Lydian Dominant", .minorAndAltered),
        ("altered", [0, 1, 3, 4, 6, 8, 10], "Altered", .minorAndAltered),
        ("bebopDominant", [0, 2, 4, 5, 7, 9, 10, 11], "Bebop Dominant", .minorAndAltered),
        ("bluesMajor", [0, 2, 3, 4, 7, 9], "Blues Major", .pentatonicAndBlues),
        ("diminishedWholeHalf", [0, 2, 3, 5, 6, 8, 9, 11], "Diminished (W–H)", .symmetric),
        ("diminishedHalfWhole", [0, 1, 3, 4, 6, 7, 9, 10], "Diminished (H–W)", .symmetric),
        ("phrygianDominant", [0, 1, 4, 5, 7, 8, 10], "Phrygian Dominant", .maqamAndNearEast),
        ("harmonicMajor", [0, 2, 4, 5, 7, 8, 11], "Harmonic Major", .minorAndAltered),
        ("hungarianMinor", [0, 2, 3, 6, 7, 8, 11], "Hungarian Minor", .europeanFolk),
        ("doubleHarmonic", [0, 1, 4, 5, 7, 8, 11], "Double Harmonic", .maqamAndNearEast),
        ("neapolitanMinor", [0, 1, 3, 5, 7, 8, 11], "Neapolitan Minor", .europeanFolk),
        ("neapolitanMajor", [0, 1, 3, 5, 7, 9, 11], "Neapolitan Major", .europeanFolk),
        ("romanianMinor", [0, 2, 3, 6, 7, 9, 10], "Romanian Minor", .europeanFolk),
        ("persian", [0, 1, 4, 5, 6, 8, 11], "Persian", .maqamAndNearEast),
        ("hirajoshi", [0, 2, 3, 7, 8], "Hirajoshi", .eastAndSoutheastAsia),
        ("iwato", [0, 1, 5, 6, 10], "Iwato", .eastAndSoutheastAsia),
        ("insen", [0, 1, 5, 7, 10], "Insen", .eastAndSoutheastAsia),
        ("yo", [0, 2, 5, 7, 9], "Yo", .eastAndSoutheastAsia),
        ("inSakura", [0, 1, 5, 7, 8], "In (Sakura)", .eastAndSoutheastAsia),
        ("egyptian", [0, 2, 5, 7, 10], "Egyptian", .pentatonicAndBlues),
        ("pelog", [0, 1, 3, 7, 8], "Pelog", .eastAndSoutheastAsia),
        ("enigmatic", [0, 1, 4, 6, 8, 10, 11], "Enigmatic", .europeanFolk),
        ("prometheus", [0, 2, 4, 6, 9, 10], "Prometheus", .europeanFolk),
        ("augmented", [0, 3, 4, 7, 8, 11], "Augmented", .symmetric),
        ("tritone", [0, 1, 4, 6, 7, 10], "Tritone", .symmetric),
        ("hungarianMajor", [0, 3, 4, 6, 7, 9, 10], "Hungarian Major", .europeanFolk),
        ("bebopMajor", [0, 2, 4, 5, 7, 8, 9, 11], "Bebop Major", .minorAndAltered),
        ("majorLocrian", [0, 2, 4, 5, 6, 8, 10], "Major Locrian", .minorAndAltered),
        ("lydianAugmented", [0, 2, 4, 6, 8, 9, 11], "Lydian Augmented", .minorAndAltered),
        ("spanishEightTone", [0, 1, 3, 4, 5, 6, 8, 10], "Spanish 8-Tone", .europeanFolk),
        ("kumoi", [0, 2, 3, 7, 9], "Kumoi", .eastAndSoutheastAsia),
        ("messiaen3", [0, 2, 3, 4, 6, 7, 8, 10, 11], "Messiaen 3", .symmetric),
        ("messiaen4", [0, 1, 2, 5, 6, 7, 8, 11], "Messiaen 4", .symmetric),
        ("messiaen5", [0, 1, 5, 6, 7, 11], "Messiaen 5", .symmetric),
        ("messiaen6", [0, 2, 4, 5, 6, 8, 10, 11], "Messiaen 6", .symmetric),
        ("messiaen7", [0, 1, 2, 3, 5, 6, 7, 8, 9, 11], "Messiaen 7", .symmetric),
        ("marwa", [0, 1, 4, 6, 7, 9, 11], "Marwa", .hindustaniAndCarnatic),
        ("purvi", [0, 1, 4, 6, 7, 8, 11], "Purvi", .hindustaniAndCarnatic),
        ("todi", [0, 1, 3, 6, 7, 8, 11], "Todi (Hindustani)", .hindustaniAndCarnatic),
        ("malkauns", [0, 3, 5, 8, 10], "Malkauns", .hindustaniAndCarnatic),
        ("charukeshi", [0, 2, 4, 5, 7, 8, 10], "Charukeshi", .hindustaniAndCarnatic),
        ("hamsadhwani", [0, 2, 4, 7, 11], "Hamsadhwani", .hindustaniAndCarnatic),
        ("shanmukhapriya", [0, 2, 3, 6, 7, 8, 10], "Shanmukhapriya", .hindustaniAndCarnatic),
    ]

    func testEveryStoredScaleNamePlaysItsNotesUnderItsTitleOnItsShelf() {
        XCTAssertEqual(Scale.allCases.map(\.rawValue), everyScale.map(\.name), "every scale, in its stored order")
        for row in everyScale {
            guard let scale = Scale(rawValue: row.name) else {
                XCTFail("\(row.name) names no scale")
                continue
            }
            XCTAssertEqual(scale.intervals, Set(row.steps), "\(row.name): the notes the name stands for")
            XCTAssertEqual(scale.title, row.title, row.name)
            XCTAssertEqual(scale.shelf, row.shelf, row.name)
        }
    }

    /// A scale of the earlier app plays on the song's root like any other: A Hirajoshi is A B C E F,
    /// D Hungarian Minor holds G♯ and C♯, and the frame reads them by their titles.
    func testAnAppendedScalePlaysOnTheSongsRoot() {
        let hirajoshi = MusicalContext(root: 9, scale: .hirajoshi)
        XCTAssertEqual((57...68).filter(hirajoshi.contains), [57, 59, 60, 64, 65])
        XCTAssertEqual(hirajoshi.title, "A Hirajoshi")
        XCTAssertEqual(hirajoshi.nearest(62), 60, "D lies between C and E: the lower wins")
        let hungarian = MusicalContext(root: 2, scale: .hungarianMinor)
        XCTAssertEqual((62...73).filter(hungarian.contains), [62, 64, 65, 68, 69, 70, 73])
        XCTAssertEqual(hungarian.keyMark(of: 68), .scaleTone, "G♯ is its raised fourth")
        XCTAssertEqual(MusicalContext(root: 0, scale: .todi).title, "C Todi (Hindustani)")
    }

    /// No two scales are the same notes, each holds its root and has five to twelve tones: a second
    /// case for a pitch set would put the same notes in the menu twice. A tradition's own name for a
    /// set the menu already has is a shelf's work, never another case — the earlier app's three that
    /// Studio already had are `majorPentatonic`, `minorPentatonic` and `blues`, added once.
    func testEveryScaleIsADistinctPitchSet() {
        var seen: [Set<Int>: Scale] = [:]
        for scale in Scale.allCases {
            let tones = scale.intervals
            XCTAssertTrue(tones.contains(0), "\(scale) holds its root")
            XCTAssertTrue(tones.allSatisfy { (step: Int) -> Bool in (0...11).contains(step) }, "\(scale)")
            XCTAssertTrue((5...12).contains(tones.count), "\(scale) has \(tones.count) tones")
            if let earlier = seen[tones] { XCTFail("\(scale) plays the notes of \(earlier)") }
            seen[tones] = scale
        }
        XCTAssertEqual(Scale.allCases.count, 57)
    }

    /// A grouped menu shows every scale exactly once: eight shelves, none empty, each scale on one,
    /// its scales in their stored order. Chromatic, which frames nothing, sits with the other scales
    /// of equal steps, as in the earlier app.
    func testEveryScaleSitsOnExactlyOneShelf() {
        XCTAssertEqual(Scale.Shelf.allCases.map(\.title),
                       ["Modes", "Minor & Altered", "Pentatonic & Blues", "Symmetric", "European Folk",
                        "Maqām & Near East", "East & Southeast Asia", "Hindustani & Carnatic"])
        let shelved = Scale.Shelf.allCases.flatMap(\.scales)
        XCTAssertEqual(shelved.count, Scale.allCases.count, "no scale on two shelves")
        XCTAssertEqual(Set(shelved), Set(Scale.allCases), "no scale left off the shelves")
        for shelf in Scale.Shelf.allCases {
            XCTAssertFalse(shelf.scales.isEmpty, shelf.title)
            XCTAssertTrue(shelf.scales.allSatisfy { (scale: Scale) -> Bool in scale.shelf == shelf }, shelf.title)
            let order = shelf.scales.compactMap { (scale: Scale) -> Int? in Scale.allCases.firstIndex(of: scale) }
            XCTAssertEqual(order, order.sorted(), shelf.title)
        }
        XCTAssertEqual(Scale.Shelf.modes.scales, [.major, .minor, .dorian, .phrygian, .lydian, .mixolydian, .locrian])
        XCTAssertEqual(Scale.Shelf.maqamAndNearEast.scales, [.phrygianDominant, .doubleHarmonic, .persian])
        XCTAssertEqual(Scale.chromatic.shelf, .symmetric)
    }

    /// Every scale and shelf has its own title, and none uses a word the language law keeps out
    /// (`LearnGuideTests.forbiddenWords`); a tradition's name is a name.
    func testEveryScaleAndShelfHasItsOwnPlainTitle() {
        let titles = Scale.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count, "two scales would read alike")
        for title in titles + Scale.Shelf.allCases.map(\.title) {
            XCTAssertFalse(title.isEmpty)
            let words = title.lowercased().split(whereSeparator: { (character: Character) -> Bool in
                !character.isLetter && !character.isNumber
            }).map(String.init)
            XCTAssertTrue(Set(words).isDisjoint(with: LearnGuideTests.forbiddenWords), title)
        }
    }

    func testAToneSystemRetunesFromTheKeysRoot() {
        let justThird = 386.314 - 400
        let inC = MusicalContext(tuning: "just-major").centsTable()
        XCTAssertEqual(inC[4], justThird, accuracy: 0.001, "E is the just major third of C")
        XCTAssertEqual(inC[0], 0, accuracy: 0.001)

        let inD = MusicalContext(root: 2, tuning: "just-major").centsTable()
        XCTAssertEqual(inD[6], justThird, accuracy: 0.001, "F♯ is the just major third of D")
        XCTAssertEqual(inD[2], 0, accuracy: 0.001)

        XCTAssertEqual(MusicalContext(tuning: "edo24").centsTable(), Array(repeating: 0, count: 12),
                       "quarter tones contain every semitone")
        XCTAssertEqual(MusicalContext(tuning: "bohlen-pierce").centsTable(), Array(repeating: 0, count: 12),
                       "a system without octaves has no twelve-note retuning")
        XCTAssertEqual(MusicalContext(tuning: "from-a-later-build").centsTable(), Array(repeating: 0, count: 12))
    }

    // MARK: Which degree a key plays

    /// A key near the octave plays the 1/1 above when that is the nearest degree (TH-1). In sléndro,
    /// pélog, Hirajōshi and Archytas the B key fell to the octave's highest degree, 104 to 300 cents
    /// below it, while the 1/1 an octave up is 100 cents away: B now plays the C above, and from any
    /// root the key a semitone under the root plays the root above. A song stored in one of these
    /// systems sounds different on that key.
    func testAKeyNearTheOctaveTakesTheTonicAbove() {
        for id in ["gamelan-slendro", "gamelan-pelog", "hirajoshi", "archytas-diatonic"] {
            XCTAssertEqual(MusicalContext(tuning: id).centsTable()[11], 100, accuracy: 1e-9, "\(id): B plays the C above")
            for root in MusicalContext.rootRange {
                let under = (root + 11) % 12
                XCTAssertEqual(MusicalContext(root: root, tuning: id).centsTable()[under], 100, accuracy: 1e-9,
                               "\(id) on \(root)")
            }
        }
    }

    /// No key plays farther from its own place than half the widest gap between two degrees of its
    /// system, counting the gap from the highest degree to the 1/1 above, which the rule now sees.
    func testNoKeyPlaysFartherThanHalfItsSystemsWidestGap() {
        for system in TuningSystem.library where system.repeatsAtTheOctave {
            let bounds = system.degreesCents + [system.periodCents]
            let gaps = zip(bounds, bounds.dropFirst()).map { (pair: (Double, Double)) -> Double in pair.1 - pair.0 }
            let widest = gaps.max() ?? 0
            for root in MusicalContext.rootRange {
                for deviation in MusicalContext(root: root, tuning: system.id).centsTable() {
                    XCTAssertLessThanOrEqual(Swift.abs(deviation), widest / 2 + 1e-9, "\(system.id) on \(root)")
                }
            }
        }
    }

    /// A key exactly midway between two degrees plays the lower one, the same on every platform. The F♯
    /// key sits exactly between 4/3 and 3/2 (together they make the octave) and plays the fourth; in
    /// Maqām Bayātī and Ḥijāz the B key sits exactly between B♭ and the C above and plays B♭; in 19
    /// equal F♯ sits between steps 9 and 10 and plays step 9. Worked out from exact ratios, two such
    /// distances can differ in the logarithm's last bit, and that must not choose the note.
    func testAKeyMidwayBetweenTwoDegreesPlaysTheLowerOne() {
        let fourth = 1200 * Foundation.log2(4.0 / 3)
        for id in ["just-major", "just-minor", "pythagorean", "archytas-diatonic", "ptolemy-intense-diatonic"] {
            XCTAssertEqual(MusicalContext(tuning: id).centsTable()[6], fourth - 600, accuracy: 1e-9, "\(id): F♯ plays 4/3")
        }
        XCTAssertEqual(MusicalContext(tuning: "maqam-bayati").centsTable()[11], -100, accuracy: 1e-9)
        XCTAssertEqual(MusicalContext(tuning: "maqam-hijaz").centsTable()[11], -100, accuracy: 1e-9)
        XCTAssertEqual(MusicalContext(tuning: "edo19").centsTable()[6], 1200.0 * 9 / 19 - 600, accuracy: 1e-9)
    }

    // MARK: Tone systems from their definitions

    /// Just intonation, Pythagorean tuning and the two ancient Greek tetrachords play their ratios, not
    /// a table rounded to a thousandth of a cent (TH-2).
    func testJustDegreesAreTheirRatios() {
        let systems: [(id: String, ratios: [(Double, Double)])] = [
            ("just-major", [(1, 1), (9, 8), (5, 4), (4, 3), (3, 2), (5, 3), (15, 8)]),
            ("just-minor", [(1, 1), (9, 8), (6, 5), (4, 3), (3, 2), (8, 5), (9, 5)]),
            ("pythagorean", [(1, 1), (9, 8), (81, 64), (4, 3), (3, 2), (27, 16), (243, 128)]),
            ("archytas-diatonic", [(1, 1), (28, 27), (32, 27), (4, 3), (3, 2), (14, 9), (16, 9)]),
            ("ptolemy-intense-diatonic", [(1, 1), (16, 15), (6, 5), (4, 3), (3, 2), (8, 5), (9, 5)]),
        ]
        for system in systems {
            let tuning = TuningSystem.named(system.id)
            XCTAssertEqual(tuning.id, system.id)
            XCTAssertEqual(tuning.periodCents, 1200, system.id)
            XCTAssertEqual(tuning.degreesCents.count, system.ratios.count, system.id)
            for (degree, ratio) in zip(tuning.degreesCents, system.ratios) {
                XCTAssertEqual(degree, 1200 * Foundation.log2(ratio.0 / ratio.1), accuracy: 1e-9, "\(system.id) \(ratio)")
            }
        }
    }

    /// Quarter-comma meantone is built from its fifth, 5 to the 1/4 (TH-2): the eleven fifths of the
    /// chain from E♭ to G♯ are one size, 300 · log2(5) cents, four of them make two octaves and a pure
    /// major third, and C♯ sits 76.048999… cents above C — the table stored 76.0.
    func testMeantoneIsBuiltFromItsFifth() {
        let degrees = TuningSystem.named("meantone-quarter").degreesCents
        XCTAssertEqual(degrees.count, 12)
        guard degrees.count == 12 else { return }
        let fifth = 300 * Foundation.log2(5.0)
        let chain = [3, 10, 5, 0, 7, 2, 9, 4, 11, 6, 1, 8]  // E♭ B♭ F C G D A E B F♯ C♯ G♯
        for (lower, upper) in zip(chain, chain.dropFirst()) {
            let rise = degrees[upper] - degrees[lower]
            XCTAssertEqual(rise < 0 ? rise + 1200 : rise, fifth, accuracy: 1e-9, "\(lower) to \(upper)")
        }
        XCTAssertEqual(degrees[4], 1200 * Foundation.log2(5.0 / 4), accuracy: 1e-9, "the major third is pure")
        XCTAssertEqual(degrees[1], 76.04899926346, accuracy: 1e-9)
    }

    /// An equal division is whole steps of its period (TH-2): step k of n lies k/n of the way up,
    /// worked out from that definition; sléndro here is five equal steps. Bohlen–Pierce divides the
    /// 3/1 tritave, 1200 · log2(3) cents, which the table stored as 1901.955.
    func testEqualDivisionsAreWholeStepsOfTheirPeriod() {
        for (id, steps) in [("edo12", 12), ("edo24", 24), ("edo19", 19), ("edo31", 31), ("gamelan-slendro", 5)] {
            let system = TuningSystem.named(id)
            XCTAssertEqual(system.id, id)
            XCTAssertEqual(system.periodCents, 1200, id)
            let expected = (0..<steps).map { (step: Int) -> Double in Double(step) * 1200 / Double(steps) }
            XCTAssertEqual(system.degreesCents, expected, id)
        }
        let tritave = 1200 * Foundation.log2(3.0)
        let bohlenPierce = TuningSystem.named("bohlen-pierce")
        XCTAssertEqual(bohlenPierce.periodCents, tritave, accuracy: 1e-9)
        XCTAssertEqual(bohlenPierce.degreesCents.count, 13)
        for (step, degree) in bohlenPierce.degreesCents.enumerated() {
            XCTAssertEqual(degree, tritave * Double(step) / 13, accuracy: 1e-9, "step \(step)")
        }
    }

    /// Every system ascends from its 1/1 and stays inside its period, so each key's nearest degree
    /// lies between the 1/1 and the 1/1 above.
    func testEverySystemAscendsFromItsOneOneInsideItsPeriod() {
        for system in TuningSystem.library {
            XCTAssertEqual(system.degreesCents.first, 0, system.id)
            XCTAssertEqual(system.degreesCents, system.degreesCents.sorted(), system.id)
            XCTAssertEqual(Set(system.degreesCents).count, system.degreesCents.count, system.id)
            XCTAssertTrue(system.degreesCents.allSatisfy { (degree: Double) -> Bool in
                degree.isFinite && degree >= 0 && degree < system.periodCents
            }, system.id)
        }
    }

    // MARK: What the twelve keys reach

    /// "24 equal (quarter tones)" and "Bohlen–Pierce (non-octave)" play as twelve equal steps in this
    /// build, and Core says so (TS-1): twelve keys to the octave reach no quarter tone, and a system
    /// that repeats at the 3/1 tritave has no retuning of twelve keys. Neither reaches every step; a
    /// keyboard with a key for every step is a later slice.
    func testQuarterTonesAndBohlenPiercePlayAsTwelveEqualStepsToday() {
        let twelveEqual = MusicalContext().centsTable()
        for id in ["edo24", "bohlen-pierce"] {
            let system = TuningSystem.named(id)
            XCTAssertEqual(system.id, id)
            for root in MusicalContext.rootRange {
                XCTAssertEqual(MusicalContext(root: root, tuning: id).centsTable(), twelveEqual, "\(id) on \(root)")
            }
            XCTAssertTrue(system.playsAsTwelveEqual, id)
            XCTAssertFalse(system.reachesEveryStep, id)
        }
        XCTAssertEqual(TuningSystem.named("edo24").stepsTheKeysReach, 12, "twelve of its 24 steps: the semitones")
        XCTAssertEqual(TuningSystem.named("bohlen-pierce").stepsTheKeysReach, 0, "none: the keys play twelve equal steps")
        XCTAssertEqual(TuningSystem.library.filter(\.playsAsTwelveEqual).map(\.id), ["edo12", "edo24", "bohlen-pierce"])
    }

    /// Every system of up to twelve degrees to the octave has each of them on some key — no degree
    /// falls between two keys — and the keys sound as many pitches as they reach steps. Only four
    /// systems do not reach every step: 24, 19 and 31 equal have more steps than an octave has keys
    /// (the keys play twelve of them), and Bohlen–Pierce does not repeat at the octave.
    func testTheKeysReachEveryStepOfEverySystemWithTwelveOrFewer() {
        for system in TuningSystem.library where system.repeatsAtTheOctave {
            XCTAssertEqual(system.stepsTheKeysReach, Swift.min(system.degreesCents.count, 12), system.id)
            let table = MusicalContext(tuning: system.id).centsTable()
            let sounding = (0..<12).map { (key: Int) -> Double in
                let above = 100 * Double(key) + table[key]
                return above > 1200 - 1e-6 ? above - 1200 : above
            }
            var distinct: [Double] = []
            for pitch in sounding.sorted() {
                if let last = distinct.last, pitch - last < 1e-6 { continue }
                distinct.append(pitch)
            }
            XCTAssertEqual(distinct.count, system.stepsTheKeysReach, system.id)
        }
        let partlyReached = TuningSystem.library.filter { (system: TuningSystem) -> Bool in !system.reachesEveryStep }
        XCTAssertEqual(partlyReached.map(\.id), ["edo24", "edo19", "edo31", "bohlen-pierce"])
    }

    func testConcertPitchShiftsEveryPitchClassAlike() {
        let shift = 1200 * Foundation.log2(432.0 / 440)
        for cents in MusicalContext(concertPitch: 432).centsTable() {
            XCTAssertEqual(cents, shift, accuracy: 1e-9)
        }
    }

    /// Every named concert pitch is one a song can store, and every one is a historical or
    /// orchestral standard — no pitch derived from an orbit. A song that stores such a
    /// pitch keeps it: the song holds only the number.
    func testEveryConcertPitchPresetIsAStorableStandard() throws {
        let presets = MusicalContext.concertPitchPresets
        XCTAssertEqual(presets.first?.hertz, 440)
        for preset in presets {
            XCTAssertTrue(MusicalContext.concertPitchRange.contains(preset.hertz), preset.title)
            var project = Project()
            XCTAssertNoThrow(try Command.setConcertPitch(hertz: preset.hertz).apply(to: &project), preset.title)
        }
        XCTAssertEqual(presets.map(\.hertz), [440, 442, 415, 430, 435, 466])
        XCTAssertEqual(Set(presets.map(\.title)).count, presets.count)
        var project = Project()
        try Command.setConcertPitch(hertz: 432.10).apply(to: &project)
        let reopened = try ProjectCodec.decode(ProjectCodec.encode(project))
        XCTAssertEqual(reopened.context.concertPitch, 432.10, accuracy: 1e-9, "a stored pitch off the list stays")
    }

    func testTheToneSystemIdsAreUniqueAndEqualTemperamentComesFirst() {
        let ids = TuningSystem.library.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ids.first, "edo12")
        XCTAssertTrue(TuningSystem.library.allSatisfy { $0.degreesCents.first == 0 && !$0.degreesCents.isEmpty })
    }

    func testTheCommandsSetTheContext() throws {
        var project = Project()
        try Command.setKeyRoot(9).apply(to: &project)
        try Command.setScale(.dorian).apply(to: &project)
        try Command.setTuning(id: "meantone-quarter").apply(to: &project)
        try Command.setConcertPitch(hertz: 415).apply(to: &project)
        try Command.setSwing(0.5).apply(to: &project)
        XCTAssertEqual(project.context, MusicalContext(root: 9, scale: .dorian, tuning: "meantone-quarter",
                                                       concertPitch: 415, swing: 0.5))
    }

    func testOutOfRangeContextValuesAreRefusedAndChangeNothing() {
        var project = Project()
        let refused: [Command] = [
            .setKeyRoot(12), .setKeyRoot(-1), .setTuning(id: "nope"),
            .setConcertPitch(hertz: 399), .setConcertPitch(hertz: .nan), .setConcertPitch(hertz: .infinity),
            .setSwing(1.5), .setSwing(-0.1), .setSwing(.nan),
        ]
        for command in refused {
            XCTAssertThrowsError(try command.apply(to: &project), "\(command)")
        }
        XCTAssertEqual(project.context, MusicalContext())
    }

    func testEveryContextParameterIsReachableFromAControl() throws {
        var project = Project()
        let descriptors = project.parameters.filter { $0.address.owner == .project && $0.address != .tempo }
        XCTAssertEqual(descriptors.map(\.address), [.keyRoot, .scale, .tuning, .concertPitch, .swing])
        for descriptor in descriptors {
            XCTAssertEqual(project.descriptor(for: descriptor.address), descriptor)
            let top = descriptor.value(forNormalized: 1)
            let command = try XCTUnwrap(Command.setParameter(descriptor.address, to: top))
            try command.apply(to: &project)
            XCTAssertEqual(project.value(of: descriptor.address), descriptor.range.upperBound, "\(descriptor.title)")
        }
        XCTAssertEqual(project.context.root, 11)
        XCTAssertEqual(project.context.scale, Scale.allCases.last)
        XCTAssertEqual(project.context.tuning, TuningSystem.library.last?.id)
        XCTAssertNil(Command.setParameter(.keyRoot, to: .nan))
    }

    func testTheSongWideFrameIsNotAutomated() {
        var project = Project()
        for address in [ParameterAddress.tempo, .keyRoot, .scale, .tuning, .concertPitch, .swing] {
            XCTAssertThrowsError(try Command.setAutomation(address, points: [AutomationPoint(tick: 0, value: 0)])
                .apply(to: &project), "\(address)")
        }
        XCTAssertTrue(project.automation.isEmpty)
    }

    func testASongFileKeepsAToneSystemThisBuildDoesNotKnowAndRefusesABrokenContext() throws {
        var project = Project()
        project.context.tuning = "from-a-later-build"
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)).context.tuning, "from-a-later-build")

        for broken in [MusicalContext(root: 12), MusicalContext(concertPitch: 1_000), MusicalContext(swing: 2)] {
            project.context = broken
            XCTAssertThrowsError(try ProjectCodec.decode(ProjectCodec.encode(project)))
        }
    }
}
