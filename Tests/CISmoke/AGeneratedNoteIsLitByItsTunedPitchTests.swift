// AGeneratedNoteIsLitByItsTunedPitchTests.swift
// Echoel — DMMW Phase 6 · slice 3 (founder 2026-09-29, "Klang-zu-Licht": note/frequency → octave
// colour, deterministic; key and A4 changes must change colour consistently).
//
// THE DEFECT. `PianoRollModel.musicalFrame` — the ONE publisher every renderer (visual, light,
// ADM-OSC, the OSC music out) reads — gave each generated note `a4 · 2^((p − 69)/12)`: A4, and no
// tone-system cents. Every pitched voice installs the tone system's per-pitch-class table
// (`applyTuning`), and the touch surface's colour already read it. So in a maqām, just or
// Pythagorean system a generated note SOUNDED retuned and was LIT as 12-TET, and the same note
// played on the touch surface got a different colour. One pitch, two lights.
//
// THE REPAIR, on the existing owners (no new store, clock or modal):
//   · `musicalFrame(forActive:a4Hz:pitchClassCents:…)` takes the table, with NO default (#431),
//     and folds it into the exponent exactly as `EchoelPolyDDSP.noteOn` does. A table that is not
//     twelve finite entries reads as 12-TET — the refusal `setTuningCents` applies.
//   · `PianoRollModel.musicalPitchClassCents` carries it; `applyTuning` pushes the SAME `cents`
//     (through the same Float rounding) that it hands every voice.
//
// Claims, labelled per `Tests/CISmoke/CLAUDE.md` §1:
//   1. END-TO-END — under 12-TET the published Hz is bit-identical to the old formula.
//   2. END-TO-END — under a real non-12-TET system from `TuningSystem.library`, the published Hz
//      equals the Hz the ENGINE sets on the voice for that note (Float tolerance), for all twelve
//      pitch classes; and a deviating pitch class gets a colour different from its 12-TET one.
//   3. END-TO-END — a malformed or non-finite table publishes the 12-TET pitch, never a NaN.
//   4. SOURCE-TEXT SCAN — the tick hands the model's table to the frame; `applyTuning` pushes the
//      same `cents` it gives the voices; the parameter has no default.
// GRADING against the parent: the parent's `musicalFrame` has no `pitchClassCents:` label and no
// `equalTemperamentCents`, so this file does NOT compile against it — no assertion has a verdict
// there; hand-transcribed instead. Claims 1 and 3 are FORWARD guards (the 12-TET half would have
// been green on the parent's formula); claim 2 is the REGRESSION the slice fixes (the parent's
// frame ignores the table); claim 4 is red there by ANCHOR ABSENCE (one absence).
// ⛔ HONEST LIMITS. What a viewer sees is a DEVICE PROBE. The MSL copy of the colour rule is pinned
// elsewhere (`SpectralSeamTwinTests`). The frame still carries no per-voice transpose or detune —
// those are per-instrument offsets on single voices, not the pitch system, and the touch colour
// ignores them too; recorded, not changed here. NEEDS-FOUNDER-VERIFY: pick a maqām tone system,
// let the take play with the Visual window open — the clouds of a retuned degree shift hue.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class AGeneratedNoteIsLitByItsTunedPitchTests: XCTestCase {

    private static let roll = "Sources/Echoelmusic/Studio/PianoRollView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    private func publishedHz(pitch: Int, a4: Double, cents: [Double]) throws -> Double {
        let frame = PianoRollModel.musicalFrame(
            forActive: [Note(pitch: pitch, startStep: 0, velocity: 0.8)], a4Hz: a4,
            pitchClassCents: cents, rootPitchClass: 0, scaleName: "major", tempoBPM: 120, beatPhase: 0)
        return try XCTUnwrap(frame.notes.first?.frequencyHz)
    }

    /// A real tone system from the shipped library — Maqām Bayātī, whose neutral seconds move
    /// several pitch classes by 50 cents — so the claim is about what a user can pick.
    /// `named` falls back to 12-TET for an unknown id, which the anchor below catches.
    private func retunedSystem() throws -> (id: String, cents: [Double]) {
        let system = TuningSystem.named("maqam-bayati")
        // The same rounding `applyTuning` applies: Double → Float (what the voices take) → Double.
        let cents = system.pitchClassCents(root: 0).map { Double(Float($0)) }
        guard system.id == "maqam-bayati", cents.contains(where: { abs($0) > 1 }) else {
            XCTFail("ANCHOR MISSING: the library no longer ships Maqām Bayātī with a moved pitch class (#454)")
            throw AnchorMissing()
        }
        return (system.id, cents)
    }

    // MARK: 1 — 12-TET is unchanged

    func testEqualTemperamentPublishesExactlyTheOldPitch() throws {
        for pitch in 48...84 {
            let hz = try publishedHz(pitch: pitch, a4: 440, cents: PianoRollModel.equalTemperamentCents)
            XCTAssertEqual(hz, 440 * pow(2.0, Double(pitch - 69) / 12.0),
                           "a zero table adds nothing — pitch \(pitch) must be bit-identical")
        }
        XCTAssertEqual(PianoRollModel.equalTemperamentCents.count, 12)
    }

    // MARK: 2 — the published pitch is the sounding pitch

    func testTheFrameCarriesThePitchTheEngineSounds() throws {
        let (id, cents) = try retunedSystem()
        for pitch in 60..<72 {
            let engine = EchoelPolyDDSP(maxVoices: 1)
            engine.a4Hz = 432
            engine.setTuningCents(cents.map { Float($0) })
            engine.noteOn(note: pitch)
            var sounding: [Float] = []
            engine.forEachVoice { voice in sounding.append(voice.frequency) }
            let heard = try XCTUnwrap(sounding.first, "ANCHOR: noteOn spawned no voice")

            let lit = try publishedHz(pitch: pitch, a4: 432, cents: cents)
            XCTAssertEqual(lit, Double(heard), accuracy: Double(heard) * 1e-5, """
                \(id), pitch \(pitch): the light is computed from \(lit) Hz while the voice sounds \
                \(heard) Hz — the frame dropped the tone system
                """)
        }

        var recoloured = 0
        for pitchClass in 0..<12 where abs(cents[pitchClass]) > 1 {
            let tuned = SpectralColor.toneLinearRGB(
                forToneHz: try publishedHz(pitch: 60 + pitchClass, a4: 440, cents: cents))
            let plain = SpectralColor.toneLinearRGB(
                forToneHz: try publishedHz(pitch: 60 + pitchClass, a4: 440, cents: PianoRollModel.equalTemperamentCents))
            if tuned != plain { recoloured += 1 }
        }
        XCTAssertGreaterThan(recoloured, 0, "\(id): a retuned degree must not wear its 12-TET colour")
    }

    // MARK: 3 — a bad table is 12-TET, never NaN

    func testAMalformedTablePublishesTheEqualTemperedPitch() throws {
        var poisoned = PianoRollModel.equalTemperamentCents
        poisoned[9] = .nan
        for bad in [[Double](repeating: 20, count: 11), poisoned, [Double](repeating: .infinity, count: 12), []] {
            for pitch in [57, 69, 81] {
                let hz = try publishedHz(pitch: pitch, a4: 440, cents: bad)
                XCTAssertTrue(hz.isFinite)
                XCTAssertEqual(hz, 440 * pow(2.0, Double(pitch - 69) / 12.0),
                               "a table the voices would refuse must not move the light either")
            }
        }
    }

    // MARK: 4 — SOURCE: the wiring

    func testTheTickAndTheStudioHandTheSameTableOn() throws {
        let roll = try source(Self.roll)
        XCTAssertTrue(roll.contains("a4Hz: musicalA4Hz, pitchClassCents: musicalPitchClassCents,"),
                      "the tick publishes with the model's table")
        guard let signature = roll.range(of: "public static func musicalFrame(forActive notes: [Note], a4Hz: Double,"),
              let brace = roll[signature.upperBound...].firstIndex(of: "{") else {
            return XCTFail("ANCHOR MISSING: the musicalFrame signature (#454)")
        }
        let parameters = String(roll[signature.lowerBound..<brace])
        XCTAssertTrue(parameters.contains("pitchClassCents: [Double],"),
                      "the table is a required parameter — a defaulted one appears in no diff (#431)")

        let studio = try source(Self.studio)
        let apply = try member("private func applyTuning() {", in: studio)
        guard let voices = apply.range(of: "synth.setTuningCents(cents)"),
              let frame = apply.range(of: "pianoRoll.musicalPitchClassCents = cents.map { Double($0) }") else {
            return XCTFail("ANCHOR MISSING: applyTuning's voice fan and frame push (#454)")
        }
        XCTAssertLessThan(voices.lowerBound, frame.lowerBound, "same `cents`, same function")
        XCTAssertEqual(apply.components(separatedBy: "let cents = ").count - 1, 1,
                       "ONE table computed, handed to voices and frame alike")
    }

    // MARK: - Helpers

    private struct AnchorMissing: Error {}

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }

    /// The brace-matched body that starts at `anchor`, searched from the anchor's FIRST character (#408).
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing()
        }
        var depth = 0
        var cursor = open
        while cursor < code.endIndex {
            if code[cursor] == "{" { depth += 1 }
            if code[cursor] == "}" {
                depth -= 1
                if depth == 0 { return String(code[open...cursor]) }
            }
            cursor = code.index(after: cursor)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing()
    }
}
