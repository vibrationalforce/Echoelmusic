// SleepingChainDoesNotHoardAudioTests.swift
// Echoel — falling asleep empties the signal path, so nothing stale can burst later. BLOCKING. #389.
//
// THE DEFECT, and it is the house's OWN rule applied one level up. `EchoelFXChain` states the
// SWITCH-CRACKLE RULE at the top of its own file (founder: "knistert beim Umschalten von
// Dingen"): a bypassed stage is skipped entirely, so its delay lines FREEZE holding old audio,
// and re-enabling it later would burst that stale audio into the mix — therefore every enable
// flag resets its stage on the rising edge. `PolySynthVoice`'s 2.5 s idle skip does exactly the
// same thing to the WHOLE chain and did NOT reset anything. `EchoelFXChain.noteRenderSkipped`'s
// own SCOPE paragraph said so in as many words and left it for its own slice: "The time-based
// stages (delay, reverb, tape) also freeze across a skip and can burst stale audio on resume …
// This hook is where such a fix would attach."
//
// ⭐ WHY THE REVERB TANK IS THE REAL PATH AND THE DELAY IS NOT — this was measured before it was
// built, and it corrects the task's own title. The idle skip engages only after 2.5 s of output
// below 1e-5, and:
//   • DELAY — already safe, and the existing argument in `PolySynthVoice` holds: the window
//     (2.5 s) is longer than `EchoelDelay`'s maximum gap (2.0 s), so if no repeat crossed the
//     floor within one full gap, every later repeat is peak × feedback (≤0.95) × damping,
//     i.e. strictly quieter.
//   • REVERB TAIL — also safe: a reverb tail decays MONOTONICALLY, so while it is audible the
//     output is above the floor and the counter resets every block. No tail is ever cut, however
//     long. ⛔ The first draft justified this with "`rt60` clamped to [0.1 … 30] s" — read off
//     `EchoelFDNReverb`, which has **ZERO instantiations in `Sources/`** (`grep -rn
//     "EchoelFDNReverb("` returns nothing; it is test-only DSP, like `EchoelModalBank` since
//     #167). The chain's reverb is `EchoelReverb` — Freeverb combs, decay knob `roomSize`. The
//     conclusion was right and its evidence came from a file with no production path, which is
//     the failure this repo pays for most often. The monotone-decay argument needs no number.
//   • REVERB TANK AT LOW MIX — the actual hole. The skip measures the chain OUTPUT. With
//     `reverb.mix` near zero the output can sit under the floor while the tank still holds
//     energy. Sleep then freezes that energy while the 30 Hz bio driver keeps writing
//     parameters; the next time something raises the mix, seconds-old audio walks out.
//     #386 is what made this reachable from the normal case — before it, nothing moved the
//     mix during ordinary play.
//
// WHAT SLEEPING MEANS, stated once so the fix is not mistaken for data loss: the chain's own
// `reset()` doc defines reset as "the signal path is empty". Entering sleep is the moment that
// becomes TRUE — everything the reset discards is, by the proof above, already inaudible at the
// current settings. The only way to ever hear it again is a later parameter change, and hearing
// it then means hearing 2.5-second-old audio. That is the burst, not the music.
//
// ⭐ A REAL BEHAVIOURAL TEST, not a source scan — unusual for this bundle and worth it here.
// `EchoelFXChain` is Foundation-only and `@testable import` reaches it, so this drives actual
// float buffers through the actual stages. It fails on the real symptom (audible output from a
// chain that was fed nothing), not on the presence of a line of code.
//
// NEEDS-FOUNDER-VERIFY: play until the take goes fully silent, wait ~3 s, then raise Reverb mix
// (or let a bio route raise it). No echo or wash of the previous take may appear — only silence
// until the next note.

import Foundation
import XCTest
@testable import Echoelmusic

final class SleepingChainDoesNotHoardAudioTests: XCTestCase {

    private let sampleRate: Float = 48000
    private let block = 512

    // MARK: - The defect, reproduced end to end

