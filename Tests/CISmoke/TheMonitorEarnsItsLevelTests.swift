// TheMonitorEarnsItsLevelTests.swift
// Echoel — #1273 (A2 of the founder's 2026-09-11 ask: „Monitoring (nur erlauben bzw.
// hochrecken, wenn kein Feedback)"). The monitor no longer engages at the user's level and
// waits to be ducked; it engages CLOSED and earns its way up one guard tick at a time, on the
// condition that the room shows no feedback at all.
//
// WHAT WAS THERE BEFORE, AND WHY IT IS NOT THIS. `FeedbackGuard.gainReductionDB` (the duck)
// is REACTIVE and broadband: it needs a runaway that is already over its ceiling — i.e.
// already audible — and it releases the moment the level drops, straight back into the gain
// that caused it. `HowlDetector` + the four notches (#847/#848) made the ring inaudible per
// band, which is the other half. Neither ever asked the question the founder asked: may this
// level exist in this room at all? That is a PERMISSION, it converges, and it is what stops
// the system depending on its own last line of defence.
//
// SOURCE-TEXT SCAN (§1): no AVAudioEngine and no room in a test host, so the behaviour itself
// is a device probe — NEEDS-FOUNDER-VERIFY at the engage site. What is pinned here is the
// SHAPE: closed on engage, raised only on a clear tick, multiplied into every writer of the
// monitor volume, and quantised before it reaches a view.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`fea1adc`) and this tree: claims
// 1–4 and 6 RED on the parent (no gate exists there at all), claim 5 GREEN on both (it is the
// counterweight — it must be green on both or it is not one). All six GREEN here. Claims
// 1–4 and 6 TRAGEND (5 of 6 verdicts flip); claim 5 PROPHYLAKTISCH.
// ⛔ The OFF-path reset started IN claim 5 and made it red on the parent — i.e. not a
// counterweight at all, while its own docstring said it was. Moved to claim 1, where it
// belongs anyway (engage/disengage symmetry). A counterweight that flips is the one kind of
// claim whose wrongness is invisible in a green run.

import Foundation
import XCTest

final class TheMonitorEarnsItsLevelTests: XCTestCase {

    private static let engine = "Sources/Echoelmusic/Audio/AudioEngine.swift"
    private static let sheet = "Sources/Echoelmusic/Studio/AudioInputPickerView.swift"

