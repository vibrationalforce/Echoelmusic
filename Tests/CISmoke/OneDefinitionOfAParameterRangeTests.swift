// OneDefinitionOfAParameterRangeTests.swift
// Echoel — #441. A parameter's range is ONE fact. The row that shows the number and every
// writer that clamps into it must read the same constant.
//
// WHAT WAS WRONG. Each of the Sound panel's seventeen parameters had its range written THREE
// times: as a literal at the `param(…)`/`knob(…)` call site, again inside `SoundPrompt.clamp`,
// and a third time in the hand-written model table of `SoundRowsCanReachTheShippedPatchesTests`
// next door. The first two are now one constant (`SynthPatch.Bounds`). The third stays
// hand-written ON PURPOSE and is not a defect: a guard that reads the constant it is guarding
// cannot catch a wrong constant.
//
// ⭐ THE ONE THAT ACTUALLY COST SOMETHING is `filterLFORate`. Its row spans 0…20 Hz; the prompt
// clamped to 0…12. #430 saw that difference and wrote it off as harmless because the shipped
// bank tops out at 1.2 Hz — which looked at the wrong population. The row lets a FINGER reach
// 20, and `SoundPrompt.apply` ends with an UNCONDITIONAL `clamp(&p)`, so tapping "Describe it"
// with ANY text rewrote a user-set 19 Hz as 12 Hz. Not only recognised words: an entirely
// unrecognised prompt shapes nothing and still clamps, so the value was destroyed by text the
// engine ignores. That is the `Drone Bed` defect #430 fixed one field over, in the harder-to-
// notice direction — no fixture holds a user-set value, so nothing went red.
//
// ⚠️ THE SECOND DIFFERENCE IS COSMETIC AND SAID SO RATHER THAN DRESSED UP. The prompt floored
// `attack` at 0.001 s while its row starts at 0. `EchoelDDSP`'s envelope enforces a ~3 ms
// minimum attack ramp in its `.attack` stage, so 0 s and 0.001 s are the same sound. The floor's
// stated purpose ("a musical minimum below every shipped onset") was already served one layer
// down. It is included here because a test that only covers the exciting half of a change is
// how the other half rots.
//
// ⭐ THE DIRECTION IS A RULE, NOT A CASE-BY-CASE CALL: where the two disagreed, the ROW wins and
// the prompt WIDENS. Widening can never cut a shipped or user-set value — that is exactly the
// invariant that made #430's `decay` fix safe — while narrowing a row to match a prompt would
// silently take reach away from a control the user already has.
//
// ⚠️ WHAT THIS CANNOT SHOW: that any of it is audible. `filterLFORate` drives the patch filter
// LFO, and whether 19 Hz "sounds better" than 12 Hz is a device listen. What is checkable is
// that the number the row offers is the number the app keeps.

