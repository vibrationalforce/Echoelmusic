// ANonFiniteControlCannotReachTheRenderTests.swift
// Echoel — a NaN at a control boundary must fail quiet, never trap or latch silence. #588.
//
// WHAT THIS GUARDS. Two control boundaries clamped with `Swift.min(Swift.max(v, lo), hi)` —
// the idiom this repo's own CLAUDE.md law names as NaN-transparent (`max(NaN, 0)` is NaN;
// argument order decides). Both sit on the render path:
//
//   · `EchoelDelay.processStereo` — `fb` multiplies the delay-line WRITE-BACK, so one NaN frame
//     poisons the entire line and only `reset()` heals it: the shipped permanent-silence class
//     (`AudioOutputGuard` mutes the output; the line stays poisoned underneath).
//   · `SamplerVoice`'s render state — `configurePlayback` stored the raw fraction, and the render
//     block computes `Int(startFrac * Float(count))`, where `Int(Float.nan)` is a Swift TRAP.
//     Not silence: a CRASH, on the audio thread.
//
// ⚠️ "Two" is the ORIGINAL scope of this file, kept as written rather than rewritten each time —
// the boundaries added since are named in their own test docs and counted in GRADING below. The
// heading stays honest only because that count is maintained; if you add a ninth, move the
// count, not this sentence (#818: a number in prose is a date, not a fact).
//
// ⛔ AND THE DELAY ONE OUTLIVED ITS OWN DIAGNOSIS BY A MONTH, which is the part worth a guard.
// The `spread` line in the same function was switched to the NaN-safe `clamped(to:)` earlier,
// and the comment beside it said, in effect: the two lines above are still unsafe, but fixing
// them is "a separate change with its own audible surface". That second half was WRONG — for
// finite inputs `clamped(to:)` and `min(max(…))` are bit-identical, so there was no audible
// surface to fear — and the caution kept the more dangerous half of the defect (the write-back
// multiplier) alive while sitting three lines under its cure. A stale caution that overstates
// the cost of a repair is how a known hole outlives its diagnosis.
//
// Both are LATENT: no shipped producer emits NaN into these fields today. They are closed on
// engineering.md's boundary rule — non-finite at a DSP/bio boundary is an edge case, not an
// impossibility — and because both failure modes (permanent silence; an audio-thread trap) are
// the two worst outcomes this codebase knows.
//
// ⚠️ HONEST LIMITS.
//   · 22 tests, 48 assertion statements (`grep -c '^    func test'` and `grep -c XCTAssert`,
//     measured 2026-09-10; several run inside loops or over 3 000–4 000-sample arrays).
//     Tests 1–3 are END-TO-END BEHAVIOUR on the
//     shipped `EchoelDelay` — real instance, real frames, NaN in the control fields. Tests 4–5
//     are SOURCE-TEXT SCANS for `SamplerVoice`: driving its render block needs installed sample
//     slabs and trigger plumbing, which a smoke test should not fake; the setter is the ONLY
//     writer of all three fields, so pinning the setter's sanitization pins the render's input.
//   · NOT covered: a NaN in the AUDIO INPUT samples (as opposed to control fields) still writes
//     into the delay line — that is a different boundary with a real cost per frame, owned by
//     the sanitize-at-the-boundary pattern in `applyBioReactive`, not by this slice.
//
// ⭐ THE REST OF THIS CLASS IS SWEPT AND CLEAN — a NEGATIVE, measured 2026-09-09 (#1179),
// recorded so nobody re-runs the sweep and nobody "fixes" twenty-six call sites at once.
//
//   grep -rnE 'Int\(.*(sampleRate|rate|scale|sr)\b' Sources/Echoelmusic/DSP/*.swift   ->  26
//
// Every one of those conversions can trap the same way #1171 and #1172 did (`Int(nan)`,
// `Int(inf)` and `Int(overflow)` are all Swift TRAPS, and `Swift.max(1, Int(x))` does NOT
// save you — the clamp runs AFTER the conversion). Followed to their callers, none is
// reachable today:
//
//   · EchoelReverb  — exactly ONE production construction site, in `EchoelFXChain`, whose
//     rate #1172 sanitises with a CEILING before handing it on.
//   · EchoelDDSP's envelope conversions  — one production site,
//     `BioReactiveSynthVoice.swift:299`, and it passes `Float(Self.sampleRate)` where that is
//     `private static let sampleRate: Double = 48_000`. A constant, not a runtime value.
//   · EchoelLoudnessMeter  — one external site (`AudioEngine`), behind
//     `if meterFormat.sampleRate > 0 && meterFormat.channelCount > 0`.
//   · PitchTracker  — `guard sampleRate > 0, maxHz > minHz, minHz > 0 else { return nil }`,
//     and its one call site guards `monitorTapSampleRate > 0` again.
//   · EchoelSpaceReverb, EchoelModalBank, EchoelWSOLA  — zero production construction sites.
//
// ⛔ THE FIRST DRAFT OF THE LIST ABOVE PUT `EchoelSpaceReverb` IN THE FIRST BULLET, i.e.
// claimed the FX chain protects it. It does not construct it at all: `git grep -c` finds zero
// production sites and one test. Written from the shape of the neighbouring names rather than
// measured — the #867 defect ("whoever claims a NEIGHBOUR in a register line has to measure the
// neighbour"), caught here only because the numbers were re-run before the commit. `EchoelDDSP`
// was mis-grouped in the same sentence for the same reason and is now stated from its own site.
//
// ⭐ #1195'S OWN SWEEP, RECORDED SO NOBODY RE-RUNS IT. `Sequencer/` + `Bio/`, the two
// directories #1179 and #1181 did not cover, searched for the same `Int(x * rate)` shape:
// TEN hits, and only the one this slice repairs was open on a live path.
//
//   · `WarpedClipPlan` (3 hits)  — guards `engineSampleRate > 0, .isFinite` itself, AND has
//     zero production construction sites.
//   · `SamplerVoice:90`          — `srcFormat.sampleRate` off an `AVAudioFormat`, which
//     cannot be non-finite or non-positive.
//   · `TimelineAudioSink:92`     — a millis conversion of an already-sanitised rate.
//   · `AudioRegionPlayback` (2)  — `guard sampleRate > 0` ONLY, so `+inf` reaches
//     `Int(_:)`. NOT repaired here and that is deliberate: both are doorless
//     (`startFrame` has zero callers, `frameCount` only a COMMENT mention — the #527
//     audio-lane layer), and one Ralph slice repairs one thing. If a producer for that
//     layer ever returns, these two are the first stop.
//   · `Bio/BioEventGraph:97,100` — `Int(0.3 * sampleRate)` with NO guard at all, and the
//     initialiser stores the raw rate. REPORT ONLY: the Rausch triad is READ-ONLY without
//     explicit founder approval (CLAUDE.md). Its one production construction passes a
//     constant, so it is closed by its caller, not by itself.
//
// ⚠️ THE HOUSE IDIOM HAS EXACTLY ONE HOLE, AND IT IS NOT NaN. Transcribed, not assumed:
// `x > 0` is FALSE for nan, -inf, 0 and negatives — so the common guard closes every case
// #588 was written about — and TRUE for +inf, which then reaches `Int()` and traps. That is
// why #1172 chose a CEILING (`<= maxPlausibleRate`) rather than `isFinite && > 0`: finiteness
// is not the property that matters, magnitude is. A new `Int(x * rate)` site is NOT closed by
// copying the neighbouring `> 0`.
//
// ⚠️ ONE CONVERSION HAS NO RATE GUARD AT ALL and is safe only because nothing calls it:
// `StudioCalculator.loopSamples(bars:)` -> `Int((loopSeconds * sampleRate).rounded())`.
// `git grep -n "loopSamples(" -- Sources Tests` finds its own declaration and TWO tests, and
// no production caller. Its tempo half IS guarded (`quarterNoteSeconds` returns 0 for
// `bpm > 0` false, which covers nan and zero), its RATE half is not. Wiring it is what would
// make this paragraph wrong — sanitise the rate in the same commit, do not delete the method
// on the strength of this note (#364).
//
// ⭐ GRADING (§3). SIX findings, SEVEN boundaries — the third (#1170, the poly engine's own
// sample rate), the fourth (#1171, the shared delay line's constructor), the fifth (#1172,
// the FX chain handing the raw rate to fifteen stages) and the sixth (#1194, the felt sub's
// two audio-thread character mirrors), the seventh (#1195, the document-side
// seconds→ticks conversion) and the EIGHTH (#1206, the mod-FX control fields) were added later and
// their grading sits on their own tests. The two below are #588's,
// verified by transcription against the parent
// (the behavioural tests name no new symbol, so they COMPILE against the parent). On the parent,
// `fb = min(max(NaN, 0), 0.95)` is NaN, `wL = inL + lpL * NaN` is NaN from frame 0 — but the
// transcription showed the FIRST DRAFT of test 1 still green there, because at the default
// 0.375 s the read tap never reaches a poisoned sample inside a short run. The test as shipped
// shortens the time target and runs past the glide, and is a true REGRESSION red on the parent;
// test 2 is red there on frame 0 (`m` multiplies the output directly); test 4's needles are red
// by the old spelling. Test 3 got the same time-target treatment for the mirrored reason — at
// the default time a broken ceiling could not have grown inside the test window.
//   · 6 assertions are COUNTERWEIGHTS, green on both trees (#343): finite values still clamp to
//     the same bounds they always did — the repair's whole claim is "bit-identical for finite
//     inputs", and these are the assertions that would catch it being wrong.
//   · Stripper: **PROPHYLAKTISCH (0 of 4 scan needles flip)** — measured, and the measurement
//     overturned my own first draft of this line, which claimed TRAGEND "by construction"
//     because the #588 comment quotes the old idiom in prose. It quotes it as `min(max(…))`;
//     the negative needle searches for `Swift.min(Swift.max(` with the module prefix, and the
//     prose never spells the prefix. A grading claimed from construction instead of from the
//     drive is exactly the class this bundle's §3 exists to stop — same lesson, smaller stakes.

