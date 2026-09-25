// TheAUv3FollowsTheHostSampleRateTests.swift
// Echoel — the audible half of board A10: the plug-in nailed 48 kHz. #1407.
//
// WHAT WAS WRONG. An AUv3 renders straight into the bus the HOST configured; there is no
// converter in between. `EchoelmusicAudioUnit` declared its output bus at 48 kHz in `init`
// — which is correct, something must be declared before a host has spoken — and then built
// both DSP engines at that same literal and never asked again. A host running at 44.1 kHz
// overwrites `outputBus.format`, the engines do not notice, and every partial comes out
// multiplied by 44100/48000 = 0,91875: roughly **8,1 % LOW (≈ 1,47 semitones FLAT)**, with
// the LFO and the envelopes 8,8 % SLOW.
//
// ⚠️ IT SURVIVED THE FIRST DEVICE SESSION BECAUSE OF WHERE IT WAS MEASURED. #1386 loaded the
// plug-in in AUM at 48 kHz and read 220,15 Hz against a 220 Hz default, +1,2 cents. Rates
// equal is the one case in which this defect is invisible. A device run proves the signal
// path it exercised, not the one it happened not to.
//
// #1406 WAS THE DEEPER HALF AND SHIPPED FIRST, on purpose: with the three sub-engine
// literals still inside `EchoelDDSP`, re-pointing the extension alone would NOT have fixed
// the pitch, because a freshly built `EchoelDDSP(44100)` still ran its filter, LFO and
// entrainment oscillator at 48 kHz. This slice is what remained.
//
// THE SHAPE, AND WHY IT IS NOT THE SHORTER ONE. The engines are re-pointed IN PLACE
// (`setSampleRate(_:)` on each type) rather than rebuilt. Writing
// `synth = EchoelDDSP(sampleRate: hostRate)` is three fewer methods and is exactly the move
// `EchoelDDSP.updateReverbDecay` forbids in its own comment: reseating a reference that the
// render thread dereferences raced ARC and crashed on device (EXC_BAD_ACCESS on the first
// Generate). Claim 7 pins that the repair kept the discipline.
//
// ⚠️ THE MAIN APP IS NOT AFFECTED AND MUST NOT BE "COMPLETED" INTO. Its voices feed
// `AVAudioSourceNode`s that DECLARE 48 kHz, and `AVAudioEngine` converts to whatever the
// hardware granted on their behalf — `AudioEngine.setupMasterEngine` builds its processing
// format from `outputNode.outputFormat(forBus: 0)`. The declared format is the contract and
// the engine already honours it. Claim 8 is the counterweight that says so, and it pins the
// CONTRACT (one constant feeds both the engine and the declared format) rather than banning
// a call — banning one would forbid a future slice that moves both together (#364).
//
// GRADING (§3). **This file does not compile against the parent tree**: claims 1–6 call
// `setSampleRate`, which this same commit creates. Per §3 that means NO assertion has a
// verdict there, and it is hand-transcribed instead — it must not be read as "green against
// its own tree" (#488). What WAS driven, in Python, against both trees:
//   · claim 5's subject — `EchoelEntrainment.process`'s wrap — exists on both, and the
//     transcription is a regression there: at a degenerate rate the parent's single
//     `phase -= 1.0` reaches `inf` and `cosf(inf)` is NaN, the repaired fold stays finite.
//   · claim 6 is a COUNTERWEIGHT and green on both: inside [0, 1) the two wraps agree
//     bit-exactly, so the shipping 48 kHz path is untouched.
//   · claims 7 and 8 are SOURCE-TEXT SCANS. 7 is red on the parent by anchor content (the
//     old `allocateRenderResources` names no rate at all); 8 is a counterweight, green on
//     both, and is the only assertion here about the APP rather than the extension.
//   · claims 2 and 3 are COUNTERWEIGHTS in substance — they assert the 48 kHz behaviour is
//     unchanged — but they cannot be graded on the parent, because the call they make to
//     say so does not exist there. Said plainly rather than booked as regressions (#433).
//
// ⚠️ `SourceText.codeOnly` is PROPHYLAKTISCH here, MEASURED rather than claimed (§2): all
// six body-scoped needles (claim 7's three positives, claim 9's three absences) return the
// same verdict raw and stripped — 0 of 6 flip. It stays because the brace extraction starts
// AT the declaration, so today's doc blocks sit outside the body by luck of placement, not
// by design; a single explanatory comment moved inside either member would make it
// load-bearing without anyone noticing. Three slices in a row claimed load-bearing without
// measuring and had to retract, so this one says the weaker, true thing.
//
// MUTATION-DRIVEN, not reasoned (#914 — what bites is the composition):
//   M1 store the rate without following the sub-engines → claim 9 (0/3 followed)
//   M3 reseat the three instead of mutating         → claim 9 (all three reseats named)
//   M4 re-point AFTER `noteOn`                      → claim 7 (ordering)
//   M5 restore the nailed 48000 in the extension    → claim 7 (no host read)
//   P1 a legitimate SECOND `setSampleRate` call site → stays GREEN (#364)
//
// ⚠️ LIMIT, STATED RATHER THAN IMPLIED: `Sources/EchoelmusicAUv3/` is a DIFFERENT TARGET and
// is not compiled into this bundle, so claim 7 can only read its text. Nothing here — and
// nothing in either CI gate — proves the plug-in loads at 44.1 kHz and sounds right. That is
// a DEVICE PROBE (§1) and is registered as open, not implied by a green run.
//
// ⭐ BUT THE EXTENSION IS NOT UNGATED, AND THE FIRST DRAFT OF THE PARAGRAPH ABOVE LEFT THAT
// OUT — an omission that reads as "nothing checks this at all". `project.yml` lists
// `- target: EchoelmusicAUv3` under the APP target's `dependencies:`, so `xcodebuild build`
// on scheme `Echoelmusic` builds the extension as a dependency: **`Xcode Compile Check`
// DOES compile `Sources/EchoelmusicAUv3/`**, in Release, for a device destination.
// Measured on this slice: run 35569964166 on `2328e06d4`, success. What is NOT gated is the
// extension's RUNTIME — loading in a host, and sounding in tune there. Say which of the two
// a green covers; §5b's own warning is that a session otherwise re-guesses this every time.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheAUv3FollowsTheHostSampleRateTests: XCTestCase {

    private static let ddsp = "Sources/Echoelmusic/DSP/EchoelDDSP.swift"
    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"
    private static let bioVoice = "Sources/Echoelmusic/Tools/BioReactiveSynthVoice.swift"

    /// A rate whose quotient is a power of two at BOTH test rates, so every expected value is
    /// exact in `Float` and the assertions can be equalities (#442). Same constant and the
    /// same reasoning as `TheSubEnginesFollowTheirParentsRateTests` — it is quoted rather
    /// than imported because these are two guards, not one, and a shared private helper
    /// across files is not a thing this bundle has.
    ///   11.71875 / 48000 = 2^-12     11.71875 / 24000 = 2^-11
    private static let exactRate: Float = 11.71875

    // MARK: - Claim 1 — the finding (END-TO-END BEHAVIOUR)

    /// Re-pointing a parent AFTER construction must move its sub-engines with it.
    ///
    /// This is the property the extension depends on: it builds at the placeholder 48 kHz in
    /// a property initialiser (where `self` is not visible) and corrects itself in
    /// `allocateRenderResources`. If the correction did not reach the sub-engines the pitch
    /// defect would survive the fix in a subtler form.
    func testRepointingAParentMovesItsSubEngines() {
        let engine = EchoelDDSP(sampleRate: 48000)
        let before = Self.firstSawtoothSample(of: engine)
        engine.setSampleRate(24000)
        let after = Self.firstSawtoothSample(of: engine)

        XCTAssertEqual(before, 2 * 0.000244140625 - 1, """
            A freshly built `EchoelDDSP(sampleRate: 48000)` no longer advances its filter \
            LFO by rate/48000 per sample. Either `EchoelLFO.next()`'s phase algebra changed \
            or #1406's repair in `EchoelDDSP.init` was undone.
            """)
        XCTAssertEqual(after, 2 * 0.00048828125 - 1, """
            `EchoelDDSP.setSampleRate(24000)` did not reach `filterLFO` — it kept advancing \
            as if the rate were still 48000. The AUv3 corrects itself through exactly this \
            call, so a sub-engine that does not follow puts the #1407 pitch defect back in a \
            harder-to-see form. The repair is in `EchoelDDSP.setSampleRate`, not here.
            """)
        XCTAssertEqual(after + 1, 2 * (before + 1), """
            Halving a parent's rate after construction must exactly double the LFO's \
            per-sample phase advance. Stated as a relation so a future re-tune of \
            `exactRate` cannot make the two equalities above pass for an unrelated reason.
            """)
    }

    // MARK: - Claim 2 — re-pointing equals constructing (END-TO-END BEHAVIOUR)

    /// `setSampleRate(r)` must leave the engine indistinguishable from `init(sampleRate: r)`.
    ///
    /// This is the claim that makes the in-place shape safe to prefer over a rebuild: if the
    /// two ever diverge, the cheap fix looks like "just rebuild it", which is the ARC reseat
    /// that crashed on device. The filter is the subject because it is the one sub-engine
    /// with a DERIVED coefficient (`g = tan(π · cutoff / sampleRate)`) — the two that merely
    /// divide per sample cannot diverge, so testing them here would prove nothing.
    func testRepointingIsIndistinguishableFromConstructing() {
        let repointed = EchoelDDSP(sampleRate: 48000)
        repointed.setSampleRate(24000)
        let native = EchoelDDSP(sampleRate: 24000)

        let a = Self.filterImpulseResponse(of: repointed)
        let b = Self.filterImpulseResponse(of: native)
        XCTAssertEqual(a, b, """
            A parent re-pointed to 24 kHz answers differently from one CONSTRUCTED at \
            24 kHz. `EchoelSVFilter` bakes the rate into `g`, so the setter must re-run \
            `updateCoefficients()`; if it only stores the number, the corner stays where \
            the old rate put it and the two diverge exactly here.
            """)

        let stillAt48k = Self.filterImpulseResponse(of: EchoelDDSP(sampleRate: 48000))
        XCTAssertNotEqual(a, stillAt48k, """
            The 24 kHz and 48 kHz filters answer IDENTICALLY, which means the rate is \
            reaching no coefficient at all. Without this counterweight the equality above \
            would pass on a tree where `setSampleRate` is a no-op (#367 — an assertion that \
            is green for a reason other than the one its message states).
            """)
    }

    // MARK: - Claim 3 — the shipping rate is untouched (COUNTERWEIGHT, END-TO-END)

    /// Re-pointing an engine to the rate it already has must change nothing at all.
    ///
    /// Every shipping path is 48 kHz today (the app's declared source-node format, and any
    /// host already running at 48 kHz), so this slice must be inaudible there. Driven over
    /// 64 samples rather than asserted.
    func testThe48kHzPathIsBitIdentical() {
        let touched = EchoelDDSP(sampleRate: 48000)
        touched.setSampleRate(48000)
        let untouched = EchoelDDSP(sampleRate: 48000)

        XCTAssertEqual(Self.filterImpulseResponse(of: touched),
                       Self.filterImpulseResponse(of: untouched), """
            Calling `setSampleRate(48000)` on an engine already at 48000 changed its \
            filter. The early-out (`guard clamped != sampleRate`) is what keeps the \
            shipping path bit-identical; without it every host at the default rate gets a \
            reset filter state for nothing.
            """)

        var a: [Float] = []
        var b: [Float] = []
        let lfoA = touched.filterLFO, lfoB = untouched.filterLFO
        for lfo in [lfoA, lfoB] { lfo.reset(); lfo.waveform = .sine; lfo.depth = 1; lfo.rate = Self.exactRate }
        for _ in 0..<64 { a.append(lfoA.next()); b.append(lfoB.next()) }
        XCTAssertEqual(a, b, "The filter LFO of a re-pointed-to-its-own-rate engine drifted.")
    }

    // MARK: - Claim 4 — the texture engine follows, and refuses nonsense (END-TO-END)

    /// `EchoelCellular` derives nothing at init, so its setter is an assignment — but a bad
    /// rate must be REFUSED rather than stored: `frequency / 0` is `inf` and `phases` would
    /// fill with NaN inside one block, with no sanitiser downstream in `render`.
    func testTheTextureEngineFollowsAndRefusesADegenerateRate() {
        let texture = EchoelCellular(cellCount: 64, sampleRate: 48000)
        texture.setSampleRate(44100)
        XCTAssertEqual(texture.sampleRate, 44100, """
            `EchoelCellular.setSampleRate` did not take. The AUv3's texture voice corrects \
            itself through this call, so the cellular layer would stay 8,1 % flat while the \
            synth followed the host — the two would beat against each other.
            """)

        for bad: Float in [0, -48000, .nan, .infinity] {
            texture.setSampleRate(bad)
            XCTAssertEqual(texture.sampleRate, 44100, """
                A rate of \(bad) was STORED instead of refused. The last known-good rate \
                must survive: a zero or non-finite divisor turns every phase increment \
                non-finite within one render block and `EchoelCellular.render` has nothing \
                downstream that could recover it.
                """)
        }
    }

    // MARK: - Claim 5 — the wrap this slice made reachable (END-TO-END BEHAVIOUR)

    /// `EchoelEntrainment.process` must stay finite at any rate, however small.
    ///
    /// ⭐ THIS IS A PRECONDITION OF THE SLICE, NOT A BATCHED EXTRA. `EchoelLFO.next()`'s own
    /// doc enumerated the two `phase >= 1.0 { phase -= 1.0 }` wraps in `Sources/` and argued
    /// the entrainment one was unreachable — correctly, about the NUMERATOR: the increment is
    /// `band.centerFrequency / sampleRate`, and the numerator is a five-case enum switch
    /// returning 2/6/10/20/40 that no file or setter can enlarge. It predicted that a slice
    /// making that frequency a parameter would owe the fix. #1407 made the DENOMINATOR
    /// writable instead, which reaches the same runaway from the other side. The durable
    /// lesson, written at the LFO too (#456): a reachability argument has as many halves as
    /// the expression has terms.
    ///
    /// With the single `phase -= 1.0`, an increment above 1 never folds back — the phase
    /// climbs every sample until it overflows to `inf`, `inf - 1.0` is `inf`, and `cosf(inf)`
    /// is NaN. The modulator then multiplies the signal by NaN forever.
    ///
    /// ⛔ THE FIRST DRAFT OF THIS ASSERTION WAS GREEN ON THE PARENT, i.e. vacuous for the
    /// exact defect it names (#367, the mirror case), and only DRIVING it said so. It used
    /// `sampleRate: 1e-30` for 10 000 calls, reasoning that a 4e31 increment would reach
    /// `Float.greatestFiniteMagnitude` quickly. It does not: 3,4e38 / 4e31 is **8,5 million**
    /// calls, not eight thousand — the arithmetic was off by three orders of magnitude, in
    /// the flattering direction. The rate below is measured rather than reasoned: at
    /// `4e-36` the increment is `1e37`, still FINITE (so this tests the FOLD, not a
    /// single-step overflow), and the phase goes non-finite on call **34**.
    func testADegenerateRateCannotMakeTheEntrainmentNonFinite() {
        let osc = EchoelEntrainment(sampleRate: 4e-36)
        osc.band = .gamma          // 40 Hz — the largest increment the enum can produce
        osc.depth = 0.5

        var last: Float = 0
        for _ in 0..<1_000 { last = osc.process(1.0) }

        XCTAssertTrue(last.isFinite, """
            `EchoelEntrainment.process` produced a non-finite sample. That is the #1207b \
            runaway the LFO was repaired for, in the file the LFO's own comment said was \
            safe: a single `phase -= 1.0` cannot fold an increment larger than 1, so the \
            phase climbs to `inf` and `cosf(inf)` is NaN. The fold must be total \
            (`phase - phase.rounded(.down)`) with an `isFinite` arm, because `inf - inf` is \
            NaN and every comparison against NaN is false, so the old form latches.
            """)
        XCTAssertGreaterThanOrEqual(last, 0.5 - 1e-6, "A depth of 0.5 cannot attenuate below 0.5.")
        XCTAssertLessThanOrEqual(last, 1.0 + 1e-6, "The isochronic envelope cannot exceed unity gain.")
    }

    // MARK: - Claim 6 — the normal path is unchanged (COUNTERWEIGHT, END-TO-END)

    /// Inside [0, 1) the repaired fold and the old single subtraction agree bit-exactly, so
    /// nothing a shipping rate can produce sounds different. Asserted against the algebra
    /// rather than against the other implementation (#442): after one call at 48 kHz the
    /// phase is exactly `band.centerFrequency / 48000`.
    func testTheOrdinaryRateIsUnchangedByTheFold() {
        let osc = EchoelEntrainment(sampleRate: 48000)
        osc.band = .alpha          // 10 Hz — the documented default band
        osc.depth = 1.0

        let out = osc.process(1.0)
        let phase: Float = 10.0 / 48000.0
        let expected = 1.0 - 1.0 + 1.0 * ((1.0 + cosf(phase * Float.pi * 2)) * 0.5)

        XCTAssertEqual(out, expected, accuracy: 1e-7, """
            At an ordinary rate the phase never leaves [0, 1), so the repaired fold must be \
            a no-op there. It is not, which means #1407's wrap changed the sound of every \
            shipping path instead of only the degenerate one.
            """)
    }

    // MARK: - Claim 7 — the extension asks the host (SOURCE-TEXT SCAN)

    /// `Sources/EchoelmusicAUv3/` is a different target and is not compiled into this
    /// bundle, so this is text, not behaviour — and it is the only assertion that can see
    /// the actual repair.
    func testTheAudioUnitRePointsItsEnginesBeforePlaying() throws {
        let code = SourceText.codeOnly(try rawText(Self.audioUnit))
        let body = try Self.bodyOfMember(
            startingWith: "public override func allocateRenderResources() throws {", in: code
        )

        XCTAssertTrue(body.contains("outputBus.format.sampleRate"), """
            `allocateRenderResources` no longer reads the host's bus format. That read IS \
            the #1407 repair: the 48000 in the property initialiser is a placeholder, and \
            without this line the plug-in is ~1,47 semitones flat in any 44,1 kHz session.
            """)
        XCTAssertTrue(body.contains("synth.setSampleRate("), "The synth is no longer re-pointed.")
        XCTAssertTrue(body.contains("texture.setSampleRate("), "The texture is no longer re-pointed.")

        // ORDER, not just presence: `noteOn` starts the idle tone, so a re-point after it
        // would start the tone at the wrong pitch and jump. (⛔ "`internalRenderBlock` also
        // derives `bioInterval` … when the host fetches it, which is after this method
        // returns" stood here: a host-ordering premise nothing enforced. Since P8w the
        // throttle is set in this method — claim 10.)
        let repoint = try XCTUnwrap(body.range(of: "synth.setSampleRate("), """
            anchor absent — the assertion above already reported it; this unwrap only keeps \
            the ordering check from reading as a pass it did not earn
            """)
        let noteOn = try XCTUnwrap(body.range(of: "synth.noteOn("), """
            `allocateRenderResources` no longer arms the idle voice. If that moved on \
            purpose, move this ordering check with it (#456) rather than deleting it.
            """)
        XCTAssertLessThan(repoint.lowerBound, noteOn.lowerBound, """
            The engines are re-pointed AFTER `noteOn`. The idle tone would then start at the \
            placeholder rate and shift once the correction lands — audible as a blip on \
            every instantiation, and only in hosts that are not at 48 kHz.
            """)
    }

    // MARK: - Claim 10 — the bio throttle follows the host rate at allocate (SOURCE-TEXT SCAN)

    /// ⭐ 2026-09-25 (overnight P8w). The render-side bio application runs every
    /// `sampleRate / 10` frames. That interval was a capture of the render-block GETTER, so it
    /// took whatever rate the synth had when the host FETCHED the block — right only if the
    /// host fetches after `allocateRenderResources`, which this class does not control; a block
    /// fetched at the 48 kHz placeholder and played at 96 kHz applied bio at ~20 Hz.
    /// Grading, parent `b09f6d1a7`: REGRESSION — one finding (the getter computed it there and
    /// allocate never set it). HOST: the fetch order of real hosts stays unmeasured; the repair
    /// removes the dependence on it.
    func testTheBioThrottleIsSetWhereTheRateIsKnown() throws {
        let code = SourceText.codeOnly(try rawText(Self.audioUnit))
        let allocate = try Self.bodyOfMember(
            startingWith: "public override func allocateRenderResources() throws {", in: code)
        let set = try XCTUnwrap(allocate.range(of: "bioRenderState.interval = BioRenderState.frames(forSampleRate: synth.sampleRate)"), """
            `allocateRenderResources` no longer sets the bio throttle from the host rate.
            """)
        let repoint = try XCTUnwrap(allocate.range(of: "synth.setSampleRate("),
                                    "the re-point moved — claim 7 reports it; this keeps the order check honest")
        XCTAssertLessThan(repoint.lowerBound, set.lowerBound,
                          "the throttle is derived before the synth has the host rate")
        let getter = try Self.bodyOfMember(startingWith: "public override var internalRenderBlock", in: code)
        XCTAssertFalse(getter.contains("synth.sampleRate"), """
            The render-block getter reads the synth's rate again. It runs when the HOST fetches \
            the block, which may be before allocate — the rate it sees can be the placeholder.
            """)
        XCTAssertTrue(getter.contains("bioState.frameAccum >= bioState.interval"),
                      "the render block no longer throttles against the allocate-time interval")
    }

    // MARK: - Claim 8 — the app is a different case (COUNTERWEIGHT, SOURCE-TEXT SCAN)

    /// The main app must NOT be "completed" into this change, and the durable way to say so
    /// is the CONTRACT rather than a ban: ONE constant feeds both the engine it builds and
    /// the format its `AVAudioSourceNode` declares, and `AVAudioEngine` converts from that
    /// declared format to whatever the hardware granted. Pinning the pair (#416) leaves a
    /// future slice free to move both together, which a "never call setSampleRate" scan
    /// would have forbidden (#364).
    func testTheAppsVoiceDeclaresTheRateItGeneratesAt() throws {
        let code = SourceText.codeOnly(try rawText(Self.bioVoice))

        XCTAssertTrue(code.contains("EchoelDDSP(sampleRate: Float(Self.sampleRate))"), """
            `BioReactiveSynthVoice` no longer builds its engine from `Self.sampleRate`.
            """)
        XCTAssertTrue(code.contains("AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate"), """
            `BioReactiveSynthVoice`'s source node no longer DECLARES the same constant its \
            engine generates at. That pair is why the app needs no host-rate follow-up at \
            all: the declared format is a contract and `AVAudioEngine` resamples to the \
            hardware rate on the voice's behalf. If the two ever name different numbers, \
            the app detunes silently — and unlike the AUv3 there is no host to blame.
            """)
    }

    // MARK: - Claim 9 — the repair kept the ARC discipline (SOURCE-TEXT SCAN)

    /// `EchoelDDSP.setSampleRate` must mutate its sub-engines, never replace them.
    ///
    /// The shorter code — assigning three fresh instances — is exactly what
    /// `updateReverbDecay` forbids twelve lines below, having been paid for with an
    /// EXC_BAD_ACCESS on device. A guard is warranted because the shorter version is what a
    /// reader reaches for first and it LOOKS correct.
    func testTheRatePathNeverReseatsASubEngine() throws {
        let code = SourceText.codeOnly(try rawText(Self.ddsp))
        let body = try Self.bodyOfMember(
            startingWith: "public func setSampleRate(_ newRate: Float) {", in: code
        )

        for type in ["EchoelSVFilter(", "EchoelLFO(", "EchoelEntrainment("] {
            XCTAssertFalse(body.contains(type), """
                `EchoelDDSP.setSampleRate` CONSTRUCTS a \(type.dropLast()). The render block \
                dereferences these objects; reseating such a reference from the control \
                plane raced ARC and crashed on device on the first Generate — the law is \
                written out at `updateReverbDecay` in this same file. Call the sub-engine's \
                own `setSampleRate` instead; it mutates in place.
                """)
        }

        let followed = ["filter.setSampleRate(", "filterLFO.setSampleRate(", "entrainment.setSampleRate("]
            .filter { body.contains($0) }
            .count
        XCTAssertEqual(followed, 3, """
            Only \(followed) of the three sub-engines is re-pointed. All three bake or \
            divide by the rate, so a missed one keeps computing at the old one — silently, \
            and only in a host that is not at 48 kHz.
            """)
    }

    // MARK: - Helpers

    /// One deterministic sample from a parent's filter LFO, sawtooth at unit depth.
    private static func firstSawtoothSample(of ddsp: EchoelDDSP) -> Float {
        let lfo = ddsp.filterLFO
        lfo.reset()
        lfo.waveform = .sawtooth
        lfo.depth = 1
        lfo.rate = exactRate
        return lfo.next()
    }

    /// Eight samples of a parent's filter answering a unit impulse, lowpass at 1 kHz. The
    /// cutoff is set AFTER any re-pointing so both engines under comparison carry the same
    /// requested corner and differ only in the rate that prewarps it.
    private static func filterImpulseResponse(of ddsp: EchoelDDSP) -> [Float] {
        let filter = ddsp.filter
        filter.reset()
        filter.mode = .lowpass
        filter.resonance = 0.3
        filter.cutoff = 1000
        var out: [Float] = []
        out.append(filter.process(1))
        for _ in 0..<7 { out.append(filter.process(0)) }
        return out
    }

    /// Thrown after an `XCTFail` so the calling claim stops; the failure is already recorded.
    private struct AnchorMissing: Error {}

    /// Brace-matched body extraction — NOT a fixed line window. This repo writes 30-40 line
    /// comment blocks and `SourceText.codeOnly` preserves line count, so any window is
    /// unsound by construction and gets worse as the prose grows (#408).
    private static func bodyOfMember(startingWith anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("""
                the declaration `\(anchor)` is not present — this guard reads a member body, \
                so a missed anchor FAILS rather than skipping (#1240). If the member was \
                renamed, re-anchor it here in the same commit (#456).
                """)
            throw AnchorMissing()
        }
        var depth = 0
        var body = ""
        for ch in code[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { body.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return body }
            }
        }
        XCTFail("unbalanced braces after `\(anchor)` — extraction cannot be trusted")
        throw AnchorMissing()
    }

    private func rawText(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("""
                \(relativePath) is not present — this guard inspects source text, so it SKIPS \
                rather than reporting a green it did not earn (#454)
                """)
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