// ⭐ #1207 — A THIRD WRITER JOINED, AND IT WAS THE ONE WITH NO BOUND AT ALL. The rows and
// the prompt shared `SynthPatch.Bounds` since #441; `SynthPatch.init(from:)` applied NO range
// check to any field. That decoder is reachable from a LIVE door — "Open project" →
// `.fileImporter` → `ProjectStore.importProject(fromDocument:)` → `Project` → its embedded
// `SynthPatch` → `apply(to:)`. The seventeen clamp lines now live ONCE, on
// `SynthPatch.clampToBounds()`, and both writers call it (#416).
//
// ⛔ THE NEEDLES OF `testThePromptClampReadsTheSharedBound` MOVED FILES IN THIS COMMIT (#456).
// They pointed at `SoundPrompt.swift`; the code they name is now in `SynthPatch.swift`, and the
// prompt is asserted to ROUTE through it. Leaving them where they were would have been a guard
// red on a correct tree — the exact §4 failure this bundle keeps paying for.
//
// ⭐ GRADING (§3), transcribed in Python against BOTH trees (no local toolchain, §0) — the
// comment stripper re-implemented, every needle in the two changed tests driven, plus the two
// behavioural claims simulated in float32.
//   · SOURCE SCANS (19 assertion statements in `testThePromptClampReadsTheSharedBound`):
//     parent = `typealias B = Bounds` 0, field needles 0/17, `p.clampToBounds()` absent.
//     That is ONE ABSENCE — `clampToBounds` does not exist on the parent — reported once
//     (#486), NOT nineteen findings. Worktree: 17/17 + both singles present.
//   · `testAPatchFileCannotCarryAValueTheRowRefuses` — a true REGRESSION for its named reason
//     (#367): on the parent the decoder returns the raw value, so the very first field already
//     fails — the ceiling assertion on the `upperBound * 1e6` probe and the floor assertion on
//     the `-1e6` probe. ⛔ "both bound assertions fail" stood here; per PROBE exactly one of
//     the two fails (a huge value passes the floor, a negative one passes the ceiling). Both
//     fail only when read across both probes of the same field. FORWARD it is not: the door,
//     the type and the encoder all predate this commit; only the clamp is new.
//   · `testAStoredLFORateCannotLatchTheOscillatorIntoNaN` — REWRITTEN by #1207b, and the
//     reason is worth keeping: #1207's counterweight asserted that a RAW 3.4e38 rate still
//     latches the oscillator, and #1207b's `next()` fix made that FALSE. Its own message said
//     what to do ("either the oscillator gained its own guard — good, say so here — or this
//     counterweight has stopped measuring anything"), and this is that. The hazard proof now
//     runs against `OldWrapLFO`, a TRANSCRIPTION of the pre-fix wrap, so it can never be
//     "fixed" out from under the claim — the same device `applyOldPromptBounds` uses at the
//     top of this file. Grading: the decode assertion and the three `next()` assertions
//     (huge / hostile-negative / NaN rate) are REGRESSIONS on the parent; the transcription
//     counterweight and the five-rate BIT-IDENTITY sweep are green on both trees, and the
//     second of those is what makes the wrap change safe rather than merely safe-sounding
//     (verified in float32 at 0,25 / 0,6 / 2 / 6,5 / 20 Hz before pushing).
//   · `testTheThreeRowlessFieldsAreBoundedToo` (#1207b) — REGRESSIONS on the #1207 tree too,
//     not only on its parent: `outputLevel`, `warmthDrive` and `timbreBlend` had no `Bounds`
//     entry, so #1207 shipped clamping 17 of the 20 decoded fields that reach the render.
//     `outputLevel` is the one that mattered — a per-sample multiplier on every voice whose
//     `didSet` rejects only NON-finite. Its two nil-counterweights and the row-chain needle
//     are green on the #1207 tree and red on ITS parent (the row held a literal there).
//   · STRIPPER: PROPHYLAKTISCH — 0 flips of 38 verdicts (19 needles x 2 trees), measured, not
//     assumed. No retracted spelling of these needles
//     is quoted anywhere in either source file, measured raw vs. `codeOnly` on both trees. Said
//     rather than claimed — three slices in a row once claimed load-bearing without measuring.
//   · `moved-needles.py` REPORTS ONE HIT AND IT IS ANSWERED, NOT IGNORED (#1092): the string
//     `typealias B = SynthPatch.Bounds` left `Sources/` with this commit and still occurs in
//     this file — inside the `fields` helper, as THIS TEST'S OWN Swift. It is not a needle;
//     the needle is `typealias B = Bounds`, against `SynthPatch.swift`.
//     ⛔ TWO CORRECTIONS #1207b OWES THIS BULLET. It cited a LINE NUMBER, which this repo's
//     own law says is a date and not a fact — it was already off by six when written. And it
//     said "exactly one `contains("typealias` in the file", a recipe that FALSIFIES ITSELF:
//     writing it put a second occurrence in the prose, so running it returns two. The durable
//     claim is the one that does not count its own sentence — exactly one such needle stands
//     in CODE, and it names the new spelling.
//   · `moved-needles.py` REPORTS TWO MORE HITS AFTER #1207b, both `[still in Sources]`, and
//     both are ANSWERED: `if phase >= 1.0 {` and `phase -= 1.0` occur in this file as the body
//     of `OldWrapLFO`, a deliberate TRANSCRIPTION of the pre-fix oscillator — Swift, not
//     needles. Nothing scans for them. They also still occur in `Sources/`, in
//     `EchoelEntrainment.process`, which is a different and unreachable instance of the same
//     shape (its rate is a five-case enum `switch`) — see `EchoelLFO.next()`'s doc for why it
//     is left alone.
//   · WHAT NO TEST HERE CAN SHOW: that a clamped project file sounds like the one the sender
//     saved. A file written by THIS app cannot be out of range (its rows are bounded by the
//     same constant), so the only patch this can alter is one Echoel did not write.

import Foundation
import XCTest
@testable import Echoelmusic

final class OneDefinitionOfAParameterRangeTests: XCTestCase {

    // MARK: - The pre-#441 prompt bounds, kept here as the reference to measure against

    /// ⚠️ `min(max(…))` here ON PURPOSE — this is the HISTORICAL arithmetic, transcribed exactly
    /// as it stood before #441, not new code. The house rule (`Core/FloatingPointClamp.swift`)
    /// says never to write it on a live path because it passes NaN through; a reference
    /// implementation that "fixed" it would stop being a reference.
    ///
    /// Every old bound is a SUBSET of its new one (two are strictly narrower, fifteen are equal),
    /// which is what makes `testTheChangeIsInertExceptForTheTwoNamedFields` exact without
    /// reimplementing `shape`: clamping is monotone and idempotent, so applying the OLD bounds to
    /// the NEW result is bit-identical to what the old `clamp` produced from the same raw shape.
    ///
    /// ⚠️ AND THE PRICE OF THAT ARGUMENT, said rather than left for a reader to notice: on the
    /// fifteen fields where old == new, re-clamping is the IDENTITY, so that test cannot fail on
    /// today's tree. It is a counterweight against a future mis-transcription, not evidence about
    /// this change — and it is blind in the NARROWING direction for the same reason (a value
    /// already inside a smaller range comes back unchanged). The narrowing direction is guarded by
    /// the data sweep and the one hand-written ceiling further down, not here.
    private func applyOldPromptBounds(_ p: SynthPatch) -> SynthPatch {
        var q = p
        func c01(_ x: Float) -> Float { min(max(x, 0), 1) }
        q.brightness = c01(q.brightness)
        q.harmonicity = c01(q.harmonicity)
        q.harmonicLevel = c01(q.harmonicLevel)
        q.noiseLevel = c01(q.noiseLevel)
        q.sustain = c01(q.sustain)
        q.reverbMix = c01(q.reverbMix)
        q.filterResonance = c01(q.filterResonance)
        q.lfoToFilterDepth = c01(q.lfoToFilterDepth)
        q.filterLFODepth = c01(q.filterLFODepth)
        q.vibratoDepth = c01(q.vibratoDepth)
        q.attack = min(max(q.attack, 0.001), 5)
        q.decay = min(max(q.decay, 0.0), 10)
        q.release = min(max(q.release, 0.0), 10)
        q.filterCutoff = min(max(q.filterCutoff, 20), 18_000)
        q.filterLFORate = min(max(q.filterLFORate, 0), 12)
        q.reverbDecay = min(max(q.reverbDecay, 0), 10)
        q.vibratoRate = min(max(q.vibratoRate, 0), 12)
        return q
    }