// ⭐ #1206'S GRADING, and its own measured NEGATIVE. Six tests added; every expectation was
// derived by re-implementing chorus, flanger, LFO and delay line in float32 Python and driving
// BOTH trees, because a CI round trip is a lottery ticket (#686). Result:
//   · SEVEN REGRESSION assertions, red on the parent: chorus depth 50-vs-1, flanger depth
//     50-vs-1, the two NaN-depth equalities, the tremolo latching claim, and claim 6's two
//     positive needles. Claim 6's two NEGATIVE needles are red on the parent too but are the
//     SAME absence seen from the other side (#486) — one finding, not four.
//   · SEVEN COUNTERWEIGHT assertions, green on both trees: depth still shapes the sound inside
//     [0, 1] (chorus and flanger), the output is finite, the output is non-zero, and the count
//     pin. Without the first two, all four equalities above are satisfied by a clamp that pins
//     every depth to one value or by a stage that stopped making sound.
//   · Stripper: **PROPHYLAKTISCH (0 of 10 verdicts flip)** — measured, not assumed, on both
//     trees with and without comment-stripping. It is close to load-bearing by construction and
//     was written to stay clear of it: the doc block over `clamp01` QUOTES the retracted
//     spelling, so the two negative needles were deliberately written with the shipped literals
//     (`x, 0.0), 1.0`) while the prose quotes the shorter form (`x, 0), 1`). Either guard alone
//     would do; both together mean a future prose edit cannot redden a correct tree (#491).
//
// ⛔ THE NaN HALF IS LATENT, AND THE RANGE HALF IS NOT. Say them apart. No shipped producer
// emits NaN into these fields (`JSONDecoder`'s default `nonConformingFloatDecodingStrategy` is
// `.throw`; the UI fields carry finite ranges; `FXBioModulator` is guarded by
// `FXModulation.clamp01`, which spells it `x.isFinite ? x : 0`). An OUT-OF-RANGE depth is a
// different story: `FXPreset.init(from:)`'s `f(_:_:)` decodes any finite Float and
// `FXPresetStore` reads a user-writable file.
//
// ⭐ AND #1206 DELIBERATELY DID NOT SWEEP THE CLASS — a measured negative, recorded so nobody
// re-runs it and nobody "fixes" three hundred call sites at once (the same discipline the
// #1179 note above asks for):
//
//   grep -rnE '(Swift\.)?min\(\s*(Swift\.)?max\(' --include='*.swift' Sources/  ->  309
//   ... the same, restricted to Sources/Echoelmusic/DSP/                            ->   74
//
// Many of those 74 are already closed by an explicit `isFinite` ternary in the same expression
// (`EchoelGranular`, `EchoelFDNReverb`, `ChannelInsertFX`, `SubCharacter`, `EchoelDDSP`), and
// several of the hits are COMMENTS quoting the idiom in order to warn about it — including two
// in `EchoelDelayLine` and three in `EchoelDelay`. So 74 is an upper bound on candidates, NOT a
// count of defects, and anyone acting on it must read the hits rather than the number.
// #1206 repaired the two helpers in ONE file, chosen because that file's `clampRate` feeds an
// LFO phase accumulator that LATCHES.