    /// ⭐ THE ONE THAT WOULD HAVE CAUGHT IT. Charge the tank at a mix low enough that the chain
    /// OUTPUT stays under the idle floor — the exact condition under which the voice decides to
    /// sleep — then sleep, then raise the mix the way a bio route does. A chain that hoarded the
    /// energy answers with audio it was never fed.
    func testRaisingTheMixAfterSleepCannotResurrectTheOldTake() {
        let chain = makeChain(reverbMix: 0.0008)

        // Charge: a loud burst goes in, but at ~0 mix almost nothing comes out.
        var quietestOutput: Float = 0
        for _ in 0..<24 {
            var l = burst(), r = burst()
            chain.processBuffer(left: &l, right: &r, frameCount: block)
            quietestOutput = max(quietestOutput, peak(l, r))
        }
        XCTAssertGreaterThan(quietestOutput, 0, """
            the charging phase produced literal digital zero, so this test never set up the \
            condition it claims to test. Check that the reverb is enabled and being fed.
            """)

        // Sleep. This is the transition `PolySynthVoice` performs when the idle counter expires.
        chain.noteRenderSleeping()

        // Resume the way the bio driver does: the mix comes up, and NOTHING is fed in.
        chain.reverb.mix = 0.9
        var maxAfter: Float = 0
        for _ in 0..<24 {
            var l = [Float](repeating: 0, count: block)
            var r = [Float](repeating: 0, count: block)
            chain.processBuffer(left: &l, right: &r, frameCount: block)
            maxAfter = max(maxAfter, peak(l, r))
        }

        XCTAssertLessThan(maxAfter, 1e-6, """
            a chain that was fed nothing produced \(maxAfter) after waking (#389).

            That is the previous take's energy, held in the reverb tank across a sleep and let \
            out by a mix change — the stale burst the SWITCH-CRACKLE RULE at the top of \
            EchoelFXChain.swift exists to prevent, arriving through the idle skip instead of \
            through a bypass toggle. Falling asleep must empty the signal path.
            """)
    }

    /// The same hole one stage earlier, because delay and reverb are reached by different
    /// parameters and a fix that only drained one would still pass the test above.
    func testTheDelayLineIsEmptyAfterSleepToo() {
        let chain = makeChain(reverbMix: 0)
        chain.delayEnabled = true
        chain.delay.timeSeconds = 0.75
        chain.delay.feedback = 0.9
        chain.delay.mix = 0.0008

        for _ in 0..<24 {
            var l = burst(), r = burst()
            chain.processBuffer(left: &l, right: &r, frameCount: block)
        }
        chain.noteRenderSleeping()
        chain.delay.mix = 0.9

        var maxAfter: Float = 0
        for _ in 0..<40 {          // > 0.75 s at 512/48k, so a held repeat would have to appear
            var l = [Float](repeating: 0, count: block)
            var r = [Float](repeating: 0, count: block)
            chain.processBuffer(left: &l, right: &r, frameCount: block)
            maxAfter = max(maxAfter, peak(l, r))
        }
        XCTAssertLessThan(maxAfter, 1e-6, """
            the delay line still held audio across a sleep and released it when the mix rose \
            (\(maxAfter)) — same defect as the reverb tank, different stage (#389).
            """)
    }

    // MARK: - The fix must not become a mute

    /// ⛔ THE FAILURE MODE OF THE FIX ITSELF, and the reason this test exists next to the two
    /// above: "drain everything on sleep" is one careless edit away from "drain everything on
    /// every skipped block", which would silence the instrument's first note after any pause.
    /// Sleeping empties the path; it must not disable it.
    func testTheChainStillPassesAudioAfterWaking() {
        let chain = makeChain(reverbMix: 0.25)
        chain.noteRenderSleeping()

        var l = burst(), r = burst()
        chain.processBuffer(left: &l, right: &r, frameCount: block)
        XCTAssertGreaterThan(peak(l, r), 0.01, """
            the chain produced (near) silence for a full-scale burst on the block after waking \
            (#389). Draining on sleep must leave the chain able to process — if this fails, the \
            drain is being applied to every skipped block, or a stage was left disabled.
            """)
    }

    /// The per-block hook and the once-per-sleep hook are different things and must stay so.
    /// `noteRenderSkipped` runs thousands of times while asleep; if IT drained, the cost would
    /// be paid every block for nothing, and the two would be impossible to tell apart later.
    func testThePerBlockSkipHookDoesNotDrain() {
        let chain = makeChain(reverbMix: 0.0008)
        for _ in 0..<24 {
            var l = burst(), r = burst()
            chain.processBuffer(left: &l, right: &r, frameCount: block)
        }
        chain.noteRenderSkipped()      // the per-block hook — must NOT empty the tank
        chain.reverb.mix = 0.9

        var maxAfter: Float = 0
        for _ in 0..<8 {
            var l = [Float](repeating: 0, count: block)
            var r = [Float](repeating: 0, count: block)
            chain.processBuffer(left: &l, right: &r, frameCount: block)
            maxAfter = max(maxAfter, peak(l, r))
        }
        XCTAssertGreaterThan(maxAfter, 1e-6, """
            `noteRenderSkipped` now drains the chain (#389). It is called on EVERY skipped \
            block, so draining there pays a full buffer clear thousands of times per sleep and \
            erases the distinction between "this block was skipped" and "the voice went to \
            sleep". The drain belongs in `noteRenderSleeping`, which fires once.
            """)
    }

    // MARK: - The drain must stay conditional (the race the first version shipped)

