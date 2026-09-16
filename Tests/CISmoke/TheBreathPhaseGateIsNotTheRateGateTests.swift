// TheBreathPhaseGateIsNotTheRateGateTests.swift
// Echoel — #1323. Blocking bundle. Claims 1, 2 and 5 are END-TO-END BEHAVIOUR on shipped,
// `public`, Foundation-only value types (`Tests/CISmoke/CLAUDE.md` §1) — they build frames and
// ask the shipped gates. Claims 3 and 4 are SOURCE-TEXT. Nothing here proves what a Watch on a
// wrist produces; that is a DEVICE PROBE and stays open.
//
// ⭐ WHY THIS FILE EXISTS, AND IT IS NOT "A GATE WAS WRONG". #1140 SPLIT one question into two
// — `hasMeasuredBreath` answers whether a RATE was measured, `hasMeasuredBreathWaveform`
// whether the PHASE was traced — wrote the reason into the predicate's own doc ("Use this —
// not `hasMeasuredBreath` — wherever the PHASE itself is asserted outward"), and migrated
// THREE readers: the OSC egress, the ADM-OSC object position and the renderer. THREE more read
// the phase and were never migrated: `BioModulationMap.isMeasured(.breath:)`,
// `ModSource.isMeasured` (which lumped `.breathRate` and `.breathPhase` into one arm) and
// `AlwaysOnBioChannel.isMeasured(.breathPhase:)` plus the breath caption beside it.
//
// The consequence is specific: HealthKit measures a genuine respiratory rate and leaves
// `breathPhase` at the literal `0.5` its engine writes only in fallback mode. On a Watch frame
// all three unmigrated readers therefore answered "measured" about a number nothing had
// measured — the metrics guide printed a confident `0.50` in accent colour and VoiceOver spoke
// "Currently 50 percent", while the sound did not move at all, because 0.5 IS the engine's
// declared neutral. A user-built unipolar `.breathPhase` route sat at a permanent half-depth
// offset off that placeholder, which is exactly the failure `ModulationMatrix`'s own prose
// claimed was closed.
//
// ⭐ THE LAW, and it is why claim 3 is a SWEEP rather than three more pins: **a split predicate
// is not done until every reader has been moved, and "every" is a set the next session cannot
// hold in its head.** #1140 migrated the readers it could see. The three it missed all had the
// same shape — a `case .breathPhase:` or `case .breath:` arm returning the bare predicate — so
// that shape, not a list of files, is what this file forbids. The next unmigrated reader goes
// red without anyone having to remember it exists.
//
// ⚠️ THE CAPTION HAD TO MOVE WITH ITS GATE, AND CLAIM 5 IS WHY. Switching the gate alone would
// have told a user whose Watch just measured their respiratory rate "No breathing measured
// yet" — trading one false sentence for another, on the surface whose whole job is to say what
// is measured. The caption now names the MOVEMENT the note follows. The needle in
// `TheBioPanelRowsSayWhoseBodyTests` moved in the same commit; this claim covers the state that
// guard has no case for, a source with a real rate and no waveform.
//
// ⚠️ WHAT THE SWEEP CANNOT SEE, stated rather than implied. It reads ONE LINE at a time, so an
// arm whose `return` sits on the next line is invisible to it; all four arms in this repo are
// single-line today. It also only inspects arms that mention the predicate at all — a reader
// that copies the phase into a local first is a different shape and would need a different
// scan. What it DOES cover is the shape all three unmigrated readers had, including the LUMPED
// `case .breathRate, .breathPhase:` that hid the third one: the labels are split, so a lumped
// case is caught rather than walked past.
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **14 assertions across five claims**
// (claim 1 = 6, claim 2 = 4, claim 3 = 2, claim 4 = 1, claim 5 = 1). All were transcribed in
// Python — the four gates and the caption's branch reimplemented from each tree's own source,
// the sweep driven directly over `Sources/`. On the PARENT tree (`7f0bfea`) **5 are red**, and
// they are ONE finding (#486): one unmigrated predicate seen through three readers, its sweep
// and its caption. On today's tree all 14 are green.
//
// Claim 2's four are COUNTERWEIGHTS (#343) and are green on BOTH trees: on the camera — the
// source that DOES trace a waveform — every phase gate still says measured, so a "fix" that
// silenced breath everywhere goes red here instead of shipping. Claim 1's `breathRate`
// assertion is the same counterweight from the other side: the RATE gate was always correct
// and must not be migrated with the rest.
import Foundation
import XCTest
@testable import Echoelmusic