import Foundation
import XCTest
@testable import Echoelmusic

final class ANonFiniteControlCannotReachTheRenderTests: XCTestCase {

    // MARK: - END-TO-END: the delay's control fields

    /// THE REGRESSION. NaN feedback used to reach the write-back multiply; the line was then
    /// poisoned for good. Now it clamps to the range's lower bound and the output stays finite.
    ///
    /// ⛔ THE FIRST DRAFT OF THIS TEST COULD NOT FAIL ON THE PARENT (#367), and transcription is
    /// what caught it: it ran 512 frames at the DEFAULT 0.375 s delay — 18 000 samples — so the
    /// read tap never reached a poisoned position and the output stayed finite on BOTH trees.
    /// The write-back was NaN from frame 0 either way; the test just never looked where it
    /// landed. Hence: a short time target, run long enough for the 40 ms time-glide to settle
    /// AND for the tap to wrap into samples written during this test.
    func testNaNFeedbackProducesFiniteOutput() {
        let d = EchoelDelay(sampleRate: 48_000)
        d.feedback = .nan
        d.mix = 0.5
        d.timeSeconds = 0.005   // ~240 samples once the glide settles
        for i in 0..<20_000 {
            let x: Float = i % 7 == 0 ? 0.5 : 0.1
            let (l, r) = d.processStereo(x, x)
            XCTAssertTrue(l.isFinite && r.isFinite,
                          "Frame \(i): NaN in the feedback CONTROL reached the output — the "
                          + "write-back multiplier is the permanent-silence path.")
            if !(l.isFinite && r.isFinite) { return }   // one report, not twenty thousand
        }
    }

    /// Same boundary, second field. A NaN mix would put NaN directly on the output sum.
    func testNaNMixProducesFiniteOutput() {
        let d = EchoelDelay(sampleRate: 48_000)
        d.mix = .nan
        let (l, r) = d.processStereo(0.25, 0.25)
        XCTAssertTrue(l.isFinite && r.isFinite)
    }

    /// COUNTERWEIGHT — the repair's whole claim is "bit-identical for finite inputs". An
    /// out-of-range finite feedback must clamp to the same 0.95 ceiling as always (the ceiling
    /// is what keeps the feedback loop from self-oscillating past unity), and a legal value
    /// must pass through untouched. If either moved, this slice changed the sound.
    func testFiniteValuesStillClampToTheSameBounds() {
        let d = EchoelDelay(sampleRate: 48_000)
        d.feedback = 2.0   // must behave as 0.95, exactly as before #588
        d.mix = 1.0
        d.timeSeconds = 0.005   // same reasoning as the NaN test: the loop must actually
                                // recirculate many times inside the test, or a broken ceiling
                                // could never grow past the assertion and this counterweight
                                // would be green for a reason other than its named one (#367).
                                // ~240-sample period → hundreds of passes in 30 000 frames;
                                // 2× per pass would overflow to infinity almost immediately.
        var last: Float = 0
        for i in 0..<30_000 {
            let x: Float = i == 0 ? 1.0 : 0.0
            (last, _) = d.processStereo(x, x)
            XCTAssertTrue(last.isFinite && abs(last) < 8,
                          "Frame \(i): a >1 feedback escaped the 0.95 ceiling — the loop is "
                          + "running away, which means the finite path changed.")
            if !(last.isFinite && abs(last) < 8) { return }
        }
    }

    // MARK: - SOURCE-TEXT: the sampler's setter (the render's only writer)

    func testTheSamplerSetterSanitizesAllThreeFields() throws {
        let src = try source("Sources/Echoelmusic/Sequencer/SamplerVoice.swift")
        XCTAssertTrue(src.contains("let s = startFrac.clamped(to: 0...0.999)"),
                      "`Int(startFrac * Float(count))` in the render block is a Swift TRAP for "
                      + "NaN — the setter is the only writer, so it must sanitize.")
        XCTAssertTrue(src.contains("self.endFrac = endFrac.clamped(to: (s + 0.001)...1)"))
        XCTAssertTrue(src.contains("self.rate = rate.clamped(to: 0.25...4)"))
    }