    /// The seventeen fields the Sound panel renders, each with its bound and a reader — one place
    /// to add a row, so a new parameter cannot be half-covered.
    private struct Field {
        let name: String
        let bound: ClosedRange<Float>
        let read: (SynthPatch) -> Float
        let write: (inout SynthPatch, Float) -> Void
    }

    /// ⚠️ BUILT BY `append`, NOT AS ONE ARRAY LITERAL, and that is not style: seventeen
    /// initializers carrying thirty-four closures in a single expression is exactly the shape
    /// that made the blocking gate red in #287 ("expression too complex to type-check"). One
    /// statement per row costs nothing and cannot hit it.
    private var fields: [Field] {
        typealias B = SynthPatch.Bounds
        var out: [Field] = []
        out.append(Field(name: "brightness", bound: B.brightness,
                         read: { $0.brightness }, write: { $0.brightness = $1 }))
        out.append(Field(name: "harmonicity", bound: B.harmonicity,
                         read: { $0.harmonicity }, write: { $0.harmonicity = $1 }))
        out.append(Field(name: "harmonicLevel", bound: B.harmonicLevel,
                         read: { $0.harmonicLevel }, write: { $0.harmonicLevel = $1 }))
        out.append(Field(name: "noiseLevel", bound: B.noiseLevel,
                         read: { $0.noiseLevel }, write: { $0.noiseLevel = $1 }))
        out.append(Field(name: "filterCutoff", bound: B.filterCutoff,
                         read: { $0.filterCutoff }, write: { $0.filterCutoff = $1 }))
        out.append(Field(name: "filterResonance", bound: B.filterResonance,
                         read: { $0.filterResonance }, write: { $0.filterResonance = $1 }))
        out.append(Field(name: "lfoToFilterDepth", bound: B.lfoToFilterDepth,
                         read: { $0.lfoToFilterDepth }, write: { $0.lfoToFilterDepth = $1 }))
        out.append(Field(name: "filterLFORate", bound: B.filterLFORate,
                         read: { $0.filterLFORate }, write: { $0.filterLFORate = $1 }))
        out.append(Field(name: "filterLFODepth", bound: B.filterLFODepth,
                         read: { $0.filterLFODepth }, write: { $0.filterLFODepth = $1 }))
        out.append(Field(name: "attack", bound: B.attack,
                         read: { $0.attack }, write: { $0.attack = $1 }))
        out.append(Field(name: "decay", bound: B.decay,
                         read: { $0.decay }, write: { $0.decay = $1 }))
        out.append(Field(name: "sustain", bound: B.sustain,
                         read: { $0.sustain }, write: { $0.sustain = $1 }))
        out.append(Field(name: "release", bound: B.release,
                         read: { $0.release }, write: { $0.release = $1 }))
        out.append(Field(name: "reverbMix", bound: B.reverbMix,
                         read: { $0.reverbMix }, write: { $0.reverbMix = $1 }))
        out.append(Field(name: "reverbDecay", bound: B.reverbDecay,
                         read: { $0.reverbDecay }, write: { $0.reverbDecay = $1 }))
        out.append(Field(name: "vibratoRate", bound: B.vibratoRate,
                         read: { $0.vibratoRate }, write: { $0.vibratoRate = $1 }))
        out.append(Field(name: "vibratoDepth", bound: B.vibratoDepth,
                         read: { $0.vibratoDepth }, write: { $0.vibratoDepth = $1 }))
        return out
    }

    // MARK: - The defect, named and measured

    /// RED before #441: a user-set 19 Hz LFO rate came back as 12 Hz from a prompt that shapes
    /// nothing at all. `"lorem"` is in no vocabulary, so this isolates the UNCONDITIONAL clamp —
    /// the part that makes the old bound reachable without the user typing anything meaningful.
    func testAnUnrecognisedPromptCannotCutTheLFORate() {
        let patch = SynthPatch(name: "Test", filterLFORate: 19)
        let out = SoundPrompt.apply("lorem", to: patch)
        XCTAssertEqual(out.filterLFORate, 19, accuracy: 1e-6, """
            "Describe it" rewrote a 19 Hz filter LFO rate as \(out.filterLFORate) Hz on text the \
            engine does not even recognise. The row spans \
            \(SynthPatch.Bounds.filterLFORate.lowerBound)…\
            \(SynthPatch.Bounds.filterLFORate.upperBound) Hz, so 19 is a value a finger can set; \
            `SoundPrompt.apply` ends with an unconditional clamp, so a narrower bound there \
            destroys it.
            """)
    }

