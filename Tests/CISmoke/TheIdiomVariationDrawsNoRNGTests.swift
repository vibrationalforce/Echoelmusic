// TheIdiomVariationDrawsNoRNGTests.swift
// Echoel — the G3 variation axis never moves the composer's seeded streams, BLOCKING bundle.
//
// KIND: MIXED. Claims 1–2 and 4 are END-TO-END BEHAVIOUR; claim 3 is a SOURCE-TEXT SCAN.
//
// ⭐ WHY THIS IS A SEPARATE FACT FROM "the take is identical", and why it needs its own file.
// A take can be identical note-for-note and the stream can still be in the wrong place — the
// two only coincide while every genre resolves to `nil`. The moment a batch authors an envelope,
// the takes DIVERGE on purpose, and the only thing left holding the design together is that they
// diverge in the notes the envelope chose and NOWHERE ELSE. The measurable form of that is the
// UUID SEQUENCE: `nextUUID` draws twice from `rng` per note, so a single stray `rng.next()`
// anywhere upstream renumbers every note in the take while leaving pitches and steps alone.
// An equality assertion cannot see that; a sequence comparison is the only thing that can.
//
// ⛔ THE FAILURE THIS EXISTS TO CATCH is cheap to write and invisible in review: seeding the
// variation with `rng.next()` instead of deriving it. That is the obvious way to seed something
// in this file, it reads as correct, and it would make every note identity in the app depend on
// whether the "Vary" flag happened to be on — breaking take-to-take reproducibility, the
// `structureSeed` contract, and every golden guard in the bundle at once. `IdiomControl.seed` is
// therefore MIXED from the skeleton seed, exactly the way `chordSeed` is, and that choice is
// asserted here rather than only commented.
//
// ⚠️ HONEST GRADING (§0/§3), transcribed in Python against the parent and the worktree:
//   · claim 3 is a REGRESSION on the parent for its named reason (`idiomControl` does not exist
//     there).
//   · claims 1, 2 and 4 are COUNTERWEIGHTS, GREEN ON BOTH TREES by construction (#343). Claim 4
//     is the one that makes the other two mean something: it shows that this comparison CAN
//     fail, by changing something that genuinely does consume the stream.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheIdiomVariationDrawsNoRNGTests: XCTestCase {

    private static let composerFile = "Sources/Echoelmusic/Sequencer/BioComposer.swift"

    private func input(_ style: MusicStyle, seed: UInt64, vary: Bool, nonce: UInt64) -> BioComposer.Input {
        BioComposer.Input(heartRateBPM: 68, hrvNormalized: 0.55, coherence: 0.42,
                          breathPhase: 0.25, breathDepth: 0.4,
                          key: MusicalKey(root: 0, scale: style.scale),
                          style: style, mode: .studioLocked,
                          lockedTempo: Double(style.defaultTempo),
                          seed: seed, structureSeed: seed &+ 1,
                          suggestJourney: true,
                          idiomVariation: vary, variationNonce: nonce)
    }

    private func ids(_ input: BioComposer.Input) -> [UUID] {
        BioComposer.compose(input).notes.map { $0.id }
    }

    // MARK: - claim 1 (BEHAVIOUR) — the nonce does not renumber the take

    func testTheNonceLeavesTheUUIDSequenceUntouched() {
        for style in MusicStyle.offered {
            let base = ids(input(style, seed: 0x5EED, vary: true, nonce: 0))
            XCTAssertFalse(base.isEmpty, "\(style) composed no notes — the comparison would be vacuous (#806)")
            for nonce in [UInt64(1), 2, 999_983] {
                let rolled = ids(input(style, seed: 0x5EED, vary: true, nonce: nonce))
                XCTAssertEqual(base.count, rolled.count, """
                    \(style): nonce \(nonce) changed the NOTE COUNT. The variation seed is \
                    being drawn from a compose RNG rather than derived from the skeleton \
                    seed — see `idiomControl`.
                    """)
                XCTAssertEqual(base, rolled, """
                    \(style): nonce \(nonce) renumbered the notes while producing the same \
                    count. That is the signature of a shifted stream: `nextUUID` draws twice \
                    per note, so one stray draw upstream renumbers everything after it and \
                    changes nothing else. Nothing else in the bundle would go red.
                    """)
            }
        }
    }

    // MARK: - claim 2 (BEHAVIOUR) — the flag itself does not renumber the take

    func testTheFlagLeavesTheUUIDSequenceUntouched() {
        for style in MusicStyle.offered {
            XCTAssertEqual(ids(input(style, seed: 0xD00D, vary: false, nonce: 0)),
                           ids(input(style, seed: 0xD00D, vary: true, nonce: 0)), """
                \(style): turning `idiomVariation` on renumbered the notes. `idiomControl` \
                must derive its seed; a `rng.next()` in it advances the generator whether or \
                not the genre owns an envelope.
                """)
        }
    }

    // MARK: - claim 3 (SOURCE SCAN) — the derivation is a mix, not a draw

    func testTheIdiomSeedIsDerivedNotDrawn() throws {
        let code = try source(Self.composerFile)
        guard let start = code.range(of: "static func idiomControl(for input: Input) -> IdiomControl? {") else {
            throw AnchorMissing(reason: "`idiomControl` is gone — re-anchor (#454)")
        }
        guard let end = code.range(of: "\n    }", range: start.upperBound..<code.endIndex) else {
            throw AnchorMissing(reason: "`idiomControl` has no closing brace at the expected depth — re-anchor")
        }
        let body = String(code[start.lowerBound..<end.upperBound])
        XCTAssertFalse(body.contains("rng.next()"), """
            `idiomControl` draws from a compose RNG. It runs once per take, before the first \
            note is written, so the draw renumbers EVERY note — and only when the flag is on, \
            which makes it a bug that appears the day the door ships and not before.
            """)
        XCTAssertFalse(body.contains("SeededRNG("),
                       "`idiomControl` builds its own generator — derive the seed instead, see `chordSeed`")
        XCTAssertTrue(body.contains("0x9E3779B97F4A7C15"), """
            The idiom seed is no longer mixed with the golden-ratio constant the rest of this \
            file uses to derive a sub-seed without consuming a stream. If the derivation has \
            been replaced, say with what — an unmixed `structureSeed` would make the variation \
            correlate with the chord journey it is supposed to vary against.
            """)
        XCTAssertTrue(body.contains("input.variationNonce"), """
            `idiomControl` no longer reads the nonce. The re-generate door (G3b) raises \
            exactly that field; without this read the button is inert and nothing says so.
            """)
    }

    // MARK: - claim 4 (BEHAVIOUR, COUNTERWEIGHT) — the comparison can fail

    /// #367: a claim that cannot fail for its named reason is not a claim. Changing the take's
    /// own seed genuinely re-runs both streams, so the UUID sequence MUST differ — if this is
    /// green, the comparison above is measuring nothing.
    func testADifferentTakeSeedDoesRenumberTheNotes() {
        let style = MusicStyle.offered.first ?? .dubTechno
        let a = ids(input(style, seed: 0x5EED, vary: true, nonce: 0))
        let b = ids(input(style, seed: 0xA11CE, vary: true, nonce: 0))
        XCTAssertFalse(a.isEmpty, "no notes — the counterweight would be vacuous (#806)")
        XCTAssertNotEqual(a, b, """
            Two different take seeds produced the same note identities. The UUID sequence is \
            then not a function of the stream, and claims 1–2 of this file prove nothing.
            """)
    }

    // MARK: - source access (§0/§2)

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: path, encoding: .utf8) else {
            throw AnchorMissing(reason: "\(relativePath) is missing — re-anchor, do not skip (#454)")
        }
        return SourceText.codeOnly(text)
    }
}
