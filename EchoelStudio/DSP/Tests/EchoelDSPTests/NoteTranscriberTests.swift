import Foundation
import XCTest
@testable import EchoelDSP

final class NoteTranscriberTests: XCTestCase {
    private let rate = 48_000.0

    /// A sine at `hertz` for `seconds`, amplitude `level`; `vibratoCents` swings the pitch at 5 Hz.
    private func tone(_ hertz: Double, seconds: Double, level: Double = 0.5, vibratoCents: Double = 0) -> [Float] {
        let count = Int(rate * seconds)
        var phase = 0.0
        var out = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let time = Double(index) / rate
            let cents = vibratoCents * Foundation.sin(2 * Double.pi * 5 * time)
            let now = hertz * Foundation.pow(2, cents / 1_200)
            phase += 2 * Double.pi * now / rate
            out[index] = Float(level * Foundation.sin(phase))
        }
        return out
    }

    private func silence(_ seconds: Double) -> [Float] {
        [Float](repeating: 0, count: Int(rate * seconds))
    }

    private func midi(_ note: TranscribedNote) -> Int {
        Int((69 + 12 * Foundation.log2(note.hertz / 440)).rounded())
    }

    /// C4 E4 G4, half a second each, a quarter second apart, after a quarter second of silence.
    private var melody: [Float] {
        silence(0.25) + tone(261.63, seconds: 0.5) + silence(0.25) + tone(329.63, seconds: 0.5)
            + silence(0.25) + tone(392.0, seconds: 0.5) + silence(0.25)
    }

    func testAMelodyOfThreeTonesBecomesThreeNotes() throws {
        let heard = try XCTUnwrap(NoteTranscriber.transcribe(melody, sampleRate: rate))
        XCTAssertEqual(heard.notes.map(midi), [60, 64, 67])
        let starts: [Double] = [0.25, 1.0, 1.75]
        for (note, start) in zip(heard.notes, starts) {
            XCTAssertEqual(note.start, start, accuracy: 0.02, "start of \(midi(note))")
            XCTAssertEqual(note.start + note.length, start + 0.5, accuracy: 0.02, "end of \(midi(note))")
            XCTAssertTrue((1...127).contains(note.velocity))
        }
        XCTAssertGreaterThan(heard.voicedShare, 0.8)
    }

    func testSilenceHasNoNotes() throws {
        XCTAssertEqual(try XCTUnwrap(NoteTranscriber.transcribe(silence(1), sampleRate: rate)).notes, [])
        XCTAssertEqual(try XCTUnwrap(NoteTranscriber.transcribe([], sampleRate: rate)).notes, [])
        let quiet = tone(440, seconds: 1, level: 0.0005)
        XCTAssertEqual(try XCTUnwrap(NoteTranscriber.transcribe(quiet, sampleRate: rate)).notes, [], "below −60 dBFS is silence")
    }

    func testVibratoStaysOneNote() throws {
        let sung = silence(0.1) + tone(440, seconds: 1.2, vibratoCents: 30) + silence(0.1)
        let heard = try XCTUnwrap(NoteTranscriber.transcribe(sung, sampleRate: rate))
        XCTAssertEqual(heard.notes.count, 1)
        XCTAssertEqual(heard.notes.first.map(midi), 69)
        XCTAssertEqual(heard.notes.first?.length ?? 0, 1.2, accuracy: 0.04)
    }

    func testTheSameInputGivesTheSameNotes() throws {
        let first = try XCTUnwrap(NoteTranscriber.transcribe(melody, sampleRate: rate))
        let second = try XCTUnwrap(NoteTranscriber.transcribe(melody, sampleRate: rate))
        XCTAssertEqual(first, second)
    }

    func testALouderNoteHasAHigherVelocity() throws {
        let played = silence(0.1) + tone(330, seconds: 0.4, level: 0.05) + silence(0.2) + tone(330, seconds: 0.4, level: 0.6)
        let heard = try XCTUnwrap(NoteTranscriber.transcribe(played, sampleRate: rate))
        XCTAssertEqual(heard.notes.count, 2)
        if heard.notes.count == 2 { XCTAssertLessThan(heard.notes[0].velocity, heard.notes[1].velocity) }
        XCTAssertEqual(NoteTranscriber.velocity(forDecibels: -100), 1)
        XCTAssertEqual(NoteTranscriber.velocity(forDecibels: 0), 127)
        XCTAssertEqual(NoteTranscriber.velocity(forDecibels: .nan), 1)
    }

    func testALegatoStepIsTwoNotes() throws {
        let played = silence(0.1) + tone(261.63, seconds: 0.4) + tone(293.66, seconds: 0.4) + silence(0.1)
        let heard = try XCTUnwrap(NoteTranscriber.transcribe(played, sampleRate: rate))
        XCTAssertEqual(heard.notes.map(midi), [60, 62])
        XCTAssertEqual(heard.notes.last?.start ?? 0, 0.5, accuracy: 0.03)
    }

    func testACancelledReadingReturnsNothing() {
        XCTAssertNil(NoteTranscriber.transcribe(melody, sampleRate: rate, isCancelled: { true }))
    }
}
