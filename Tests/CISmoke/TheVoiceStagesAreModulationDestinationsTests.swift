// TheVoiceStagesAreModulationDestinationsTests.swift
// Echoel — #1249 (founder 2026-09-11: *"Das Biofeedback die Stimmeffekte moduliert sollte klar
// sein"*). The body can drive the voice stages — through the modulation MATRIX, the persisted,
// OSC-tapped, ~1 Hz control plane that already carried the tempo.
//
// MEASURED BEFORE THIS SLICE: `ModDestinationKey` held ONE key (`seq.tempo`); `FXModTarget`
// knew neither harmonizer nor granular; the monitor insert's chain is private behind
// `applyVoicePreset`. So the honest route is four new DESTINATIONS whose closures write the
// `AudioEngine` parameters that already funnel through `pushVoicePreset()` (#416) — never the
// chain, never the render thread. Enable flags are deliberately NOT destinations.
//
// A ~1 Hz step on a wet mix is audible, so `EchoelHarmonizer` now smooths its mix per sample
// (~42 ms) — but ADOPTS the mix on its first sample after init/reset, so a stage configured
// before audio runs is exactly what it was configured to be (the existing dry test).
//
// END-TO-END for claim 4 (the harmonizer is a shipped value type); SOURCE-TEXT SCAN for 1–3.
// The matrix has no editing surface yet — that is S5 (#1250); until then a route reaches
// these keys only from a persisted document. Audibility is a DEVICE PROBE.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`3d86123`) and this tree: claims
// 1–3 RED on the parent (no voice keys — one finding, #486), GREEN here; claim 4a (dry from
// the first sample) GREEN on both, 4b (a live change fades rather than steps) RED on the
// parent, GREEN here. Stripper: PROPHYLAKTISCH (0 of 8 scan verdicts flip).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheVoiceStagesAreModulationDestinationsTests: XCTestCase {

    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let engine = "Sources/Echoelmusic/Core/ModulationEngine.swift"

    /// Claim 1 — the four keys exist, are listed, and have names for a picker.
    func testTheFourVoiceKeysAreDeclaredAndNamed() {
        let keys = [ModDestinationKey.voiceHarmonyMix, ModDestinationKey.voiceGranularMix,
                    ModDestinationKey.voiceGranularPitch, ModDestinationKey.voiceTuneStrength]
        XCTAssertEqual(keys, ["voice.harmony.mix", "voice.granular.mix", "voice.granular.pitch", "voice.tune.strength"],
                       "the voice destination keys changed spelling — a persisted route would silently stop reaching its stage (#1249)")
        XCTAssertEqual(ModDestinationKey.all, [ModDestinationKey.tempo] + keys,
                       "`ModDestinationKey.all` must list tempo first, then the four voice keys, in picker order (#1249)")
        for key in ModDestinationKey.all {
            XCTAssertNotEqual(ModDestinationKey.displayName(key), key, "`\(key)` has no display name (#1249)")
        }
        XCTAssertEqual(ModDestinationKey.displayName("future.key"), "future.key", "an unknown key shows as-is, never crashes (#1249)")
    }

    /// Claim 2 — the launch registers all four, beside the tempo, each writing ONE engine parameter.
    func testTheLaunchRegistersTheVoiceDestinations() throws {
        let src = SourceText.codeOnly(try text(Self.app))
        let wires: [(String, String)] = [
            ("ModDestinationKey.voiceHarmonyMix", "audioEngine?.voiceHarmonyMix = value.clamped(to: 0...1)"),
            ("ModDestinationKey.voiceGranularMix", "audioEngine?.voiceGranularMix = value.clamped(to: 0...1)"),
            ("ModDestinationKey.voiceGranularPitch", "audioEngine?.voiceGranularPitch = (value.clamped(to: 0...1) * 24 - 12)"),
            ("ModDestinationKey.voiceTuneStrength", "audioEngine?.voiceTuneStrength = value.clamped(to: 0...1)"),
        ]
        for (key, write) in wires {
            XCTAssertEqual(src.components(separatedBy: "modulationEngine.register(\(key))").count - 1, 1,
                           "`\(key)` is not registered exactly once at launch (#1249)")
            XCTAssertTrue(src.contains(write), "the `\(key)` handler no longer writes its one clamped parameter (#1249)")
        }
        // Counterweight: the tempo registration the older guard pins is untouched.
        XCTAssertTrue(src.contains("modulationEngine.register(ModDestinationKey.tempo)"))
        // No handler flips an enable — the enable stays the singer's (#1249).
        for forbidden in ["setVoiceHarmony(", "setVoiceGranular(", "setVoiceTune("] {
            XCTAssertFalse(src.contains("audioEngine?.\(forbidden)"),
                           "a modulation handler switches a voice stage on/off — a ~1 Hz enable is a click machine and the enable is the singer's (#1249)")
        }
    }

    /// Claim 3 — the engine parameters the handlers write still funnel through `pushVoicePreset()`.
    func testTheParametersStillFunnelThroughOnePush() throws {
        let src = SourceText.codeOnly(try text("Sources/Echoelmusic/Audio/AudioEngine.swift"))
        for decl in ["var voiceHarmonyMix: Float = 0.5 { didSet { pushVoicePreset() } }",
                     "var voiceGranularMix: Float = 0.4 { didSet { pushVoicePreset() } }",
                     "var voiceGranularPitch: Float = 0 { didSet { pushVoicePreset() } }"] {
            XCTAssertTrue(src.contains(decl), "`\(decl)` changed — the destination's write no longer reaches the insert through the ONE push (#416/#1249)")
        }
        XCTAssertTrue(src.contains("var voiceTuneStrength: Float = 1"),
                      "`voiceTuneStrength` moved — the tune tick reads it each pass; if it gained a didSet that is fine, move this needle (#1249)")
    }

    /// Claim 4 — the harmonizer adopts its mix on the first sample and FADES on a live change.
    func testTheHarmonizerFadesALiveMixChangeButStartsWhereItIsSet() {
        let fx = EchoelHarmonizer(sampleRate: 48_000)
        fx.mix = 0
        for i in 0..<64 {
            let x = sinf(Float(i) * 0.11)
            let (l, _) = fx.processStereo(x, x)
            XCTAssertEqual(l, x, accuracy: 1e-6, "mix 0 set before audio must be dry from the FIRST sample (#1249)")
        }
        // Fill the delay lines with a steady tone, then step the mix live.
        for i in 0..<4_000 { let x = sinf(2 * Float.pi * 220 * Float(i) / 48_000); _ = fx.processStereo(x, x) }
        fx.mix = 1
        var firstDeviation: Float = 0
        var lateDeviation: Float = 0
        for i in 4_000..<12_000 {
            let x = sinf(2 * Float.pi * 220 * Float(i) / 48_000)
            let (l, _) = fx.processStereo(x, x)
            let dev = abs(l - x)
            if i < 4_010 { firstDeviation = max(firstDeviation, dev) }
            if i >= 11_000 { lateDeviation = max(lateDeviation, dev) }
        }
        XCTAssertLessThan(firstDeviation, 0.05, "the first 10 samples after a live mix step must still be nearly dry — the step is a fade, not a jump (#1249)")
        XCTAssertGreaterThan(lateDeviation, 0.2, "seven thousand samples later the harmony must be audible — the fade must actually arrive (#1249)")
        fx.reset()
        fx.mix = 0
        let (l, _) = fx.processStereo(0.5, 0.5)
        XCTAssertEqual(l, 0.5, accuracy: 1e-6, "after `reset()` the stage adopts the mix again on its first sample (#1249)")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
