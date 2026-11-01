import XCTest
@testable import EchoelCore

/// The harmonizer's styles (VOX): which notes the voices sing for a sung note, in a song's key.
/// The expected intervals are written out by hand, from the scales as a musician reads them.
final class HarmonyStyleTests: XCTestCase {
    private func key(_ root: Int, _ scale: Scale) -> SongKey {
        SongKey(MusicalContext(root: root, scale: scale))
    }

    /// Semitones above (left) and below (right) for each white key, C to B, in C major.
    private let whiteKeyThirds: [(note: Int, above: Int, below: Int)] = [
        (0, 4, -3), (2, 3, -3), (4, 3, -4), (5, 4, -3), (7, 4, -3), (9, 3, -4), (11, 3, -4),
    ]

    func testEveryStyleHasAPlainNameAndAnUnknownIndexIsFree() {
        XCTAssertEqual(Set(HarmonyStyle.allCases.map(\.title)).count, HarmonyStyle.allCases.count)
        for style in HarmonyStyle.allCases {
            XCTAssertFalse(style.title.contains(where: \.isNumber), style.title)
            XCTAssertEqual(HarmonyStyle(index: Float(style.rawValue)), style)
            XCTAssertTrue(style.summary.hasSuffix("."), style.title)
        }
        XCTAssertEqual(HarmonyStyle(index: 2.2), .organumAtTheFourth)
        for bad: Float in [-1, 6, 99, .nan, .infinity] { XCTAssertEqual(HarmonyStyle(index: bad), .free) }
    }

    func testFreeAndTheIsonSetNoSideVoices() {
        for note in 0..<12 {
            XCTAssertNil(HarmonyStyle.free.sides(for: note, in: key(0, .major)))
            XCTAssertNil(HarmonyStyle.ison.sides(for: note, in: key(0, .major)))
        }
        XCTAssertFalse(HarmonyStyle.free.followsKey)
        XCTAssertTrue(HarmonyStyle.ison.followsKey)
    }

    /// Parallel organum keeps its perfect intervals on every note, whatever the key.
    func testOrganumSingsAFifthOrAFourthAndAnOctaveBelowEveryNote() throws {
        for songKey in [key(0, .major), key(9, .minor), key(6, .lydian), SongKey()] {
            for note in 0..<12 {
                let fifth = try XCTUnwrap(HarmonyStyle.organum.sides(for: note, in: songKey))
                XCTAssertEqual(fifth.left, -7)
                XCTAssertEqual(fifth.right, -12)
                let fourth = try XCTUnwrap(HarmonyStyle.organumAtTheFourth.sides(for: note, in: songKey))
                XCTAssertEqual(fourth.left, -5)
                XCTAssertEqual(fourth.right, -12)
            }
        }
    }

    /// C major, A minor and D Dorian share their seven notes, so each white key takes the same
    /// thirds in all three: the root and the scale are read, not assumed.
    func testDiatonicThirdsInCMajorAMinorAndDDorian() throws {
        for songKey in [key(0, .major), key(9, .minor), key(2, .dorian)] {
            for expected in whiteKeyThirds {
                let sides = try XCTUnwrap(HarmonyStyle.diatonicThirds.sides(for: expected.note, in: songKey))
                XCTAssertEqual(sides.left, expected.above, "\(songKey) note \(expected.note) above")
                XCTAssertEqual(sides.right, expected.below, "\(songKey) note \(expected.note) below")
            }
        }
    }

    func testDiatonicThirdsMoveWithTheKey() throws {
        // E major: E takes G sharp above (major) and C sharp below (minor).
        let eMajor = try XCTUnwrap(HarmonyStyle.diatonicThirds.sides(for: 4, in: key(4, .major)))
        XCTAssertEqual(eMajor.left, 4)
        XCTAssertEqual(eMajor.right, -3)
        // C harmonic minor holds both B and C above A flat: the scale's own third is C, two steps up.
        let flatSix = try XCTUnwrap(HarmonyStyle.diatonicThirds.sides(for: 8, in: key(0, .harmonicMinor)))
        XCTAssertEqual(flatSix.left, 4)
        XCTAssertEqual(flatSix.right, -3)
        // Its raised seventh, B: D above, G below.
        let seventh = try XCTUnwrap(HarmonyStyle.diatonicThirds.sides(for: 11, in: key(0, .harmonicMinor)))
        XCTAssertEqual(seventh.left, 3)
        XCTAssertEqual(seventh.right, -4)
    }

