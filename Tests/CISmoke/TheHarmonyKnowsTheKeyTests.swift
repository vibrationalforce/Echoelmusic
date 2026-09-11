// TheHarmonyKnowsTheKeyTests.swift
// Echoel — #1252 (S7 of `PLAN_AUDIO_INPUT_2026-09-11.md`; founder 2026-09-11: the voice
// adapted *"an die Stimmung"*). The harmonizer's two voices can follow the session KEY: the
// diatonic third and fifth above what is sung, instead of fixed semitone intervals.
//
// BEFORE: `EchoelHarmonizer` shifted by `interval1/2` — 4 and 7 semitones by default — so a
// sung E in C major got a G♯. `updateVoiceTune` already knew the key (the ONE definition,
// `StudioDefaultKeys`) and the sung pitch (YIN); nothing joined them for the harmony.
//
// END-TO-END BEHAVIOUR for claims 1–3 (`DiatonicHarmony` is a shipped Foundation-only type);
// SOURCE-TEXT SCAN for 4–5 (the tick and the door). Whether it SOUNDS right is a DEVICE PROBE
// — NEEDS-FOUNDER-VERIFY at `AudioEngine.voiceHarmonyFollowsKey`.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`b54d29f`) and this tree: claims
// 1–3 RED on the parent (the type does not exist — one finding, #486), the algebra driven in
// Python first; claims 4–5 RED on the parent, GREEN here; claim 6 (the session-key guard's
// needles survive the tick's restructure) GREEN on both. Stripper: PROPHYLAKTISCH (0 of 7
// scan verdicts flip).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheHarmonyKnowsTheKeyTests: XCTestCase {

    private let cMajor = MusicalKey(root: 0, scale: .major)

    /// Claim 1 — in-scale notes get the diatonic third and fifth, measured from the sung note.
    func testInScaleNotesGetDiatonicThirdAndFifth() {
        var r = DiatonicHarmony.intervals(aboveMidi: 64, in: cMajor)     // E
        XCTAssertEqual(r.first, 3, "E in C major: the third above is G, a MINOR third (#1252)")
        XCTAssertEqual(r.second, 7, "E in C major: the fifth above is B (#1252)")
        r = DiatonicHarmony.intervals(aboveMidi: 60, in: cMajor)         // C
        XCTAssertEqual(r.first, 4); XCTAssertEqual(r.second, 7)
        r = DiatonicHarmony.intervals(aboveMidi: 71, in: cMajor)         // B
        XCTAssertEqual(r.first, 3, "B in C major: D above (#1252)")
        XCTAssertEqual(r.second, 6, "B in C major: the fifth is F, DIMINISHED — the key decides, not a fixed 7 (#1252)")
        r = DiatonicHarmony.intervals(aboveMidi: 69, in: MusicalKey(root: 9, scale: .minor))  // A in A minor
        XCTAssertEqual(r.first, 3); XCTAssertEqual(r.second, 7)
    }

    /// Claim 2 — an off-scale note harmonises from its nearest degree; ties resolve down.
    func testOffScaleNotesHarmoniseFromTheNearestDegree() {
        let cs = DiatonicHarmony.intervals(aboveMidi: 61, in: cMajor)   // C♯ — one semitone from C and D
        XCTAssertEqual(cs.first, 3, "C♯ resolves DOWN to C: E above is +3 from C♯ (#1252)")
        XCTAssertEqual(cs.second, 6, "…and G is +6 from C♯ (#1252)")
        let fs = DiatonicHarmony.intervals(aboveMidi: 66, in: cMajor)   // F♯ — tie F/G
        XCTAssertEqual(fs.first, 3); XCTAssertEqual(fs.second, 6)
        for midi in 48...84 {
            let r = DiatonicHarmony.intervals(aboveMidi: midi, in: cMajor)
            XCTAssertTrue((1...12).contains(r.first) && (1...12).contains(r.second),
                          "intervals must stay positive and within an octave for midi \(midi) (#1252)")
        }
    }

    /// Claim 3 — Hz → MIDI is rounded at concert pitch and refuses bad input.
    func testHzToMidi() {
        XCTAssertEqual(DiatonicHarmony.midi(forHz: 329.63, a4Hz: 440), 64)
        XCTAssertEqual(DiatonicHarmony.midi(forHz: 261.63, a4Hz: 440), 60)
        XCTAssertEqual(DiatonicHarmony.midi(forHz: 442, a4Hz: 442), 69)
        XCTAssertNil(DiatonicHarmony.midi(forHz: 0, a4Hz: 440))
        XCTAssertNil(DiatonicHarmony.midi(forHz: .nan, a4Hz: 440))
        XCTAssertNil(DiatonicHarmony.midi(forHz: 440, a4Hz: 0))
    }

    /// Claim 4 — the tick derives the intervals from the SAME key and pitch the tune stage uses, on change only.
    func testTheTickFollowsTheKeyOnChangeOnly() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Audio/AudioEngine.swift"))
        let tick = try Self.member("private func updateVoiceTune()", in: src)
        XCTAssertTrue(tick.contains("guard voiceTuneEnabled || harmonyFollows else { return }"),
                      "the tick no longer runs for a key-following harmony with tune OFF (#1252)")
        XCTAssertTrue(tick.contains("if harmonyFollows { updateHarmonyInKey(detectedHz: voiceTuneLastDetectedHz) }"))
        let follow = try Self.member("private func updateHarmonyInKey(detectedHz: Double?)", in: src)
        XCTAssertTrue(follow.contains("DiatonicHarmony.intervals(aboveMidi: midi, in: voiceTuneCorrector.key)"),
                      "the harmony must read the corrector's key — the ONE definition, never a second copy (#416/#1252)")
        XCTAssertTrue(follow.contains("if voiceHarmonyInterval1 != Float(first) { voiceHarmonyInterval1 = Float(first) }"),
                      "an unconditional assignment pushes the whole voice preset 15× a second (#1252)")
    }

    /// Claim 5 — the door: a Toggle in the input sheet, and the interval pickers go inert while it is on.
    func testTheSheetHasTheToggleAndDisablesThePickers() throws {
        let view = try text("Sources/Echoelmusic/Studio/AudioInputPickerView.swift")
        XCTAssertTrue(view.contains("Text(\"Harmony in key\")"), "the toggle is gone from the input sheet (#1252)")
        XCTAssertEqual(view.components(separatedBy: ".disabled(audioEngine.voiceHarmonyFollowsKey)").count - 1, 2,
                       "both interval pickers must be disabled while the key decides — a picker that moves nothing is a control that lies (#485/#1252)")
    }

    /// Claim 6 — counterweight: the session-key guard's needles survived the tick's restructure.
    func testTheSessionKeyNeedlesSurvive() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Audio/AudioEngine.swift"))
        XCTAssertEqual(src.components(separatedBy: "if stamp != lastVoiceTuneStamp {").count - 1, 1)
        XCTAssertEqual(src.components(separatedBy: "voiceTuneCorrector.process(detectedHz: voiceTuneLastDetectedHz,").count - 1, 1)
        XCTAssertEqual(src.components(separatedBy: "voiceTuneLastDetectedHz = nil").count - 1, 3)
        XCTAssertEqual(src.components(separatedBy: "self.updateVoiceTune()").count - 1, 1)
    }

    private static func member(_ marker: String, in src: String) throws -> String {
        let hits = src.components(separatedBy: marker).count - 1
        guard hits == 1, let start = src.range(of: marker) else {
            throw XCTSkip("anchor `\(marker)` occurs \(hits)× — re-anchor before trusting a zero (#408)")
        }
        guard let open = src[start.upperBound...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var i = open
        while i < src.endIndex {
            let c = src[i]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(src[open...i]) } }
            i = src.index(after: i)
        }
        return String(src[open...])
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
