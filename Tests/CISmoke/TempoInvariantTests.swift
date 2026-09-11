// TempoInvariantTests.swift
// Echoel — #565. The T1–T3 tempo invariant, ratified 2026-08-13, made executable.
//
// WHY THE RULING EXISTED. `BioComposer.tempo(for:)` under `.flowFree` computes
// `min(max(hr, 40), 160)` — the clock follows the pulse, clamped (#1271; the coherence
// blend it used to carry was removed by founder decision 2026-09-11)
// as self-regulation rises. That is shipped, device-approved (decisions 2026-06-22, refined
// 07-03/07-04), and it flatly contradicted a doctrine line banning HR→tempo outright. An
// invariant the shipped product violates is not an invariant; it is a trap for every later
// session, which will either "fix" working audio or quietly learn to ignore the doctrine.
// The ruling keeps the servo and makes the rule precise:
//   T1 — tempo sources are ENUMERABLE and LOGGED (user | flowServo | automation).
//   T2 — raw heart rate never reaches the clock except through the servo or a user gesture;
//        `.studioLocked` is provably independent of `heartRateBPM`.
//   T3 — the TESTS are the invariant. Prose that contradicts a green test is stale prose.
// This file is the T3 half. It is why the doctrine may now be believed.
//
// ⭐ THE ENGINE IS THE CHOKEPOINT, AND CLAIM 4 IS WHY THE OTHER CLAIMS COVER THE APP.
// Measured while writing this: every `transport?.setTempo(…)` in `Sources/` is inside
// `PatternEngine.swift`, so `Transport.setTempo` has no production caller of its own. Naming
// the source on the two `PatternEngine` methods therefore names it for every production path
// to the clock — and `Transport.setTempo` stays a pure relay, which matters because three of
// those six relay sites fire per TICK while a glide eases. Putting `source:` on the relay
// would have forced the audio-rate path to restate something it cannot know, and a breadcrumb
// there would log at 20 Hz. Claim 4 pins the premise so that reasoning cannot rot in silence.
//
// ⚠️ THE LIMIT, PER ASSERTION:
//   · claims 1–3 are END-TO-END BEHAVIOUR. `BioComposer.tempo(for:)` is a pure static over a
//     public `Sendable` struct, and `PatternEngine` is constructed directly (the ungated
//     relay tests already do). These drive shipped code, not a description of it.
//   · claims 4–5 are SOURCE-TEXT SCANS, and they are about SHAPE, which no behaviour can
//     reach: "no other file talks to the relay" and "the parameter has no default" are
//     statements about the call graph and the signature, not about a value.
//   · DEVICE PROBE, open: whether `tempoSource=` actually appears on Flow, Loop, tap,
//     glide-lock and loopExport in a real device log. That is the founder's C1 acceptance
//     line and nothing here can stand in for it.
//
// ⚠️ HONEST GRADING, transcribed in Python against the parent (`1df43ac`) and this tree.
// The file does NOT compile against the parent — `PatternEngine.TempoSource` does not exist
// there and claims 3–5 name it — so per §3 no assertion has a verdict on that tree and the
// grading is by hand-transcription of the LOGIC, stated as such rather than implied green:
//   · claims 1 and 2 are COUNTERWEIGHTS and would be green on both trees. They are the point
//     of the file, not padding (#343): the ruling KEPT the servo, so the guard's first job is
//     to pin what the servo does — clamp 40…160, ignore coherence, and never let `.studioLocked`
//     read the heart. A future "simplification" that made Flow follow raw HR passes every T1
//     scan below and fails claim 2.
//   · claims 3–5 are FORWARD guards over shape this same commit creates. Booking them as
//     regressions would be the flattering direction (#433); they can only start earning from
//     the next commit onward, and claim 5 is the one that earns most — a `= .unspecified`
//     default added later is invisible in every diff that matters (#431/#440/#443).
//   · ONE ABSENCE, REPORTED ONCE (#486): `TempoSource` missing on the parent is a single
//     fact, not five findings.
//   · STRIPPER: load-bearing in ONE direction and measured, not assumed. Claim 4 counts
//     `transport?.setTempo(` across `Sources/`; raw, `MIDIOutput.swift:338` matches inside a
//     DOC COMMENT that quotes the call ("relays `transport?.setTempo(tempo)` on EVERY tick"),
//     so RAW the scan finds 2 files (`MIDIOutput.swift`, `PatternEngine.swift`) and STRIPPED
//     it finds 1. **TRAGEND, 2 of 2 verdicts flip** — claim 4 is one assertion and it flips on
//     BOTH trees, because the parent carries the same doc comment and the same relay sites.
//     (My draft wrote "1 of 2" from counting the tree I was standing in; the run counts both.)
//     Without `SourceText.codeOnly` this guard would report a second file talking to the relay
//     and go red on a correct tree — #367 in its exact prototype form.
//   · claims 1 and 2 driven numerically against the shipped formula: locked 124 is identical
//     across {40, 55, 71, 100, 121, 190} bpm × {0, 0.5, 1} coherence; flow gives exactly 40 at
//     20 bpm, exactly 160 at 200 bpm, and the pulse itself in between, at EVERY coherence.

