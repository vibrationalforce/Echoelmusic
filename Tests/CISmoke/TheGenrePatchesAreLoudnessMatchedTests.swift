// TheGenrePatchesAreLoudnessMatchedTests.swift
// Echoel — #1361: the founder's "angleichen" reached one patch roster of two.
//
// WHY THIS EXISTS. `SynthPatch.factory` has carried `rawFactory.map { $0.loudnessNormalized() }`
// since 2026-07-11, with the founder's own word in its doc comment. The GENRE roster never got
// the same treatment: `GenrePatches.patch(...)` never called it and never wrote `outputLevel`,
// so all 81 genre patches shipped at `level == 1.0`. That is the #456 shape — a repair travels
// to EVERY home, not only to the one being edited that day — and it stood for two months.
//
// ⭐ WHAT IT COST, measured over all 81 `return patch(` blocks (brace-matched, coverage printed
// and CHECKED at 81 of 81 before a single number was believed; the first attempt reached 73 and
// refused itself, which is the #1350 rule working): the 57 pad/lead patches spanned **15.61 dB**
// while `MusicStyle.mixLevels.harmony` spans 2.34 dB. The control that looks like the level
// control had an order of magnitude less authority than the spread it was supposed to ride.
//
// ⚠️ THE BASS ROSTER IS DELIBERATELY NOT NORMALISED, and claim 3 is what keeps that a decision
// instead of an oversight. Measured: all 24 of 24 bass patches land PAST the normaliser's 1.4
// ceiling, so wrapping the `patch(...)` helper instead would hand every one of them the same
// ×1.4 with their 6.19 dB spread unchanged — a level CHANGE wearing a level MATCH's clothes.
// A sub is not supposed to read as loud as a pad; that roster needs its own reference, and that
// is a separate slice. #364: claim 3 does not forbid it, it goes red the day someone does it and
// names the sentence to pull along.
//
// KIND (§1): **END-TO-END BEHAVIOUR** on claims 1–4 (`MusicStyle.synthPatch` and
// `SynthPatch.loudnessEstimate` are shipped, public, Foundation-only value types, driven here
// for real), plus one **SOURCE-TEXT SCAN** in claim 5. None of it is a DEVICE PROBE: no guard
// can say the result sounds right. That is the `NEEDS-FOUNDER-VERIFY` on `rawSynthPatch`.

import XCTest
@testable import Echoelmusic

final class TheGenrePatchesAreLoudnessMatchedTests: XCTestCase {

    /// The patch's own perceptual estimate — the same function the normaliser uses, so this
    /// guard and the code under test cannot drift apart (#416: ask the definition, do not
    /// restate it).
    private func estimate(_ patch: SynthPatch) -> Float {
        SynthPatch.loudnessEstimate(harmonicLevel: patch.harmonicLevel,
                                    brightness: patch.brightness,
                                    sustain: patch.sustain,
                                    noiseLevel: patch.noiseLevel,
                                    unisonVoices: patch.unisonVoices)
    }

    private func decibels(_ ratio: Float) -> Float { 20 * log10(ratio) }

    private func spreadDB(_ values: [Float]) -> Float {
        guard let lo = values.min(), let hi = values.max(), lo > 0 else { return 0 }
        return decibels(hi / lo)
    }

    // 1 — the wrap actually ran on every offered genre.
    func testEveryOfferedGenrePatchCarriesATrim() {
        XCTAssertFalse(MusicStyle.offered.isEmpty, """
            ANCHOR MISSING: the offered roster is empty, so every sweep below would pass \
            vacuously (§4 — a missing anchor is a finding, not a pass).
            """)
        for style in MusicStyle.offered {
            XCTAssertNotNil(style.synthPatch.outputLevel, """
                \(style.rawValue)'s patch "\(style.synthPatch.name)" ships with no `outputLevel`, \
                i.e. `level == 1.0` by fallback. The `loudnessNormalized()` wrap on `synthPatch` \
                is gone or was bypassed, and the roster is back to a 15.6 dB spread under a \
                2.3 dB fader.
                """)
        }
    }