    /// The retracted spelling must not return AT THIS SETTER. Scoped to the function body by
    /// anchoring on its signature (#408): `min(max(…))` elsewhere in the file is legal — only
    /// this setter feeds the `Int(…)` conversion.
    func testTheOldNaNTransparentSpellingIsGoneFromTheSetter() throws {
        let src = try source("Sources/Echoelmusic/Sequencer/SamplerVoice.swift")
        guard let fn = src.range(of:
            "func configurePlayback(startFrac: Float, endFrac: Float, reverse: Bool, rate: Float)")
        else { return XCTFail("The render-state setter was renamed — re-anchor (#454).") }
        let body = src[fn.upperBound...].prefix(700)
        XCTAssertFalse(body.contains("Swift.min(Swift.max("),
                       "The NaN-transparent clamp idiom is back in the one setter whose output "
                       + "reaches an `Int(_:)` conversion on the audio thread.")
    }

    // MARK: - THE THIRD BOUNDARY: the poly engine's own sample rate (#1170)

    /// A THIRD boundary of this file's law, found by sweeping the `min(max(` idiom this header
    /// already names. `EchoelDDSP.init` has always clamped `self.sampleRate = max(1, sampleRate)`.
    /// `EchoelPolyDDSP.init`, in the SAME file, stored it raw — and the poly engine reads its OWN
    /// `sampleRate` in four audio-thread expressions (the portamento coefficient and three
    /// `exp(-Float(frameCount) / sampleRate / τ)` envelopes). At 0 those give inf; at NaN they
    /// give NaN, the coefficients go NaN, and the bus is permanently silent.
    ///
    /// `max(1, x)` is NaN-safe BY ARGUMENT ORDER — `NaN >= 1` is false, so it returns 1. The
    /// reversed `max(x, 1)` passes NaN straight through, which is why the scan below demands
    /// this exact spelling and not merely "a max somewhere".
    ///
    /// ⚠️ LATENT, NOT LIVE, and said plainly rather than implied: every production caller passes
    /// a `static let 48_000` (`BioReactiveSynthVoice`, `PolySynthVoice`, `SubBassVoice`), so no
    /// hardware rate reaches this initialiser today. It is closed on engineering.md's boundary
    /// rule and because the sibling one constructor up already spells the guard — #937, one form
    /// repaired and its twin left broken, in the same file, on the same property name.
    ///
    /// ⛔ THE SWEEP THAT FOUND IT FIRST COUNTED A COMMENT AS A THIRD ASSIGNMENT — the #762
    /// hazard, hit one turn after it was fixed in two separate rot-checkers the same day. Hence
    /// `source(_:)` here, which blanks comments; a raw scan of this file reports three sites and
    /// two of them "unguarded".
    func testBothSampleRateAssignmentsInTheDSPFileAreClamped() throws {
        let dsp = try source("Sources/Echoelmusic/DSP/EchoelDDSP.swift")
        let assignments = dsp.components(separatedBy: "self.sampleRate = ").dropFirst()
        // COUNTERWEIGHT (#926): a vacuous pass if both initialisers were ever deleted or the
        // property renamed. Two is the shipped shape — EchoelDDSP and EchoelPolyDDSP.
        XCTAssertEqual(assignments.count, 2, """
            EchoelDDSP.swift no longer has exactly two `self.sampleRate = ` assignments \
            (found \(assignments.count)). If a voice engine was added, clamp its rate the same \
            way and raise this number; if one was removed, lower it. Do not delete this claim — \
            it is the only thing standing between a zero/NaN rate and NaN render coefficients.
            """)
        for assignment in assignments {
            XCTAssertTrue(assignment.hasPrefix("max(1, sampleRate)"), """
                A `self.sampleRate = ` in EchoelDDSP.swift is not clamped with the exact \
                spelling `max(1, sampleRate)`. Argument order is the whole point: `max(1, NaN)` \
                returns 1 because `NaN >= 1` is false, while `max(NaN, 1)` returns NaN and the \
                poly engine's four audio-thread `exp(-frameCount / sampleRate / τ)` terms then \
                go NaN — permanent silence, the class this file exists for. Found instead: \
                \(assignment.prefix(40))
                """)
        }
    }

    // MARK: - THE FOURTH BOUNDARY: the shared delay line's constructor (#1171)

    /// END-TO-END, because this one CAN be driven: `EchoelDelayLine` is a plain value type
    /// with a public init, so the parent's behaviour is a trap and the child's is a line.
    ///
    /// `Int(_: Float)` traps on `.nan`, on `.infinity`, and on any finite value past
    /// `Int.max`. The parent computed
    /// `Swift.max(4, Int((maxDelaySeconds * sampleRate).rounded(.up)) + 4)` — `Swift.max`
    /// runs AFTER the conversion, so the net hung behind the hole. FIVE stage initialisers
    /// reach this site with a rate they never checked (`EchoelTape`, `EchoelHarmonizer`,
    /// `EchoelChorus`, `EchoelDelay`); `EchoelGranular` was the only one that guarded, and
    /// its own comment names this exact line as the thing that TRAPS. #937 — one form
    /// repaired, four twins left broken — so the repair went to the shared site.
    ///
    /// ⚠️ This test cannot be written as "assert it does not crash": a trap takes the whole
    /// process down, so on the parent this method does not fail, it ABORTS the runner. That
    /// is a louder red than an assertion, not a quieter one, and it is why the arithmetic
    /// claims below matter — they are what distinguishes "did not crash" from "built the
    /// right line".
    func testTheDelayLineSurvivesNonFiniteConstruction() {
        for (seconds, rate) in [(Float(0.05), Float.infinity),
                                (Float(0.05), Float.nan),
                                (Float.infinity, Float(48000)),
                                (Float.nan, Float(48000)),
                                (Float(3e38), Float(48000)),
                                (Float(0.05), Float(0))] {
            let line = EchoelDelayLine(maxDelaySeconds: seconds, sampleRate: rate)
            XCTAssertTrue(line.sampleRate.isFinite && line.sampleRate > 0, """
                EchoelDelayLine kept a non-finite or non-positive sampleRate \
                (\(line.sampleRate)) from seconds=\(seconds) rate=\(rate). Every read/write \
                tap is derived from it.
                """)
            XCTAssertGreaterThan(line.maxDelaySamples, 0, """
                EchoelDelayLine built a zero-length line from seconds=\(seconds) \
                rate=\(rate) — it would read and write the same cell forever.
                """)
        }
    }

