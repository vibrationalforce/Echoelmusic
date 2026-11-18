import Foundation
import XCTest
@testable import EchoelCore

/// The heartbeat as a tone: one beat lasts 60 ÷ the pulse seconds, moved by whole octaves into
/// octave 3 by the same arithmetic as the cycles (`CycleTone`).
final class BodyTonesTests: XCTestCase {
    func testAPulseOf64GivesCSharp3AndATempoOf64() throws {
        let tone = try XCTUnwrap(BodyTones.heartbeat(beatsPerMinute: 64))
        XCTAssertEqual(tone.periodSeconds, 0.9375, accuracy: 1e-12)
        XCTAssertEqual(tone.octaves, 7, "doubled 7 times")
        XCTAssertEqual(tone.hertz, 136.5333, accuracy: 0.0001)
        XCTAssertEqual(NoteEditing.name(of: tone.pitch), "C♯3")
        XCTAssertEqual(tone.centsFromKey, -25.90, accuracy: 0.01)
        XCTAssertEqual(tone.concertPitch, 433.4663, accuracy: 0.0001)
        XCTAssertEqual(tone.tempo, 64, accuracy: 1e-9, "a pulse inside the tempo window is its own tempo")
    }

    func testTheTempoIsThePulseMovedByWholeOctaves() throws {
        // python3: 60/bpm s, doubled into 127.09 … 254.18 Hz; tempo = tone · 60 / 128.
        let table: [(Int, Double, String, Double, Double)] = [
            (30, 128.0, "C3", 430.539, 60), (40, 170.6667, "F3", 430.0531, 80), (60, 128.0, "C3", 430.539, 60),
            (72, 153.6, "D♯3", 434.4464, 72), (100, 213.3333, "G♯3", 452.0376, 100), (119, 253.8667, "B3", 452.339, 119),
            (120, 128.0, "C3", 430.539, 60), (150, 160.0, "D♯3", 452.5483, 75), (180, 192.0, "G3", 431.0254, 90),
            (220, 234.6667, "A♯3", 442.9917, 110),
        ]
        for (pulse, hertz, key, concertPitch, tempo) in table {
            let tone = try XCTUnwrap(BodyTones.heartbeat(beatsPerMinute: pulse), "\(pulse)")
            XCTAssertEqual(tone.hertz, hertz, accuracy: 0.0001, "\(pulse)")
            XCTAssertEqual(NoteEditing.name(of: tone.pitch), key, "\(pulse)")
            XCTAssertEqual(tone.concertPitch, concertPitch, accuracy: 0.0001, "\(pulse)")
            XCTAssertEqual(tone.tempo, tempo, accuracy: 1e-9, "\(pulse)")
            XCTAssertTrue(MusicalContext.concertPitchRange.contains(tone.concertPitch), "\(pulse)")
        }
    }

    func testAPulseOutsideTheRangeIsNotTaken() {
        for pulse in [Int.min, -64, 0, 29, 221, Int.max] {
            XCTAssertNil(BodyTones.heartbeat(beatsPerMinute: pulse), "\(pulse)")
        }
        XCTAssertNotNil(BodyTones.heartbeat(beatsPerMinute: BodyTones.pulseRange.lowerBound))
        XCTAssertNotNil(BodyTones.heartbeat(beatsPerMinute: BodyTones.pulseRange.upperBound))
    }

    func testNoWordOfTheBodyPageIsOneEchoelNeverUses() {
        for text in [BodyTones.method, BodyTones.credit, BodyTones.noSource, BodyTones.healthNotTaken,
                     BodyTones.sharingOff, BodyTones.heartbeatTitle] {
            let words = Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
            XCTAssertTrue(words.isDisjoint(with: LearnGuideTests.forbiddenWords), text)
            for phrase in LearnGuideTests.forbiddenPhrases {
                XCTAssertFalse(text.lowercased().contains(phrase), "\(text): \(phrase)")
            }
        }
        XCTAssertTrue(BodyTones.method.contains("claim nothing about what a tone does"), "arithmetic, not an effect")
    }
}