final class TheBreathPhaseGateIsNotTheRateGateTests: XCTestCase {

    /// A frame shaped like what HealthKit actually publishes: a real respiratory rate, and the
    /// `0.5` placeholder `EchoelBioEngine` never writes outside fallback mode.
    private func frame(_ source: BioSource, rate: Float = 14, phase: Float = 0.5) -> BioSampleFrame {
        BioSampleFrame(timestamp: 0, heartRateBPM: 62, hrvNormalized: 0.4,
                       breathRate: rate, breathPhase: phase, coherence: 0,
                       motionEnergy: 0, source: source)
    }

    // MARK: - claim 1 (BEHAVIOUR) — a measured RATE is not a measured PHASE

    func testAWristFrameDoesNotClaimAMeasuredBreathPhase() {
        let wrist = frame(.healthKit)
        XCTAssertTrue(wrist.hasMeasuredBreath, """
            The RATE gate stopped admitting a HealthKit respiratory rate. That half was always \
            correct — HealthKit measures a real rate — and #1323 must not have taken it with \
            the phase. If the rate band moved, this is the assertion to re-derive.
            """)
        XCTAssertFalse(wrist.hasMeasuredBreathWaveform, """
            A source that traces no breath waveform now claims one. `providesBreathWaveform` is \
            the whole basis of the #1140 split; if HealthKit genuinely started delivering a \
            phase, that is a real change and every claim below follows it.
            """)
        XCTAssertFalse(BioModulationMap.isMeasured(.breath, in: wrist), """
            `BioModulationMap` reports the breath driver as measured on a wrist frame. Its \
            value accessor reads `breathPhase`, which is the frozen 0.5 here — the metrics \
            guide then prints a confident `0.50` and VoiceOver speaks "Currently 50 percent" \
            about a number nothing measured (#1323).
            """)
        XCTAssertFalse(ModSource.breathPhase.isMeasured(in: wrist), """
            `ModSource.breathPhase` reports measured on a wrist frame. A unipolar route on this \
            channel then sits at a permanent half-depth offset off a placeholder — the failure \
            `ModulationMatrix`'s own prose claims is closed.
            """)
        XCTAssertTrue(ModSource.breathRate.isMeasured(in: wrist), """
            `ModSource.breathRate` stopped reporting measured. #1323 SPLIT a lumped case; \
            migrating both halves is over-correcting, and the rate is the half HealthKit really \
            does provide.
            """)
        XCTAssertFalse(AlwaysOnBioChannel.breathPhase.isMeasured(in: wrist), """
            The always-on breath channel reports measured on a wrist frame. Its value is \
            `breathPhaseForSound`, which returns the engine's declared neutral here, so the row \
            would draw a confident half while the sound does not move.
            """)
    }

    // MARK: - claim 2 (BEHAVIOUR, counterweights) — the camera is untouched

    func testACameraFrameStillClaimsAMeasuredBreathPhase() {
        let cam = frame(.cameraPPG, phase: 0.8)
        XCTAssertTrue(cam.hasMeasuredBreathWaveform,
                      "The camera traces a waveform; if this is false the split lost its "
                      + "positive case and breath is silent everywhere.")
        XCTAssertTrue(BioModulationMap.isMeasured(.breath, in: cam),
                      "The breath driver must still read as measured on the source that "
                      + "actually measures it.")
        XCTAssertTrue(ModSource.breathPhase.isMeasured(in: cam),
                      "A breath-phase route must still work on the camera — that is the "
                      + "source the channel was built for.")
        XCTAssertTrue(AlwaysOnBioChannel.breathPhase.isMeasured(in: cam),
                      "The always-on breath row must still light on the camera.")
    }