    /// COUNTERWEIGHT (#343): the repair's whole claim is "bit-identical for every request the
    /// shipped stages actually make". These are those requests, with the capacities the
    /// PARENT produced — so if the clamp ever changes a real line, this goes red, not the
    /// test above. 0.05 s is Tape and Chorus, 0.12 s the Harmonizer, 1.0 s Granular, 2.0 s
    /// the Delay default.
    func testEveryRealDelayRequestKeepsItsParentCapacity() {
        for (seconds, rate, expected) in [(Float(0.05), Float(48000), 4096),
                                          (Float(0.12), Float(48000), 8192),
                                          (Float(1.0), Float(48000), 65536),
                                          (Float(2.0), Float(48000), 131072),
                                          (Float(0.05), Float(44100), 4096)] {
            let line = EchoelDelayLine(maxDelaySeconds: seconds, sampleRate: rate)
            XCTAssertEqual(line.maxDelaySamples, expected - 2, """
                A real delay request changed size: \(seconds)s @ \(rate) Hz now gives \
                \(line.maxDelaySamples + 2) frames, not \(expected). The #1171 clamp is only \
                allowed to bound inputs that would TRAP; every valid request must keep the \
                capacity it had before.
                """)
            XCTAssertEqual(line.sampleRate, rate, "a valid rate must pass through unchanged")
        }
    }

    // MARK: - #1172 — the FX chain guarded its own field and nothing it built

    /// FINDING FOUR-B. `EchoelFXChain.init` computed a sanitised `sampleRateHz` and then handed
    /// the RAW `sampleRate` to all FIFTEEN stages. `EchoelReverb.init` — whose ONLY construction
    /// site in the whole tree is that line — scales its Freeverb tuning by `sampleRate / 44100`
    /// and converts with `Int(...)`, so a non-finite rate TRAPS there exactly as it used to trap
    /// in the delay line (#1171). Building the chain is therefore the whole test: if the raw
    /// value still reached the reverb, this crashes rather than fails.
    ///
    /// ⛔ AND `1e30` IS IN THE LIST ON PURPOSE. It is FINITE and POSITIVE, so it satisfies the
    /// chain's original `sampleRate > 0 && sampleRate.isFinite` guard — and it still traps
    /// (~2.5e28 frames on the first comb). A ceiling, not just a finiteness test, is what closes
    /// this boundary; without `maxPlausibleRate` this case would still be a crash.
    func testTheFXChainSurvivesEveryDegenerateConstructionRate() {
        for rate in [Float.nan, .infinity, -.infinity, 0, -48_000, 1e30] {
            let chain = EchoelFXChain(sampleRate: rate)
            var buf = [Float](repeating: 0.25, count: 64)
            chain.processBufferMono(&buf, frameCount: 64)
            XCTAssertTrue(buf.allSatisfy { $0.isFinite }, """
                EchoelFXChain(sampleRate: \(rate)) produced a non-finite sample. The chain must \
                fall back to 48 kHz for any rate it cannot use — a degenerate rate may not reach \
                a stage's coefficient maths.
                """)
        }
    }

    /// COUNTERWEIGHT (#926/#343). Two ways the test above could pass while the repair is wrong:
    /// the chain could clamp EVERY rate to 48 kHz (losing 44.1/96 kHz support), or it could be
    /// neutered into producing nothing. Both go red here — a real rate must pass through and
    /// still make sound.
    func testTheFXChainStillWorksAtEveryRealRate() {
        for rate in [Float(44_100), 48_000, 96_000, 192_000] {
            let chain = EchoelFXChain(sampleRate: rate)
            var buf = (0..<128).map { Float(sin(Double($0) * 0.19)) * 0.5 }
            chain.processBufferMono(&buf, frameCount: 128)
            XCTAssertTrue(buf.allSatisfy { $0.isFinite }, "\(rate) Hz produced a non-finite sample")
            XCTAssertTrue(buf.contains { $0 != 0 }, """
                The chain went silent at \(rate) Hz. The #1172 sanitiser is only allowed to \
                replace a rate that would trap; every rate a real device offers must still run.
                """)
        }
    }

    /// COUNTERWEIGHT (#762-safe, reads through `source(_:)`). Pins the SHAPE, so a later stage
    /// added with the raw value goes red here even if it happens not to trap. The count is the
    /// second half: a "repair" that deletes stages cannot satisfy the first half vacuously.
    ///
    /// ⛔ THE COUNT IS ALSO A RETRACTION. #1171 recorded this finding as "all seven sub-stages"
    /// in its own commit body and session log. Measured with comments blanked: FIFTEEN
    /// constructions of fourteen distinct types. The number was written from a partial read of
    /// the initialiser, not from a count — the #1163 lesson one level up: a survey is a memory
    /// of one look, and only the executable count is the measurement.
    func testTheFXChainHandsTheSanitisedRateToEveryStage() throws {
        let src = try source("Sources/Echoelmusic/DSP/EchoelFXChain.swift")
        guard let start = src.range(of: "public init(sampleRate: Float = 48000) {"),
              let end = src.range(of: "\n    }\n", range: start.upperBound..<src.endIndex) else {
            throw BoundaryAnchorMissing(reason: """
                EchoelFXChain's initialiser no longer matches its anchor. Re-anchor this scan; \
                do not let it pass by finding nothing (#1163).
                """)
        }
        let body = String(src[start.upperBound..<end.lowerBound])
        XCTAssertEqual(body.components(separatedBy: "(sampleRate: rate)").count - 1, 15, """
            EchoelFXChain.init no longer builds fifteen stages from the sanitised `rate`. If a \
            stage was added, give it `rate`; if one was removed, correct this count and the \
            "fifteen" in the initialiser's own comment.
            """)
        XCTAssertFalse(body.contains("(sampleRate: sampleRate)"), """
            A stage is being built from the RAW `sampleRate` again. That is the #1172 defect: \
            the chain's guard then protects only the field it stores, not what it constructs — \
            and EchoelReverb.init traps on a rate it cannot scale.
            """)
    }

