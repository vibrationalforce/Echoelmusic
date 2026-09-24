// TheEntryPointTellsTheTruthTests.swift
// Echoel — the first line of the app must not describe a different product. #587, re-anchored
// 2026-09-24 on the founder product law.
//
// WHAT THIS GUARDS. The doc comment on the `@main` struct is an IDENTITY line: the first prose a
// session or a new contributor reads, and identity lines are what plans get derived FROM. It
// has been wrong twice, in opposite directions:
//   · #587 — it carried the v10 DAW-era tagline "Make Beats. Record Video. Stream Live.", three
//     claims all struck (beats #166/#167, video edit #121 Slice 3, streaming never linked).
//   · 2026-09-24 — it carried the 2026-07-25 instrument sentence as the product BOUNDARY after
//     the founder had replaced that boundary with the DMMW law (`docs/dev/FOUNDER_PRODUCT_LAW.md`:
//     CURRENT PRODUCT LAW SUPERSEDES HISTORICAL PRODUCT CUTS). The sentence is still TRUE of what
//     ships; read as the boundary, it made every historical cut look like a standing ban.
//
// ⚠️ HONEST LIMITS. SOURCE-TEXT SCAN over RAW source — deliberately NOT `SourceText.codeOnly`,
// which blanks comments, and a doc comment is the entire subject here. It proves the entry point
// STATES the canonical law and that the superseded definition says it is superseded; it cannot
// prove anyone reads either, and it says nothing about what ships (that is FEATURE_STATUS).
//
// ⚠️ THE NEGATIVE NEEDLES CARRY THE `/// ` PREFIX, on purpose: the retraction blocks at the site
// QUOTE both retired lines (as CLAUDE.md's ⛔ blocks do), which is the #491 collision a bare-phrase
// needle would walk into. A quote that starts mid-line can never begin with `/// Echoel is`.
//
// ⭐ GRADING (§3), driven by transcription against both trees, raw:
//   · parent (1e9188d50): the entry point states the instrument sentence as its live first line →
//     claim 1 red by ABSENCE of the law text (one absence, #486), claim 3 red by PRESENCE of the
//     retired line; claims 5 and 6 are FORWARD guards on the R1/R2 documents, green there already
//     because those commits precede this one. Claim 2 (#587 tagline) and claim 4 are
//     COUNTERWEIGHTS, green on both trees.
//   · worktree: all six green.
// ⚠️ This guard does NOT forbid the instrument sentence anywhere else. It is a true description
// of today's build and legitimately appears in history, store-copy discussion and the ⛔ quote at
// the site (#364).

import Foundation
import XCTest

final class TheEntryPointTellsTheTruthTests: XCTestCase {

    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let law = "docs/dev/FOUNDER_PRODUCT_LAW.md"
    private static let superseded = "docs/dev/PRODUCT_DEFINITION.md"

    /// The one spelling of the identity clause, owned by the law file (#416). Kept to a span that
    /// sits on ONE line in both files — a needle across a hard wrap can never match.
    private static let identityClause = "full professional distributed multidimensional multimedia"
    private static let headline = "CURRENT PRODUCT LAW SUPERSEDES HISTORICAL PRODUCT CUTS."

    /// 1. The entry point states the canonical product law and names the file it comes from.
    func testTheEntryPointStatesTheCanonicalProductLaw() throws {
        let src = try rawSource(Self.app)
        XCTAssertTrue(src.contains(Self.identityClause),
                      "The @main doc no longer states the DMMW identity of FOUNDER_PRODUCT_LAW.md.")
        XCTAssertTrue(src.contains(Self.headline),
                      "The @main doc lost the supersession headline — without it a reader takes "
                      + "every historical cut in the repo for a standing scope ban.")
        XCTAssertTrue(src.contains(Self.law),
                      "The @main doc must name the law file it quotes, or it becomes a third spelling.")
    }

    /// 2. The retired v10 tagline must not be the LIVE doc line again (#587). Full original line,
    /// prefix included — the retraction block quotes the bare phrase and must stay legal (#491/#364).
    func testTheRetiredTaglineIsNotTheLiveDocLine() throws {
        XCTAssertFalse(try rawSource(Self.app)
            .contains("/// Echoelmusic — Make Beats. Record Video. Stream Live."),
            "The v10 DAW tagline is back on the entry point. All three of its claims are "
            + "struck; decisions.csv row 29 superseded it on 2026-05-30.")
    }

    /// 3. The 2026-07-25 instrument sentence must not be the LIVE opening line again. It may be
    /// QUOTED (the ⛔ block at the site does); a quote never starts a line with `/// Echoel is`.
    func testTheInstrumentSentenceIsNotTheLiveBoundary() throws {
        XCTAssertFalse(try rawSource(Self.app)
            .contains("/// Echoel is a bio-reactive instrument."),
            "The @main doc opens with the 2026-07-25 instrument sentence again. It is superseded "
            + "as the product boundary by FOUNDER_PRODUCT_LAW.md (2026-09-24); quote it, do not "
            + "state it as the identity.")
    }

    /// 4. COUNTERWEIGHT. The law the entry point cites exists and carries its own headline.
    func testTheLawFileStillCarriesItsHeadline() throws {
        let law = try rawSource(Self.law)
        XCTAssertTrue(law.contains(Self.headline),
                      "FOUNDER_PRODUCT_LAW.md lost its supersession headline — the entry point "
                      + "quotes it and must move WITH it, not outlive it.")
    }

    /// 5. COUNTERWEIGHT (#416). One spelling of the identity clause, owned by the law file.
    func testTheIdentityClauseIsTheLawsOwnSpelling() throws {
        XCTAssertTrue(try rawSource(Self.law).contains(Self.identityClause),
                      "The law no longer contains the clause the entry point quotes — update BOTH "
                      + "in one commit or the app header becomes a second spelling.")
    }

    /// 6. The superseded definition says so and points at its successor — otherwise its own
    /// "CANONICAL" status line would still read as current to anyone who opens it first.
    func testTheSupersededDefinitionPointsAtTheLaw() throws {
        let def = try rawSource(Self.superseded)
        XCTAssertTrue(def.contains("SUPERSEDED 2026-09-24"),
                      "PRODUCT_DEFINITION.md lost its supersession banner.")
        XCTAssertTrue(def.contains("FOUNDER_PRODUCT_LAW.md"),
                      "PRODUCT_DEFINITION.md no longer names the law that superseded it.")
    }

    // MARK: - source access (raw on purpose — the subject IS a comment; §2 skip/fail rules)

    private struct IdentityAnchorMissing: Error { let reason: String }

    private func rawSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw IdentityAnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — renamed or moved. \
                Re-anchor this scan; do not let it skip (#454).
                """)
        }
        return try String(contentsOf: path, encoding: .utf8)
    }
}
