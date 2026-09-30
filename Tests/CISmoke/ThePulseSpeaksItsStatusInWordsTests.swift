// ThePulseSpeaksItsStatusInWordsTests.swift
// Echoel — interface audit 2026-09-30, "Status-Leiter in Wörtern: Suche · fast · da · verloren;
// die Zahl bleibt daneben". The audit's finding, confirmed against the pill: "Status ist Farbe
// oder Zahl, nie ein Satz" — while the camera searched, the value slot showed "—" (the
// `.finding` cue is not actionable, so `showCue` is false), then a green number, and after a
// dropped lock "—" again. One glyph for three different moments; only the trace's colour told
// them apart, and colour is the channel daylight, colour-blindness and VoiceOver cannot read.
//
// WHAT THIS GUARDS.
//   1. END-TO-END: `PulseLadder.step` is the truth table the doc names — locked → found; a lock
//      seen earlier this take → lost; else halfway to the gate → nearly; else searching — and it
//      never traps on a non-finite input (the NaN law).
//   2. END-TO-END: the four words fit the slot they share (≤ 12 characters, the law
//      `AStalledAcquisitionSaysSoTests` states for every short label), are distinct, and carry
//      no digit or percent sign — the audit's "Locked 87 %" is the shape this replaces.
//   3. SOURCE: the pill RENDERS the word — in the value slot as the LAST rung of the precedence
//      (remedy > source status > ladder > "—"), beside the number when found — and SPEAKS it
//      (`accessibilityText` falls back to `ladder?.spoken`, keeping "No pulse lock" for sources
//      without a ladder). The live wrapper hands the camera's rung in once; the publisher's
//      `lockSeenThisTake` is set in the publish branch and cleared by `stop()`.
//   4. COUNTERWEIGHTS (#343): the precedence the ladder sits under still exists — `showCue`
//      returns the remedy, `showStatus` the source status — and the lock gate the share is a
//      share OF is still a named constant.
//
// ⚠️ LIMIT. Claims 3–4 are source text: nothing here renders the pill or proves "Almost" appears
// at a moment that FEELS right on a finger — that is the NEEDS-FOUNDER-VERIFY at `nearlyShare`.
//
// ⚠️ GRADING (§0, no toolchain in a web session): claims 1–2 transcribed into Python over the
// same truth table; claims 3–4 driven against this tree and its parent 2856bf9ed. On the parent
// `PulseLadder` does not exist — claims 1–2 cannot compile (ONE absence, #486), claim 3's nine
// needles are absent together, claim 4 is green on both.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePulseSpeaksItsStatusInWordsTests: XCTestCase {

    private static let monitors = "Sources/Echoelmusic/Studio/HeaderMonitors.swift"
    private static let publisher = "Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift"
    private static let ladder = "Sources/Echoelmusic/Bio/PulseLadder.swift"

    // MARK: 1 — the truth table

    func testTheLadderClimbsSearchingAlmostFoundAndFallsToLost() {
        let gate = CameraRPPGBioPublisher.lockThreshold
        XCTAssertEqual(PulseLadder.step(locked: true, confidence: 0, lockSeen: false, lockThreshold: gate), .found,
                       "locked is found, whatever the confidence says")
        XCTAssertEqual(PulseLadder.step(locked: true, confidence: 1, lockSeen: true, lockThreshold: gate), .found,
                       "locked wins over a lock seen earlier — a re-found pulse is found, not lost")
        XCTAssertEqual(PulseLadder.step(locked: false, confidence: 1, lockSeen: true, lockThreshold: gate), .lost,
                       "not locked after a lock this take is lost, however confident the estimate")
        XCTAssertEqual(PulseLadder.step(locked: false, confidence: 0, lockSeen: false, lockThreshold: gate), .searching)
        let halfway = gate * PulseLadder.nearlyShare
        XCTAssertEqual(PulseLadder.step(locked: false, confidence: halfway, lockSeen: false, lockThreshold: gate), .nearly,
                       "at exactly halfway to the gate the rung is Almost")
        XCTAssertEqual(PulseLadder.step(locked: false, confidence: halfway.nextDown, lockSeen: false, lockThreshold: gate),
                       .searching, "one ulp below halfway is still Searching")
        XCTAssertEqual(PulseLadder.step(locked: false, confidence: gate, lockSeen: false, lockThreshold: gate), .nearly,
                       "confident but not locked (rhythm strength or bpm missing) reads Almost, never Found")
        // The NaN law — the gate and the confidence both come off a live analyzer.
        for bad in [Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(PulseLadder.step(locked: false, confidence: bad, lockSeen: false, lockThreshold: gate), .searching,
                           "a non-finite confidence (\(bad)) is the bottom rung, not a trap or a promotion")
            XCTAssertEqual(PulseLadder.step(locked: false, confidence: 1, lockSeen: false, lockThreshold: bad), .searching,
                           "a non-finite gate (\(bad)) is the bottom rung")
        }
        XCTAssertEqual(PulseLadder.step(locked: false, confidence: 1, lockSeen: false, lockThreshold: 0), .searching,
                       "a zero gate cannot be halved into a rung")
        XCTAssertGreaterThan(PulseLadder.nearlyShare, 0)
        XCTAssertLessThan(PulseLadder.nearlyShare, 1, "Almost must come BEFORE the gate, or it is Found")
    }

    // MARK: 2 — the words fit the slot and are words

    func testTheFourWordsFitTheSlotAndSayNothingNumeric() {
        XCTAssertEqual(PulseLadderStep.allCases, [.searching, .nearly, .found, .lost],
                       "the rungs are the doc's four, in climbing order")
        let words = PulseLadderStep.allCases.map(\.word)
        XCTAssertEqual(Set(words).count, words.count, "two rungs share a word: \(words)")
        for step in PulseLadderStep.allCases {
            XCTAssertFalse(step.word.isEmpty, "\(step) has no word")
            XCTAssertLessThanOrEqual(step.word.count, 12, """
                "\(step.word)" is \(step.word.count) characters — the pill's value slot is shared \
                with every `PulseCue.shortLabel`, all of which keep to 12.
                """)
            XCTAssertNil(step.word.rangeOfCharacter(from: .decimalDigits), "a rung is a word, not a number")
            XCTAssertFalse(step.word.contains("%"), "\"Locked 87 %\" is the shape this ladder replaces")
            XCTAssertFalse(step.spoken.isEmpty, "\(step) has no spoken sentence")
            XCTAssertTrue(step.spoken.lowercased().contains("pulse") || step.spoken.lowercased().contains("finger"),
                          "the spoken rung names the pulse or the finger — VoiceOver hears it under the label \"Heart rate\"")
        }
    }

    // MARK: 3 — the pill renders and speaks it; the publisher remembers a lock per take

    func testThePillRendersTheWordAndSpeaksIt() throws {
        let pill = try source(Self.monitors)
        XCTAssertTrue(pill.contains("var ladder: PulseLadderStep? = nil"), "the pill takes an optional rung — nil is the plain monitor")
        guard let status = pill.range(of: "} else if showStatus, let status {"),
              let rung = pill.range(of: "} else if let ladder {", range: status.upperBound..<pill.endIndex),
              let dash = pill.range(of: "Text(\"—\")", range: rung.upperBound..<pill.endIndex) else {
            return XCTFail("ANCHOR MISSING: the value slot's precedence (status → ladder → dash) (#454)")
        }
        _ = dash
        XCTAssertTrue(pill.contains("Text(ladder.word)"), "the pill renders the rung's word")
        XCTAssertTrue(pill.contains("ladder == .lost ? EchoelTheme.warning : EchoelTheme.dim"),
                      "Lost is the one rung that warns; Searching and Almost stay dim")
        XCTAssertTrue(pill.contains("if let ladder, ladder == .found {"),
                      "locked, the word sits beside the number — the doc's \"die Zahl bleibt daneben\"")
        // E4-32: the old sentence is a catalog key now — same fallback, same position.
        XCTAssertTrue(pill.contains("return ladder?.spoken ?? String(localized: \"No pulse lock\")"),
                      "VoiceOver hears the rung; a source without a ladder keeps the old sentence")
        let live = try body(from: "PulseMonitorMini(waveform: cameraRPPG.waveform,",
                            to: ".contentShape(Rectangle())", in: pill)
        XCTAssertEqual(live.components(separatedBy: "ladder:").count - 1, 1, "the live wrapper passes the rung once")
        XCTAssertTrue(live.contains("PulseLadder.step(locked: cameraRPPG.isLocked,"),
                      "the rung is computed from the publisher's own lock, not a second definition")
        XCTAssertTrue(live.contains("lockSeen: cameraRPPG.lockSeenThisTake,"))
        XCTAssertTrue(live.contains("lockThreshold: CameraRPPGBioPublisher.lockThreshold)"),
                      "the share is a share OF the publisher's gate (#416)")
        let publisher = try source(Self.publisher)
        XCTAssertTrue(publisher.contains("public private(set) var lockSeenThisTake = false"))
        XCTAssertTrue(publisher.contains("if !self.lockSeenThisTake { self.lockSeenThisTake = true }"),
                      "set once per take in the publish branch, written only on the flip (10 Hz loop)")
        // The clear sits in `stop()` beside `isSettled = false` (the source is comment-stripped,
        // so the needle is the statement, and its POSITION says which method it is in).
        guard let settledReset = publisher.range(of: "isSettled = false"),
              publisher.range(of: "lockSeenThisTake = false", range: settledReset.upperBound..<publisher.endIndex) != nil else {
            return XCTFail("`lockSeenThisTake = false` is not cleared after `isSettled = false` in stop() — a latch stop() forgets is a previous take's washout (#454)")
        }
        let ladder = try source(Self.ladder)
        XCTAssertFalse(ladder.contains("import SwiftUI") || ladder.contains("@Environment"),
                       "the ladder is a pure Foundation type — testable without a view")
    }

    // MARK: 4 — counterweights: the precedence and the gate the ladder sits under

    func testThePrecedenceAndTheGateStillExist() throws {
        let pill = try source(Self.monitors)
        XCTAssertTrue(pill.contains("if showCue, let cue { return cue.fullHint }"),
                      "the remedy still outranks everything in the spoken value")
        XCTAssertTrue(pill.contains("private var showStatus: Bool { !locked && !showCue && status != nil }"),
                      "the source status still outranks the ladder")
        let publisher = try source(Self.publisher)
        XCTAssertTrue(publisher.contains("nonisolated static let lockThreshold"),
                      "the lock gate is a named constant the share can be a share of")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// The text between two unique anchors.
    private func body(from start: String, to end: String, in code: String) throws -> String {
        guard let s = code.range(of: start), let e = code.range(of: end, range: s.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: `\(start)` → `\(end)` (#454)")
            throw AnchorMissing(name: start)
        }
        return String(code[s.lowerBound..<e.lowerBound])
    }
}