    /// ⛔ THE SHIP BLOCKER THE FIRST VERSION OF #389 CARRIED, and the only guard in this file
    /// that no behavioural test can replace — it is a THREADING invariant, and everything above
    /// drives the chain single-threaded.
    ///
    /// That version was `reset(); renderSkipped = true`. `EchoelFXChain.reset()` is documented
    /// CONTROL PLANE ONLY (see `snapFilterToTarget`: "two threads snapping the same `ParamGlide`
    /// structs is a race with no guard on it") and it resets all thirteen stages UNCONDITIONALLY.
    /// The second half is the one that breaks the file's own SWITCH-CRACKLE RULE: that rule is
    /// safe only because the control thread resets a stage exclusively while its flag is still
    /// FALSE — exactly when the audio thread is not touching it. Resetting DISABLED stages from
    /// the render block voids that, and puts both threads inside the same `[[Float]]` zero-fill.
    ///
    /// So: every reset in the drain must be gated on its own enable flag, and `reset()` /
    /// `snapFilterToTarget()` must not appear at all.
    func testTheDrainIsGatedOnEachStagesOwnEnableFlag() throws {
        let body = try codeLines("Sources/Echoelmusic/DSP/EchoelFXChain.swift")
        guard let start = body.firstIndex(where: {
            $0.contains("func noteRenderSleeping()")
        }) else {
            return XCTFail("""
                `noteRenderSleeping()` is gone from `EchoelFXChain`. If the idle drain was \
                removed, remove this file with it; if it was renamed, move this guard too.
                """)
        }
        let indent = body[start].prefix { $0 == " " }.count
        let close = body[(start + 1)...].firstIndex {
            $0.trimmingCharacters(in: .whitespaces) == "}"
                && $0.prefix { c in c == " " }.count == indent
        } ?? body.endIndex
        let drain = Array(body[(start + 1)..<close])

        for line in drain where line.contains(".reset()") {
            XCTAssertTrue(line.contains("if ") && line.contains("Enabled"), """
                a stage reset in `noteRenderSleeping` is no longer gated on its enable flag \
                (#389 Nachlese):
                    \(line.trimmingCharacters(in: .whitespaces))

                An UNgated reset from the render block clears stages the audio thread is not \
                touching — which is precisely when the control thread resets them on their \
                rising edge. Two threads in the same buffer zero-fill: an exclusivity trap, and \
                an index cleared against a half-cleared buffer, i.e. a stale-audio burst \
                produced by the fix for stale-audio bursts.
                """)
        }
        XCTAssertFalse(drain.contains(where: {
            $0.trimmingCharacters(in: .whitespaces) == "reset()"
        }), """
            `noteRenderSleeping` calls the whole-chain `reset()` again (#389 Nachlese). That is \
            the exact line that made this a ship blocker: control-plane-only, and unconditional \
            across all thirteen stages. Drain the ENABLED stages instead.
            drain: \(drain.map { $0.trimmingCharacters(in: .whitespaces) })
            """)
        XCTAssertFalse(drain.contains(where: { $0.contains("snapFilterToTarget()") }), """
            `noteRenderSleeping` snaps the tone-filter glide from the audio thread (#389 \
            Nachlese). `snapFilterToTarget` names itself CONTROL PLANE ONLY and says why. \
            `renderSkipped = true` alone is sufficient and correct: `advanceFilterGlide`'s \
            resume branch performs the identical snap inline, on the audio thread.
            """)
        XCTAssertTrue(drain.contains(where: {
            $0.trimmingCharacters(in: .whitespaces) == "renderSkipped = true"
        }), """
            the drain no longer re-arms `renderSkipped` (#389). Without it the first block after \
            waking GLIDES from a value the voice last heard seconds ago instead of landing on \
            the current target — the #138 Slice 2 sweep, reintroduced.
            """)
    }

    // MARK: - The caller

    /// ⛔ SOURCE-SCANNED ON PURPOSE, and only this one assertion is. The transition lives inside
    /// `PolySynthVoice`'s render block behind `nonisolated(unsafe)` audio-thread state that no
    /// test can drive without a running engine — so the behavioural tests above prove the chain
    /// keeps its half of the contract, and this proves the voice actually calls it. Without it,
    /// all four pass while nothing in the app ever sleeps cleanly.
    func testTheVoiceDrainsTheChainWhenItFallsAsleep() throws {
        let voice = try codeLines("Sources/Echoelmusic/Tools/PolySynthVoice.swift")
        guard let idx = voice.firstIndex(where: {
            $0.contains("idleQuietFrames >= Self.idleFrameThreshold")
        }) else {
            return XCTFail("""
                the idle-sleep transition is gone from `PolySynthVoice` — \
                `idleQuietFrames >= Self.idleFrameThreshold` no longer appears. If the skip was \
                removed, remove this guard with it; if it moved, move this guard too.
                """)
        }
        // The drain must sit in the transition itself, not somewhere else in the file that
        // happens to mention it: the whole point is "once, at the moment of falling asleep".
        let window = voice[idx..<min(idx + 4, voice.endIndex)]
        XCTAssertTrue(window.contains(where: { $0.contains("noteRenderSleeping()") }), """
            `PolySynthVoice` no longer drains the FX chain where it sets `renderIdle = true` \
            (#389).

            The chain-side tests in this file would all still pass — they drive the chain \
            directly. The app would go back to freezing the reverb tank and the delay line for \
            the whole sleep, and to letting a later mix change walk seconds-old audio out.
            transition: \(window.map { $0.trimmingCharacters(in: .whitespaces) })
            """)
    }

