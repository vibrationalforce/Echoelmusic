// TheRecordCountsInWithTheOneClickTests.swift
// A10 (founder 2026-10-16, gap list item 5 "Count-in"): Record can count in one or two bars of click
// before the piece starts and the take begins. A "Count-in" menu beside Record holds the choice
// (Off · 1 bar · 2 bars, persisted); the click is the one `MetronomeVoice`, restarted on a fresh
// downbeat; a tap during the count-in cancels it and nothing is armed.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claim 1 is END-TO-END on shipped pure values: the count-in length through the click's own
//     tempo clamp, the persisted raw values, and an unknown stored value counting in nothing.
//   · Claims 2–3 are SOURCE-TEXT SCANS: the button's paths (count-in → take, cancel, the click
//     given back its state, nothing armed before the take), the metronome's bar restart, and the
//     menu mounted once beside Record writing the key Record reads.
//   · NOT CLAIMED (DEVICE PROBE): that the count-in lands in time. NEEDS-FOUNDER-VERIFY (A10) — the
//     probe is at `CountInChoice.swift`'s head.
//
// HONEST GRADING against the parent (§3): the file does not compile there (`CountInChoice`,
// `restartBar` are new), so no assertion has a verdict on the parent. Hand-transcribed: claim 1 is
// the CAPABILITY plus COUNTERWEIGHTS (no bars = no wait; a non-finite tempo never yields a
// non-finite wait; an unknown value is Off); claims 2–3 are FORWARD guards. Mutants: the wait
// ignores the bar length (1) · NaN tempo passes through (1) · an unknown value counts in (1) · the
// count-in arms first (2) · the click left on after a count-in that switched it on (2) · a second
// click voice (2) · the menu writing another key (3).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheRecordCountsInWithTheOneClickTests: XCTestCase {

    // MARK: 1 — the length of a count-in, and the stored choice

    func testTheCountInLastsItsBarsAtTheClicksTempo() {
        XCTAssertEqual(CountInChoice.seconds(bars: 1, bpm: 120, beatsPerBar: 4), 2, accuracy: 1e-9,
                       "one bar of four beats at 120 BPM is two seconds")
        XCTAssertEqual(CountInChoice.seconds(bars: 2, bpm: 90, beatsPerBar: 4), 16.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(CountInChoice.seconds(bars: 0, bpm: 120, beatsPerBar: 4), 0, "Off waits for nothing")
        XCTAssertEqual(CountInChoice.seconds(bars: 1, bpm: 120, beatsPerBar: 0), 0)
        let clamped = MetronomeVoice.samplesPerBeat(bpm: 400) / 48_000 * 4
        XCTAssertEqual(CountInChoice.seconds(bars: 1, bpm: 10_000, beatsPerBar: 4), clamped, accuracy: 1e-9,
                       "the count-in runs at the tempo the click itself plays, never faster")
        XCTAssertTrue(CountInChoice.seconds(bars: 2, bpm: .nan, beatsPerBar: 4).isFinite,
                      "a non-finite tempo never yields a non-finite wait")
        XCTAssertEqual(CountInChoice.allCases.map(\.rawValue), [0, 1, 2], "the stored value is the number of bars")
        XCTAssertEqual(CountInChoice.resolved(7), .off, "a count-in nobody chose is never played")
        XCTAssertEqual(CountInChoice.resolved(2), .twoBars)
        // Step 0 sounds one step after `play()`, so the start comes one sixteenth before the bar.
        XCTAssertEqual(CountInChoice.startDelay(bars: 1, bpm: 120, beatsPerBar: 4),
                       2 - Transport.stepDuration(atTempo: 120), accuracy: 1e-9,
                       "bar 1 lands on the count-in's next downbeat, not a sixteenth after it")
        XCTAssertEqual(CountInChoice.startDelay(bars: 0, bpm: 120, beatsPerBar: 4), 0, "Off waits for nothing")
        XCTAssertGreaterThanOrEqual(CountInChoice.startDelay(bars: 1, bpm: .nan, beatsPerBar: 4), 0, "never negative")
    }

    // MARK: 2 — the button: count in, then the take; cancel; the click given back

    func testRecordCountsInBeforeTheTakeAndCanBeCancelled() throws {
        let door = try source("Sources/Echoelmusic/Studio/RecordTakeControls.swift")
        XCTAssertTrue(door.contains("@AppStorage(CountInChoice.key) private var countInRaw"),
                      "Record reads the one persisted choice")
        XCTAssertTrue(door.contains("if countIn != nil { endCountIn(); return }"), "a tap during the count-in cancels it")
        let button = try XCTUnwrap(door.range(of: "if countIn != nil { endCountIn(); return }"))
        let stateSwitch = try XCTUnwrap(door.range(of: "switch state {"))
        XCTAssertTrue(button.upperBound <= stateSwitch.lowerBound,
                      "the cancel comes before the state is asked — a state changed meanwhile must not keep it running")
        XCTAssertTrue(door.contains(".onChange(of: transport.isPlaying) { _, _ in endCountIn() }"),
                      "Play or Stop pressed anywhere else cancels the count-in")
        XCTAssertTrue(door.contains("guard bars > 0 else { beginTake(); break }"), "Off records at once, as before")
        let start = try body(of: "private func startCountIn(", to: "private func endCountIn(", in: door)
        XCTAssertFalse(start.contains("recorder.arm()"), "nothing is armed while counting in")
        XCTAssertTrue(start.contains("if metronome.enabled { metronome.restartBar() } else { metronome.enabled = true }"),
                      "the one click, from a fresh downbeat")
        XCTAssertTrue(start.contains("guard !Task.isCancelled else { return }"))
        XCTAssertTrue(start.contains("if still.offersATake { beginTake() }"),
                      "the take begins only if Record still offers one — a disarm or a start meanwhile records nothing")
        XCTAssertTrue(start.contains("CountInChoice.startDelay(bars: bars, bpm: transport.tempo"),
                      "the wait is the count-in less the one step before step 0 sounds")
        let end = try body(of: "private func endCountIn(", to: "\n}", in: door)
        XCTAssertTrue(end.contains("if countInSilencesClick { metronome.enabled = false }"),
                      "a click the count-in switched on is off again when the take starts")
        XCTAssertTrue(door.contains(".onDisappear { endCountIn() }"), "a count-in never outlives its button")
        XCTAssertEqual(door.components(separatedBy: "MetronomeVoice(").count - 1, 0, "no second click voice")
        let metronome = try source("Sources/Echoelmusic/Audio/MetronomeVoice.swift")
        let restart = try body(of: "public func restartBar() {", to: "public var bpm", in: metronome)
        XCTAssertTrue(restart.contains("pendingResync = true"), "the bar restarts the way arming the click does")
    }

    // MARK: 3 — the menu beside Record

    func testTheCountInMenuSitsBesideRecord() throws {
        let workstation = try source("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(workstation.components(separatedBy: "CountInPicker()").count - 1, 1, "one mount")
        let record = try XCTUnwrap(workstation.range(of: "RecordTakeButton(playing: playing, startable: startable,"))
        let menu = try XCTUnwrap(workstation.range(of: "CountInPicker()"))
        XCTAssertTrue(record.upperBound <= menu.lowerBound, "the menu follows Record")
        let picker = try source("Sources/Echoelmusic/Studio/CountInChoice.swift")
        XCTAssertTrue(picker.contains("@AppStorage(CountInChoice.key) private var raw"), "the menu writes the key Record reads")
        XCTAssertTrue(picker.contains(".pickerStyle(.menu)"), "a named choice is a menu, not a number field")
    }

    // MARK: helpers

    private struct Unreadable: Error {}

    private func body(of start: String, to end: String, in text: String) throws -> String {
        guard let a = text.range(of: start),
              let b = text.range(of: end, range: a.upperBound..<text.endIndex) else {
            XCTFail("ANCHOR MISSING: \(start) (#454)")
            throw Unreadable()
        }
        return String(text[a.upperBound..<b.lowerBound])
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw Unreadable()
        }
        return SourceText.codeOnly(text)
    }
}