    // 2 — the trim NARROWS the roster, and the raw spread is big enough for that to mean
    //     something (#367: the guard must be able to fail for its NAMED reason).
    func testTheTrimNarrowsTheRoster() {
        let patches = MusicStyle.offered.map(\.synthPatch)
        let raw = patches.map { estimate($0) }
        let matched = patches.map { estimate($0) * $0.level }

        let rawSpread = spreadDB(raw)
        let matchedSpread = spreadDB(matched)

        XCTAssertGreaterThan(rawSpread, 9, """
            The UN-trimmed roster now spans only \(rawSpread) dB. That is the premise of this \
            whole slice (#343 — pin the premise, or a green here proves nothing): if the genre \
            patches were re-authored to sit close together by hand, the normaliser is no longer \
            what is holding them together and this guard is measuring nothing.
            """)
        XCTAssertLessThan(matchedSpread, rawSpread, """
            The trim did not narrow the roster: raw \(rawSpread) dB, trimmed \(matchedSpread) dB. \
            Either `loudnessNormalized()` changed meaning or the wrap is applied to something \
            other than the patches this sweep reads.
            """)
        XCTAssertLessThan(matchedSpread, 9, """
            The trimmed roster still spans \(matchedSpread) dB. The normaliser clamps its trim to \
            0.45…1.4, so a roster authored far enough apart can out-run it — that is a signal to \
            re-author the outliers' `harmonicLevel`/`brightness`/`sustain`/`uni`, NOT to widen \
            the clamp: the clamp is what stops a patch being silenced or blown up.
            """)
    }

    // 3 — COUNTERWEIGHT (#343/#364). The bass roster is untouched ON PURPOSE.
    func testTheBassRosterIsDeliberatelyNotNormalised() {
        let bassOwners = MusicStyle.offered.compactMap { style in
            style.bassPatch.map { (style, $0) }
        }
        XCTAssertFalse(bassOwners.isEmpty, """
            ANCHOR MISSING: no offered genre has a bass patch, so this counterweight cannot \
            fail for its named reason (§4, #367).
            """)
        for (style, bass) in bassOwners {
            XCTAssertNil(bass.outputLevel, """
                \(style.rawValue)'s bass patch "\(bass.name)" now carries a trim. If that was \
                deliberate, this claim is the one to retract — but measure FIRST: all 24 of 24 \
                bass patches land past `loudnessNormalized()`'s 1.4 ceiling, so normalising them \
                against the PAD reference gives every one of them the same ×1.4 and leaves their \
                6.19 dB spread exactly where it was. That is a level change, not a level match. \
                A bass roster needs its own reference, and a sub is not supposed to read as loud \
                as a pad. Pull this comment and `GenrePatches.synthPatch`'s doc along.
                """)
        }
    }

    // 4 — the trim can never reach the two bounds that other sweeps read.
    //
    // ⚠️ Not decoration: `GainLatchRecoveryTests` asserts every shipped patch's `level` stays
    // under `EchoelDDSP.masterGainRange.upperBound`, and `OneDefinitionOfAParameterRangeTests`
    // sweeps all three banks against `SynthPatch.Bounds`. A trim that crossed either would turn
    // a robustness clamp into a gain stage — the exact defect those two files exist to catch.
    func testTheTrimStaysInsideEveryBoundOtherGuardsRead() {
        for style in MusicStyle.offered {
            let level = style.synthPatch.level
            XCTAssertTrue(SynthPatch.Bounds.outputLevel.contains(level), """
                \(style.rawValue)'s trim \(level) is outside `SynthPatch.Bounds.outputLevel` \
                \(SynthPatch.Bounds.outputLevel) — `clampToBounds` would start reshaping it.
                """)
            XCTAssertLessThan(level, EchoelDDSP.masterGainRange.upperBound, """
                \(style.rawValue)'s trim \(level) reaches the master-gain ceiling \
                \(EchoelDDSP.masterGainRange.upperBound); the clamp would begin SHAPING this \
                patch instead of only catching impossible values.
                """)
        }
    }

    // 5 — the house pattern stays a pattern: the switch lives behind the wrap, not inside it.
    func testTheSwitchStaysBehindTheWrap() throws {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        let path = dir.appendingPathComponent("Sources/Echoelmusic/Sequencer/GenrePatches.swift")
        guard let source = try? String(contentsOf: path, encoding: .utf8) else {
            return XCTFail("ANCHOR MISSING: GenrePatches.swift could not be read (§4).")
        }
        let code = SourceText.codeOnly(source)
        XCTAssertTrue(code.contains("var synthPatch: SynthPatch { rawSynthPatch.loudnessNormalized() }"), """
            `synthPatch` is no longer the one-line normalising wrapper. If the switch was inlined \
            back into it, every genre silently returns to `level == 1.0` while claims 1 and 2 \
            above may still pass on a stale build. This is the same two-part split that \
            `SynthPatch.factory`/`rawFactory` and `GenreFX.fxPreset`/`rawFXPreset` already use.
            """)
        XCTAssertTrue(code.contains("private var rawSynthPatch: SynthPatch"), """
            `rawSynthPatch` is gone. The un-normalised definitions need a name of their own, or \
            the next author has nowhere to put a timbre edit that is not also a level edit.
            """)
    }
}
