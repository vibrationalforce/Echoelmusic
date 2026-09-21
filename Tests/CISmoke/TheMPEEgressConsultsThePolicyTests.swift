// TheMPEEgressConsultsThePolicyTests.swift
// Echoel — #1434, founder Slice 0. MIDI was the ONE external bio-egress surface that
// never asked `BioEgressPolicy` whether this body's numbers may leave the device.
//
// THE MEASUREMENT THAT SHAPED THIS FILE. `EngineBus.usableBio()` filters on FRESHNESS
// ONLY — it reads `f.source.freshnessWindow` and never `f.source` itself — so a
// `.healthKit` / `.watch` / `.oura` frame passed straight into
// `MPEExpression.from(coherence:breathDepth:hrvNormalized:)` and left as CC74,
// channel pressure and pitch bend, through a virtual CoreMIDI source AND a fan-out
// over every destination. Meanwhile OSC, ADM-OSC, Art-Net, sACN and Multipeer all
// consulted the policy. One surface out of six did not.
//
// ⛔ SAY THE SEVERITY ACCURATELY, because the flattering direction here is DRAMA, not
// understatement. This was NOT a shipped privacy breach and NOT a clinical-data leak.
// Three default-off switches sat in front of it (the `midi.out` route,
// `midi.out.mpe`, `midi.out.expression`), the values are `FieldClass.derived` — the
// class the policy exists to PERMIT — and the millisecond HRV statistics gated by
// #1292 were never on this path. It is a MISSING PRIVACY GATE ON AN OPT-IN EGRESS
// PATH. That is the whole claim, and it is enough of one.
//
// ⭐ THE FIX IS THE #511 SHAPE, NOT A NEW POLICY TYPE. `BioPeek.egressible(from:)`
// solved this exact problem on the Multipeer surface by taking the FRAME instead of a
// provenance-free projection, so the rule is applied by the thing that projects rather
// than by whoever remembers to ask. `MPEExpression.egressible(from:)` is that symbol
// for MIDI. No `MIDIEgressPolicy`, no second rule to drift.
//
// ⚠️ WHAT IS DELIBERATELY NOT GATED, and claim 3 is what keeps it that way: a note
// whose VELOCITY was musically shaped by the body is a CREATIVE RESULT, not a
// measurement — it has passed generation, scale quantisation, `noteExpression` and the
// lane gain. Over-gating ordinary musical output would be its own defect, and a
// version of this file that "fixed" more would have broken the instrument.
//
// ⚠️ THE MIDI CLOCK IS NOT IN THIS SLICE, and that is a decision with a reason rather
// than an oversight. Under `.flowFree` its BPM follows the pulse, and `OSCSender`
// withholds exactly that value (`bodyMayEgress`). But withholding a clock TEMPO is not
// the same move as returning nil for an expression: the pulse train keeps running, so
// a suppressed update DESYNCS the receiver instead of silencing a value. Different
// failure story ⇒ different slice. Claim 5 pins that nothing here touched it.
//
// KIND (§1): END-TO-END BEHAVIOUR for claims 2 and 3 (`MPEExpression` and
// `BioSampleFrame` are Foundation-only value types, driven directly). SOURCE-TEXT SCAN
// for 1, 4 and 5. What a MIDI monitor SEES is a DEVICE PROBE and is NOT claimed here.
//
// ⚠️ HONEST GRADING (§3): this file names `MPEExpression.egressible`, which THIS COMMIT
// CREATES, so it does NOT COMPILE against the parent and no assertion has a verdict
// there. That is ONE absence (#486), not five findings. Graded by TRANSCRIPTION (§0)
// against both trees. Claims 3, 4 and 5 are COUNTERWEIGHTS — green on BOTH trees on
// purpose (#343): they exist to redden the day someone "improves" this by gating
// ordinary music, by flipping a default-off switch on, or by quietly widening the
// policy that four other senders share.

import XCTest
@testable import Echoelmusic

final class TheMPEEgressConsultsThePolicyTests: XCTestCase {