    // MARK: - Helpers

    private func makeChain(reverbMix: Float) -> EchoelFXChain {
        let chain = EchoelFXChain(sampleRate: sampleRate)
        chain.reverbEnabled = true
        chain.reverb.mix = reverbMix
        // `roomSize`, NOT `decayTime` — the chain's reverb is `EchoelReverb` (Freeverb combs,
        // whose decay knob is `roomSize`), not `EchoelFDNReverb` (which is the one with
        // `decayTime` clamped to [0.1 … 30] s). The first draft of this file wrote `decayTime`
        // here, having read the tail bound off the WRONG reverb while diagnosing #389. With no
        // local compiler that is a CI-only failure, so it is recorded rather than quietly fixed.
        chain.reverb.roomSize = 0.9
        // Off, so the assertions measure the time-based stages and not a limiter's recovery or
        // a saturator's colour. `limiterEnabled` defaults to TRUE — leaving it on would clamp
        // the burst and blunt the very peak these tests compare against.
        chain.limiterEnabled = false
        chain.compressorEnabled = false
        return chain
    }

    /// A full-scale-ish noise burst. Deterministic (a fixed recurrence, no `Random`) so a
    /// failure reproduces exactly — the house rule for anything that can end up in CI.
    private func burst() -> [Float] {
        var out = [Float](repeating: 0, count: block)
        var state: UInt32 = 0x9E3779B9
        for i in 0..<block {
            state = state &* 1_664_525 &+ 1_013_904_223
            out[i] = Float(Int32(bitPattern: state)) / Float(Int32.max) * 0.5
        }
        return out
    }

    private func peak(_ l: [Float], _ r: [Float]) -> Float {
        var p: Float = 0
        for v in l where abs(v) > p { p = abs(v) }
        for v in r where abs(v) > p { p = abs(v) }
        return p
    }

    private func codeLines(_ path: String) throws -> [String] {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources/Echoelmusic")
        guard FileManager.default.fileExists(atPath: sources.path) else {
            throw XCTSkip("""
                source tree not present at \(sources.path) — the caller assertion inspects \
                source text, so it SKIPS rather than reporting a green it did not earn
                """)
        }
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }
    // MARK: - #1196b: the drain is a BULK fill, not an element loop