    /// The recognised-word half of the same defect. "evolving" adds 0.25 Hz, so the honest
    /// expectation is 19.25 — not "unchanged". Old behaviour: 12.
    func testARecognisedPromptShapesTheLFORateInsteadOfCappingIt() {
        let patch = SynthPatch(name: "Test", filterLFORate: 19)
        let out = SoundPrompt.apply("evolving", to: patch)
        XCTAssertEqual(out.filterLFORate, 19.25, accuracy: 1e-5, """
            "evolving" adds 0.25 Hz; from 19 Hz that is 19.25 and the row admits it. Got \
            \(out.filterLFORate).
            """)
    }

    /// The cosmetic half, included so it cannot rot unnoticed. Old behaviour: 0.001.
    func testTheAttackFloorIsTheRowsFloor() {
        let patch = SynthPatch(name: "Test", attack: 0)
        let out = SoundPrompt.apply("lorem", to: patch)
        XCTAssertEqual(out.attack, 0, accuracy: 1e-9, """
            The prompt still floors attack at its own value (\(out.attack) s) rather than the \
            row's 0. Inaudible either way — `EchoelDDSP` enforces a ~3 ms minimum ramp — but it \
            is a second definition of one range, which is the whole point of #441.
            """)
    }

    // MARK: - The general property

    /// Every field, at BOTH ends of its own row, survives a prompt that shapes nothing. This is
    /// the claim the two named cases are instances of; it is here so the next parameter added to
    /// `Bounds` is covered without anyone remembering to write a case for it.
    func testNoBoundOfAnyRowIsCutByAPrompt() {
        for f in fields {
            for edge in [f.bound.lowerBound, f.bound.upperBound] {
                var patch = SynthPatch(name: "Test")
                f.write(&patch, edge)
                let out = SoundPrompt.apply("lorem", to: patch)
                XCTAssertEqual(f.read(out), edge, accuracy: Swift.max(1e-6, abs(edge) * 1e-6), """
                    \(f.name) was set to \(edge) — a value its own row admits — and a prompt that \
                    shapes nothing returned \(f.read(out)). The prompt's bound is narrower than \
                    the row's, which means the panel offers reach it then takes away.
                    """)
            }
        }
    }

    // MARK: - Honest scope: what did NOT move

    /// The counterweight, and the reason this slice can be called inert outside the two named
    /// fields: over every shipped patch × every shipped suggestion, the result differs from the
    /// old arithmetic ONLY in `attack` and `filterLFORate`, and only where the old bound was
    /// actually biting. See `applyOldPromptBounds` for why re-clamping the new result is exact.
    func testTheChangeIsInertExceptForTheTwoNamedFields() {
        var moved: [String] = []
        var checked = 0
        for patch in SynthPatch.factory {
            for prompt in SoundPrompt.suggestions {
                let now = SoundPrompt.apply(prompt, to: patch)
                let before = applyOldPromptBounds(now)
                checked += 1
                for f in fields where f.name != "attack" && f.name != "filterLFORate" {
                    if f.read(now) != f.read(before) {
                        moved.append("\(patch.name)/\(prompt): \(f.name)")
                    }
                }
            }
        }
        XCTAssertGreaterThan(checked, 0, "The sweep did not run — a green below proves nothing.")
        XCTAssertEqual(moved.count, 0, """
            \(moved.prefix(5).joined(separator: ", ")) — a field OTHER than attack and \
            filterLFORate changed behaviour. #441 is a single-sourcing pass with two named \
            widenings; anything else moving means a bound was transcribed wrong.
            """)
    }

    /// The three shipped banks, named separately so the floor below can notice that ONE of them
    /// went empty — a single flat count cannot, because the factory bank alone clears any
    /// plausible total. Same three the sibling guard sweeps, for the same reason.
    private enum Bank: String, CaseIterable {
        case factory = "SynthPatch.factory"
        case library = "PatchLibrary.all"
        case genres  = "MusicStyle.allCases.synthPatch"

        func patches() -> [SynthPatch] {
            switch self {
            case .factory: return SynthPatch.factory
            case .library: return PatchLibrary.all.map { $0.patch }
            case .genres:  return MusicStyle.allCases.map { $0.synthPatch }
            }
        }
    }

