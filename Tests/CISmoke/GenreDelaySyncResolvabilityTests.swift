// GenreDelaySyncResolvabilityTests.swift
// ⚠️ RENAMED. It was `GenreDelaySyncAudibilityTests` for one commit, and "audibility" was
// exactly the wrong word — see the header below: nothing in this file is about what anyone
// hears. A test file whose NAME asserts more than its contents do is the same defect class it
// guards against.
// Echoel — a notated note division that cannot RESOLVE at any tempo the genre allows is a lie in
// the source. BLOCKING bundle (Tests/CISmoke), because the other suite cannot fail a merge (#208).
//
// ⛔ READ THIS FIRST — THE FIRST VERSION OF THIS HEADER WAS A PLAYBACK CLAIM AND IT WAS FALSE.
// It said the two genres below "played a flat 2.0 s echo" and called that "the '#81/#125
// everything sounds the same' collapse, on the delay axis". They played no such thing. All three
// sites that stamp a genre/character preset (`EchoelStudioView.applyFX()`, the re-seed path, the
// open-take path) call `applyDelaySync(bpm:)` immediately afterwards over the SAME chain
// inventory, and it writes the view's `@State delaySync` — the user's delay-division picker,
// default dotted 1/8 — over `chain.delay.timeSeconds`.
//
// ⚠️ "The picker is the last writer, ALWAYS" stood here for one commit and was FALSE at the
// time: `EchoelFXView.applyCharacter` is a FOURTH stamp site and had no `applyDelaySync` after
// it, so a CHARACTER stamp from the FX panel won instead (and wrote only `synth.fxChain`, never
// `touchSynth`'s). ⭐ BOTH HALVES ARE REPAIRED — #318 gave that site the full chain inventory and
// #1364 gave it the resync — so the absolute is true again, as a REPAIR and not as something
// that always held. No genre preset is involved in that menu (`.auto` is filtered out), so the
// claim about GENRE divisions never depended on any of it.
// That is the deliberate resolution of #240, guarded by `DelayReachesEveryChainTests` in this
// same bundle, which states it plainly. Asserting the opposite two files away is exactly the
// "a surviving copy reads as independent confirmation" failure this repo keeps paying for — and
// this header paid it once more: it went on describing the un-repaired fourth site for the whole
// of #1364 and #1369, both of which rewrote the OTHER homes of the same sentence.
//
// ⛔ AND THE NEXT PARAGRAPH IS SPENT TOO, SINCE #1371. It read: "SO WHAT THIS FILE GUARDS IS A
// SOURCE-LEVEL CONTRACT, NOT AN AUDIBLE ONE … 29 authored divisions currently reach nothing and
// every genre shares whichever one the picker holds — a far bigger delay-axis collapse than any
// preset tuning, and a founder decision." The founder delegated that decision (2026-09-18, "die
// Parameter sollen intelligent sein"), and #1371 took it: a genre change now SETS `delaySync`
// from `style.fxPreset.delaySync` and stamps it, so the per-genre divisions are AUDIBLE. This
// file's contract is unchanged in what it checks — resolvable and distinct — but the stakes
// flipped: a wrong value here is now a wrong SOUND, not dead data. (The count is deleted rather
// than refreshed a third time, #818; `GenreFXPreset.apply(to:bpm:)`'s doc carries the commands.)
//
// ⭐ AND THE FLIPPED STAKES CASHED IN ONE COMMIT LATER (#1372), WHICH IS THE PART WORTH READING
// BEFORE TRUSTING ANY ALLOWANCE IN THIS FILE. Two of this file's claims carried an exemption
// whose written reason was "no listener hears it": `selfObservation` was permitted to truncate
// at its own default tempo, and the whole-window sweep covered a hand-written pair of genres.
// Measured after #1371: THREE genres clamped `.half` against the 2.0 s ceiling at their slowest
// tempo — `selfObservation` (46…78), `stillMeditation` (50…70), `doom` (50…80) — and the first
// two are OFFERED and both `.flowFree`, so their echo froze flat exactly where a body takes
// them. All three are re-voiced to `.half, .triplet` (`deepDrone`'s division), the allowance is
// now zero, and the sweep is a universal floor check instead of a roster.
//
// **THE DURABLE LESSON, and it is about guards rather than about delay: an exemption is only as
// good as the premise written next to it, and a roster-shaped guard goes blind as its roster
// ages.** Both defects were visible in this file's own prose the whole time.
//
// ⚠️ HONEST GRADING OF #1372 (§3): no Swift toolchain in the web session. The three data
// claims were re-implemented in Python — the arithmetic READ out of `StudioCalculator.swift`
// (`seconds = 60/bpm × division.quarters × modifier.factor`), not invented — and driven against
// the parent tree `438cf23` and the worktree. Parent: claim "slowest" ROT with
// `[doom, selfObservation, stillMeditation]`, claim "default" ROT with `[selfObservation]`,
// cluster count 5. Worktree: both green, cluster count 5.
//
// Four mutants, landed and MEASURED:
//   `selfObservation` back to `.half` → slowest AND default (clusters 6, green)
//   `stillMeditation` back to `.half` → slowest ONLY — **the case no claim in this file could
//                                       see before #1372**: it resolves at its default (60 BPM
//                                       is exactly 2.000 s) and truncates below it
//   `doom` back to `.half`            → slowest ONLY — it is not `offered`, so only the
//                                       all-genres claim reaches it
//   `drift` to `.half, .triplet`      → clusters 4, the merge the ratchet exists for
//
// ⛔ AND ONE NUMBER IN THIS FILE WAS NEARLY RAISED ON A BAD MEASUREMENT. The first #1372 draft
// reported the cluster count as 7 and raised the floor to match. Seven counts the drum-free
// offered genres without the `delayEnabled` filter the method itself applies — `celticAir`,
// `glacialField` and `slowBloom` ship no echo. **A re-derivation is only a check if it is driven
// against the CODE of the claim, not against a memory of what the claim asks**; the floor stays
// at its measured 5.
//
// THE SOURCE DEFECT THIS FILE WAS WRITTEN FOR. `apply(to:bpm:)` resolves `delaySync` against the
// BPM and clamps to `maxDelaySeconds` = 2.0. Two genres authored divisions over that clamp at
// EVERY tempo in their own `tempoRange`, so the notated value could not resolve anywhere:
//
//   · deepDrone      `.whole`         40…58 BPM → 6.00…4.14 s
//   · contemplation  `.half, .dotted` 44…66 BPM → 4.09…2.73 s
//
// Re-authored to `.half, .triplet` and `.quarter`, both un-clamped across their whole windows.
// The ceiling was deliberately NOT raised — but not for the reason first written here either:
// see `GenreFXPreset.maxDelaySeconds`, where three unlinked `2.0` literals are separated and
// only one of them sizes a buffer.
//
// WHAT THIS FILE CANNOT CATCH, stated so the coverage is not overread:
//   · anything a user hears — see above; that is the routing question, not this one;
//   · whether the new times would sound good once routed — a founder listening call;
//   · `FXCharacter` presets, which have no tempo window of their own (they are stamped at
//     whatever BPM is running) so "cannot resolve at any allowed tempo" is undefined for them;
//   · a genre whose division resolves in only a sliver of its window. Test 3 bounds how many
//     genres may be clamped AT THEIR DEFAULT TEMPO, which is the tempo a fresh take starts on,
//     but a window is not swept for the untouched presets on purpose — tightening that would
//     force a retune of presets that already resolve as authored over most of their range.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreDelaySyncResolvabilityTests: XCTestCase {

    /// One reusable chain per TEST METHOD (XCTest builds a fresh instance for each, which is
    /// what makes this bleed-free across methods — the property does the sharing, not a static).
    /// A fresh `EchoelFXChain` allocates ≥1 MB of delay-line buffers plus tape/chorus/flanger/
    /// reverb lines, and the sweeps below call `stamped` ~90 times: 90 chains would
    /// churn ~100 MB inside the bundle that gates every merge, for no added coverage.
    ///
    /// ⚠️ EQUIVALENT FOR WHAT THIS FILE READS, AND NOT IN GENERAL — the first version claimed
    /// "exactly equivalent to a fresh one", which is only true of `delay.timeSeconds`, the single
    /// field measured here (`apply` writes it unconditionally, and it is a plain stored property
    /// with no smoothing on the read path). Reuse DOES carry over `EchoelDelay.timeSmoothed`, the
    /// ring buffers, filter states and LFO phases, and the `delayEnabled` rising-edge reset now
    /// fires only on the first `apply` because every genre preset sets it true. A sixth test that
    /// calls `processStereo` or asserts on a settled value must build its own chain.
    private let chain = EchoelFXChain(sampleRate: 48000)

    /// The stamped delay time and the time the preset ASKED for, at one BPM.
    /// Measured through `apply` rather than by reading the private ceiling constant — the
    /// observable form, and it tracks the constant automatically if it ever moves.
    private func stamped(_ style: MusicStyle, bpm: Double) -> (got: Double, authored: Double) {
        let preset = style.fxPreset
        preset.apply(to: chain, bpm: bpm)
        return (Double(chain.delay.timeSeconds), preset.delaySync.seconds(bpm: bpm))
    }

    /// True when the chain refused the authored time at `bpm`.
    private func isClamped(_ style: MusicStyle, bpm: Double) -> Bool {
        let r = stamped(style, bpm: bpm)
        return r.got < r.authored - 1e-4
    }

    // MARK: - The invariant

    /// ⛔ THE ONE THAT MATTERS. Every genre's division must resolve un-clamped at the FASTEST
    /// tempo its own window allows — the tempo at which the resolved time is SHORTEST, so if it
    /// does not fit there it fits nowhere and the notated value is unreachable.
    ///
    /// Swept over `allCases`, not `offered`: a genre curated out of the picker today can be
    /// re-offered tomorrow (seven of them are waiting), and it should not carry a dead division
    /// in when it comes.
    /// ⚠️ NAMED POSITIVELY ON PURPOSE. It was `testNoGenresDelayDivisionIsInaudible…` and then
    /// `…FailsToResolveAtEveryTempo…` — a double negative with a second, equally grammatical
    /// reading ("every division resolves at every allowed tempo") that is FALSE and that test 3
    /// explicitly permits. A name must not assert more than the body; that is why this file was
    /// renamed, so the method name has to obey it too.
    func testEveryGenresDivisionResolvesAtItsFastestAllowedTempo() {
        for style in MusicStyle.allCases {
            let preset = style.fxPreset
            guard preset.delayEnabled else { continue }

            let fastest = style.tempoRange.upperBound
            let r = stamped(style, bpm: fastest)
            XCTAssertEqual(r.got, r.authored, accuracy: 1e-4,
                "\(style): `\(preset.delaySync.label)` is \(String(format: "%.3f", r.authored)) s "
                + "even at its FASTEST allowed tempo (\(fastest) BPM), so the delay-line ceiling "
                + "truncates it to \(String(format: "%.3f", r.got)) s at every tempo in "
                + "\(style.tempoRange) — the notated division can never RESOLVE, and the genre "
                + "sits on the clamp next to every other genre that overruns it. Author a "
                + "SHORTER division; do not raise the ceiling (see GenreFXPreset.maxDelaySeconds).")
        }
    }

    /// EVERY genre, at its SLOWEST allowed tempo — the one end where the ceiling can fire.
    ///
    /// ⛔ #1372 REPLACED A NAMED LIST WITH THIS, AND THE REPLACEMENT IS THE POINT. It was
    /// `testTheTwoRepairedGenresResolveUnclampedAcrossTheirEntireWindow`, sweeping
    /// `[.deepDrone, .contemplation]` at 1 BPM. That guard was correct and could not see the
    /// defect #1372 repaired, because the two genres that were truncating were not in its list —
    /// **a guard whose reach is a hand-written roster grows blind exactly as fast as the roster
    /// ages**, and this slice would have had to edit it either way. The sweep itself was also
    /// more machinery than the question needs: `seconds(bpm) = k / bpm` is monotonically
    /// DECREASING, so the longest resolved time in a window is always at its floor. One endpoint
    /// per genre is therefore not a weaker check than 1-BPM steps across all of them; it is the
    /// same check without the roster.
    ///
    /// ⚠️ ITS SIBLING ABOVE TESTS THE OTHER END AND IS DELIBERATELY KEPT. At the fastest tempo
    /// the time is SHORTEST, so that claim cannot catch a truncation — it answers a different
    /// question ("can this division resolve at ALL, anywhere in the window?") and its failure
    /// message says so. Two ends, two diagnoses; merging them would lose the second.
    func testEveryGenresDivisionResolvesAtItsSlowestAllowedTempo() {
        for style in MusicStyle.allCases {
            let preset = style.fxPreset
            guard preset.delayEnabled else { continue }

            let slowest = style.tempoRange.lowerBound
            let r = stamped(style, bpm: slowest)
            XCTAssertEqual(r.got, r.authored, accuracy: 1e-4,
                "\(style) at its SLOWEST allowed tempo (\(slowest) BPM): `\(preset.delaySync.label)` "
                + "notates \(String(format: "%.3f", r.authored)) s and the delay-line ceiling "
                + "truncates it to \(String(format: "%.3f", r.got)) s. The echo is then FLAT over "
                + "the slow part of \(style.tempoRange) — it stops tracking tempo exactly where a "
                + "body takes a contemplative genre, and the Delay-note picker (which since #1371 "
                + "shows this genre's own division) says a note value the chain does not play. "
                + "Author a SHORTER division; do not raise the ceiling (see "
                + "GenreFXPreset.maxDelaySeconds, whose own doc says the same).")
        }
    }

    // MARK: - The collapse itself

    /// The clamp must not be what makes two offered genres share an echo — and since #1372 the
    /// permitted count is ZERO.
    ///
    /// ⛔ IT READ `XCTAssertLessThanOrEqual(truncated.count, 1)` AND ITS ALLOWANCE HAD A STATED
    /// PREMISE THAT EXPIRED. The exemption was `selfObservation`, "left alone on purpose because
    /// its division DOES resolve over most of its window", and the failure message next to it
    /// spelled the premise out: "what a LISTENER hears is a separate, open routing question".
    /// #1371 routed it; #1372 re-voiced the genre. **An allowance is only as good as the premise
    /// written beside it — and this one was written beside it, honestly, which is the only
    /// reason it could be found and closed rather than inherited.**
    ///
    /// Kept as a COUNT over `offered` even though the claim above now covers every genre at its
    /// floor: this one asks about the DEFAULT tempo, the one a fresh take actually starts on, and
    /// its failure message names the genres. A zero here and a green sibling are two different
    /// reassurances.
    func testNoOfferedGenreIsTruncatedAtItsDefaultTempo() {
        let truncated = MusicStyle.offered.filter { style in
            style.fxPreset.delayEnabled && isClamped(style, bpm: style.defaultTempo)
        }
        XCTAssertEqual(truncated.count, 0,
            "\(truncated.count) offered genres have their echo truncated by the delay-line "
            + "ceiling at their own default tempo (\(truncated.map { "\($0)" }.sorted())). Every "
            + "one of them resolves to the SAME flat time regardless of what it notated — and "
            + "since #1371 a listener HEARS that, because a genre change now sets the Delay-note "
            + "picker from the genre's own preset. Give it a division that fits its window.")
    }

    /// The positive form of the same claim: the drum-free offered genres must actually OCCUPY the
    /// delay axis. Clustered at 5% relative distance because two times 1% apart are one echo to
    /// an ear, not two — a distinct-values count would score the pre-fix state 4 and call it
    /// spread.
    ///
    /// ⛔ **THIS CLAIM DEMANDED THAT EVERY DRUM-FREE OFFERED GENRE CARRY A DELAY, AND IT WAS RED
    /// ON A CORRECT TREE FROM #1285 UNTIL #1290.** That batch shipped `glacialField` and
    /// `slowBloom` as offered `.none`-archetype genres with no delay at all — deliberately, an
    /// echo repeats an event and neither has one — so `times.count` was 7 against a
    /// `drumFree.count` of 9 and the equality could not hold. Nothing surfaced it: CI/CD reports
    /// `failure` on every push (#396) and the job log is `tail -200` (#807), and #1285's own
    /// commit message asserted the opposite in as many words — *"both presets have no delay at
    /// all, so `GenreDelaySyncResolvabilityTests` skips them by construction"*. It does not skip
    /// them; this claim counted them. **A verification sentence written from what a guard was
    /// MEANT to do is not a measurement of what it does.**
    ///
    /// ⭐ The equality is replaced by a RATCHET, which is what the assertion was actually for: a
    /// FLOOR on how many drum-free offered genres carry a delay. Removing an echo to game the
    /// cluster count still reddens it; adding a calm genre that legitimately has none does not
    /// (#364). The floor is the measured count, so it only ever moves up, by hand, in a commit
    /// that says why.
    ///
    /// ⚠️ 5 clusters, MEASURED, and #1372 did NOT move the number — which is the honest
    /// result and was very nearly reported as a raise to 7. Seven is what you get by counting
    /// the drum-free offered genres WITHOUT the `delayEnabled` filter this method applies:
    /// `celticAir`, `glacialField` and `slowBloom` legitimately ship no echo at all, so they are
    /// not on this axis. **The flattering number came from dropping a filter the code right here
    /// applies; the check that caught it was re-deriving against this method rather than against
    /// the idea of it.**
    ///
    /// ⭐ WHAT #1372 DID CHANGE IS THE REASON FOR ONE TIE, not the count. The old doc named the
    /// tightest pair as `selfObservation` 2.000 s ≈ `stillMeditation` 2.000 s and called it
    /// "AUTHORSHIP — same division, near-identical default tempo … neither is a clamp artefact".
    /// Half of that was wrong: `stillMeditation`'s half note at 60 BPM really is exactly 2.000 s
    /// un-clamped, but `selfObservation`'s at 58 is 2.069 s TRUNCATED to 2.0 — **the ceiling was
    /// manufacturing that tie**, which is exactly the artefact this claim exists to detect,
    /// sitting in its own documentation as an example of something else. Today the pair is
    /// `stillMeditation` 1.333 ≈ `selfObservation` 1.379 (3.4%): still one cluster, now by
    /// honest arithmetic. It is deliberately left — the two differ in delay MODE (`.digital` vs
    /// `.tape`), wow, mix, tone and spread, so their echoes are not one echo; only their TIMES
    /// are close, and time is all this metric can see.
    ///
    /// ⚠️ THIS SITS EXACTLY ON ITS BOUND — 5 is the measured value, not a floor with slack. Any
    /// merge of two clusters reddens it, which is the point (a ratchet against re-collapse, not
    /// a quality bar). The other tie is `ambientPulse` 0.706 ≈ `classical` 0.714 (1.1%, both
    /// straight quarters whose windows meet); the tightest SPLIT is now `selfObservation` 1.379
    /// vs `drift` 1.500, 8.8% apart (it was `deepDrone` 1.667 vs `drift` 1.500, 11%). 5% at
    /// ~1.4 s is 70 ms, which is not two echoes to an ear. If this is ever to become a real
    /// quality bar rather than a regression latch, raise the distance to 10% and assert whatever
    /// count that yields — deliberately NOT done here, because it would demand retuning presets
    /// on taste.
    func testTheDrumFreeOfferedGenresOccupyTheDelayAxis() {
        let drumFree = MusicStyle.offered.filter { $0.beatArchetype == .none }
        XCTAssertGreaterThanOrEqual(drumFree.count, 6,
            "too few drum-free offered genres for this measurement to mean anything")

        let times = drumFree
            .filter { $0.fxPreset.delayEnabled }
            .map { stamped($0, bpm: $0.defaultTempo).got }
            .sorted()
        XCTAssertGreaterThanOrEqual(times.count, 7, """
            Only \(times.count) of the \(drumFree.count) drum-free offered genres carry a delay \
            at all (\(drumFree.filter { !$0.fxPreset.delayEnabled }.map(\.rawValue).sorted()) \
            have none). Seven is the measured floor: a calm genre may legitimately ship without \
            an echo, but taking an echo AWAY shrinks the axis this file exists to keep open, and \
            it is the cheapest way to make the cluster count below look healthy.
            """)

        // `guard` and not just the assertion above: `XCTAssert*` does not halt the method, and
        // `1..<0` TRAPS ("Range requires lowerBound <= upperBound"). A future `beatArchetype`
        // edit that emptied this set would crash the test process and take the rest of the
        // bundle's tests with it instead of printing the diagnostic written above.
        guard times.count > 1 else {
            return XCTFail("fewer than two drum-free offered genres carry a delay — there is no "
                           + "axis left to measure; fix the set, not this test")
        }

        var clusters = 1
        for i in 1..<times.count where times[i] > times[i - 1] * 1.05 { clusters += 1 }

        XCTAssertGreaterThanOrEqual(clusters, 5,
            "the drum-free genres resolve to only \(clusters) audibly distinct echo times "
            + "(\(times.map { String(format: "%.3f", $0) })). The calm family is collapsing onto "
            + "one echo again — check whether a division started clamping before retuning "
            + "anything by ear. #1372 did not raise this floor: it replaced a tie the CEILING "
            + "was manufacturing (two genres flat on 2.000 s) with an honest one 3.4% apart, "
            + "same count. So a drop below 5 is a real collapse, not a leftover.")
    }

    // MARK: - Anti-vacuity

    /// ⛔ WITHOUT THIS, EVERY TEST ABOVE PASSES BY RAISING THE CEILING. A 100 s clamp makes
    /// "nothing clamps" trivially true while changing nothing about what any genre notates.
    ///
    /// ⚠️ THIS PINS ONE OF THREE UNLINKED `2.0` LITERALS, and the first version of this comment
    /// wrongly treated them as one. It pins `GenreFXPreset.maxDelaySeconds`, a pure clamp that
    /// allocates nothing. The other two are UNGUARDED here:
    ///   · `EchoelDelay.init(maxDelaySeconds: Float = 2.0)` — the one that SIZES the buffer, and
    ///     the one `EchoelFXChain` actually uses. Usable line is `capacity - 2` = 131 070 =
    ///     2.7306 s at 48 kHz, so the clamp this test pins is already 0.73 s below the hardware.
    ///   · `EchoelStudioView.applyDelaySync(bpm:)`'s hardcoded `0.001...2.0`, for the USER's
    ///     delay-division picker — which per this file's header is the value a listener actually
    ///     meets, and whose own menu (`TempoSyncOption.common`) offers 1/1 straight/dotted/
    ///     triplet. On `deepDrone` at 40 BPM the picker's own 1/1 is 6.0 s and truncates to 2.0:
    ///     the very defect class this file exists for, one surface over, untested.
    ///
    /// So if you are here because this went red: moving this constant alone is cheap (free up to
    /// ~2.73 s) but changes nothing a user hears. Read `GenreFXPreset.maxDelaySeconds`' doc for
    /// which literal does what before moving any of them, and note that
    /// `PolySynthVoice.idleFrameThreshold`'s 2.5 s derives from `EchoelDelay`'s ceiling — and is
    /// already violable via `FXPreset`'s unbounded `delayTime` decode.
    func testTheDelayCeilingIsStillTwoSecondsAndStillEngages() {
        let probe = GenreFXPreset(delayEnabled: true, delaySync: TempoSyncOption(.whole))
        probe.apply(to: chain, bpm: 40)          // a whole note at 40 BPM = 6.0 s

        XCTAssertEqual(probe.delaySync.seconds(bpm: 40), 6.0, accuracy: 1e-9,
                       "the note-division math changed — re-derive this probe before trusting "
                       + "the ceiling measurement below")
        XCTAssertEqual(Double(chain.delay.timeSeconds), 2.0, accuracy: 1e-4,
            "GenreFXPreset.maxDelaySeconds is no longer 2.0 s. If it was RAISED past ~2.73 s the "
            + "delay LINE truncates instead (EchoelDelayLine.read), so the authored value still "
            + "does not resolve — it just fails one layer down where nothing checks it. If it was "
            + "LOWERED, presets that resolved before now clamp.")
    }
}