    /// Claim 1 — the monitor engages with the gate closed, and closes it again on the way out. The line this replaces
    /// (`monitorMixer.outputVolume = min(max(inputMonitorGain, 0), 1)` straight after
    /// `isInputMonitoring = true`) is a howl that exists before any defence has seen a
    /// sample: the duck needs eight level samples and the detector a full FFT window.
    func testMonitoringEngagesWithTheGateClosed() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        let on = try Self.member("func setInputMonitoring(_ on: Bool) -> Bool", in: src)
        let engage = try XCTUnwrap(on.range(of: "isInputMonitoring = true")).upperBound
        let after = String(on[engage...].prefix(400))
        XCTAssertFalse(after.contains("monitorMixer.outputVolume = min(max(inputMonitorGain, 0), 1)"), """
            monitoring engages at the user's full level again. In a speaker-monitoring room \
            that is a howl before any defence has a sample to look at — the gate exists to \
            make the worst case a swell that stops where the room stops it (#1273)
            """)
        XCTAssertTrue(after.contains("monitorGateFraction = 0"),
                      "the engage site no longer closes the gate — the next engage would start wherever the last room left it (#1273)")
        XCTAssertTrue(after.contains("monitorMixer.outputVolume = 0"),
                      "the engage site no longer silences the monitor before the first guard tick (#1273)")
        // SYMMETRY — the gate also closes with the monitor. It describes ONE room in ONE
        // session; carried across an off/on cycle it would let the next engage start at a
        // level the defence has not re-earned, which is the jump this slice just removed.
        let off = try XCTUnwrap(src.range(of: "logMonitorOutcome(\"off 2/5")).lowerBound
        XCTAssertTrue(String(src[..<off].suffix(600)).contains("monitorGateFraction = 0"),
                      "the OFF path no longer closes the gate (#1273)")
    }

    /// Claim 2 — the gate rises ONLY on a tick with no feedback of any kind, and falls on any
    /// of the three signals. All three are named: the duck (already audible), a detector
    /// candidate (not yet audible, #847) and a notch still biting or holding (the room is not
    /// quiet, it is being held quiet).
    func testTheGateRisesOnlyWhileTheRoomIsClear() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        let tick = try Self.member("private func updateFeedbackGuard()", in: src)
        XCTAssertTrue(tick.contains("let clear = duckDB <= 0 && candidates.isEmpty && !notchBiting"), """
            the gate's clear condition changed. Dropping a term is the dangerous direction: \
            without `candidates.isEmpty` the gate keeps climbing through a howl the detector \
            has already seen, and the preventive half of FeedbackGuard is back to being \
            reactive (#847/#1273)
            """)
        XCTAssertTrue(tick.contains("$0.gainDB < 0 || $0.holdTicks > 0"),
                      "the biting-notch test no longer reads the HOLD — a band parked past its last detection would read as a clear room (#848/#1273)")
        XCTAssertTrue(tick.contains("monitorGateFraction + Self.monitorGateRiseStep"),
                      "the gate no longer rises in steps on the clear branch (#1273)")
        XCTAssertTrue(tick.contains("monitorGateFraction - Self.monitorGateFallStep"),
                      "the gate no longer falls on the at-risk branch — it would only ever open (#1273)")
        let clear = try XCTUnwrap(tick.range(of: "let clear =")).lowerBound
        let spectrum = try XCTUnwrap(tick.range(of: "howlDetector.observe(magnitudes:")).lowerBound
        XCTAssertLessThan(spectrum, clear, """
            the gate step runs BEFORE this tick's spectrum, so `candidates` is empty by \
            construction and the detector term is decorative — the exact shape of a check \
            that cannot fail (#1273)
            """)
    }

    /// Claim 3 — every writer of the monitor volume goes through the gate. There are two: the
    /// guard tick and `inputMonitorGain.didSet`. A raw write in the setter would let one drag
    /// of the field jump straight past a gate the tick had deliberately closed.
    func testBothWritersOfTheMonitorVolumeRespectTheGate() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        XCTAssertTrue(src.contains("monitorMixer.outputVolume = g * monitorGateFraction"), """
            the `inputMonitorGain` setter writes the monitor volume without the gate. The \
            field is the REQUEST; what reaches the speaker is the request times what the room \
            has allowed (#1273)
            """)
        XCTAssertTrue(src.contains("monitorMixer.outputVolume = base * factor * monitorGateFraction"), """
            the guard tick writes the monitor volume without the gate — the duck alone is \
            back to holding the system together (#1273)
            """)
    }

    /// Claim 4 — the value a view reads is quantised and written on change, and the view that
    /// reads it is a LEAF. The raw fraction moves on every one of ~15 ticks per second; a
    /// plain mirror read in the sheet's own body would make the whole sheet — the draggable
    /// "Monitor level" field included — rebuild at 15 Hz. That is the 10.76.50 mechanism, and
    /// the engine's own note at `feedbackGuardActive` records the near miss one property over.
    func testTheGateReadoutCannotChurnTheSheet() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        XCTAssertTrue(src.contains("if quantised != monitorGateCeiling { monitorGateCeiling = quantised }"), """
            the UI mirror is assigned unconditionally. Assigning an equal value to an \
            `@Observable` stored property STILL notifies, so every reader becomes a ~15 Hz \
            observer for as long as monitoring runs (#298/#1273)
            """)
        let ui = SourceText.codeOnly(try text(Self.sheet))
        XCTAssertTrue(ui.contains("private struct FeedbackGateLine: View"), """
            the gate readout is no longer its own `View`. Read from `monitoringSection`'s body \
            it churns the sheet it sits in; a leaf churns eight words (10.76.50/#1273)
            """)
        XCTAssertEqual(ui.components(separatedBy: "audioEngine.monitorGateCeiling").count - 1, 1, """
            `monitorGateCeiling` is read more than once in this sheet. The second reader is \
            almost certainly a parent body, which is exactly what the leaf exists to avoid \
            (10.76.50/#1273)
            """)
    }

    /// Claim 5 — COUNTERWEIGHT, green on both trees. The gate ADDS a permission stage; it
    /// replaces nothing. The duck still computes its reduction, `feedbackGuardActive` is still
    /// written only on change, the notch defence still runs every tick, and the gate closes
    /// again with the monitor.
    func testTheDuckAndTheNotchDefenceAreUntouched() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        let tick = try Self.member("private func updateFeedbackGuard()", in: src)
        XCTAssertTrue(tick.contains("FeedbackGuard.gainReductionDB(rmsHistory: monitorLevelHistory)"),
                      "the broadband duck is gone — the gate is slow on purpose and cannot replace a last resort (#1273)")
        XCTAssertTrue(tick.contains("if ducking != feedbackGuardActive { feedbackGuardActive = ducking }"),
                      "`feedbackGuardActive` is assigned every tick again (#298)")
        XCTAssertTrue(tick.contains("applyNotchDefence(candidates: candidates)"),
                      "the preventive notch half no longer runs on the guard tick (#848)")
    }

    /// Claim 6 — the asymmetry IS the design: slow to trust the room, quick to stop feeding
    /// it. Pinned as a RELATION between the two constants, never as their values — a literal
    /// here would be a date, and both numbers are ear-tunable (#818/#903).
    func testTheGateFallsFasterThanItRises() throws {
        let src = SourceText.codeOnly(try text(Self.engine))
        func value(_ name: String) throws -> Double {
            let marker = "nonisolated static let \(name): Float = "
            let r = try XCTUnwrap(src.range(of: marker), "`\(name)` is gone — re-anchor (§4)")
            let rest = src[r.upperBound...].prefix(while: { "0123456789.".contains($0) })
            return try XCTUnwrap(Double(rest), "`\(name)` is no longer a plain literal — re-anchor (§4)")
        }
        let rise = try value("monitorGateRiseStep")
        let fall = try value("monitorGateFallStep")
        XCTAssertGreaterThan(fall, rise, """
            the gate now falls no faster than it rises. A symmetric gate oscillates: it climbs \
            back into the howl it just left at the same speed it backed out of it, which is \
            the pumping the founder already hears from the duck alone (#1273)
            """)
        XCTAssertGreaterThan(rise, 0, "a zero rise step never opens the gate — monitoring would be silent forever (#1273)")
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