    /// ⛔ THE GAP THIS CLOSES WAS FOUND BY ASKING WHAT THE TESTS ABOVE CANNOT SEE, and it is a
    /// gap #441 CREATED. Every check so far reads `Bounds` on both sides, so NARROWING a bound
    /// moves the row and the prompt together and nothing goes red — while the row would then clip
    /// a patch it used to reach. Before #441 the four full-call-text pins in
    /// `SoundRowsCanReachTheShippedPatchesTests` were the thing standing in the way of that, and
    /// #441 replaced their range half with a binding. So the constant has to be answerable to the
    /// DATA instead: every shipped patch value must fit inside its own bound. That is the same
    /// shape of claim the sibling guard makes against its hand-written table, and the two are not
    /// redundant — that one catches "the row drifted from the model", this one catches "the model
    /// AND the row drifted together".
    ///
    /// ⛔ AND THE FIRST VERSION SWEPT ONLY `SynthPatch.factory` WHILE CLAIMING — here, in the
    /// commit message, and in the sibling's comment — that "`Drone Bed`'s 6.0 s decay is the value
    /// that makes it bite". `Drone Bed` is NOT in that bank. It is built by
    /// `GenrePatches.patch("EE", "Drone Bed", … d: 6.0, …)` and reached through
    /// `MusicStyle.synthPatch`, a separate population that lands in `currentPatch` just the same.
    /// The factory bank's decay maximum is 1.5, so the guard had 85% slack on the one field it
    /// named and `Bounds.decay` could have been narrowed to `0...5` — the literal #430 defect —
    /// with every test in the repo green. **That is the same methodology error the sibling's own
    /// header records** ("the third source it NAMED, `MusicStyle.synthPatch`, was invisible to the
    /// scan"), committed in the slice that cites it, one paragraph after calling #430's reasoning
    /// "the wrong population". Measured over all three banks the maxima are: decay 6.0 (Drone Bed),
    /// release 7.5, reverbDecay 8.5, filterCutoff 8000, attack 3.5, vibratoRate 6.2.
    func testEveryShippedPatchFitsInsideItsOwnBound() {
        var outside: [String] = []
        for bank in Bank.allCases {
            let patches = bank.patches()
            XCTAssertFalse(patches.isEmpty, """
                \(bank.rawValue) is empty — a bank that vanishes takes its coverage with it and \
                leaves the remaining ones looking sufficient.
                """)
            for patch in patches {
                for f in fields where !f.bound.contains(f.read(patch)) {
                    outside.append("\(bank.rawValue)/\(patch.name).\(f.name) = \(f.read(patch)) ∉ \(f.bound)")
                }
            }
        }
        XCTAssertEqual(outside.count, 0, """
            \(outside.prefix(5).joined(separator: ", ")) — a shipped patch holds a value its own \
            row cannot reach. Widen the bound; NEVER round the patch (#430 paid that once: a \
            narrower bound rewrote `Drone Bed`'s 6.0 s decay as 5.0 on first touch).
            """)
    }

    /// ⚠️ AND THE DATA SWEEP ABOVE CANNOT GUARD THE FIELD THIS SLICE EXISTS FOR. Measured across
    /// all three banks, the highest shipped `filterLFORate` is **1.2 Hz** — so re-narrowing the
    /// bound to the old `0...12` leaves every patch comfortably inside and every other test in
    /// this file green, while the row silently loses 8 Hz of reach. The value #441 rescued was a
    /// USER-SET 19 Hz, and no fixture holds a user-set value; that is the whole shape of the
    /// defect. So this one ceiling is pinned by hand, as the independent authority the data
    /// cannot be.
    ///
    /// ⚠️ DELIBERATELY ONE FIELD AND NOT SEVENTEEN. #430 recorded the reason in this same bundle:
    /// pinning every constant makes an ordinary panel edit red, and that is how a guard gets
    /// deleted rather than obeyed. Pinned here is the single bound whose shipped maximum sits far
    /// enough below it that nothing else would notice the loss.
    func testTheLFORateCeilingIsPinnedBecauseNoShippedPatchReachesIt() {
        XCTAssertEqual(SynthPatch.Bounds.filterLFORate.upperBound, 20, accuracy: 1e-6, """
            The patch filter-LFO row's ceiling moved. If it went back to 12, that is #441 undone: \
            a finger can set 19 Hz, `SoundPrompt.apply` ends in an unconditional clamp, and no \
            shipped patch goes above 1.2 Hz — so nothing else in this repo would go red.
            """)
        let shippedMax = Bank.allCases
            .flatMap { $0.patches() }
            .map(\.filterLFORate)
            .max() ?? 0
        XCTAssertLessThan(shippedMax, 12, """
            A shipped patch now reaches \(shippedMax) Hz, at or above the OLD prompt ceiling. The \
            premise of this hand-written pin — that the data cannot see a re-narrowing — no longer \
            holds, so fold this back into the data sweep instead of keeping a second copy.
            """)
    }

    // MARK: - The wiring (source scans, and they say so)

    /// The seventeen rows read the constant rather than a literal. A substring rather than the
    /// whole call text on purpose — #430's sibling guard pins full call sites and pays for it on
    /// every reformat; this one only needs the BINDING to survive.
    func testEveryRowReadsTheSharedBound() throws {
        let text = try source("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        for f in fields {
            XCTAssertTrue(text.contains("SynthPatch.Bounds.\(f.name)"), """
                The Sound panel's \(f.name) row no longer reads `SynthPatch.Bounds.\(f.name)`. \
                If it went back to a literal, that is the third spelling returning — and the \
                prompt will drift away from it again without anything going red.
                """)
        }
    }