import Foundation
import XCTest
@testable import Echoelmusic

final class TempoInvariantTests: XCTestCase {

    private static let engine = "Sources/Echoelmusic/Sequencer/PatternEngine.swift"

    /// One Input, varied only where a claim varies it. `.disco` is a style with a wide tempo
    /// window and no sustained-Fläche special-casing, so nothing here depends on genre logic
    /// — the flow branch ignores `style` entirely and the locked branch only clamps into it.
    private func input(mode: ComposerMode, hr: Float, coherence: Float,
                       locked: Double) -> BioComposer.Input {
        BioComposer.Input(heartRateBPM: hr, hrvNormalized: 0.5, coherence: coherence,
                          breathPhase: 0.25, breathDepth: 0.5,
                          key: MusicalKey(root: 0, scale: .minor),
                          style: .disco, mode: mode, lockedTempo: locked,
                          seed: 0xC10C)
    }

    // MARK: - claim 1 (END-TO-END, T2) — a locked take cannot hear the heart

    /// ⛔ THE RULING'S OWN DRAFT OF THIS CASE ASSERTED `t == 124` AND THAT IS NOT THE
    /// INVARIANT. `tempo(for:)`'s locked branch returns
    /// `min(max(lockedTempo, style.tempoRange.lowerBound), style.tempoRange.upperBound)`, so a
    /// literal expectation is really a claim about the STYLE's window — it would go red the
    /// day someone re-tunes a genre's range, for a reason that has nothing to do with heart
    /// rate. What T2 actually says is INDEPENDENCE, so independence is what is driven: every
    /// heart rate from bradycardia to tachycardia must yield the identical number.
    func testStudioLockedIsIndependentOfHeartRate() {
        let reference = BioComposer.tempo(for: input(mode: .studioLocked, hr: 71,
                                                     coherence: 0, locked: 124))
        for hr: Float in [40, 55, 71, 100, 121, 190] {
            for coherence: Float in [0, 0.5, 1] {
                let t = BioComposer.tempo(for: input(mode: .studioLocked, hr: hr,
                                                     coherence: coherence, locked: 124))
                XCTAssertEqual(t, reference, accuracy: 1e-9, """
                    A locked take returned \(t) at \(hr) bpm / coherence \(coherence) but \
                    \(reference) at 71 bpm. `.studioLocked` is the mode a player chooses to \
                    make the clock THEIRS; if the body can move it at all, the lock is a \
                    label rather than a lock (T2).
                    """)
            }
        }
    }

    // MARK: - claim 2 (END-TO-END, T2) — Flow follows the pulse, clamped, and nothing else

    /// ⭐ #1271 REPLACES THIS CLAIM'S OTHER HALF, by founder decision 2026-09-11: "Es soll
    /// ganz einfach entweder direkt an die Herzrate gekoppelt sein oder man stellt sie selbst
    /// ein." What stood here asserted the OPPOSITE of what ships now — that at full coherence
    /// the tempo forgets the heart entirely and converges on 72. A guard that forbids the
    /// shipped, founder-chosen behaviour is itself the defect (#364), so it is rewritten
    /// rather than deleted, and the replacement is STRICTLY STRONGER: the old form pinned two
    /// sample points of a blend, this one pins that coherence cannot move the clock at all.
    ///
    /// ⛔ AND T2 IS NOT WEAKENED BY IT. The ban was on "dein Herzschlag IST der Beat" — the
    /// raw signal, 1:1, trembling with every artefact. Four mechanisms downstream of this
    /// function still prevent exactly that, none of them changed: `bodyTempoTrustworthy` (a
    /// unsettled reading moves nothing), the octave fold into the genre window, the
    /// ±`tempoConvergeStep` cap per evolve tick, and `glideTempo`'s ~2 s ease.
    func testFlowFollowsThePulseAndIsClamped() {
        let slow = BioComposer.tempo(for: input(mode: .flowFree, hr: 20, coherence: 0,
                                                locked: 0))
        XCTAssertEqual(slow, 40, accuracy: 1e-9, """
            An implausibly slow pulse produced \(slow) bpm. The floor is what stops a failing \
            rPPG estimate from dragging the take to a halt; without it the WORST bio signal \
            has the LARGEST effect on the music.
            """)
        let fast = BioComposer.tempo(for: input(mode: .flowFree, hr: 200, coherence: 0,
                                                locked: 0))
        XCTAssertEqual(fast, 160, accuracy: 1e-9,
                       "an implausibly fast pulse produced \(fast) bpm — the ceiling is gone")

        // Inside the window the tempo IS the pulse. This is the founder's "direkt an die
        // Herzrate gekoppelt", stated as the equality it is.
        for hr: Float in [41, 55, 72, 100, 159] {
            let t = BioComposer.tempo(for: input(mode: .flowFree, hr: hr, coherence: 0,
                                                 locked: 0))
            XCTAssertEqual(t, Double(hr), accuracy: 1e-9, """
                A \(hr) bpm body inside the window produced \(t). In Flow the suggested tempo \
                IS the pulse; anything else is a second mapping nobody asked for.
                """)
        }
    }

