// TheBodyVibeReverbIsHeardAndAnchoredTests.swift
// Echoel — WA3.3 (2026-09-24): the AUv3's "Reverb" (host address 6, canonical
// `bodyvibe.fx.reverbMix`) is AUDIBLE, and the host value is the ANCHOR that bio modulates
// around. Blocking bundle.
//
// THE DEFECT (measured before the repair). Three facts together made address 6 a dead knob:
// (1) the binding wrote `EchoelDDSP.reverbMix` only; (2) the one reader of that field, the
// convolution stage, is gated off (`useConvolutionReverb`); (3) the render-side
// `applyBioReactive` rewrote it about every 100 ms from `bioBaseReverbMix`, which nothing in
// the AUv3 set (0.25 default), clamped 0…0.9. The host value was neither kept nor heard.
//
// THE REPAIR. The binding writes the anchor (`bioBaseReverbMix`), the pair `SynthPatch.apply`
// already writes. The law is ONE function (`EchoelDDSP.bioModulatedReverbMix`: anchor + ±0.06
// HRV offset, 0…1). The consumer is `EchoelBodyVibeDevice.renderSpace`, which feeds
// `EchoelReverb` (the Freeverb stage the app's FX chain already runs on its audio thread).
//
// WHAT KIND OF GREEN (§1), PER CLAIM:
// · claims 1–7 are END-TO-END BEHAVIOUR on the real `EchoelDDSP`, `EchoelCellular` and
//   `EchoelReverb`, driven through the same shared binding and the same `renderSpace` the
//   AUv3 render block calls. Claim 5 is RENDERED AUDIO, not a property read.
// · claim 8 is a SOURCE-TEXT SCAN of the extension (this bundle cannot instantiate its
//   `AUAudioUnit`): setup resolves bindings fail-loud, allocation seeds the anchor, and render
//   calls `renderSpace`.
// · HOST/DEVICE — automating address 6 in AUM/Logic/GarageBand and hearing it — is not
//   reachable here and stays owed (`ECHOELMUSIC_MASTER_PLAN.md` §9, WA3-5).
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not freeze the ±0.06 depth or the Freeverb
// choice; it freezes the LAW: a neutral body leaves the host value exactly, a body moves it
// only around that value, the result stays in 0…1, and the value reaches an audible stage.
// The APP's convolution reverb is still off and unclaimed (`DisabledReverbIsNotClaimedLiveTests`);
// this guard is about the plug-in.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `b62b3f240`:
// `bioModulatedReverbMix`, `renderSpace`, `resolveBindings` and `unboundCreativeParameter` do
// not exist, so claims 1–7 do not COMPILE against it — FORWARD guards, no verdict there. The
// DEFECT they target was driven in Python on the parent's arithmetic (anchor never written,
// 0.25 default, 0…0.9 clamp): a host value of 0.9 read back 0.25 after one neutral tick.
// Claim 8 is a REGRESSION: its three anchors are absent in the parent.
// Claim 9 (review, 2026-09-25) is a REGRESSION too: before the rising-edge reset in
// `renderSpace`, a tank frozen at mix 0 replayed its tail when the mix rose. Its
// counterweight (the tank held energy) is green on both trees.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheBodyVibeReverbIsHeardAndAnchoredTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"
    private static let neutral: Float = 0.5

    private func engines() -> (EchoelDDSP, EchoelCellular) {
        (EchoelDDSP(sampleRate: 48000), EchoelCellular(cellCount: 128, sampleRate: 48000))
    }

    private func bioTick(_ synth: EchoelDDSP, hrv: Float) {
        synth.applyBioReactive(coherence: Self.neutral, hrvVariability: hrv,
                               heartRate: Self.neutral, breathPhase: Self.neutral)
    }

    // MARK: - claims 1–7 (END-TO-END)

    /// 1 (C) — a neutral body leaves the host value EXACTLY, across the whole host range.
    func testANeutralBodyLeavesTheHostValueExactly() {
        for base: Float in [0, 0.1, 0.3, 0.84, 0.95, 1] {
            XCTAssertEqual(EchoelDDSP.bioModulatedReverbMix(base: base, hrv: Self.neutral), base,
                           "the law moves the anchor \(base) at neutral HRV")
            let (synth, texture) = engines()
            EchoelBodyVibeDevice.apply(.synthReverbMix, value: base, synth: synth, texture: texture)
            for _ in 0..<30 { bioTick(synth, hrv: Self.neutral) }
            XCTAssertEqual(synth.bioBaseReverbMix, base, "the binding did not write the anchor")
            XCTAssertEqual(synth.reverbMix, base, """
                Host value \(base), thirty neutral bio ticks, effective \(synth.reverbMix). A \
                resting body must leave the host's reverb exactly where the host put it. Above \
                0.9 this was the pre-WA3.3 0…0.9 ceiling.
                """)
        }
    }

    /// 2 (D) — a live body moves the effective value AROUND the anchor and never rewrites it.
    func testALiveBodyModulatesAroundTheAnchor() {
        let (synth, texture) = engines()
        EchoelBodyVibeDevice.apply(.synthReverbMix, value: 0.4, synth: synth, texture: texture)
        for _ in 0..<30 { bioTick(synth, hrv: 0.9) }
        XCTAssertEqual(synth.bioBaseReverbMix, 0.4, "bio ticks rewrote the host anchor")
        XCTAssertEqual(synth.reverbMix, 0.4 + 0.4 * 0.12, accuracy: 1e-6)
        for _ in 0..<30 { bioTick(synth, hrv: 0.1) }
        XCTAssertEqual(synth.bioBaseReverbMix, 0.4)
        XCTAssertEqual(synth.reverbMix, 0.4 - 0.4 * 0.12, accuracy: 1e-6)
    }

    /// 3 (E) — the effective value is always finite and inside the parameter's 0…1.
    func testTheEffectiveValueStaysInsideTheParameterRange() {
        let hrvs: [Float] = [0, 0.5, 1, -5, 7, .nan, .infinity, -.infinity]
        var base: Float = 0
        while base <= 1.0001 {
            for hrv in hrvs {
                let v = EchoelDDSP.bioModulatedReverbMix(base: base, hrv: hrv)
                XCTAssertTrue(v.isFinite && v >= 0 && v <= 1,
                              "base \(base), hrv \(hrv) → \(v), outside 0…1")
            }
            base += 0.05
        }
    }

    /// 4 (F) — a host move while bio is running becomes the new anchor at once.
    func testAHostMoveDuringLiveBioBecomesTheNewAnchor() {
        let (synth, texture) = engines()
        EchoelBodyVibeDevice.apply(.synthReverbMix, value: 0.2, synth: synth, texture: texture)
        for _ in 0..<10 { bioTick(synth, hrv: 0.8) }
        EchoelBodyVibeDevice.apply(.synthReverbMix, value: 0.9, synth: synth, texture: texture)
        XCTAssertEqual(synth.reverbMix, 0.9, "the host move did not take effect before the next tick")
        for _ in 0..<10 { bioTick(synth, hrv: 0.8) }
        XCTAssertEqual(synth.bioBaseReverbMix, 0.9)
        XCTAssertEqual(synth.reverbMix, EchoelDDSP.bioModulatedReverbMix(base: 0.9, hrv: 0.8))
    }

    /// 5 (A, B) — RENDERED AUDIO: a low and a high host value sound different, through several
    /// bio intervals, and the consumer receives the anchored value. COUNTERWEIGHT: the
    /// pre-WA3.3 write (the field alone) is erased by the first tick, so this claim can see
    /// the defect.
    func testTheHostReverbIsAudibleThroughBioTicks() {
        let low = render(hostMix: 0.05, hrv: 0.8)
        let high = render(hostMix: 0.8, hrv: 0.8)
        XCTAssertGreaterThan(low.bioTicks, 3, "the run did not span several bio intervals")

        XCTAssertEqual(low.finalMix, EchoelDDSP.bioModulatedReverbMix(base: 0.05, hrv: 0.8))
        XCTAssertEqual(high.finalMix, EchoelDDSP.bioModulatedReverbMix(base: 0.8, hrv: 0.8))

        let half = low.samples.count / 2
        var diff: Float = 0, energy: Float = 0
        for i in half..<low.samples.count {
            diff += abs(low.samples[i] - high.samples[i])
            energy += abs(low.samples[i])
        }
        XCTAssertTrue(low.samples.allSatisfy(\.isFinite) && high.samples.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(energy, 1, "the dry run is silent — the comparison would be vacuous")
        XCTAssertGreaterThan(diff / energy, 0.1, """
            After \(low.bioTicks) bio intervals, host reverb 0.05 and 0.8 differ by only \
            \(diff / energy) (relative L1) in the rendered output. Address 6 must be audible.
            """)

        let (legacy, texture) = engines()
        EchoelBodyVibeDevice.apply(.synthReverbMix, value: 0.25, synth: legacy, texture: texture)
        legacy.reverbMix = 0.9      // the pre-WA3.3 binding wrote only this field
        bioTick(legacy, hrv: Self.neutral)
        XCTAssertEqual(legacy.reverbMix, 0.25, """
            A value written to the field alone must be replaced by the anchor on the next tick. \
            If this fails, the claim above no longer tells the anchor from the field.
            """)
    }

    /// 6 — at mix 0 the space stage is transparent: the output equals the pre-WA3.3 dry synth.
    func testAtZeroTheSpaceStageIsTransparent() {
        let wet = render(hostMix: 0, hrv: Self.neutral)
        let dry = render(hostMix: 0, hrv: Self.neutral, throughSpace: false)
        XCTAssertEqual(wet.finalMix, 0)
        XCTAssertEqual(wet.samples.count, dry.samples.count)
        var maxDelta: Float = 0
        for i in 0..<wet.samples.count { maxDelta = max(maxDelta, abs(wet.samples[i] - dry.samples[i])) }
        XCTAssertLessThanOrEqual(maxDelta, 1e-6, "mix 0 changed the output by \(maxDelta)")
    }

    /// 9 — a mix that returns from 0 starts from a silent room, not from the tail it froze.
    ///
    /// WA3.3 review (2026-09-25): at mix 0 `processStereo` returns before touching a comb, so
    /// the tank kept its old tail and the next rise played it back. The counterweight proves
    /// the tank really held energy — without it, "silent after the rise" would be vacuous.
    /// Only the rise through 0 is under test: the input is silent after the fill, so anything
    /// the stage emits in the first block is the tank.
    func testAMixReturningFromZeroStartsFromASilentRoom() {
        func firstBlockAfterRise(crossingZero: Bool) -> Float {
            let (synth, _) = engines()
            let reverb = EchoelReverb(sampleRate: 48000)
            let block = 512
            var left = [Float](repeating: 0, count: block)
            var right = [Float](repeating: 0, count: block)
            func pass(_ input: (Int) -> Float) {
                for i in 0..<block { left[i] = input(i) }
                left.withUnsafeMutableBufferPointer { l in
                    right.withUnsafeMutableBufferPointer { r in
                        EchoelBodyVibeDevice.renderSpace(reverb, synth: synth,
                                                         left: l, right: r, count: block)
                    }
                }
            }
            synth.reverbMix = 0.8
            for b in 0..<20 { pass { i in 0.5 * sinf(Float(b * block + i) * 0.05) } }
            if crossingZero {
                synth.reverbMix = 0
                for _ in 0..<10 { pass { _ in 0 } }
            }
            synth.reverbMix = 0.5
            pass { _ in 0 }
            var peak: Float = 0
            for i in 0..<block { peak = max(peak, abs(left[i]), abs(right[i])) }
            return peak
        }
        let held = firstBlockAfterRise(crossingZero: false)
        XCTAssertGreaterThan(held, 1e-3, "the tank held no tail — the claim below would be vacuous")
        let risen = firstBlockAfterRise(crossingZero: true)
        XCTAssertLessThanOrEqual(risen, 1e-6, """
            After the mix sat at 0 and rose again, the stage emitted \(risen) from a silent input. \
            That is the tail frozen at mix 0 being played back — `renderSpace` must reset the \
            tank on the rising edge, as `EchoelFXChain` does on its reverb enable edge.
            """)
    }

    /// 7 (G) — every creative host parameter has a runtime binding, and a missing one THROWS.
    func testEveryCreativeHostParameterIsBoundOrSetupFails() throws {
        let resolved = try EchoelBodyVibeAUv3Mapping.resolve()
        let bindings = try EchoelBodyVibeAUv3Mapping.resolveBindings(resolved)
        var creative: Set<UInt64> = []
        for r in resolved { if case .creative = r.target { creative.insert(r.address) } }
        XCTAssertFalse(creative.isEmpty, "no creative host parameter — the check matched nothing")
        XCTAssertEqual(Set(bindings.keys), creative, "a creative host parameter has no binding")
        XCTAssertEqual(bindings[6], .synthReverbMix, "address 6 no longer binds the reverb")

        var asked: [String] = []
        XCTAssertThrowsError(try EchoelBodyVibeAUv3Mapping.resolveBindings(resolved) { id in
            asked.append(id)
            return id == EchoelBodyVibeDevice.BaseID.reverbMix ? nil : EchoelBodyVibeDevice.binding(for: id)
        }) {
            XCTAssertEqual($0 as? AUv3MappingError,
                           .unboundCreativeParameter(EchoelBodyVibeDevice.BaseID.reverbMix))
        }
        for control in LegacyLiveControl.allCases {
            XCTAssertFalse(asked.contains(control.rawValue),
                           "a legacy live control was asked for a creative binding")
        }
    }

    // MARK: - claim 8 (SOURCE-TEXT SCAN of the extension)

    /// 8 — the extension uses the three shared pieces this guard drives.
    func testTheAudioUnitUsesTheSharedReverbPath() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        guard let setup = Self.body(startingWith: "private func setupParameterTree() throws", in: code),
              let allocate = Self.body(startingWith: "public override func allocateRenderResources() throws",
                                       in: code),
              let render = Self.body(startingWith: "public override var internalRenderBlock", in: code)
        else {
            return XCTFail("an anchor in \(Self.audioUnit) is gone — re-anchor, do not delete")
        }
        XCTAssertTrue(setup.contains("try EchoelBodyVibeAUv3Mapping.resolveBindings(resolved)"),
                      "setup no longer fails loudly on a creative parameter without a binding")
        XCTAssertFalse(setup.contains("if let binding = EchoelBodyVibeDevice.binding(for:"),
                       "setup skips a missing binding again")
        // ⚠️ 2026-09-24 (P2): the reverb-only seed became the shared seed of ALL creative
        // values (`EchoelBodyVibeDevice.seed`); `TheBodyVibeStartsWhereItsTreeSaysTests`
        // proves that function writes the reverb anchor. The needle moved with it (#456).
        XCTAssertTrue(allocate.contains("EchoelBodyVibeDevice.seed(creativeValues"),
                      "allocation no longer seeds the reverb anchor from the host value")
        XCTAssertTrue(render.contains("EchoelBodyVibeDevice.renderSpace("),
                      "the render block no longer feeds the reverb stage")
    }

    // MARK: - helpers

    private struct Run { var samples: [Float]; var finalMix: Float; var bioTicks: Int }

    /// Mirrors the AUv3 render block's order: bio (~10 Hz), synth, then the space stage.
    private func render(hostMix: Float, hrv: Float, throughSpace: Bool = true) -> Run {
        let (synth, texture) = engines()
        let reverb = EchoelReverb(sampleRate: 48000)
        EchoelBodyVibeDevice.apply(.synthReverbMix, value: hostMix, synth: synth, texture: texture)
        synth.amplitude = 0.6
        synth.noteOn(frequency: 220)
        let block = 512
        let bioInterval = 4800
        var left = [Float](repeating: 0, count: block)
        var right = [Float](repeating: 0, count: block)
        var out: [Float] = []
        var accum = 0
        var ticks = 0
        for _ in 0..<60 {
            accum += block
            if accum >= bioInterval {
                accum = 0
                ticks += 1
                bioTick(synth, hrv: hrv)
            }
            synth.render(buffer: &left, frameCount: block)
            if throughSpace {
                left.withUnsafeMutableBufferPointer { l in
                    right.withUnsafeMutableBufferPointer { r in
                        EchoelBodyVibeDevice.renderSpace(reverb, synth: synth,
                                                         left: l, right: r, count: block)
                    }
                }
            } else {
                right = left
            }
            out.append(contentsOf: left)
            out.append(contentsOf: right)
        }
        return Run(samples: out, finalMix: reverb.mix, bioTicks: ticks)
    }

    private static func body(startingWith anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor) else { return nil }
        var depth = 0
        var out = ""
        for ch in code[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { out.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return out }
            }
        }
        return nil
    }

    private func text(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — source-text claim cannot run (#454)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