    /// And so does the writer on the other side of the same panel — but SINCE #1207 it does
    /// it by CALLING the one applier instead of holding its own copy of the list.
    ///
    /// ⛔ THE SEVENTEEN `clamped(to: B.<field>)` NEEDLES USED TO POINT AT `SoundPrompt.swift`
    /// AND NOW POINT AT `SynthPatch.swift`. That is not a weakening: #1207 needed the SAME
    /// seventeen lines in the decoder, and a second copy is precisely how a bounded field
    /// added later gets clamped on one path and forgotten on the other (#416). The needles
    /// moved with the code in the same commit (#456) rather than being deleted; what this
    /// test asserts is unchanged in substance — every bounded field is folded into the
    /// shared constant, by a writer that does not restate the number.
    func testThePromptClampReadsTheSharedBound() throws {
        let patchSource = try source("Sources/Echoelmusic/DSP/SynthPatch.swift")
        XCTAssertTrue(patchSource.contains("typealias B = Bounds"), """
            `SynthPatch.clampToBounds` no longer aliases `Bounds`. It is the ONE writer that
            folds a patch into the range its rows offer; if it grows its own numbers again,
            #441 is undone.
            """)
        for f in fields {
            XCTAssertTrue(patchSource.contains("clamped(to: B.\(f.name))"), """
                `SynthPatch.clampToBounds` no longer clamps \(f.name) into the shared bound. \
                Both the "Describe it" prompt and the project-file decoder route through this \
                one function, so a field dropped here is unbounded on BOTH paths at once.
                """)
        }

        let promptSource = try source("Sources/Echoelmusic/DSP/SoundPrompt.swift")
        XCTAssertTrue(promptSource.contains("p.clampToBounds()"), """
            `SoundPrompt.clamp` no longer routes through `SynthPatch.clampToBounds()`. If it \
            grew its own list back, the prompt and the decoder can drift apart field by \
            field — which is the #416 defect this call site exists to prevent.
            """)
    }

    /// #1207 — THE DECODER IS THE THIRD WRITER, and it was the one with no bound at all.
    /// END-TO-END BEHAVIOUR (§1): real `JSONEncoder`/`JSONDecoder` on the shipped pure
    /// value type, no mocks, no view.
    ///
    /// The memberwise init stays UNCLAMPED on purpose — every in-app producer already
    /// writes through a bounded row — so encoding an out-of-range patch really does put the
    /// raw number in the JSON, and only the decode can pull it back.
    func testAPatchFileCannotCarryAValueTheRowRefuses() throws {
        for f in fields {
            let probes: [Float] = [f.bound.upperBound * 1e6, -1e6]
            for raw in probes {
                var wild = SynthPatch(name: "Wild")
                f.write(&wild, raw)
                let data = try JSONEncoder().encode(wild)
                XCTAssertTrue(String(data: data, encoding: .utf8)?.contains("\"\(f.name)\"") == true,
                              "\(f.name) is not in the encoded JSON — this row proves nothing.")
                let back = try JSONDecoder().decode(SynthPatch.self, from: data)
                let got = f.read(back)
                XCTAssertGreaterThanOrEqual(got, f.bound.lowerBound, """
                    A decoded patch carries \(f.name) = \(got), below its row's floor of \
                    \(f.bound.lowerBound). A project file is user-supplied: `EchoelStudioView`'s \
                    "Open project" `.fileImporter` hands it to `ProjectStore.importProject`, and \
                    the decoded `SynthPatch` goes straight to `apply(to:)`.
                    """)
                XCTAssertLessThanOrEqual(got, f.bound.upperBound, """
                    A decoded patch carries \(f.name) = \(got), above its row's ceiling of \
                    \(f.bound.upperBound). Same live door as the floor message above.
                    """)
            }
        }
    }