    /// The drain this whole file is about runs ON THE AUDIO THREAD, and until #1196b it
    /// zeroed its ring buffers element by element. That is the part nobody had costed: the
    /// ⛔ block in `noteRenderSleeping` argues at length about the THREAD SAFETY of the resets
    /// it calls, and says nothing about how long they take.
    ///
    /// MEASURED WORST CASE. `EchoelDelay` takes `maxDelaySeconds: 2.0`, so one delay line is
    /// 131 072 floats per channel; granular, harmonizer, chorus, flanger and tape all bottom
    /// out in the SAME `EchoelDelayLine.reset()`; the reverb tank adds ~26 000 through a
    /// NESTED array-of-arrays loop. A full drain is on the order of 1.8 MB of Array-subscript
    /// stores — each with a bounds check, the loop with a uniqueness check — inside a 10.67 ms
    /// render deadline at 512 frames / 48 kHz. And it CONVOYS: `idleQuietFrames` advances per
    /// block, so when the composer stops, poly / lead / bass / touch cross the 2.5 s threshold
    /// in the SAME block.
    ///
    /// `.claude/rules/swift-audio.md` lists `memcpy`/`memmove` as SAFE on the audio thread and
    /// does not list an Array subscript loop. `update(repeating:)` is the bulk form; the
    /// result is bit-identical, it is the same zeroes written the fast way.
    ///
    /// ⚠️ THIS CLAIM DOES NOT WEAKEN THE OWNERSHIP RULE the rest of this file pins. Making the
    /// drain cheaper is not a licence to call it from both threads — `testTheDrainIsGatedOn\
    /// EachStagesOwnEnableFlag` above is still the load-bearing one.
    /// ⭐ THE TWO ABSENCE ASSERTIONS ARE HERE SINCE #1200, and the delay is worth recording
    /// because it is the shape of an honest tool debt. #1196b wanted them and withheld them:
    /// `scripts/moved-needles.py` had no polarity awareness, so it reported every absence
    /// needle as "[GONE from Sources]" forever, and a permanently red checker is exactly how
    /// `continue-on-error` stayed invisible for fourteen hours. `foreign-needles.py` had
    /// carried polarity since #1191; this was the half that did not. #1200 taught it, and the
    /// assertions came back in that same commit — as the withheld note instructed.
    ///
    /// WHAT THEY ADD, which is precisely what the note said was lost by waiting: someone could
    /// re-add the element loop while KEEPING the bulk fill, and the two positive assertions
    /// below would stay green. The result is a double zero-fill — slower than today, still
    /// correct, and not the regression this claim exists to catch.
    ///
    /// ⚠️ The retracted spellings appear here ONLY inside the absence assertions themselves.
    /// That is the #491 shape and it is deliberate: an absence assertion must name what it
    /// forbids. What must NOT happen is quoting the same spelling in the prose beside them —
    /// #1196b did exactly that and only survived because `codeLines` happens to strip comment
    /// lines, so a refactor of that helper would have reddened a correct tree.
    func testTheAudioThreadDrainUsesABulkFill() throws {
        let delay = try codeLines("Sources/Echoelmusic/DSP/EchoelDelayLine.swift").joined(separator: "\n")
        XCTAssertTrue(delay.contains("buffer.withUnsafeMutableBufferPointer { $0.update(repeating: 0) }"), """
            `EchoelDelayLine.reset()` is back to an element-by-element zero loop. It is called \
            from the audio thread by `noteRenderSleeping`, for up to 131 072 floats per \
            channel, and it is the shared bottom of delay, granular, harmonizer, chorus, \
            flanger and tape (#1196b).
            """)
        let reverb = try codeLines("Sources/Echoelmusic/DSP/EchoelReverb.swift").joined(separator: "\n")
        XCTAssertEqual(reverb.components(separatedBy: ".withUnsafeMutableBufferPointer { $0.update(repeating: 0) }").count - 1, 4, """
            `EchoelReverb.reset()` no longer bulk-fills all FOUR of its tanks (comb L/R, \
            allpass L/R). A nested array-of-arrays element loop pays two bounds checks per \
            store, on the audio thread (#1196b).
            """)
        // #1200 — the two ABSENCE halves, withheld by #1196b until the checker could tell a
        // satisfied retraction from a broken anchor. Without these, re-adding the loop BESIDE
        // the bulk fill stays green.
        XCTAssertFalse(delay.contains("for i in 0..<capacity { buffer[i] = 0 }"), """
            the element-by-element zero loop is back in `EchoelDelayLine.reset()`, alongside \
            the bulk fill. Both together zero the buffer twice: correct, slower than either \
            alone, and invisible to the positive assertion above.
            """)
        XCTAssertFalse(reverb.contains("for j in 0..<combBufL[i].count"), """
            the nested array-of-arrays element loop is back in `EchoelReverb.reset()`. The \
            comb-L tank is checked as the representative of the four: they were written and \
            removed together, and pinning one spelling is enough to catch the paste that \
            brings them back.
            """)
    }

    // MARK: - #1203: the bulk fill cannot make a concurrent reader TRAP