    private func source(_ path: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func frame(source s: BioSource, coherence: Float = 0.8,
                       hrv: Float = 0.7, breathPhase: Float = 0.5) -> BioSampleFrame {
        BioSampleFrame(timestamp: 0, heartRateBPM: 64, hrvNormalized: hrv,
                       breathRate: 6, breathPhase: breathPhase, coherence: coherence,
                       motionEnergy: 0, source: s)
    }

    // CLAIM A — the direct bio-derived MIDI path consults BioEgressPolicy, and it does
    // so BY NAME in the projecting function rather than at a caller that could be
    // duplicated. Parent: RED (the symbol does not exist there).
    func testTheProjectionFromABodyAsksThePolicyByName() throws {
        let src = SourceText.codeOnly(try source("Sources/Echoelmusic/Sync/MPEExpression.swift"))
        XCTAssertTrue(src.contains("func egressible(from frame: BioSampleFrame) -> MPEExpression?"), """
        MPEExpression no longer offers a frame-taking projection. Three loose Floats carry \
        no provenance, so whatever replaced it cannot ask the 5.1.3 question at all — that \
        is precisely the position BioPeek was in before #511.
        """)
        XCTAssertTrue(src.contains("BioEgressPolicy.allowsEgress(frame.source)"), """
        The frame-taking projection no longer calls BioEgressPolicy.allowsEgress(frame.source). \
        It must CALL the shared policy, never restate the source list: #186's first cut \
        inlined the rule and its test re-implemented it, so the test passed with the \
        production guard deleted.
        """)
    }

    // CLAIM A2 — the one production producer routes through it. A gate nothing calls is
    // #367. This is the half that would go red if someone re-introduced a bare `.from`
    // call on the note path.
    func testTheNotePathProjectsThroughTheGateAndNotAroundIt() throws {
        let roll = SourceText.codeOnly(try source("Sources/Echoelmusic/Studio/PianoRollView.swift"))
        XCTAssertTrue(roll.contains("MPEExpression.egressible(from: bio)"), """
        The piano-roll note path no longer projects through MPEExpression.egressible. If it \
        went back to MPEExpression.from(coherence:...), the gate still exists and is simply \
        bypassed — the exact failure this slice repaired.
        """)
        XCTAssertFalse(roll.contains("MPEExpression.from("), """
        PianoRollView calls MPEExpression.from( directly again. That overload takes three \
        provenance-free Floats and therefore cannot honour 5.1.3; it is kept only as the \
        pure mapping the gate delegates to, and as the unit-test surface.
        """)
    }

    // CLAIM B — behaviour: a body the policy refuses cannot become MIDI bytes. Driven,
    // not scanned, and over EVERY refused source rather than one representative.
    func testABlockedSourceYieldsNoExpressionAtAll() {
        for blocked in [BioSource.healthKit, .watch, .oura] {
            XCTAssertNil(MPEExpression.egressible(from: frame(source: blocked)), """
            \(blocked) is refused by BioEgressPolicy.allowsEgress, yet the MPE projection \
            still produced an expression. CC74 / channel pressure / pitch bend are one map \
            away from the sensor; this is the value that must not reach CoreMIDI.
            """)
        }
    }

    // CLAIM C — COUNTERWEIGHT, and the one that makes B mean anything (#367, the mirror
    // case). "Nothing leaves for a blocked source" is ALSO true of a projection that
    // returns nil for everything, or of a MIDI sender someone disabled to get green.
    // Echoel's OWN measured bodies must still produce a full, unchanged expression.
    func testEchoelsOwnBodiesStillPlayTheFullExpression() {
        for allowed in [BioSource.cameraPPG, .ble, .fallback] {
            guard let e = MPEExpression.egressible(from: frame(source: allowed)) else {
                return XCTFail("""
                \(allowed) is a source Echoel measures itself and the policy admits it. \
                Returning nil here does not protect a body — it silences the instrument.
                """)
            }
            // The mapping itself must be untouched: this slice moved WHERE the rule is
            // asked, never WHAT the body sounds like.
            let reference = MPEExpression.from(coherence: 0.8,
                                               breathDepth: Float(sin(Double(0.5) * .pi)),
                                               hrvNormalized: 0.7)
            XCTAssertEqual(e, reference, """
            The gated projection no longer agrees with the pure mapping for an ALLOWED \
            source. Slice 0 was a privacy gate, not a re-voicing — if these differ, the \
            breath swell, the neutral-for-sound reads or the bend range moved with it.
            """)
        }
    }

    // CLAIM D — COUNTERWEIGHT: the three switches in front of this path stay default-off.
    // A slice that "fixed privacy" while turning an egress route on by default would be
    // a net loss, and no behavioural test above would notice.
    func testTheSwitchesInFrontOfThisPathStayDefaultOff() throws {
        let keys = SourceText.codeOnly(try source("Sources/Echoelmusic/Core/StudioDefaultKeys.swift"))
        for (key, label) in [("midi.out.mpe", "MPE note layout"),
                             ("midi.out.expression", "per-note expression")] {
            guard let r = keys.range(of: "key: \"\(key)\"") else {
                return XCTFail("the \(label) default key is gone — re-anchor this guard (#1092)")
            }
            let window = String(keys[r.lowerBound...].prefix(60))
            XCTAssertTrue(window.contains("value: false"), """
            \(key) is no longer default-false. The expression path is opt-in, and its \
            severity statement in this file's header depends on that being true.
            """)
        }
    }

    // CLAIM E — COUNTERWEIGHT: the shared policy's own source rule is untouched, so the
    // five other senders that call it behave exactly as before. Slice 0 added a CALLER,
    // it did not widen a rule.
    func testTheSharedSourceRuleIsUnchangedForEveryOtherSender() throws {
        let policy = SourceText.codeOnly(try source("Sources/Echoelmusic/Core/BioEgressPolicy.swift"))
        XCTAssertTrue(policy.contains("case .ble, .cameraPPG, .fallback:"), """
        The permitted-source list moved. Every other egress surface (OSC, ADM-OSC, \
        Art-Net, sACN, Multipeer) reads this same switch; widening it here would change \
        five senders at once, which is not what a MIDI slice may do.
        """)
        XCTAssertTrue(policy.contains("case .healthKit, .watch, .oura:"), """
        The refused-source list moved. See above — this rule is shared, and claim B's \
        meaning rests entirely on it.
        """)
        // And the CLOCK, deliberately out of scope, is still ungated — pinned so the next
        // session reads this as a known open decision rather than as finished work.
        let out = SourceText.codeOnly(try source("Sources/Echoelmusic/Audio/MIDIOutput.swift"))
        XCTAssertFalse(out.contains("BioEgressPolicy"), """
        MIDIOutput now references BioEgressPolicy. That is not wrong — but it means the \
        MIDI-CLOCK question this file's header explicitly deferred has been answered \
        somewhere, and this guard's scope paragraph is now stale (#456). Update the header \
        in the same commit.
        """)
    }
}
