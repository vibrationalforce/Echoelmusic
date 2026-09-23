// TheDetectedTuningHasAProducerTests.swift
// Echoel — Phase E. Blocking bundle. MIXED: claims 1–4 are END-TO-END BEHAVIOUR over pure
// statics (`Tests/CISmoke/CLAUDE.md` §1) and claims 5–7 are SOURCE-TEXT SCANS, labelled as
// such at each one. Nothing here is a device probe; no file is decoded and no sound is made.
//
// ⭐ WHY THIS FILE EXISTS. `Core/TuningDetector` and `DSP/PitchTracker` were BOTH orphans —
// pure, unit-tested, zero production callers — and they are the two halves of ONE
// capability: YIN produces exactly the `[Double]` of fundamentals that Krumhansl–Kessler
// key-finding consumes. #C1 wrote that down. This slice supplies the missing middle
// (reading PCM windows out of an imported file) and this guard holds the three things that
// would quietly undo it: the window arithmetic, the non-write rule, and the realtime hop.
//
// ⛔ THE FAILURE MODE THIS WAS WRITTEN AGAINST IS SILENT, WHICH IS WHY CLAIM 2 EXISTS.
// `PitchTracker.detect` computes `tauMax = min(n - 1, Int(sampleRate / minHz))` and REFUSES
// unless `n >= tauMax * 2`. A fixed window literal therefore works at 44.1 kHz and returns
// nil at EVERY position of a high-rate file — no error, no log, just "this file has no
// key". A first draft clamped the window at 16,384 and broke exactly that way above
// ~327 kHz; the clamp is 32,768 because of that measurement, and claim 2 is what stops the
// number drifting back down to a figure that looks generous and is not.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does NOT forbid an "Apply detected key"
// action. V1 deliberately does not write — `SessionContext` stays the one owner of
// `echoel.keyRoot`/`echoel.keyScale`/`echoel.a4Hz` and the user decides — but claim 5 scans
// the ANALYSIS file for session writes, not the app. Wiring an explicit, user-pressed Apply
// elsewhere is correct work and this file stays green for it. What claim 5 forbids is the
// analysis writing by itself, which is the #164/#227 shape: an effect the user cannot see
// the cause of.
//
// ⚠️ HONEST GRADING, AND IT IS GRADED BY MUTATION. No local Swift toolchain (§0), and
// red-on-the-parent-tree is degenerate here because half this file names a type the parent
// does not have — so every claim was instead transcribed into Python, driven against the
// worktree, and then each one attacked with a mutant of the code it protects (#1422 took the
// same route for the same reason). **Twenty assertions across seven claims** — counted with
// `awk '/^final class/,0' <file> | grep -c XCTAssert`, which excludes this header so the note
// is not its own hit (#708). The pure arithmetic was additionally driven over 20,000
// randomised (frameCount, window, maxWindows) triples for the five properties claim 3 names:
// zero violations.
//
// ⛔ NINE MUTANTS WERE DRIVEN AND ONE ESCAPED, WHICH IS THE MOST USEFUL THING IN THIS FILE.
// Removing `isFinite` from `windowFrames(forSampleRate:)` left every claim green, because the
// NaN assertion that was supposed to pin it proves nothing: `Double.nan > 0` is ALREADY false,
// so `guard sampleRate > 0` alone covers NaN. The claim was written in the flattering
// direction and is corrected in place, with the correction kept next to it — INFINITY is what
// that guard protects, and the repaired assertion goes red on the mutant. The other eight
// mutants were caught by the claim named in their commit note.
//
// ⚠️ AND ONE HONESTY NOTE ABOUT CLAIM 6. It proves the hop is WRITTEN, not that it is taken
// (§1 — a source-text scan can never prove execution). Whether the plate actually stays
// responsive while a long file is analysed is [NEEDS-FOUNDER-VERIFY] and is registered at
// the bottom of this file, not claimed here.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheDetectedTuningHasAProducerTests: XCTestCase {

    private static let analysisFile = "Sources/Echoelmusic/Sequencer/AudioKeyAnalysis.swift"
    private static let doorFile = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let detectorFile = "Sources/Echoelmusic/Core/TuningDetector.swift"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    /// Comment-stripped text of one file. `SourceText.codeOnly` is the ONE definition of
    /// "code, not prose" (#453) — this repo writes long ⛔ blocks that name the very symbols
    /// they forbid, and a raw scan would read this slice's own header as a violation.
    private func code(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read — a missing anchor is a "
                    + "finding, not a pass (#454).")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    private func sourcesCode() throws -> String {
        let dir = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: dir.path) else {
            XCTFail("Sources/ is present but not enumerable — re-anchor rather than skip (#454).")
            return ""
        }
        var out = ""
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            let text = try String(contentsOf: dir.appendingPathComponent(rel), encoding: .utf8)
            out += SourceText.codeOnly(text) + "\n"
        }
        guard !out.isEmpty else {
            XCTFail("walked Sources/ and read nothing — the scan found nothing, not nothing wrong.")
            return ""
        }
        return out
    }

    // MARK: - Behaviour

    /// Claim 1 (BEHAVIOUR) — the estimator refuses rather than inventing, and the phrasing
    /// helper refuses with it. This is the property that lets the door stay silent: a nil
    /// summary means NOTHING is appended, so thin evidence can never reach the screen as a
    /// confident sentence.
    func testAThinResultProducesNoSentenceAtAll() {
        XCTAssertNil(TuningDetector().analyze(frequencies: []), """
            `TuningDetector.analyze` answered an EMPTY frequency list. Its nil return is what \
            the import note relies on to stay silent when a file has no pitched material; if \
            it starts guessing, the door will print a key for a drum loop.
            """)

        XCTAssertNil(AudioKeyAnalysis.summarise(nil), """
            `summarise(nil)` produced a sentence. nil in must mean nil out — this is the ONE \
            place the user-facing phrasing lives (#416), and a non-nil answer here would put \
            an estimate on screen that the estimator explicitly declined to make.
            """)
    }

    // MARK: - Uncertainty (#F3)

    /// Equal-tempered frequency for a MIDI note at A4 = 440, so a fixture can be written as
    /// notes rather than as numbers nobody can check by eye.
    private func hz(_ midi: Int) -> Double { 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0) }

    /// Claim 1b (BEHAVIOUR) — material with no tonal centre is reported as HAVING no tonal
    /// centre, instead of being named.
    ///
    /// ⛔ THE DEFECT THIS PINS WAS LIVE AND USER-FACING. `analyze` returns non-nil on ≥8
    /// valid pitches with NO floor on the correlation; `correlation` returns 0 for a flat
    /// histogram; `bestCorr` starts at −2.0 and the first candidate tried is root 0 major.
    /// So one chromatic pass — every pitch class once, i.e. the least tonal input there is —
    /// produced `confidence == 0` and the sentence "Sounds like C major". The named key came
    /// from the ITERATION ORDER, not from the audio, and `confidence` had zero readers in
    /// `Sources/` to stop it.
    func testMaterialWithNoTonalCentreIsNotGivenAKey() throws {
        let chromatic = (60...71).map { hz($0) }
        let tuning = try XCTUnwrap(TuningDetector().analyze(frequencies: chromatic), """
            A chromatic pass no longer produces an estimate at all. That is not a failure of \
            this claim's subject — it means `analyze`'s nil rule changed — but it makes the \
            assertion below vacuous (#343), so re-anchor the fixture rather than deleting it.
            """)
        let sentence = try XCTUnwrap(AudioKeyAnalysis.summarise(tuning))
        XCTAssertFalse(sentence.contains("Sounds like"), """
            A flat pitch-class histogram was given a NAMED key: "\(sentence)" \
            (confidence \(tuning.confidence), margin \(tuning.keyMargin)). There is no key \
            in this material; whichever one is printed came from the order the 24 candidates \
            are tried in. `AudioKeyAnalysis.summarise` must consult \
            `keyConfidenceFloor` before naming anything.
            """)
    }

    /// Claim 1c (BEHAVIOUR) — the case a CONFIDENCE-ONLY gate would have let through, which
    /// is why `keyMargin` exists.
    ///
    /// ⭐ A SINGLE SUSTAINED NOTE SCORES ≈0.68, comfortably above any sane confidence floor,
    /// because one tall bar correlates decently with the profile whose tonic it sits on. But
    /// it correlates EXACTLY as well with the other key built on that same tonic, so the
    /// runner-up ties the winner and the margin is 0. Measured, not assumed: the winner is
    /// then whichever of the two the loop reached first. **A guard written only against
    /// `confidence` would be green here while the sentence was still a coin flip** — that is
    /// the whole argument for the second number, stated where it can fail.
    func testASinglePitchClassIsReportedAsAmbiguousRatherThanNamed() throws {
        let oneNote = [Double](repeating: hz(69), count: 12)   // twelve A4s
        let tuning = try XCTUnwrap(TuningDetector().analyze(frequencies: oneNote), """
            Twelve copies of one pitch no longer produce an estimate. Re-anchor the fixture \
            (#343) — without an estimate the assertion below proves nothing.
            """)
        XCTAssertGreaterThan(tuning.confidence, AudioKeyAnalysis.keyConfidenceFloor, """
            This fixture no longer scores ABOVE the confidence floor (\(tuning.confidence)), \
            so it no longer demonstrates what it was written for: a case a confidence-only \
            gate would pass. The claim below would still hold, but for the wrong reason.
            """)
        let sentence = try XCTUnwrap(AudioKeyAnalysis.summarise(tuning))
        XCTAssertFalse(sentence.contains("Sounds like"), """
            One repeated pitch class was given a NAMED key: "\(sentence)" \
            (confidence \(tuning.confidence), margin \(tuning.keyMargin)). Its two best \
            candidates are tied, so the name is the iteration order again — this time ABOVE \
            the confidence floor. `summarise` must consult `keyMargin`, not only \
            `confidence`.
            """)
    }

    /// Claim 1e (BEHAVIOUR) — WEAK evidence is not named even when ONE key clearly leads.
    /// This is the fixture the OTHER floor cannot catch, and writing the pair is the point:
    /// after claims 1b/1c a reader could reasonably conclude `keyMargin` had made
    /// `keyConfidenceFloor` redundant, because the chromatic run and the repeated pitch are
    /// BOTH tied at the top (margin 0) — the margin branch alone would have rejected both.
    ///
    /// ⚠️ A GATE NO CLAIM CAN FAIL FOR IS NOT A GATE (#367), so the floor needs material that
    /// only it rejects. Eight ADJACENT semitones are it: a cluster has no tonal centre, yet
    /// whichever eight semitones it happens to span lean toward one key by accident, so the
    /// winner leads the runner-up comfortably while correlating weakly with EVERY key. That
    /// lean is an artefact of the span, not evidence about the music — measured here rather
    /// than argued, and it is why "how alone does the winner stand" and "how well does it fit
    /// at all" are two questions and need two numbers.
    func testWeakEvidenceIsNotNamedEvenWhenOneKeyLeads() throws {
        let cluster = [60, 61, 62, 63, 64, 65, 66, 67, 60, 61, 62, 63, 64, 65, 66, 67].map { hz($0) }
        let tuning = try XCTUnwrap(TuningDetector().analyze(frequencies: cluster), """
            A chromatic cluster no longer produces an estimate. Re-anchor the fixture (#343).
            """)
        XCTAssertGreaterThan(tuning.keyMargin, AudioKeyAnalysis.keyMarginFloor, """
            This fixture no longer clears the MARGIN floor (\(tuning.keyMargin)), so it no \
            longer isolates the confidence floor — the claim below would pass through the \
            other branch and `keyConfidenceFloor` would again be pinned by nothing.
            """)
        let sentence = try XCTUnwrap(AudioKeyAnalysis.summarise(tuning))
        XCTAssertFalse(sentence.contains("Sounds like"), """
            A chromatic cluster was given a NAMED key: "\(sentence)" (confidence \
            \(tuning.confidence), margin \(tuning.keyMargin)). The winner leads here, so \
            `keyMargin` is satisfied and cannot save this one — `summarise` must ALSO refuse \
            material that fits no key well. Both floors are load-bearing; neither subsumes \
            the other.
            """)
    }

    /// Claim 1f (BEHAVIOUR) — the CONCERT PITCH half carries its own evidence, and the two
    /// halves are INDEPENDENT. This fixture is the demonstration: twelve exactly-tuned
    /// chromatic semitones have NO tonal centre (`confidence` 0) and a PERFECT tuning
    /// reference (`a4Confidence` 1) — every deviation is zero, so they all point the same
    /// way. A single threshold over both would have thrown the good measurement away to
    /// hide the bad one.
    func testAFileWithNoKeyCanStillHaveATrustworthyTuning() throws {
        let chromatic = (60...71).map { hz($0) }
        let tuning = try XCTUnwrap(TuningDetector().analyze(frequencies: chromatic))
        XCTAssertGreaterThan(tuning.a4Confidence, AudioKeyAnalysis.a4ConfidenceFloor, """
            Exactly-tuned material scored \(tuning.a4Confidence) for concentration, below \
            the floor. Every cents-deviation here is zero, so the resultant length must be \
            1 — a value below the floor means `analyze` is no longer measuring the \
            magnitude of the same sum it takes the angle from.
            """)
        let sentence = try XCTUnwrap(AudioKeyAnalysis.summarise(tuning))
        XCTAssertFalse(sentence.contains("Sounds like"), """
            The key half regressed: "\(sentence)". Claim 1b covers this; if it is also \
            red, fix that one first — this claim is about the TUNING half.
            """)
        XCTAssertTrue(sentence.contains("A4 "), """
            A trustworthy tuning was withheld: "\(sentence)". The key being unknown must \
            not suppress the concert pitch — they are separate facts with separate \
            evidence, and collapsing them is what this claim exists to prevent.
            """)
    }

    /// Claim 1g (BEHAVIOUR) — scattered detuning is NOT given a concert pitch, and the
    /// fixture is the exact failure that motivated the floor.
    ///
    /// ⭐ THE STAKES ARE BRAND, NOT JUST CORRECTNESS. Untuned material measured
    /// a4 = 432.55 Hz in simulation, and `snappedA4`'s 1.5 Hz tolerance SNAPS that to the
    /// 432 Hz preset — so without the floor the instrument announces "A4 ≈ 432 Hz" over
    /// noise it generated the reading from. `CLAUDE.md` bans exactly that claim in
    /// user-facing copy; having the analyser invent it is worse than writing it.
    ///
    /// ⚠️ The fixture is DETERMINISTIC — a fixed spread of cents offsets, not a random
    /// draw. A guard that rolls dice fails intermittently and gets muted (#343).
    ///
    /// ⭐ AND THIS FIXTURE MAKES THE SHARPER POINT THAN THE 432 ONE DOES: its deviations
    /// cancel to a4 ≈ 440.4 Hz, which snaps to 440 — the most PLAUSIBLE answer there is.
    /// Before the floor, the app answered "A4 ≈ 440 Hz" for material with no tuning
    /// reference at all, and nothing about that sentence looks wrong. An invented 432 is
    /// caught by a reader; an invented 440 is not, which is why the gate has to be the
    /// evidence and not the value.
    func testScatteredDetuningIsNotGivenAConcertPitch() throws {
        // Twelve pitches whose cents-deviations are spread evenly around the circle: their
        // vectors cancel, so the mean direction is meaningless and its length is ~0.
        let scattered = (0..<12).map { i -> Double in
            let cents = -50.0 + (100.0 / 12.0) * Double(i)
            return hz(60 + i) * pow(2.0, cents / 1200.0)
        }
        let tuning = try XCTUnwrap(TuningDetector().analyze(frequencies: scattered), """
            Evenly scattered detuning no longer yields an estimate. Re-anchor (#343).
            """)
        XCTAssertLessThan(tuning.a4Confidence, AudioKeyAnalysis.a4ConfidenceFloor, """
            Deviations spread evenly around the circle scored \(tuning.a4Confidence) for \
            concentration — at or above the floor. They cancel by construction, so this \
            means the concentration is not being computed from the same vector sum.
            """)
        let sentence = try XCTUnwrap(AudioKeyAnalysis.summarise(tuning))
        XCTAssertFalse(sentence.contains("A4 "), """
            A concert pitch was reported for material with no tuning reference: \
            "\(sentence)" (concentration \(tuning.a4Confidence), a4 \(tuning.a4Hz)). \
            `summarise` must consult `a4Confidence` before naming a Kammerton — an \
            invented 432 Hz reading is the worst claim this app can make.
            """)
    }

    /// Claim 1h (SOURCE-TEXT SCAN) — the producer WRITES `a4Confidence`, and no call site
    /// may lean on a default, because there is none. This is the counterpart to claim 1d
    /// and it exists for the opposite reason: `runnerUpConfidence` defaults PERMISSIVELY
    /// (a forgetful producer names a key it should not, and the gating claims go red),
    /// while a default here would be RESTRICTIVE — the sentence would quietly stop
    /// reporting a tuning, which no claim would notice. So the init takes it with no
    /// default and a forgetful producer fails to COMPILE. This claim pins that the
    /// declaration stays that way.
    func testTheConcentrationArgumentHasNoDefault() throws {
        let src = try code(Self.detectorFile)
        XCTAssertTrue(src.contains("a4Confidence: Double,"), """
            `DetectedTuning.init` no longer declares `a4Confidence: Double,` without a \
            default. If it gained one, a producer that stops writing the concentration \
            compiles silently and every tuning reading becomes unevidenced (default 0) or \
            unconditionally trusted (default 1) — neither is visible in a diff \
            (#431/#440/#443). Keep it mandatory, or add a claim that asserts the value.
            """)
        XCTAssertFalse(src.contains("a4Confidence: Double = "), """
            `a4Confidence` acquired a default in `Core/TuningDetector.swift`. See above — \
            the asymmetry with `runnerUpConfidence` is deliberate and documented at the \
            init.
            """)
    }

    /// COUNTERWEIGHT (#343) — genuinely tonal material is STILL named. Without this, the two
    /// claims above would pass just as well if `summarise` had been changed to refuse
    /// everything, which would be a worse product than the defect they fix.
    func testTonalMaterialIsStillNamedConfidently() throws {
        // A C-major melody that returns to its tonic — the weighting a real recording has.
        // ⚠️ A UNIFORM C-major SCALE would NOT pass this, and correctly so: C major and A
        // minor contain the identical pitch-class set, so nothing in a histogram can
        // separate them. The tonic emphasis is what makes the key knowable at all.
        let melody = [60, 62, 64, 65, 67, 69, 71, 72, 64, 67, 60, 65, 69, 67, 64, 60].map { hz($0) }
        let tuning = try XCTUnwrap(TuningDetector().analyze(frequencies: melody))
        XCTAssertEqual(tuning.keyRoot, 0, "The C-major fixture no longer resolves to C.")
        XCTAssertFalse(tuning.isMinor, "The C-major fixture resolved to a minor key.")
        let sentence = try XCTUnwrap(AudioKeyAnalysis.summarise(tuning))
        XCTAssertTrue(sentence.contains("Sounds like C major"), """
            Clearly tonal material is no longer named: "\(sentence)" \
            (confidence \(tuning.confidence), margin \(tuning.keyMargin)). The floors are \
            meant to remove a false claim, not the feature — if they now reject real music, \
            they are set wrong.
            """)
    }

    /// Claim 1d (BEHAVIOUR) — the producer WRITES the runner-up. `runnerUpConfidence` carries
    /// a default so the memberwise init stays source-compatible, and a defaulted value no
    /// production site writes is invisible in a diff (#431/#440/#443). This is the assertion
    /// that makes the default safe.
    func testTheEstimatorReportsTheRunnerUpAndNotJustTheWinner() throws {
        let melody = [60, 62, 64, 65, 67, 69, 71, 72, 64, 67, 60, 65, 69, 67, 64, 60].map { hz($0) }
        let tuning = try XCTUnwrap(TuningDetector().analyze(frequencies: melody))
        XCTAssertGreaterThan(tuning.runnerUpConfidence, 0, """
            `analyze` returned `runnerUpConfidence == \(tuning.runnerUpConfidence)` on \
            clearly tonal material. Twenty-four candidates are scored, so a runner-up always \
            exists; a zero here means the producer stopped writing the field and every \
            `keyMargin` in the app silently became the full confidence — the permissive \
            direction, which no sentence would reveal.
            """)
        XCTAssertEqual(tuning.keyMargin,
                       tuning.confidence - tuning.runnerUpConfidence, accuracy: 1e-12, """
            `keyMargin` is no longer the gap between the two reported numbers. It is the ONE \
            ambiguity measure (#416); a second definition would let the gate and the report \
            disagree.
            """)
    }

    /// Claim 2 (BEHAVIOUR) — the window satisfies `PitchTracker`'s own precondition at every
    /// sample rate a file can carry. THE CATCH THIS GUARDS IS SILENT: violating it returns
    /// nil from every window instead of failing.
    func testTheWindowSatisfiesTheDetectorsPreconditionAtEveryRealSampleRate() {
        let rates: [Double] = [8_000, 22_050, 44_100, 48_000, 88_200, 96_000,
                               176_400, 192_000, 352_800, 384_000, 768_000]
        for rate in rates {
            let n = AudioKeyAnalysis.windowFrames(forSampleRate: rate)
            // Transcribed from `PitchTracker.detect`, deliberately rather than imported:
            // if that computation changes, this claim must go red and be re-derived (#416
            // does not apply — a copy that is CHECKED against the original is the point).
            let tauMax = Swift.min(n - 1, Int(rate / AudioKeyAnalysis.minHz))
            XCTAssertGreaterThanOrEqual(n, tauMax * 2, """
                At \(Int(rate)) Hz the analysis window is \(n) frames but `PitchTracker` needs \
                at least \(tauMax * 2). EVERY window of such a file would return nil and the \
                file would silently appear to have no key. If the clamp in \
                `windowFrames(forSampleRate:)` was lowered, raise it back: a clamp that turns \
                a precondition into a silent nil is not a safety margin.
                """)
        }
    }

    /// Claim 3 (BEHAVIOUR) — the five properties of the read plan, including the one that is
    /// a CORRECTNESS property and not an efficiency one: the windows must not overlap,
    /// because the output feeds a pitch-class histogram and re-reading audio would weight
    /// whatever note is there twice.
    func testTheReadPlanIsBoundedOrderedAndNonOverlapping() {
        let window = 2048
        let maxWindows = 64

        XCTAssertTrue(AudioKeyAnalysis.windowStarts(frameCount: Int64(window) - 1,
                                                    windowFrames: window,
                                                    maxWindows: maxWindows).isEmpty, """
            A file SHORTER than one window produced windows to read. It must produce none, so \
            that "too short" and "no pitched material" both arrive at the caller as the same \
            nil rather than as a short read.
            """)

        XCTAssertEqual(AudioKeyAnalysis.windowStarts(frameCount: Int64(window),
                                                     windowFrames: window,
                                                     maxWindows: maxWindows), [0], """
            A file of EXACTLY one window must be read exactly once, at 0.
            """)

        // ⛔ THIS ARRAY CARRIED NO TYPE ANNOTATION AND THE BUILD DIED ON IT (#E2).
        // Mixing ONE conversion expression (`Int64(window) * 2`) with bare integer
        // literals let inference collapse the literal to `[Any]`, so `frameCount` was
        // `Any` and three errors followed from one root cause (#689). The §0
        // transcription could not see it: it grades what a needle SAYS, never what
        // the Swift around it type-checks to. Annotate the collection.
        let frameCounts: [Int64] = [Int64(window) * 2, 100_000, 5_000_000, 44_100 * 600]
        let windowFrames = Int64(window)
        for frameCount in frameCounts {
            let starts = AudioKeyAnalysis.windowStarts(frameCount: frameCount,
                                                       windowFrames: window,
                                                       maxWindows: maxWindows)
            XCTAssertLessThanOrEqual(starts.count, maxWindows, """
                \(frameCount) frames produced \(starts.count) windows, above the cap of \
                \(maxWindows). The cap bounds BOTH the bytes read and the YIN work — it is \
                the difference between a second of analysis and an unbounded read of a \
                two-hour file.
                """)
            XCTAssertEqual(starts, starts.sorted(), "window starts must ascend (\(frameCount)).")
            XCTAssertEqual(starts.count, Set(starts).count,
                           "window starts must be distinct (\(frameCount)).")
            if let last = starts.last {
                XCTAssertLessThanOrEqual(last + windowFrames, frameCount, """
                    The last window of a \(frameCount)-frame file starts at \(last) and would \
                    read past the end.
                    """)
            }
            let overlapping: [(Int64, Int64)] = zip(starts, starts.dropFirst())
                .filter { (pair: (Int64, Int64)) in pair.1 - pair.0 < windowFrames }
            XCTAssertTrue(overlapping.isEmpty, """
                Windows OVERLAP at \(frameCount) frames: \(overlapping.prefix(3)). This is a \
                correctness defect, not a performance one — the fundamentals feed a \
                pitch-class histogram, so audio read twice is counted twice and the key \
                estimate is biased toward whatever happens to sit in the overlap.
                """)
        }
    }

    /// Claim 4 (BEHAVIOUR, COUNTERWEIGHT #343) — the degenerate arguments are answered rather
    /// than trapped. Without this, claims 1–3 would all be satisfiable by a function that
    /// crashes on a zero.
    func testTheDegenerateArgumentsAreAnsweredNotTrapped() {
        XCTAssertTrue(AudioKeyAnalysis.windowStarts(frameCount: 0, windowFrames: 0,
                                                    maxWindows: 0).isEmpty,
                      "zero window / zero cap must answer with no work, not divide or trap.")
        XCTAssertEqual(AudioKeyAnalysis.windowFrames(forSampleRate: 0), 2048,
                       "a zero sample rate must fall back rather than size an allocation from it.")
        XCTAssertEqual(AudioKeyAnalysis.windowFrames(forSampleRate: .nan), 2048, """
            A NaN sample rate must fall back to the default window.
            """)

        // ⛔ THE NaN LINE ABOVE DOES NOT PROVE THE `isFinite` GUARD, AND AN EARLIER DRAFT OF
        //    THIS FILE SAID IT DID. A mutation drive removed `isFinite` from
        //    `windowFrames(forSampleRate:)` and the NaN assertion stayed GREEN — because
        //    `Double.nan > 0` is already false, so `guard sampleRate > 0` alone handles NaN
        //    here. The claim was graded in the flattering direction (§3) and is corrected in
        //    place rather than quietly fixed. INFINITY is what `isFinite` actually protects:
        //    `Double.infinity > 0` is TRUE, so without the guard the next line evaluates
        //    `Int(.infinity / minHz)`, which TRAPS. This assertion therefore goes red — by
        //    crashing rather than failing — if the guard is removed, which is the discrimination
        //    the NaN line only appeared to provide.
        XCTAssertEqual(AudioKeyAnalysis.windowFrames(forSampleRate: .infinity), 2048, """
            An INFINITE sample rate must fall back. If `isFinite` was dropped from the guard, \
            this does not merely return the wrong number — `Int(Double.infinity / 50)` traps, \
            and a decoder reporting a nonsense rate would crash the analysis rather than \
            decline it.
            """)
    }

    // MARK: - Source-text scans (they prove where code sits, never that it runs)

    /// Claim 5 (SOURCE-TEXT SCAN — CATCH) — the analysis does not write the session's key.
    /// `SessionContext` is the one owner; detection reports and the user decides.
    func testTheAnalysisNeverWritesTheSessionKey() throws {
        let analysis = try code(Self.analysisFile)
        for forbidden in ["SessionContext", "keyRoot", "keyScale", "a4Hz ="] {
            XCTAssertFalse(analysis.contains(forbidden), """
                \(Self.analysisFile) now mentions `\(forbidden)` in CODE. The analysis must not \
                author the song's key: `SessionContext` owns it, and an import that silently \
                re-keyed the session would change what the generative engine plays with \
                nothing on screen saying why (#164/#227). An explicit, user-pressed "Apply \
                detected key" elsewhere is correct work and is NOT what this forbids (#364) — \
                the rule is scoped to this file.
                """)
        }
    }

    /// Claim 6 (SOURCE-TEXT SCAN — CATCH) — the expensive call is written behind a hop off
    /// the main actor, and is not folded into the synchronous `@MainActor` import.
    func testTheExpensiveAnalysisIsWrittenOffTheMainActor() throws {
        let door = try code(Self.doorFile)
        XCTAssertTrue(door.contains("Task.detached"), """
            The Workstation door calls the analysis without a `Task.detached` hop. \
            `AudioKeyAnalysis.analyse` is seconds of YIN; running it on the main actor freezes \
            the plate at the moment the user is watching it — the 10.76.48 lesson in bulk \
            form. NOTE what this claim does and does not prove (§1): it proves the hop is \
            WRITTEN, never that it is taken.
            """)

        let importer = try code(Self.analysisFile)
        XCTAssertFalse(importer.contains("@MainActor"), """
            `AudioKeyAnalysis` acquired a `@MainActor` annotation. It must stay non-isolated \
            so its caller can run it anywhere; isolating it to the main actor would make every \
            call site the freeze this slice was shaped to avoid.
            """)

        let audioImport = try code("Sources/Echoelmusic/Sequencer/AudioImport.swift")
        XCTAssertFalse(audioImport.contains("AudioKeyAnalysis"), """
            `AudioImport` now calls the analysis. `AudioImport.perform` is `@MainActor` AND \
            synchronous — folding YIN into the import transaction is precisely the freeze. If \
            the import should trigger analysis, it does so the way the door does: by handing \
            a URL to something that hops first.
            """)
    }

    /// Claim 7 (SOURCE-TEXT SCAN — CATCH) — no SECOND estimator was minted. #C1 recorded that
    /// the value already exists; the whole point of this slice was to supply the producer.
    func testNoSecondEstimatorWasMinted() throws {
        let all = try sourcesCode()
        for declaration in ["struct DetectedTuning", "struct TuningDetector", "enum PitchTracker"] {
            let count = all.components(separatedBy: declaration).count - 1
            XCTAssertEqual(count, 1, """
                `\(declaration)` is declared \(count)× in Sources/. Exactly one is the point: \
                #C1 measured that the key/tuning value and both estimators already existed and \
                only lacked a producer, and the expensive mistake this slice was written to \
                prevent is someone building a parallel one beside them (#416).
                """)
        }

        XCTAssertTrue(try code(Self.detectorFile).contains("public struct DetectedTuning"), """
            `DetectedTuning` left \(Self.detectorFile). Say where it went — this file, \
            `AudioKeyAnalysis` and CLAUDE.md's orphan register all name that location.
            """)
    }
}

// NEEDS-FOUNDER-VERIFY (Phase E): (1) import a real track on the device and say whether the
// detected key and Kammerton are RIGHT — no test in this repo can judge that, and claim 1 only
// proves the estimator refuses when it has nothing. (2) Say whether the plate stays responsive
// while a long file is analysed; claim 6 proves the hop is written, not that it is taken.
// (3) Say whether "Sounds like …" reads as a suggestion rather than a claim — if it reads as a
// claim, the wording is the fix, not the estimator.
