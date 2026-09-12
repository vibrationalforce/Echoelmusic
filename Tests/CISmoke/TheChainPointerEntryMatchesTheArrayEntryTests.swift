// TheChainPointerEntryMatchesTheArrayEntryTests.swift
// Echoel — #822: the pointer entry point the V1a monitor insert needs, pinned to be the SAME
// law as the array entry point before any render block rides on it.
//
// WHY THIS EXISTS. The founder's 2026-08-25 directive green-lit the vocal chain on the voice
// ("Monitoring … latenzfrei … mit intelligenter Harmonizer und Granular Synthese Effekt
// Strategie") and closed the voice-clone question with NO. ⛔ THAT DIRECTIVE WAS WITHDRAWN:
// the monitor rail went with the audio input (#1302) and the two named stages with #1305
// ("Kein audioninout kein Autotune, Harmonizer, granularsynthese"), so the ORIGIN of this
// guard no longer exists. It is kept anyway, and the reason is in the ⭐ block below — the
// law it pins is about ONE DEFINITION, not about voices. The decided mechanism (#669) was an
// `AUAudioUnit` insert on the monitor rail, whose `internalRenderBlock` receives an
// `AudioBufferList` — raw pointers — so `EchoelFXChain.processBuffer(left:right:)`, which takes
// Swift `Array`s, cannot be called from it without an audio-thread copy. #822 adds
// `processInPlace(left:right:frameCount:)`: same body shape, glide once per block, then
// `processStereo` per sample.
//
// ⭐ WHAT THIS GUARD ACTUALLY PROTECTS: the ONE-DEFINITION law (#416). The moment the pointer
// path and the array path drift — one gains a stage, a clamp, a different glide cadence — the
// two callers hear DIFFERENT chains under the same settings, and no panel could say why.
// `processInPlace` is still declared and still public, so the two entry points still exist
// and can still drift. Claim 1 is therefore bitwise equality with a WET and a NONLINEAR stage
// armed, so a dropped or reordered stage cannot hide in a dry path.
//
// ⛔ IT ARMED harmonizer + granular — "the two stages the founder named" — until #1305
// deleted both. ⭐ The replacement is chosen on the PROPERTY, not on a name: tape (nonlinear
// + wow), chorus (modulated wet) and delay (a long ring the array path must flush the same
// way). **A guard armed by WHICH FEATURE SOMEONE ASKED FOR expires with that ask; one armed
// by WHICH CODE PATH IT COVERS does not.**
//
// ⚠️ DETERMINISM IS A MEASURED PREMISE, not an assumption: both chains are freshly
// constructed with identical settings, and the remaining stages take no random seed at all
// (granular's seeded RNG was the only one, and it is gone).
//
// #364 — NOTHING HERE FORBIDS A FUTURE POINTER-PATH CONSUMER. It is the floor such a consumer
// stands on, not a wall in front of it.
//
// KIND (§1): **BEHAVIOURAL** — claims 1 and 2 execute the DSP. Claim 3 is a source-text pin on
// the one-definition shape (the pointer body must call the same two functions, not re-derive).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheChainPointerEntryMatchesTheArrayEntryTests: XCTestCase {

    /// Deterministic non-trivial input: a fixed linear-congruential sequence mapped to
    /// [-0.6, 0.6]. No `Float.random` — the whole point is bit-identical replays.
    private func signal(frames: Int, channelSeed: UInt64) -> [Float] {
        var state = channelSeed
        var out = [Float](repeating: 0, count: frames)
        for i in 0..<frames {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let unit = Float(state >> 40) / Float(1 << 24)      // [0, 1)
            out[i] = (unit - 0.5) * 1.2
        }
        return out
    }

    private func armedChain() -> EchoelFXChain {
        let chain = EchoelFXChain()
        chain.tapeEnabled = true            // nonlinear + wow, so drift cannot hide
        chain.chorusEnabled = true          // a modulated WET path
        chain.delayEnabled = true           // a long ring both entry points must flush alike
        chain.saturationEnabled = true      // a second nonlinearity
        return chain
    }

    // 1 — same settings, same input ⇒ bitwise same output through BOTH entry points.
    func testThePointerEntryIsBitwiseIdenticalToTheArrayEntry() {
        let arrayChain = armedChain()
        let pointerChain = armedChain()
        let block = 256
        for blockIndex in 0..<4 {
            let seedL = UInt64(0xA11CE + blockIndex)
            let seedR = UInt64(0xB0B + blockIndex)
            var arrL = signal(frames: block, channelSeed: seedL)
            var arrR = signal(frames: block, channelSeed: seedR)
            var ptrL = arrL
            var ptrR = arrR
            arrayChain.processBuffer(left: &arrL, right: &arrR, frameCount: block)
            ptrL.withUnsafeMutableBufferPointer { l in
                ptrR.withUnsafeMutableBufferPointer { r in
                    guard let lBase = l.baseAddress, let rBase = r.baseAddress else {
                        XCTFail("buffer base address missing — the fixture is broken")
                        return
                    }
                    pointerChain.processInPlace(left: lBase, right: rBase, frameCount: block)
                }
            }
            XCTAssertEqual(arrL, ptrL, """
                Block \(blockIndex): LEFT diverged between processBuffer and processInPlace. \
                The two entry points are one law (#416) — if a stage, clamp or glide cadence \
                changed in one, change it in both, or the monitor insert and the synth voices \
                hear different chains under the same settings.
                """)
            XCTAssertEqual(arrR, ptrR, "Block \(blockIndex): RIGHT diverged — same law as left.")
        }
        // The fixture must have DONE something, or the equality above compares silence to
        // silence: a processed block through saturation+tape+chorus+delay cannot be the
        // identity on this input.
        var probeL = signal(frames: block, channelSeed: 0xA11CE)
        var probeR = signal(frames: block, channelSeed: 0xB0B)
        let originalL = probeL
        armedChain().processBuffer(left: &probeL, right: &probeR, frameCount: block)
        XCTAssertNotEqual(probeL, originalL, """
            precondition failed: the armed chain returned its input unchanged, so every \
            equality above was vacuous. A stage default changed — re-arm the fixture.
            """)
    }

    // 2 — a zero or negative frame count is a safe no-op, because the render block's count
    //     is external input to this API.
    func testAZeroFrameCallTouchesNothing() {
        let chain = armedChain()
        var left: [Float] = [0.25, -0.5]
        var right: [Float] = [0.125, 0.75]
        let expectedLeft = left
        let expectedRight = right
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lBase = l.baseAddress, let rBase = r.baseAddress else { return }
                chain.processInPlace(left: lBase, right: rBase, frameCount: 0)
                chain.processInPlace(left: lBase, right: rBase, frameCount: -3)
            }
        }
        XCTAssertEqual(left, expectedLeft, "frameCount ≤ 0 must not read or write a sample")
        XCTAssertEqual(right, expectedRight, "frameCount ≤ 0 must not read or write a sample")
    }

    // 3 — the pointer body IS the same law, not a re-derivation (#416): it must call the same
    //     glide-once-per-block and per-sample functions the array body calls, and it must not
    //     build an Array (that would put an allocation on the audio thread).
    func testThePointerBodyReusesTheOneDefinition() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Echoelmusic/DSP/EchoelFXChain.swift")
        guard let source = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: EchoelFXChain.swift could not be read — fail, not skip (§4)")
            return
        }
        guard let start = source.range(of: "func processInPlace") else {
            XCTFail("processInPlace is gone from EchoelFXChain. The V1a render block depends "
                    + "on it — if it was renamed, re-anchor this guard in the same commit.")
            return
        }
        let body = String(source[start.lowerBound...].prefix(900))
        XCTAssertTrue(body.contains("advanceFilterGlide(frameCount: frameCount)"),
                      "The pointer body must run the glide once per block, like processBuffer.")
        XCTAssertTrue(body.contains("processStereo("),
                      "The pointer body must go through processStereo — one law, no re-derived DSP.")
        XCTAssertFalse(body.contains("Array("),
                       "The pointer body constructs an Array — that is an allocation on the "
                       + "audio thread, the exact copy this entry point exists to avoid.")
    }
}
