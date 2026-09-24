// TheBodyVibeKnobsMoveTheSoundTests.swift
// Echoel — 2026-09-24 (overnight P4): every creative BodyVibe parameter is DECLARED → MAPPED →
// BOUND → and moves what the device RENDERS. Blocking bundle.
//
// THE QUESTION. WA3.2 proved the first three links for all four parameters (descriptor, AU
// address, binding, the engine field `apply` writes); WA3.3 proved the fourth for the reverb
// alone. A field write is not a sound: `EchoelDDSP.frequency` could be shadowed by a glide
// target, `EchoelCellular.gain` could be read nowhere, and the output gain has no engine field
// at all. This file closes the fourth link for the other three and makes a FIFTH parameter
// without a probe a red build.
//
// MEASURED (read, then driven here):
//   · pitch — `EchoelDDSP.render` glides `smoothedFreq` toward `frequency` every sample, so a
//     write while a note sounds moves the pitch; the texture reads `frequency` per partial.
//   · texture gain — `EchoelCellular.render` multiplies every sample by `gain`, linearly.
//   · reverb — `renderSpace` reads the synth's effective `reverbMix` (WA3.3 claim 5 renders it).
//   · output gain — the AUv3 render block writes `(synth + texture) * gainBox.value`; the only
//     link this bundle cannot RENDER, because it cannot instantiate the extension.
//
// WHAT KIND OF GREEN (§1), PER CLAIM:
// · claim 1 is an INVENTORY over the shipped descriptors and mapping (behaviour of public types).
// · claims 2–4 are RENDERED AUDIO through the real engines, with exact counterweights: both
//   engines are deterministic (`EchoelDDSP`'s noise is a seeded xorshift; the texture starts
//   from one centre cell), so the same settings render bit-identical blocks.
// · claim 5 is a SOURCE-TEXT SCAN of the AUv3 render block.
// · HOST — turning each knob in AUM and hearing it — stays owed (WA3-5/WA3-6).
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). Claim 1 does not forbid a new parameter; it forbids
// a new parameter WITHOUT a runtime probe here. Add the probe in the same commit.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `2ed46b045`: every claim
// names only symbols that exist there, so the file COMPILES there and all claims are green on
// both trees — this is a PROOF file, not a regression guard: nothing was broken, the fourth link
// had simply never been driven. Its value is claim 1 (fail-loud) and the counterweights.
// Texture audibility was SIMULATED before writing claim 3: with rule 90 (the default) and the
// in-place update `evolve1D` performs, cells 0…31 carry a live partial from evolution 2 on;
// at the AUv3's 8 evolutions/s that is 12 000 samples, and the claim renders 24 000.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheBodyVibeKnobsMoveTheSoundTests: XCTestCase {

    private typealias ID = EchoelBodyVibeDevice.BaseID
    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"
    private static let rate: Float = 48000
    private static let frames = 24000

    /// Every creative parameter and the claim below that renders it. A descriptor missing here
    /// is a knob nobody has shown to move the sound.
    private static let probedIDs: Set<String> = [
        ID.baseFrequency,   // claim 2
        ID.textureAmount,   // claim 3
        ID.reverbMix,       // claim 4 (+ TheBodyVibeReverbIsHeardAndAnchoredTests claim 5)
        ID.masterGain,      // claim 5 (source scan — the adapter's own stage)
    ]

    // MARK: - claim 1 (INVENTORY, fail-loud)

    func testEveryCreativeParameterIsDeclaredMappedBoundAndProbed() throws {
        let declared = Set(EchoelBodyVibeDevice.creativeDescriptors.map(\.keyPath))
        XCTAssertEqual(declared, Self.probedIDs, """
            The creative parameter set changed: \(declared.symmetricDifference(Self.probedIDs).sorted()). \
            A parameter needs a runtime probe in this file IN THE SAME COMMIT — declared, mapped \
            and bound is not the same as heard.
            """)
        let resolved = try EchoelBodyVibeAUv3Mapping.resolve()
        var mapped: Set<String> = []
        for r in resolved {
            if case .creative(let id) = r.target { mapped.insert(id) }
        }
        XCTAssertEqual(mapped, declared, "a creative parameter has no AUv3 address")
        for id in declared {
            XCTAssertNotNil(EchoelBodyVibeDevice.binding(for: id), "\(id) has no runtime binding")
        }
    }

    // MARK: - claim 2 (pitch)

    func testTheBaseFrequencyMovesTheSynthAndTheTexture() {
        let low = renderSynth(values: [ID.baseFrequency: 110])
        let lowAgain = renderSynth(values: [ID.baseFrequency: 110])
        let high = renderSynth(values: [ID.baseFrequency: 220])
        XCTAssertGreaterThan(rms(low), 1e-4, "the synth is silent — the claim would be vacuous")
        XCTAssertEqual(low, lowAgain, "the synth is not deterministic — the comparison below means nothing")
        XCTAssertGreaterThan(rms(zip(low, high).map { $0 - $1 }), 0.1 * rms(low), """
            Moving the base frequency from 110 to 220 Hz barely changes the rendered synth. The \
            knob writes a field the render path does not follow.
            """)

        let texLow = renderTexture(values: [ID.baseFrequency: 110])
        let texHigh = renderTexture(values: [ID.baseFrequency: 220])
        XCTAssertGreaterThan(rms(texLow), 1e-5, "the texture is silent — the claim would be vacuous")
        XCTAssertNotEqual(texLow, texHigh, "the base frequency does not reach the texture")
    }

    // MARK: - claim 3 (texture gain)

    func testTheTextureAmountScalesTheTextureLinearly() {
        let quiet = renderTexture(values: [ID.textureAmount: 0.1])
        let loud = renderTexture(values: [ID.textureAmount: 0.8])
        let reference = rms(quiet)
        XCTAssertGreaterThan(reference, 1e-6, "the texture is silent — the claim would be vacuous")
        XCTAssertEqual(rms(loud) / reference, 8, accuracy: 1e-3, """
            Texture 0.8 is not eight times texture 0.1. The texture knob no longer scales what \
            the texture renders.
            """)
    }

    // MARK: - claim 4 (reverb)

    func testTheReverbMixChangesTheSpaceStageOutput() {
        func spaced(_ mix: Float) -> [Float] {
            let synth = EchoelDDSP(sampleRate: Self.rate)
            let texture = EchoelCellular(cellCount: 128, sampleRate: Self.rate)
            EchoelBodyVibeDevice.seed([ID.reverbMix: mix], synth: synth, texture: texture)
            let reverb = EchoelReverb(sampleRate: Self.rate)
            synth.amplitude = 0.6
            synth.noteOn(frequency: synth.frequency)
            var out: [Float] = []
            var left = [Float](repeating: 0, count: 512)
            var right = [Float](repeating: 0, count: 512)
            for _ in 0..<(Self.frames / 512) {
                synth.render(buffer: &left, frameCount: 512)
                left.withUnsafeMutableBufferPointer { l in
                    right.withUnsafeMutableBufferPointer { r in
                        EchoelBodyVibeDevice.renderSpace(reverb, synth: synth, left: l, right: r, count: 512)
                    }
                }
                out.append(contentsOf: right)
            }
            return out
        }
        let dry = spaced(0)
        let wet = spaced(1)
        XCTAssertGreaterThan(rms(dry), 1e-4, "the dry path is silent — the claim would be vacuous")
        XCTAssertGreaterThan(rms(zip(dry, wet).map { $0 - $1 }), 0.1 * rms(dry),
                             "reverb 0 and reverb 1 render nearly the same — the knob is not heard")
    }

    // MARK: - claim 5 (output gain, SOURCE-TEXT SCAN)

    func testTheOutputGainScalesEveryRenderedSample() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let render = try XCTUnwrap(Self.body(startingWith: "public override var internalRenderBlock",
                                             in: code),
                                   "the render block is not found — re-anchor this guard (#456)")
        XCTAssertTrue(render.contains("let gain = gainBox.value"), """
            The render block no longer reads the output-gain mirror. Master Gain would then be \
            a knob with no reader.
            """)
        XCTAssertTrue(render.contains("data[i] = (synthSample + texBuf[i]) * gain"), """
            The output is no longer `(synth + texture) * gain`. If the mix stage moved, move this \
            needle with it (#456) — the claim is that every rendered sample passes the gain.
            """)
        XCTAssertTrue(code.contains("self.gainMirror.value = value"),
                      "a host write to Master Gain no longer reaches the render mirror")
    }

    // MARK: - helpers

    private func renderSynth(values: [String: Float]) -> [Float] {
        let synth = EchoelDDSP(sampleRate: Self.rate)
        let texture = EchoelCellular(cellCount: 128, sampleRate: Self.rate)
        EchoelBodyVibeDevice.seed(values, synth: synth, texture: texture)
        synth.amplitude = 0.6
        synth.noteOn(frequency: synth.frequency)
        var out: [Float] = []
        var block = [Float](repeating: 0, count: 512)
        for _ in 0..<(Self.frames / 512) {
            synth.render(buffer: &block, frameCount: 512)
            out.append(contentsOf: block)
        }
        return out
    }

    /// The texture configured as the AUv3 configures it (`init`), then seeded.
    private func renderTexture(values: [String: Float]) -> [Float] {
        let synth = EchoelDDSP(sampleRate: Self.rate)
        let texture = EchoelCellular(cellCount: 128, sampleRate: Self.rate)
        texture.synthMode = .additive
        texture.rule = .rule90
        texture.evolutionRate = 8
        EchoelBodyVibeDevice.seed(values, synth: synth, texture: texture)
        var out = [Float](repeating: 0, count: Self.frames)
        texture.render(buffer: &out, frameCount: Self.frames)
        return Array(out[(Self.frames / 2)...])
    }

    private func rms(_ x: [Float]) -> Double {
        guard !x.isEmpty else { return 0 }
        var sum = 0.0
        for v in x { sum += Double(v) * Double(v) }
        return (sum / Double(x.count)).squareRoot()
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
