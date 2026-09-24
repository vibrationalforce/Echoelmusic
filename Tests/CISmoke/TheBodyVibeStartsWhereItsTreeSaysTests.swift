// TheBodyVibeStartsWhereItsTreeSaysTests.swift
// Echoel — 2026-09-24 (overnight P2): a fresh BodyVibe instance plays the values its parameter
// tree shows. Blocking bundle.
//
// THE DEFECT (measured before the repair). The AUv3 writes each parameter's default into the
// tree BEFORE it installs `implementorValueObserver`, and the observer is the only thing that
// calls `EchoelBodyVibeDevice.apply`. So no creative value reached an engine until a host MOVED
// it. `allocateRenderResources` seeded exactly one of the four (the reverb anchor, WA3.3); the
// other three played what the AUv3 constructed:
//   · texture gain — `init` wrote a literal `texture.gain = 0.15`; the tree showed **0.3**.
//     A fresh instance played the texture at half the level its knob displayed.
//   · pitch — `texture.frequency = 110` in `init` and `noteOn(frequency:)` at allocate agreed
//     with the 220 Hz default only because both were typed to match it; a restored state
//     changed the synth, not the texture, until the knob moved.
//   · output gain — `GainMirror` defaulted to a literal 0.7, a second spelling of the
//     descriptor default (#416); a restored gain sounded only after the host moved it.
//
// THE REPAIR. `EchoelBodyVibeDevice.seed` writes every creative value (canonical base ID →
// value; missing or non-finite → descriptor default; clamped to the descriptor range) and
// returns the output gain. The AUv3 calls it in `init` (from the defaults) and in
// `allocateRenderResources` (from the tree), and the two literals are gone.
//
// WHAT KIND OF GREEN (§1), PER CLAIM:
// · claims 1–3 are BEHAVIOUR on the real `EchoelDDSP` / `EchoelCellular`: engine fields after a
//   seed, compared with the descriptors and with the observer's own `apply`.
// · claim 4 is a SOURCE-TEXT SCAN of the extension, which this bundle cannot instantiate.
// · HOST — a fresh instance in AUM whose texture level matches its 0.3 knob — stays owed. The
//   texture is LOUDER than before on a fresh instance (0.3 against 0.15); that is the repair,
//   and it is an audible change to the plug-in's default sound.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not freeze any default — every expected
// value is read from `creativeDescriptors`. A designer may move the texture default; the claim
// is that the engine then starts where the knob does.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `0f4b01b72`: `seed` does not
// exist, so claims 1–3 do not COMPILE there — FORWARD guards, no verdict on the parent. Claim 4
// is a REGRESSION: the parent's `init` carries `texture.gain = 0.15` and its allocate names no
// `seed(`. The DEFECT itself was read, not driven: the order "tree defaults, then observer" is
// in `setupParameterTree`, and 0.15 ≠ 0.3 is the two literals side by side.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheBodyVibeStartsWhereItsTreeSaysTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    private func engines() -> (EchoelDDSP, EchoelCellular) {
        (EchoelDDSP(sampleRate: 48000), EchoelCellular(cellCount: 128, sampleRate: 48000))
    }

    private func descriptor(_ id: String) throws -> ParameterDescriptor {
        try XCTUnwrap(EchoelBodyVibeDevice.creativeDescriptors.first { $0.keyPath == id },
                      "no creative descriptor \(id) — the device's parameter set changed")
    }

    // MARK: - claim 1

    func testAFreshSeedPutsEveryEngineFieldAtItsDescriptorDefault() throws {
        let (synth, texture) = engines()
        let pitch = try descriptor(EchoelBodyVibeDevice.BaseID.baseFrequency).defaultValue
        let textureGain = try descriptor(EchoelBodyVibeDevice.BaseID.textureAmount).defaultValue
        let reverb = try descriptor(EchoelBodyVibeDevice.BaseID.reverbMix).defaultValue
        let gain = try descriptor(EchoelBodyVibeDevice.BaseID.masterGain).defaultValue

        // COUNTERWEIGHT — the engines' own construction values differ from the tree, or the
        // claims below could not tell a seed from no seed.
        XCTAssertNotEqual(texture.gain, textureGain, "the texture's construction gain equals the default — vacuous")
        XCTAssertNotEqual(synth.bioBaseReverbMix, reverb, "the synth's construction reverb equals the default — vacuous")

        let returned = EchoelBodyVibeDevice.seed([:], synth: synth, texture: texture)

        XCTAssertEqual(texture.gain, textureGain, """
            A fresh instance plays the texture at \(texture.gain) while its knob shows \
            \(textureGain). This was the literal 0.15 in the AUv3's init.
            """)
        XCTAssertEqual(synth.frequency, pitch)
        XCTAssertEqual(texture.frequency, pitch * 0.5, "the texture no longer tracks the base pitch")
        XCTAssertEqual(synth.bioBaseReverbMix, reverb, "the reverb anchor is not seeded")
        XCTAssertEqual(synth.reverbMix, reverb)
        XCTAssertEqual(returned, gain, "the output gain is not the descriptor default")
    }

    // MARK: - claim 2

    func testSeedTakesTheTreeValuesAndRefusesGarbage() {
        let (synth, texture) = engines()
        let returned = EchoelBodyVibeDevice.seed([
            EchoelBodyVibeDevice.BaseID.baseFrequency: 330,
            EchoelBodyVibeDevice.BaseID.textureAmount: 5,          // above range → max
            EchoelBodyVibeDevice.BaseID.reverbMix: .nan,           // non-finite → default
            EchoelBodyVibeDevice.BaseID.masterGain: 0.25,
            "bodyvibe.bio.heartRate": 1,                            // not creative → ignored
        ], synth: synth, texture: texture)

        XCTAssertEqual(synth.frequency, 330)
        XCTAssertEqual(texture.frequency, 165)
        XCTAssertEqual(texture.gain, 1, "an out-of-range value was not clamped to the descriptor")
        let reverbDefault = EchoelBodyVibeDevice.creativeDescriptors
            .first { $0.keyPath == EchoelBodyVibeDevice.BaseID.reverbMix }?.defaultValue
        XCTAssertEqual(synth.bioBaseReverbMix, reverbDefault, "a NaN reached the reverb anchor")
        XCTAssertEqual(returned, 0.25)
    }

    // MARK: - claim 3

    func testSeedEqualsWhatTheObserverWouldHaveWritten() {
        let values: [String: Float] = [
            EchoelBodyVibeDevice.BaseID.baseFrequency: 97,
            EchoelBodyVibeDevice.BaseID.textureAmount: 0.42,
            EchoelBodyVibeDevice.BaseID.reverbMix: 0.61,
        ]
        let (seededSynth, seededTexture) = engines()
        EchoelBodyVibeDevice.seed(values, synth: seededSynth, texture: seededTexture)

        let (movedSynth, movedTexture) = engines()
        for (id, value) in values {
            guard let binding = EchoelBodyVibeDevice.binding(for: id) else {
                return XCTFail("\(id) has no binding — seed and observer cannot agree")
            }
            EchoelBodyVibeDevice.apply(binding, value: value, synth: movedSynth, texture: movedTexture)
        }
        XCTAssertEqual(seededSynth.frequency, movedSynth.frequency)
        XCTAssertEqual(seededTexture.frequency, movedTexture.frequency)
        XCTAssertEqual(seededTexture.gain, movedTexture.gain)
        XCTAssertEqual(seededSynth.bioBaseReverbMix, movedSynth.bioBaseReverbMix)
        XCTAssertEqual(seededSynth.reverbMix, movedSynth.reverbMix, """
            Seeding and moving a knob to the same value leave different engine state. There \
            must be ONE write per binding, and `seed` must go through it.
            """)
    }

    // MARK: - claim 4 (SOURCE-TEXT SCAN)

    func testTheAudioUnitSeedsFromItsTreeAndCarriesNoLiteral() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        XCTAssertFalse(code.contains("texture.gain = 0.15"), """
            The AUv3 sets a literal texture gain again. The texture then plays a value no knob \
            shows; the default lives in `creativeDescriptors`.
            """)
        let allocate = try XCTUnwrap(Self.body(
            startingWith: "public override func allocateRenderResources() throws {", in: code),
            "allocateRenderResources not found — re-anchor this guard (#456)")
        let seed = try XCTUnwrap(allocate.range(of: "gainMirror.value = EchoelBodyVibeDevice.seed("), """
            `allocateRenderResources` no longer seeds the engines and the output gain from the \
            tree. A restored or host-set value then sounds only after the knob moves.
            """)
        let noteOn = try XCTUnwrap(allocate.range(of: "synth.noteOn("),
                                   "the idle voice is no longer armed here — move this check (#456)")
        XCTAssertLessThan(seed.lowerBound, noteOn.lowerBound,
                          "the engines are seeded after the note starts — the first block plays stale values")
        let initBody = try XCTUnwrap(Self.body(startingWith: "public override init(", in: code),
                                     "the AUv3 init is not found — re-anchor this guard (#456)")
        XCTAssertTrue(initBody.contains("EchoelBodyVibeDevice.seed("),
                      "init no longer seeds the engines from the descriptor defaults")
    }

    // MARK: - helpers

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