    /// #1196b's mandatory review left this open and named it exactly: the bulk fill did not
    /// change the PROBABILITY of the drain race, it changed its CONSEQUENCE.
    /// `withUnsafeMutableBufferPointer` swaps the array for the empty-storage singleton for
    /// the duration of the closure, so a concurrent reader indexes a zero-count array —
    /// `Index out of range`, a TRAP on the audio thread, where the element loop it replaced
    /// had only left a half-cleared buffer (a click).
    ///
    /// ⛔ IT HAPPENED IN TWO FILES AND #1203's FIRST DRAFT GATED ONE. Both mandatory reviewers
    /// found the same thing first and independently: `EchoelReverb.reset()` performs the
    /// identical swap on 24 tanks, its `comb`/`allpass` index them unguarded, and its subscript
    /// is a MUTATING one — so it runs the copy-on-write path on the audio thread before it
    /// traps. The reachability runs the wrong way round too: `EchoelFXChain`'s own cost table
    /// says `delayEnabled` defaults to FALSE while a typical sounding chain drains reverb.
    /// The file that got the analysis was the one usually switched off. This claim now covers
    /// BOTH, which is also why the four reverb bulk fills pinned by
    /// `testTheAudioThreadDrainUsesABulkFill` above no longer sit in this file un-answered.
    ///
    /// ⚠️ STATE THE LIMIT BEFORE THE CLAIM (§1). This is a NARROWING, not a fix. The gates
    /// remove the bulk of the window — a clear of up to 131 072 floats — but the count read
    /// and the subscript are two source-level accesses, and how they LOWER decides whether a
    /// seam survives at all. That is **UNMEASURED** and there is no toolchain here to measure
    /// it; `EchoelDelayLine.reset()` carries both bounds. ⛔ An earlier draft of this header
    /// asserted the gates "sit AT the index rather than at the top of its function" and called
    /// that "the whole size of the effect". Both halves were wrong — the assertion below only
    /// ever checked BEFORE, which a top-of-function gate also satisfies, and in `write` the
    /// gate IS the top of the function. Prose and assertion now say the same thing.
    ///
    /// ⚠️ AND THE UNDERLYING HAZARD IS UNTOUCHED, so nobody reads a green here as "handled":
    /// `fxEnabled` is still an unfenced `Bool`, and the thread disjointness still rests on
    /// source order. This file's `testTheDrainIsGatedOnEachStagesOwnEnableFlag` is still the
    /// load-bearing one.
    ///
    /// ⭐ #364 — THIS CLAIM MUST NOT OUTLIVE ITS STORAGE MODEL. It pins two spellings that are
    /// only meaningful while these lines store their samples in Swift `Array`s. Moving either
    /// to a manually managed `UnsafeMutablePointer` — which `EchoelDelayLine.reset()` names as
    /// the structural repair — or fencing `fxEnabled` so the gates are no longer the right
    /// shape is legitimate work; it must REWRITE this claim in the same commit, together with
    /// the ⛔/⚠️ blocks in both `reset()`s. The failure messages say so, so a red does not read
    /// as an order to revert.
    ///
    /// SOURCE-TEXT SCAN (§1). It proves where the gates sit, not that a race cannot fire.
    ///
    /// GRADING against `git show HEAD:<path>` (§3), transcribed in Python because there is no
    /// local toolchain (§0), driven over both trees:
    /// · TEN REGRESSIONS — the gate lookup and the ordering check in each of the five
    ///   accessors (three in `EchoelDelayLine`, two in `EchoelReverb`). Each is its own site,
    ///   not one absence counted ten times (#486): five different functions in two files.
    /// · SIX COUNTERWEIGHTS, green on both trees and the point of the file (#343) — the
    ///   `capacity` immutability, the `mask` derivation, the masked `writeIndex` store, the
    ///   two index-site count pins and the reverb wrap. Every one of them names a way to keep
    ///   the letter of a gate and lose its meaning.
    /// · ZERO anchor absences: all five signatures and all five index expressions resolve on
    ///   BOTH trees, so no assertion is red for a reason other than the one it gives (#367).
    func testEveryDrainedBufferIndexIsGatedOnRealStorage() throws {
        let delayFile = "Sources/Echoelmusic/DSP/EchoelDelayLine.swift"
        let delay = try codeLines(delayFile).joined(separator: "\n")
        let delayGate = "guard buffer.count == capacity else"

        // COUNTERWEIGHT: the gate compares against something the audio thread cannot see
        // change. If `capacity` ever became a `var`, the comparison would still read fine and
        // would stop meaning anything.
        XCTAssertTrue(delay.contains("private let capacity: Int"), """
            `EchoelDelayLine.capacity` is no longer an immutable `let`. Every gate added by \
            #1203 compares the live storage count against it, so a mutable `capacity` makes \
            all three gates vacuous while still reading as protection.
            """)

        // COUNTERWEIGHT: the gate is sufficient for the two READERS only because `mask`
        // already bounds their indices below `capacity`. Lose that and one comparison stops
        // covering four sites.
        XCTAssertTrue(delay.contains("self.mask = capacity - 1"), """
            `mask` is no longer `capacity - 1`. #1203's single `buffer.count == capacity` \
            gate per accessor is sufficient ONLY because the mask already guarantees \
            `idx < capacity`; without it each index needs its own bound.
            """)

        // ⭐ THE INVARIANT `write` ACTUALLY DEPENDS ON, and the one the first draft of this
        // claim left unpinned (mandatory review). `buffer[writeIndex]` is NOT masked at the
        // use site; it is in range only because the field is STORED masked. A change to a bare
        // `writeIndex &+ 1` would break `write` and no gate here would see it, because
        // `buffer.count == capacity` says nothing about `writeIndex`.
        XCTAssertTrue(delay.contains("writeIndex = (writeIndex &+ 1) & mask"), """
            `EchoelDelayLine.write` no longer stores `writeIndex` masked. That store is the \
            ONLY thing keeping its unmasked subscript in range — #1203's storage gate does \
            not check it (#1203, found by the mandatory review).
            """)

        // The three indexing accessors, each with the index expression the gate must precede.
        // Brace-matched bodies, not a line window (#408): this file carries 30-40 line comment
        // blocks and any fixed window is unsound by construction.
        // ⚠️ LIMIT: `codeLines` blanks only lines whose TRIMMED form starts with `//`, so a
        // trailing `// {` comment inside one of these bodies would desync the matcher. None
        // exists today; if one appears, this scan mis-scopes silently rather than failing.
        let accessors: [(String, String)] = [
            ("public func write(_ x: Float) {", "buffer[writeIndex] = x"),
            ("public func read(delaySamples: Float) -> Float {", "return buffer[idx0] *"),
            ("public func readAllpass(delaySamples: Float) -> Float {", "let s0 = buffer[idx0]"),
        ]
        for (signature, indexLine) in accessors {
            try Self.assertGatePrecedesIndex(
                gate: delayGate, signature: signature, indexLine: indexLine,
                code: delay, file: delayFile)
        }

        // COUNT PIN — the method says EVERY index, so it has to be able to see a new one.
        // Named accessors alone stay green when a fourth is added ungated (mandatory review).
        // Comment-stripped occurrences today: the store in `write`, two in `read`'s return,
        // and one each for `s0`/`s1` in `readAllpass`.
        XCTAssertEqual(delay.components(separatedBy: "buffer[").count - 1, 5, """
            the number of `buffer[` index sites in `EchoelDelayLine` changed. Every one of \
            them must sit behind a `\(delayGate)` gate, or the drain race can trap the audio \
            thread again (#1203). Add the gate, then update this number.
            """)

        // ---- the twin, gated in the same commit ----
        let reverbFile = "Sources/Echoelmusic/DSP/EchoelReverb.swift"
        let reverb = try codeLines(reverbFile).joined(separator: "\n")
        let reverbGate = "guard idx < buf.count else"

        let filters: [(String, String)] = [
            ("private func comb(_ input: Float, buf: inout [Float], idx: inout Int, store: inout Float) -> Float {",
             "let output = buf[idx]"),
            ("private func allpass(_ input: Float, buf: inout [Float], idx: inout Int) -> Float {",
             "let bufout = buf[idx]"),
        ]
        for (signature, indexLine) in filters {
            try Self.assertGatePrecedesIndex(
                gate: reverbGate, signature: signature, indexLine: indexLine,
                code: reverb, file: reverbFile)
        }

        // COUNT PIN, same argument. Two reads and two MUTATING stores; the mutating pair is
        // why this file is the worse shape — on the empty singleton the modify accessor runs
        // the copy-on-write path on the audio thread before it traps.
        XCTAssertEqual(reverb.components(separatedBy: "buf[").count - 1, 4, """
            the number of `buf[` index sites in `EchoelReverb` changed. Each must sit behind \
            a `\(reverbGate)` gate (#1203). Add the gate, then update this number.
            """)

        // COUNTERWEIGHT: the reverb gate is sufficient only because `idx` is never negative —
        // it is 0 or a wrapped increment. This is the wrap.
        XCTAssertEqual(reverb.components(separatedBy: "if idx >= buf.count { idx = 0 }").count - 1, 2, """
            `EchoelReverb`'s index wrap changed shape. `guard idx < buf.count` is a \
            sufficient bound ONLY because `idx` is 0 or a wrapped increment and so cannot be \
            negative (#1203).
            """)
    }