    // MARK: - claim 3 (SOURCE-TEXT) — the SHAPE is forbidden, not a list of files

    /// The next unmigrated reader has the same shape as the three this slice found. Pinning the
    /// shape is what makes it go red without anyone remembering it exists.
    func testNoPhaseArmReturnsTheRateGate() throws {
        let files = try swiftSources()
        XCTAssertGreaterThan(files.count, 200, """
            Only \(files.count) Swift files were walked under `Sources/`; the tree holds well \
            over three hundred, so an "absent" verdict here would be vacuous.
            """)
        var offenders: [String] = []
        for file in files {
            for (n, line) in SourceText.codeOnly(file.text).split(separator: "\n",
                                                                  omittingEmptySubsequences: false)
                .enumerated() {
                let text = line.trimmingCharacters(in: .whitespaces)
                guard text.hasPrefix("case "), text.contains("hasMeasuredBreath"),
                      !text.contains("hasMeasuredBreathWaveform"),
                      let colon = text.firstIndex(of: ":") else { continue }
                // The LABELS, split — because the form that hid the third reader was a LUMPED
                // `case .breathRate, .breathPhase:`, which a needle for `case .breathPhase:`
                // walks straight past. Splitting is what makes the lumped form visible.
                let labels = text[text.index(text.startIndex, offsetBy: 5)..<colon]
                    .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard labels.contains(".breathPhase") || labels.contains(".breath") else {
                    continue
                }
                offenders.append("\(file.path):\(n + 1)")
            }
        }
        XCTAssertTrue(offenders.isEmpty, """
            A breath-PHASE arm returns the breath-RATE gate: \(offenders.joined(separator: ", ")).

            `hasMeasuredBreath` answers whether a RATE was measured. HealthKit measures a real \
            rate and leaves `breathPhase` at the 0.5 placeholder, so this arm says "measured" \
            about a number nothing measured. Use `hasMeasuredBreathWaveform` (#1140) — its own \
            doc says to, wherever the PHASE is asserted outward. If this arm genuinely is about \
            the RATE, give it its own case rather than lumping the two (#1323 split exactly \
            such a case).
            """)
    }

    // MARK: - claim 4 (SOURCE-TEXT, counterweight) — the predicate still means two things

    func testTheWaveformPredicateStillComposesBothQuestions() throws {
        XCTAssertTrue(try text("Sources/Echoelmusic/Core/EngineBus.swift")
            .contains("hasMeasuredBreath && source.providesBreathWaveform"), """
            `hasMeasuredBreathWaveform` is no longer "a rate was measured AND this source \
            traces a waveform". Every claim above rests on that composition; if it became a \
            bare alias the migration would be a rename and would prove nothing.
            """)
    }

    // MARK: - claim 5 (BEHAVIOUR) — the caption moved with the gate

    func testTheCaptionNamesTheMovementAndNotTheBreathing() {
        let caption = BioPanelRowCopy.breathVoiceCaption(for: frame(.healthKit))
        XCTAssertTrue(caption.contains("No breath movement measured yet"), """
            The breath caption on a rate-only source does not name the MOVEMENT. Two false \
            sentences are available here and the fix must take neither: "your inhale opens it" \
            is false because the phase is frozen, and "no breathing measured yet" is false \
            because the Watch measured the rate. What the note follows is the movement, so \
            that is what the sentence says (#1323).
            """)
    }

    // MARK: - source access (§0 — FAIL on a missing anchor, never skip it away)

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func text(_ relative: String) throws -> String {
        guard let body = try? String(contentsOf: try repoRoot().appendingPathComponent(relative),
                                     encoding: .utf8), !body.isEmpty else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read while the tree is present "
                    + "— a missing anchor is a finding, not a pass (#454).")
            return ""
        }
        return body
    }

    private func swiftSources() throws -> [(path: String, text: String)] {
        let base = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else { return [] }
        var out: [(path: String, text: String)] = []
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            guard let body = try? String(contentsOf: base.appendingPathComponent(rel),
                                         encoding: .utf8) else { continue }
            out.append((path: "Sources/\(rel)", text: body))
        }
        return out
    }
}