    // MARK: - THE SIXTH BOUNDARY: the felt sub's character mirrors (#1194)

    /// A SIXTH boundary, found by the same sweep that found the third — and this one is the
    /// only site in `Sources/` where the retracted idiom was written into a
    /// `nonisolated(unsafe)` AUDIO-THREAD MIRROR. Measured:
    /// `git grep -n "didSet.*min(max(" -- Sources` returned exactly these two lines and
    /// nothing else, so this claim closes the shape rather than sampling it.
    ///
    /// WHY IT MATTERS HERE. `SubBassVoice` writes `audioPresence`/`audioHeat` on the main
    /// actor and reads them in the render block (`SubCharacter.coefficients(presence:heat:)`,
    /// once per block). Two `didSet`s FOUR LINES ABOVE — `subGain` and `mixLevel` — already
    /// carry a long comment banning `min(max(…))` by name, for this exact failure class. The
    /// file stated its own law and then broke it twice under it, which is #937's shape again:
    /// one form repaired, its twin left, same file, same bridge.
    ///
    /// ⚠️ LATENT, NOT LIVE — said plainly, because the honest verdict is what makes the note
    /// re-usable. `SubCharacter.coefficients` opens with
    /// `presence.isFinite ? … : defaultPresence`, so a NaN mirror is neutralised one jump
    /// later. That is a guard in a DIFFERENT file protecting this one, and it holds only while
    /// `SubCharacter` stays the single consumer. #546's lesson runs the other way here: there,
    /// following the value one jump further RETRACTED a claim; here it downgrades a live bug to
    /// a latent one — and downgrading is not dismissing (engineering.md's boundary rule).
    ///
    /// ⭐ THE SWEEP'S OTHER RESULT IS A NEGATIVE AND IS RECORDED SO NOBODY RE-RUNS IT. The
    /// entrainment chain (`PolySynthVoice.clampUnit` -> `BioEntrainmentDirector.target` ->
    /// `EchoelEntrainment.process`) uses the retracted idiom at four consecutive sites and is
    /// nonetheless NaN-CLOSED — by comparison, not by clamping: `q >= qualityFloor`,
    /// `depth > 0` and `depth > 0.01` are each FALSE for NaN, so every gate fails closed and
    /// the render returns the sample untouched. Do not "repair" those four; the property that
    /// saves them is the same argument-order law this header is about, used deliberately.
    func testTheSubCharacterMirrorsClampNaNSafely() throws {
        let src = try source("Sources/Echoelmusic/Tools/SubBassVoice.swift")
        XCTAssertTrue(src.contains("didSet { audioPresence = subPresence.clamped(to: 0...1) }"), """
            The felt sub's presence mirror is read on the audio thread and must be NaN-safe at \
            the boundary, like `subGain` and `mixLevel` four lines above it — not one file \
            downstream in `SubCharacter`.
            """)
        XCTAssertTrue(src.contains("didSet { audioHeat = subHeat.clamped(to: 0...1) }"), """
            Same boundary, same law as `subPresence` (#1194).
            """)
        XCTAssertFalse(src.contains("min(max(subPresence"), """
            The NaN-transparent clamp idiom is back on an audio-thread mirror, in the one file \
            whose own `subGain` comment bans it by name.
            """)
    }

    // MARK: - THE SEVENTH BOUNDARY: seconds → ticks (#1195)

    /// A SEVENTH boundary, and the first in this file that is NOT on the audio path —
    /// `TimelineTime.ticks(fromSeconds:bpm:)`, the DOCUMENT-side conversion. It belongs
    /// here anyway because the failure is this file's own: `Int(_:)` TRAPS on NaN and on
    /// ±inf, which is a CRASH, not silence.
    ///
    /// WHAT WAS OPEN. `guard bpm > 0` and nothing else. That reads like a guard and closes
    /// only half of what it looks like it closes — FALSE for NaN, TRUE for `+inf` — and
    /// `seconds` was not checked at all. Both are `Double`s that arrive from a DECODED
    /// document, so the input is not under this file's control.
    ///
    /// ⚠️ LATENT ON THE LIVE PATH, AND THE HONEST VERSION IS THE MIXED ONE. Measured:
    /// `TimelineStore.setAudioRegionWindow` (the caller that does NOT guard `isFinite`) has
    /// ZERO production callers — the audio-lane door went with #121 Slice 4 (#527). The two
    /// LIVE callers reach it through `RegionNoteWindow.offsetTicks`, which guards
    /// `contentOffsetSeconds.isFinite` itself. What was NOT closed on the live path is
    /// `bpm`: no caller checks it, and `+inf` passed the old guard.
    ///
    /// ⭐ WHY THE REPAIR WENT IN THE SHARED FUNCTION. Two callers, asymmetric protection,
    /// one of them protecting by accident (`max(0, x)` is NaN-safe by ARGUMENT ORDER and
    /// says nothing about `+inf`) — the #1171 shape, where one of N entry points spells the
    /// guard and the pothole is shared. Fixing the function closes both and any third.
    func testNonFiniteSecondsCannotTrapTheTickConversion() {
        XCTAssertEqual(TimelineTime.ticks(fromSeconds: .nan, bpm: 120), 0)
        XCTAssertEqual(TimelineTime.ticks(fromSeconds: .infinity, bpm: 120), 0)
        XCTAssertEqual(TimelineTime.ticks(fromSeconds: -.infinity, bpm: 120), 0)
    }