    /// One accessor, one gate: the gate must occur inside the brace-matched body and BEFORE
    /// the index expression. Shared by both files so the two halves cannot drift (#416).
    private static func assertGatePrecedesIndex(
        gate: String, signature: String, indexLine: String, code: String, file: String
    ) throws {
        let body = try XCTUnwrap(Self.body(after: signature, in: code), """
            `\(signature)` was not found in \(file), so this claim asserted nothing. \
            Re-anchor it before trusting a green (#926: a missed anchor returns empty and \
            every expectation over it passes).
            """)
        let gateAt = try XCTUnwrap(body.range(of: gate), """
            `\(signature)` in \(file) indexes its buffer without first checking that the \
            storage is the real one. `reset()` installs the empty-storage singleton for the \
            duration of its bulk fill, and the audio thread can be inside this accessor at \
            that moment — `Index out of range`, i.e. a TRAP on the audio thread (#1203). If \
            you replaced the Array storage or fenced `fxEnabled` so this gate is no longer \
            the right shape, rewrite this claim and the ⛔ blocks in BOTH `reset()`s in the \
            SAME commit (#364).
            """)
        let indexAt = try XCTUnwrap(body.range(of: indexLine), """
            the index expression `\(indexLine)` is gone from `\(signature)`, so this claim \
            can no longer tell whether the gate precedes it. Re-anchor it (#367).
            """)
        XCTAssertTrue(gateAt.upperBound <= indexAt.lowerBound, """
            the storage gate in `\(signature)` no longer precedes `\(indexLine)`. A check \
            after the index is a check that never runs (#1203).
            """)
    }