    /// claim 2b (THE COMPLAINT, as an invariant) — coherence must not move the Flow clock.
    ///
    /// ⭐ THIS IS THE ONE THAT WOULD HAVE CAUGHT THE SYMPTOM. Coherence is a live measurement
    /// that drifts, so while it was a term in the tempo the TARGET drifted with it — and the
    /// target does not reach the clock directly: `EchoelStudioView` folds it octave-wise into
    /// the genre's window, and a fold amplifies a small input change into a large output one
    /// whenever it crosses a boundary. Founder 2026-09-11: "Mich irritiert die BPM die
    /// manchmal hakelt." A wandering coherence was a wandering beat.
    func testCoherenceDoesNotMoveTheFlowTempo() {
        for hr: Float in [48, 66, 88, 132] {
            let at0 = BioComposer.tempo(for: input(mode: .flowFree, hr: hr, coherence: 0,
                                                   locked: 0))
            for coherence: Float in [0.25, 0.5, 0.75, 1] {
                let t = BioComposer.tempo(for: input(mode: .flowFree, hr: hr,
                                                     coherence: coherence, locked: 0))
                XCTAssertEqual(t, at0, accuracy: 1e-9, """
                    At \(hr) bpm the tempo moved from \(at0) to \(t) when coherence went to \
                    \(coherence). Coherence is a drifting live measurement; a term of it in \
                    the tempo makes the beat wander on its own. It still shapes density, \
                    harmony and timbre — it must not shape the clock.
                    """)
            }
        }
    }

    /// claim 2c (THE FALLBACK) — no reading at all is a musical default, not the clamp floor.
    /// Before #1271 an absent pulse blended 0 bpm with the resonance band and clamped, which
    /// at neutral coherence produced 40 — the slowest tempo the instrument can run, chosen by
    /// the ABSENCE of information.
    func testAnAbsentPulseFallsBackToTheResonanceBand() {
        let t = BioComposer.tempo(for: input(mode: .flowFree, hr: 0, coherence: 0.5,
                                             locked: 0))
        XCTAssertEqual(t, BioComposer.resonancePulseBPM, accuracy: 1e-9, """
            With no pulse the tempo was \(t), not `resonancePulseBPM` \
            (\(BioComposer.resonancePulseBPM)). An absent reading must not pick the extreme \
            end of the range — the callers hold the previous tempo anyway, and this value is \
            what a first take gets before anything is measured.
            """)
    }

    // MARK: - claim 3 (END-TO-END, T1) — the engine records who moved the clock

    @MainActor
    func testEveryTempoDecisionNamesItsSource() {
        let pattern = PatternEngine()
        XCTAssertEqual(pattern.lastTempoSource, .unspecified, """
            A fresh engine already claims a tempo source. `.unspecified` before anything has \
            moved the clock is what makes a device log readable: the first named source is \
            the first real decision.
            """)
        pattern.setTempo(128, source: .user)
        XCTAssertEqual(pattern.lastTempoSource, .user,
                       "an explicit edit did not record `.user`")
        pattern.glideTempo(to: 96, source: .flowServo)
        XCTAssertEqual(pattern.lastTempoSource, .flowServo, """
            A glide did not record its source. `glideTempo` is the path `BodyTempoField`'s \
            lock toggle and the generate re-seed both take, so a source that only tracked \
            `setTempo` would miss the two decisions a player makes most often.
            """)
        pattern.setTempo(140, source: .automation)
        XCTAssertEqual(pattern.lastTempoSource, .automation)
        // Hoisted out of the message: a key-path closure inside a `\(…)` inside a multi-line
        // literal is the shape that made the blocking gate red on #287.
        let names = PatternEngine.TempoSource.allCases.map { $0.rawValue }.joined(separator: ", ")
        XCTAssertEqual(PatternEngine.TempoSource.allCases.count, 6, """
            The source list changed size. That is legitimate work — the ruling enumerated \
            three, the code needed a fourth for the modulation route and a fifth for the OSC \
            control cue (#1255, locked mode only) — but it must be a DECISION: add the case, say \
            what path writes it, and move this number with it. Sources today: \(names).
            """)
        XCTAssertTrue(PatternEngine.TempoSource.allCases.contains(.remoteControl),
                      "the OSC control cue lost its own name in the transport log (#1255)")
    }