    /// The half the old `bpm > 0` genuinely missed: `+inf` passes `> 0`.
    func testNonFiniteTempoCannotTrapTheTickConversion() {
        XCTAssertEqual(TimelineTime.ticks(fromSeconds: 1, bpm: .infinity), 0)
        XCTAssertEqual(TimelineTime.ticks(fromSeconds: 1, bpm: .nan), 0)
    }

    /// FINITE inputs can still overflow `Int` — the hole an `isFinite` guard alone leaves.
    /// `1e300 × 2 × 480` is finite and roughly 1e303; `Int(_:)` traps on it just as hard.
    func testAnAstronomicalButFiniteOffsetIsCappedRatherThanConverted() {
        let capped = TimelineTime.ticks(fromSeconds: 1e300, bpm: 120)
        XCTAssertEqual(Double(capped), TimelineTime.tickMagnitudeCeiling)
        let negative = TimelineTime.ticks(fromSeconds: -1e300, bpm: 120)
        XCTAssertEqual(Double(negative), -TimelineTime.tickMagnitudeCeiling)
    }

    /// COUNTERWEIGHT (#343). Ordinary values are untouched, and the SIGN survives — the
    /// obvious wrong repair is clamping to `0...ceiling`, which would silently turn every
    /// negative offset into 0 and look like a tightened guard.
    func testOrdinaryTicksConversionsAreUnchanged() {
        XCTAssertEqual(TimelineTime.ticks(fromSeconds: 0.5, bpm: 120), 480)
        XCTAssertEqual(TimelineTime.ticks(fromSeconds: 1.0, bpm: 60), 480)
        XCTAssertEqual(TimelineTime.ticks(fromSeconds: -0.25, bpm: 120), -240)
        XCTAssertEqual(TimelineTime.ticks(fromSeconds: 0, bpm: 120), 0)
        XCTAssertEqual(TimelineTime.ticks(fromSeconds: 1, bpm: 0), 0)
    }

    // MARK: - EIGHTH BOUNDARY (#1206) — the mod-FX control fields

    /// A 220 Hz half-amplitude tone, the signal every mod-FX claim below is driven with.
    /// Deterministic and identical across runs, so two configurations can be compared
    /// sample-for-sample without a tolerance (#442).
    private func tone(_ n: Int) -> Float { sinf(2 * .pi * 220 * Float(n) / 48000) * 0.5 }

    private func runChorus(depth: Float, mix: Float = 0.5, frames: Int = 4000) -> [Float] {
        let fx = EchoelChorus(sampleRate: 48000)
        fx.depth = depth; fx.mix = mix
        return (0..<frames).map { fx.processStereo(tone($0), tone($0)).0 }
    }

    private func runFlanger(depth: Float, frames: Int = 3000) -> [Float] {
        let fx = EchoelFlanger(sampleRate: 48000)
        fx.depth = depth
        return (0..<frames).map { fx.processStereo(tone($0), tone($0)).0 }
    }

    /// REGRESSION (#1206). END-TO-END BEHAVIOUR on the shipped `EchoelChorus`.
    ///
    /// `depth` is documented `[0, 1]` and its UI field carries `0...1`, but the stored property
    /// took anything and `processStereo` used it RAW — while `mix` one line above and the
    /// flanger's `feedback` were both bounded at the use site. A preset JSON is the reachable
    /// producer: `FXPreset.init(from:)`'s `f(_:_:)` decodes a Float with no range check, and
    /// `FXPresetStore` reads a user-writable file.
    ///
    /// At `depth = 50` the excursion is ±350 ms around a 12 ms centre, so BOTH taps sit on the
    /// line's end stops — `msToSamples` floors at 1.0, `readAllpass` ceilings at
    /// `maxDelaySamples` — and the LFO switches between two fixed integer taps. A hard
    /// alternation, not a chorus. After the clamp, `depth = 50` is indistinguishable from
    /// `depth = 1`, which is what this asserts.
    func testTheChorusBoundsItsDepthLikeItsMix() {
        XCTAssertEqual(runChorus(depth: 50), runChorus(depth: 1), """
            `EchoelChorus.depth` is no longer bounded to its documented [0, 1] at the use site. \
            An out-of-range depth from a preset file drives both taps onto the delay line's end \
            stops and the stage becomes a hard two-tap switch (#1206).
            """)
    }

    /// REGRESSION (#1206). Same defect, shorter line: the flanger's base is 3 ms in a 20 ms
    /// buffer, so it reaches its end stops at a lower depth than the chorus does.
    func testTheFlangerBoundsItsDepthLikeItsFeedback() {
        XCTAssertEqual(runFlanger(depth: 50), runFlanger(depth: 1), """
            `EchoelFlanger.depth` is no longer bounded at the use site, while `feedback` two \
            lines above still is. The two came from the same preset record (#1206).
            """)
    }