    /// A passing note outside the key becomes the third of a chord whose other notes are in it.
    func testANoteOutsideTheKeyTakesThirdsInTheKey() throws {
        let cMajor = key(0, .major)
        let expected: [(note: Int, above: Int, below: Int)] = [
            (1, 3, -4),   // C sharp in A major: A, C sharp, E
            (3, 4, -3),   // E flat in C minor: C, E flat, G
            (6, 3, -4),   // F sharp in D major
            (8, 3, -4),   // G sharp in E major
            (10, 4, -3),  // B flat in G minor
        ]
        for case let (note, above, below) in expected {
            let sides = try XCTUnwrap(HarmonyStyle.diatonicThirds.sides(for: note, in: cMajor))
            XCTAssertEqual(sides.left, above, "note \(note)")
            XCTAssertEqual(sides.right, below, "note \(note)")
        }
    }

    /// A new song frames no key (chromatic): the thirds are those of the major scale on its root.
    func testAKeylessSongHarmonisesInMajorOnItsRoot() throws {
        for expected in whiteKeyThirds {
            let sides = try XCTUnwrap(HarmonyStyle.diatonicThirds.sides(for: expected.note, in: SongKey()))
            XCTAssertEqual(sides.left, expected.above)
            XCTAssertEqual(sides.right, expected.below)
        }
        let onD = SongKey(MusicalContext(root: 2))
        let fSharp = try XCTUnwrap(HarmonyStyle.diatonicThirds.sides(for: 2, in: onD))
        XCTAssertEqual(fSharp.left, 4, "D major: F sharp above D")
    }

    /// Fauxbourdon: a perfect fourth below, and a sixth below that is major or minor in the key.
    func testFauxbourdonIsAFourthAndTheKeysSixthBelow() throws {
        let cMajor = key(0, .major)
        let onE = try XCTUnwrap(HarmonyStyle.fauxbourdon.sides(for: 4, in: cMajor))
        XCTAssertEqual(onE.left, -5)
        XCTAssertEqual(onE.right, -9, "G below E: a major sixth")
        let onF = try XCTUnwrap(HarmonyStyle.fauxbourdon.sides(for: 5, in: cMajor))
        XCTAssertEqual(onF.left, -5)
        XCTAssertEqual(onF.right, -8, "A below F: a minor sixth")
    }

    /// A pentatonic scale has no third above D: the voices take the scale's fourth instead.
    func testAGapInThePentatonicTakesTheFourth() throws {
        let sides = try XCTUnwrap(HarmonyStyle.diatonicThirds.sides(for: 2, in: key(0, .majorPentatonic)))
        XCTAssertEqual(sides.left, 5, "G above D")
        XCTAssertEqual(sides.right, -5, "A below D")
    }

    /// Every voice of a key-following style lands on a note of the key, for every sung note in
    /// every scale on every root.
    func testTheKeysVoicesLandInTheKeyEverywhere() throws {
        for scale in Scale.allCases {
            for root in 0..<12 {
                let songKey = key(root, scale)
                let notes = songKey.harmonyScale
                for note in 0..<12 {
                    let thirds = try XCTUnwrap(HarmonyStyle.diatonicThirds.sides(for: note, in: songKey))
                    for interval in [thirds.left, thirds.right] {
                        XCTAssertTrue(HarmonyStyle.contains(notes, note + interval), "\(scale) \(root) \(note) \(interval)")
                        XCTAssertTrue((2...5).contains(abs(interval)), "a third, or a fourth across a gap")
                    }
                    let faux = try XCTUnwrap(HarmonyStyle.fauxbourdon.sides(for: note, in: songKey))
                    XCTAssertTrue(HarmonyStyle.contains(notes, note + faux.right), "\(scale) \(root) \(note) sixth")
                }
            }
        }
    }

    func testTheKeyReadsTheSongsFrameAndPacksIntoOneWord() {
        let dorian = key(2, .dorian)
        XCTAssertEqual(dorian.root, 2)
        XCTAssertEqual(dorian.scale, 0b1010_1011_0101, "D E F G A B C: bits 0 2 4 5 7 9 11")
        let baroque = SongKey(MusicalContext(root: 7, scale: .mixolydian, concertPitch: 415))
        for songKey in [dorian, baroque, SongKey(), key(11, .blues)] {
            XCTAssertEqual(SongKey(packed: songKey.packed), songKey)
        }
        XCTAssertEqual(SongKey(packed: baroque.packed).concertPitch, 415)
        let damaged = SongKey(packed: UInt64(Float.nan.bitPattern) << 32 | 0xF)
        XCTAssertEqual(damaged.concertPitch, 440)
        XCTAssertEqual(damaged.root, 3)
        XCTAssertEqual(SongKey(root: -1).root, 11)
        XCTAssertEqual(SongKey(concertPitch: .infinity).concertPitch, 440)
    }
}