    // MARK: - claim 3b (SOURCE SCAN, T1 (a)) — a locked generate() names the player, not the servo

    /// #1217 (audit 2026-09-10 `sequencer-core-1`). `generate()` resolves `tempo` to `lockedBPM`
    /// under the lock and then glided it with `source: .flowServo`, unconditionally — so the
    /// one log line T1 exists for named the servo for a number a human typed. `generate()` is
    /// a view method that cannot be driven here without the whole studio, so this is a scan:
    /// the glide next to the `let tempo` switch must choose its source by the lock.
    func testALockedGenerateNamesThePlayerAsTheTempoSource() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path),
                          "Sources/ not present in this checkout")
        let studio = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
        XCTAssertTrue(studio.contains("glideTempo(to: tempo, source: lockBPM ? .user : .flowServo)"), """
            generate()'s tempo glide no longer chooses its source by the lock. Under `lockBPM` \
            the number is the player's (T1 (a)); logging it as `.flowServo` puts a false word \
            into the line T1 exists for (#1217).
            """)
        XCTAssertFalse(studio.contains("glideTempo(to: tempo, source: .flowServo)"), """
            The unconditional `.flowServo` glide is back in generate() (#1217).
            """)
    }

    // MARK: - claim 4 (SOURCE SCAN, COUNTERWEIGHT) — the engine really is the only door

    /// Without this, claims 1–3 guard one door in a wall that may have others. If a second
    /// file learns to call `Transport.setTempo` directly, that path reaches the clock without
    /// ever naming a source and T1 is quietly false while every assertion above stays green.
    func testNothingOutsideTheEngineTalksToTheTransportRelay() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path),
                          "Sources/ not present in this checkout")
        var callers: [String] = []
        guard let walker = FileManager.default.enumerator(at: sources,
                                                          includingPropertiesForKeys: nil) else {
            return XCTFail("could not walk Sources/ — re-anchor this scan rather than skip (#454)")
        }
        for case let url as URL in walker where url.pathExtension == "swift" {
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if code.contains("transport?.setTempo(") || code.contains("transport.setTempo(") {
                callers.append(url.lastPathComponent)
            }
        }
        XCTAssertEqual(callers.sorted(), ["PatternEngine.swift"], """
            `Transport.setTempo` is reached from \(callers.sorted()). It must be reached only \
            from `PatternEngine`, which is where a source is named — a direct caller \
            elsewhere moves the clock anonymously and T1 becomes untrue without any assertion \
            here noticing. Either route the new path through `PatternEngine.setTempo(_:source:)` \
            or give `Transport.setTempo` a `source:` of its own AND accept that the per-tick \
            glide relay must then restate it.
            """)
    }

    // MARK: - claim 5 (SOURCE SCAN, COUNTERWEIGHT) — the parameter may never get a default

    /// The regression the compiler cannot catch. `source:` is required so that adding a new
    /// clock-reaching call site is impossible without deciding what it is; the moment someone
    /// writes `source: TempoSource = .unspecified` to silence a build error, every future path
    /// names itself "unspecified" and the log goes back to saying nothing — and that edit
    /// appears in no diff anyone reviews (#431/#440/#443).
    func testTheSourceParameterHasNoDefault() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(Self.engine)
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path),
                          "Sources/ not present in this checkout")
        let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
        for signature in ["public func setTempo(_ bpm: Double, source: TempoSource)",
                          "public func glideTempo(to bpm: Double, source: TempoSource)"] {
            XCTAssertTrue(code.contains(signature), """
                `\(signature)` is not in \(Self.engine). Either the signature changed — in \
                which case re-anchor here in the same commit (#454) — or `source:` acquired a \
                default value, which is the one edit that makes T1 stop working while every \
                call site still compiles.
                """)
        }
    }
}