    /// REGRESSION (#1206), and the one that is about NaN rather than range.
    ///
    /// ⚠️ NOT a finiteness failure, and saying so precisely matters: `msToSamples` is
    /// `Swift.max(1.0, …)` with the known-good value FIRST, so a NaN excursion already produced
    /// a finite delay of 1.0. The defect is WHICH value it produced — both taps pinned to a
    /// single sample, i.e. a 1-sample comb, silently, instead of the neutral 12 ms centre a
    /// depth of zero gives. The old `clamp01` could not have caught it because it was itself
    /// NaN-transparent.
    func testANonFiniteDepthLandsOnZeroNotOnTheEndStop() {
        XCTAssertEqual(runChorus(depth: .nan), runChorus(depth: 0), """
            a non-finite `depth` no longer resolves to the neutral zero. It used to reach \
            `msToSamples` unbounded, where `Swift.max(1.0, NaN)` pinned BOTH taps to one \
            sample — finite, and completely wrong (#1206).
            """)
        XCTAssertEqual(runFlanger(depth: .nan), runFlanger(depth: 0), """
            the flanger half of the same claim (#1206).
            """)
    }

    /// REGRESSION (#1206), and the LATCHING one — the reason this slice touches `clampRate`
    /// and not only `clamp01`.
    ///
    /// Every mod-FX stage funnels its `rate` setter through `clampRate`. Spelled
    /// `Swift.min(Swift.max(x, 0.05), 8.0)` a NaN passed straight through into
    /// `EchoelLFO.rate`, and `next()` does `phase += rate / sampleRate` with a reset on
    /// `phase >= 1.0`: once the phase is NaN that comparison is false FOREVER. The LFO never
    /// recovers, and nothing short of a new instance heals it. The tremolo is the stage where
    /// that surfaces as NaN in the OUTPUT (its gain is computed straight from the LFO), which
    /// is why the assertion lives here rather than on the chorus.
    func testANonFiniteRateCannotLatchTheLFOPhase() {
        let fx = EchoelTremolo(sampleRate: 48000)
        fx.rate = .nan
        fx.depth = 0.5
        let out = (0..<3000).map { fx.processStereo(tone($0), tone($0)).0 }
        XCTAssertTrue(out.allSatisfy { $0.isFinite }, """
            a non-finite `rate` reaches `EchoelLFO.rate` again. Its phase accumulator then \
            latches at NaN — `phase >= 1.0` is false for NaN, so the reset never fires — and \
            every stage driven by that LFO is dead for the life of the instance (#1206).
            """)
    }

    /// COUNTERWEIGHT (#343), and the one that keeps the three claims above honest. Each of them
    /// is an EQUALITY between two configurations, so all three would also pass if the clamp
    /// collapsed every depth to one value, or if the stage stopped producing sound at all.
    func testDepthStillShapesTheSoundInsideItsRange() {
        let half = runChorus(depth: 0.5)
        XCTAssertNotEqual(half, runChorus(depth: 1.0), """
            `depth` no longer changes the chorus anywhere inside [0, 1]. The three equalities \
            above are satisfied by a clamp that pins every depth to one value; this is the \
            assertion that says the parameter still does something (#1206).
            """)
        XCTAssertTrue(half.allSatisfy { $0.isFinite }, "ordinary chorus output is not finite")
        XCTAssertTrue(half.contains { $0 != 0 }, "the chorus stopped producing output entirely")
        XCTAssertNotEqual(runFlanger(depth: 0.5), runFlanger(depth: 1.0), """
            the flanger half of the same counterweight (#1206).
            """)
    }

    /// REGRESSION (#1206). SOURCE-TEXT SCAN (§1) — the half a behavioural test cannot state:
    /// WHY the spelling is what it is. Both helpers are `private` and inlined, so nothing can
    /// call them directly.
    ///
    /// ⚠️ The negative needles are the load-bearing half. A future edit that "tidies" the
    /// argument order back is bit-identical for every finite input and would pass every
    /// behavioural claim above except the two NaN ones — and those two are LATENT, so a
    /// reviewer could reasonably read them as theoretical. The absence assertion is what makes
    /// the order a rule rather than a preference.
    func testTheModFXClampHelpersPutTheKnownGoodValueFirst() throws {
        let code = try source("Sources/Echoelmusic/DSP/EchoelModFX.swift")
        XCTAssertTrue(code.contains("Swift.min(1.0, Swift.max(0.0, x))"), """
            `clamp01` in EchoelModFX no longer puts the known-good bound first. \
            `Swift.max(x, 0)` returns x for NaN because every comparison against NaN is false, \
            so the old order made the clamp a no-op for NaN (#1206).
            """)
        XCTAssertTrue(code.contains("Swift.min(8.0, Swift.max(0.05, x))"), """
            `clampRate` in EchoelModFX no longer puts the known-good bound first. This one is \
            the latching path: it feeds `EchoelLFO.rate` (#1206).
            """)
        XCTAssertFalse(code.contains("Swift.min(Swift.max(x, 0.0), 1.0)"), """
            the NaN-transparent spelling of `clamp01` is back. It is bit-identical for finite \
            inputs, which is exactly why only this scan can see it (#1206).
            """)
        XCTAssertFalse(code.contains("Swift.min(Swift.max(x, 0.05), 8.0)"), """
            the NaN-transparent spelling of `clampRate` is back (#1206).
            """)
        XCTAssertTrue(code.contains("let exc = clamp01(depth) * spreadMs"), """
            a mod-FX stage reads `depth` raw again. Both the chorus and the flanger must route \
            it through the bounded helper, the way `mix` and `feedback` already are (#1206).
            """)
        XCTAssertEqual(code.components(separatedBy: "let exc = clamp01(depth) * spreadMs").count - 1, 2, """
            COUNT PIN: exactly two stages compute an excursion from `depth` — chorus and \
            flanger. A third would be a new delay-driving stage that this claim has not been \
            checked against; a first would mean one of them lost its bound (#1206).
            """)
    }

    // MARK: - source access (§0/§2 — one stripper, skip on no tree, FAIL on a moved anchor)

    private struct BoundaryAnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw BoundaryAnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — renamed or moved. \
                Re-anchor this scan; do not let it skip (#454).
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