    /// END-TO-END BEHAVIOUR (§1) — the strong kind, and the half a scan cannot give: the
    /// gates are NEUTRAL. `EchoelDelayLine` is `public` and Foundation-only, so this drives
    /// the shipped type rather than its source text.
    ///
    /// It is a COUNTERWEIGHT by design (#343): green on both trees. That is the point — a
    /// safety gate that changed a returned sample would be a regression wearing a fix's name.
    ///
    /// ⚠️ THE REVERB HALF OF #1203 GETS NO TEST OF ITS OWN, and that is a decision, not an
    /// omission: `comb` and `allpass` are `private`, so nothing here can drive them directly,
    /// and a single-tree behavioural test cannot demonstrate bit-neutrality without the other
    /// tree to compare against. What already covers them is this file's own end-to-end
    /// tests — `testRaisingTheMixAfterSleepCannotResurrectTheOldTake` and
    /// `testTheChainStillPassesAudioAfterWaking` both push real buffers through the tank at
    /// `reverb.mix = 0.9`. A gate that dropped a sample there would fail them.
    func testTheStorageGateIsNeutralInNormalOperation() {
        let line = EchoelDelayLine(maxDelaySeconds: 0.001, sampleRate: 48000)
        let written: [Float] = [0.25, -0.5, 0.125, 1.0, -0.75]
        for x in written { line.write(x) }

        // The indexing contract from the file header: delay 1 is the most recent sample.
        for (back, expected) in zip(1...written.count, written.reversed()) {
            XCTAssertEqual(line.read(delaySamples: Float(back)), expected, """
                `read(delaySamples: \(back))` no longer returns the sample written \(back) \
                steps ago. #1203 added a storage gate in front of this index; it must be \
                bit-neutral whenever the storage is the real buffer.
                """)
        }

        // A whole-integer delay leaves `apPrev` at 0 (the `read` calls above do not touch
        // it), so `s1 + eta * (s0 - apPrev)` collapses to `s1 + eta * s0` — one multiply, and
        // the coefficient is the only unknown. Recovering it is exact algebra (#442), and it
        // deliberately does NOT restate eta's VALUE: that is #1205's business and it has ONE
        // home, `EchoelDelayLine.maxAllpassCoefficient` (#416).
        //
        // ⛔ THIS ASSERTION USED TO BE `XCTAssertEqual(readAllpass(1.0), s1 + s0)` AND #1205
        // TURNED IT RED — a zero-tolerance equality on exactly the `frac == 0` case that slice
        // changes. It is retracted here rather than re-fitted to 0.99, because a number fitted
        // to today's coefficient would go red again the day the coefficient is retuned, on a
        // correct tree (#364). The BAND is the durable fact: at an integer delay the
        // coefficient is at or just below 1, whatever it is tuned to.
        //
        // What THIS file asserts is only the #1203 storage gate, and the band still catches
        // its failure mode: a dropped gate returns 0, which recovers eta = 1.333…, outside
        // the upper bound. (Only the upper assertion fires on that tree; that is enough.)
        let s0 = written[written.count - 1]
        let s1 = written[written.count - 2]
        let recoveredEta = (line.readAllpass(delaySamples: 1.0) - s1) / s0
        XCTAssertGreaterThan(recoveredEta, 0.9, """
            `readAllpass` returned an implausible value for a whole-sample delay. With \
            `apPrev` at 0 the output is `s1 + eta * s0`, so the recovered coefficient must \
            sit just below 1 — a value this far off means the interpolator, not the gate.
            """)
        XCTAssertLessThanOrEqual(recoveredEta, 1.0, """
            `readAllpass` no longer returns its documented output for a whole-sample delay. \
            #1203 put a storage gate in front of its index and before it touches `apPrev`; \
            it must be bit-neutral whenever the storage is the real buffer. A gate that \
            returned 0 here recovers a coefficient of 1.333…, which is what this bound reads.
            """)

        line.reset()
        XCTAssertEqual(line.read(delaySamples: 1.0), 0, """
            `reset()` no longer empties the line. That is the whole subject of this file: a \
            stage that keeps its buffer across a sleep bursts stale audio on resume.
            """)
    }

    /// Brace-matched body of the declaration whose signature line is `signature`.
    /// Returns nil if the signature does not occur, so a mis-anchor is a FAILURE and not a
    /// vacuous green (#926).
    private static func body(after signature: String, in code: String) -> String? {
        guard let open = code.range(of: signature) else { return nil }
        var depth = 1
        var index = open.upperBound
        while index < code.endIndex {
            let character = code[index]
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.upperBound..<index]) }
            }
            index = code.index(after: index)
        }
        return nil
    }

}