    /// The NAMED consequence (#367) — this is why the decode clamp is worth a slice rather
    /// than being tidy. `filterLFORate` is not merely "wrong sounding" out of range: it
    /// LATCHES. `apply(to:)` writes it raw to `EchoelLFO.rate`, and `next()` does
    /// `phase += rate / sampleRate` with the wrap gated on `phase >= 1.0`, so a huge rate
    /// walks `phase` up without bound (the `-= 1.0` is a no-op at that magnitude) until
    /// `sinf` sees `inf` and returns NaN on every sample after.
    ///
    /// ⚠️ TWO DIFFERENT MILESTONES, MEASURED IN FLOAT32, and the SOUND dies at the earlier
    /// one: the argument `phase * 2 * .pi` overflows on sample **7 646** (0,159 s at
    /// 48 kHz) while `phase` is still finite; `phase` itself only becomes `+inf` on sample
    /// **48 064** (1,0013 s). The 50 000-sample budget below is sized against the LATER
    /// figure on purpose — it must hold even if a future `Float`-precision detail moves the
    /// earlier one — so the counterweight has ~42 000 samples of headroom today, not 2 000.
    ///
    /// ⚠️ NO NaN IS NEEDED AND NONE COULD BE DELIVERED: `JSONDecoder`'s
    /// `nonConformingFloatDecodingStrategy` defaults to `.throw`, so JSON cannot carry one.
    /// A large FINITE number is the entire vector, and JSON carries those happily.
    func testAStoredLFORateCannotLatchTheOscillatorIntoNaN() throws {
        let json = Data(#"{"name":"Hostile","filterLFORate":3.4e38}"#.utf8)
        let decoded = try JSONDecoder().decode(SynthPatch.self, from: json)
        XCTAssertLessThanOrEqual(decoded.filterLFORate, SynthPatch.Bounds.filterLFORate.upperBound,
                                 "A file-supplied LFO rate reached the voice unbounded.")

        XCTAssertFalse(lfoGoesNonFinite(rate: decoded.filterLFORate), """
            The LFO produced a non-finite sample from the DECODED rate \(decoded.filterLFORate) Hz.
            """)

        // #1207b, the DEFENCE IN DEPTH the review asked for: the decode clamp guards the FILE
        // path, `next()`'s wrap guards the oscillator whatever any writer hands it. Both, not
        // either — a clamp is path-specific and `EchoelLFO.rate` has exactly one writer TODAY,
        // which is a fact about today rather than an invariant.
        XCTAssertFalse(lfoGoesNonFinite(rate: 3.4e38), """
            An UNBOUNDED rate still walks the oscillator to a non-finite phase. `next()`'s wrap \
            is supposed to be total: `phase -= phase.rounded(.down)` for a finite phase, 0 for a \
            non-finite one, entered through the NEGATED test so a NaN phase cannot skip it.
            """)
        XCTAssertFalse(lfoGoesNonFinite(rate: -3.4e38),
                       "A hostile NEGATIVE rate still strands the phase.")
        XCTAssertFalse(lfoGoesNonFinite(rate: .nan),
                       "A NaN rate still latches the phase — the negated wrap test is the point.")

        // COUNTERWEIGHT 1 (§2/#343) — the hazard was REAL. The old wrap is transcribed here
        // rather than driven from `Sources/`, for the reason `applyOldPromptBounds` above gives:
        // a reference implementation stops being a reference once it is "fixed".
        XCTAssertTrue(oldWrapGoesNonFinite(rate: 3.4e38), """
            The transcribed PRE-#1207b wrap no longer reproduces the defect. Either the \
            transcription drifted from `if phase >= 1.0 { phase -= 1.0 }` or Float semantics \
            changed; re-derive before trusting the assertions above.
            """)

        // COUNTERWEIGHT 2 — and this is the one that makes the fix safe rather than merely
        // safe-sounding: for every rate the app actually uses, the new wrap is BIT-IDENTICAL
        // to the old one. Verified in float32 before shipping at 0.25 / 0.6 / 2 / 6.5 / 20 Hz —
        // the shipped writers (`EchoelDelay` 0.6 + 6.5, `EchoelModFX` 0.25/0.4/0.6,
        // `EchoelFXChain` 0.45) and the row's ceiling.
        for rate in [Float(0.25), 0.6, 2, 6.5, 20] {
            let lfo = EchoelLFO(sampleRate: 48_000)
            lfo.rate = rate
            lfo.depth = 1
            var old = OldWrapLFO(rate: rate)
            for n in 0..<20_000 {
                let a = lfo.next(), b = old.next()
                if a != b {
                    XCTFail("""
                        The wrap changed a LEGITIMATE rate: at \(rate) Hz, sample \(n) is \
                        \(a) and was \(b). `phase -= phase.rounded(.down)` must subtract \
                        exactly 1.0 on [1, 2), so every ordinary rate is untouched.
                        """)
                    return
                }
            }
        }
    }

    /// #1207b — the THREE fields `Bounds` did not cover until the review found them. They have
    /// no Sound-panel row (only `outputLevel` does), so they are not in `fields`; each reaches
    /// the render path through the SAME `apply(to:)` and the SAME importer as the seventeen.
    func testTheThreeRowlessFieldsAreBoundedToo() throws {
        func decode(_ body: String) throws -> SynthPatch {
            try JSONDecoder().decode(SynthPatch.self, from: Data("{\"name\":\"X\",\(body)}".utf8))
        }

        // `outputLevel` multiplies EVERY sample of every voice (`synth.patchOutputLevel`), and
        // its `didSet` rejects only non-finite — so a finite 1e30 was a full-scale voice.
        // ⚠️ `XCTUnwrap`, not a bare `XCTAssertEqual`: `outputLevel` and `warmthDrive` are
        // `Float?`, and the accuracy overload takes a non-optional — writing it the obvious
        // way does not compile, which is the kind of thing a bundle with no local toolchain
        // only learns at the gate.
        let loud = try XCTUnwrap(try decode("\"outputLevel\":1e30").outputLevel)
        XCTAssertEqual(loud, SynthPatch.Bounds.outputLevel.upperBound, accuracy: 1e-6,
                       "A file-supplied outputLevel is unbounded — this is a loudness hazard.")
        let quiet = try XCTUnwrap(try decode("\"outputLevel\":-1e30").outputLevel)
        XCTAssertEqual(quiet, SynthPatch.Bounds.outputLevel.lowerBound, accuracy: 1e-6,
                       "A negative outputLevel would invert the phase of every voice.")

        let cold = try XCTUnwrap(try decode("\"warmthDrive\":-5").warmthDrive)
        XCTAssertEqual(cold, 0, accuracy: 1e-6,
                       "warmthDrive drives `analogWarmth`, which clamps nothing downstream.")
        let hot = try XCTUnwrap(try decode("\"warmthDrive\":900").warmthDrive)
        XCTAssertEqual(hot, 1, accuracy: 1e-6)
        XCTAssertEqual(try decode("\"timbreBlend\":9").timbreBlend, 1, accuracy: 1e-6,
                       "timbreBlend is the raw weight in `a * (1 - blend) + tap * blend`.")

        // COUNTERWEIGHT — the two OPTIONALS keep their `nil`. Folding a MISSING value onto a
        // bound would invent a trim the patch never asked for, and `nil` means unity / clean.
        let bare = try decode("\"attack\":0.5")
        XCTAssertNil(bare.outputLevel, "An absent outputLevel must stay nil (= unity), not 0.3.")
        XCTAssertNil(bare.warmthDrive, "An absent warmthDrive must stay nil (= clean), not 0.")

        // COUNTERWEIGHT — the shipped row and the bound are ONE constant (#441), so the number
        // a finger can reach is the number a file may keep.
        let rowSource = try source("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        XCTAssertTrue(rowSource.contains("range: SynthPatch.Bounds.outputLevel"), """
            The "Output" row went back to a literal range. It and `clampToBounds` would then \
            drift apart, and a decode clamp that disagrees with the row is worse than none — \
            it silently rewrites what the user just typed.
            """)
    }

    /// The chain, in the #426 form: the cutoff bound is not restated here, it IS the engine's.
    /// The load-bearing half is the SPELLING — a literal that happens to be equal today is a
    /// second definition that can drift tomorrow, and that is not hypothetical for this constant:
    /// `EchoelDDSP.cutoffRange`'s own doc records a "[20-20000 Hz]" comment that survived next to
    /// an 18000 clamp.
    ///
    /// ⚠️ The value assertion below CANNOT FAIL while the spelling holds — `Bounds.filterCutoff`
    /// is *defined* as `cutoffRange`, so the equality is definitional (#367). It stays as the
    /// thing that keeps meaning something if a later slice replaces the chain with a literal for
    /// portability (see the Accelerate note on `Bounds` itself); it is not a second detector.
    func testTheCutoffBoundIsChainedNotCopied() throws {
        XCTAssertEqual(SynthPatch.Bounds.filterCutoff, EchoelDDSP.cutoffRange,
                       "The panel's cutoff row and the engine's cutoff domain disagree.")
        let text = try source("Sources/Echoelmusic/DSP/SynthPatch.swift")
        XCTAssertTrue(text.contains("filterCutoff: ClosedRange<Float> = EchoelDDSP.cutoffRange"), """
            `SynthPatch.Bounds.filterCutoff` is written as a literal again instead of chaining to \
            `EchoelDDSP.cutoffRange`. Equal today is not the same as single-sourced.
            """)
    }

    // MARK: - Helpers

    /// Drive a real `EchoelLFO` and say whether it ever leaves the finite numbers.
    /// 50 000 samples ≈ 1,04 s at 48 kHz — past BOTH pre-fix milestones (7 646 and 48 064).
    private func lfoGoesNonFinite(rate: Float, samples: Int = 50_000) -> Bool {
        let lfo = EchoelLFO(sampleRate: 48_000)
        lfo.rate = rate
        lfo.depth = 1
        for _ in 0..<samples {
            if !lfo.next().isFinite { return true }
        }
        return false
    }

    /// The PRE-#1207b oscillator, transcribed exactly: `if phase >= 1.0 { phase -= 1.0 }`,
    /// sine only. ⚠️ Transcribed on purpose and NOT driven from `Sources/` — a reference
    /// implementation that is kept in step with the code it is measured against has stopped
    /// being a reference (the same note `applyOldPromptBounds` carries at the top of this file).
    private struct OldWrapLFO {
        var phase: Float = 0
        let rate: Float
        let sampleRate: Float = 48_000
        mutating func next() -> Float {
            phase += rate / sampleRate
            if phase >= 1.0 { phase -= 1.0 }
            return sinf(phase * Float.pi * 2)
        }
    }

    private func oldWrapGoesNonFinite(rate: Float, samples: Int = 50_000) -> Bool {
        var lfo = OldWrapLFO(rate: rate)
        for _ in 0..<samples {
            if !lfo.next().isFinite { return true }
        }
        return false
    }


    /// ⚠️ `SourceText.codeOnly`, not the raw file. This repo answers a removal with a ⛔ block that
    /// QUOTES the token it removed — `// ⛔ this row used to read SynthPatch.Bounds.decay` would
    /// satisfy every needle below over a reverted row. #453 made that one definition two commits
    /// before this slice, and the first version of this file scanned the raw text anyway.
    /// ⭐ AND IT STOPPED BEING PROPHYLACTIC IN THE SAME COMMIT THAT ADDED IT. Correcting the
    /// stale range note beside the Decay row put the literal string `SynthPatch.Bounds.decay`
    /// into a COMMENT in `EchoelStudioView.swift`. Measured: that needle now appears twice in the
    /// raw file and once in the code. Every other needle is 1/1, and all 17 clamp needles plus
    /// the chain needle survive stripping — so the guard is unchanged in verdict today, and one
    /// row away from having been satisfied by prose.
    private func source(_ relative: String) throws -> String {
        let raw = try String(contentsOf: repoRoot().appendingPathComponent(relative), encoding: .utf8)
        return SourceText.codeOnly(raw)
    }

    private func repoRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("repo root not found from \(#filePath)")
    }
}
