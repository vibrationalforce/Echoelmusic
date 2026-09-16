// TheMultitrackRecorderIsGoneFromTheIdentityLineTests.swift
// Echoel — #1326. The IDENTITY block of the always-loaded `CLAUDE.md` — the paragraph a
// session reads before its first line of work — still said `MultiTrackRecorder` "existiert und
// wird unbedingt konstruiert", four days after #1302 deleted the file.
//
// ⭐ WHY THIS ONE IS WORSE THAN A STALE NUMBER. The struck sentence was itself a CORRECTION: on
// 2026-07-31 it replaced "nie gebaut" and argued, correctly at the time, that calling a built
// thing unbuilt "lässt eine Session neu bauen, was schon da ist". #1302 then deleted the type
// and the correction inverted into the same defect pointing the other way — it now invites a
// session to WIRE UP a recorder that no longer exists, from the most load-bearing paragraph in
// the repo. A correction ages exactly like the claim it corrected.
// Both line citations it carried had rotted independently (`AudioEngine.swift:345` is a pointer
// allocation, `EchoelmusicApp.swift:1179` a comment) — §E's law, on the same paragraph twice.
//
// ⚠️ NO NEGATIVE TEXT SCAN ON `CLAUDE.md` (#491). This file deliberately QUOTES the struck
// sentence in its ⛔ retraction, so a guard forbidding the words would go red on the repair
// itself. Claim 1 is POSITIVE — the retraction is present — and claim 2 pins the FACT in the
// place where it is checkable: `Sources/` code, read through `SourceText.codeOnly` so the many
// legitimate comment mentions (`RecordController`, `FeatureFlags`, `AudioConfiguration`) do not
// count. That split is the whole design: the prose claim and the code fact are asserted in
// different corpora, and neither can drift without the other going red.
//
// ⚠️ IT FORBIDS NO RESTORATION (#364). If a multitrack recorder is built again, claim 2 goes
// red and its message names the identity line that must move in the same commit.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **4 assertions across two claims**
// (claim 1 = 2, claim 2 = 2), transcribed in Python and driven against BOTH trees. On the
// parent (`b554e4a`) **2 are red and they are ONE finding** (#486): claim 1's retraction did
// not exist. Claim 2 is a COUNTERWEIGHT (#343) — green on both trees, and it is what keeps
// claim 1 from being a sentence about a sentence.
// SOURCE-TEXT SCAN throughout (§1); nothing here observes behaviour.

import Foundation
import XCTest

final class TheMultitrackRecorderIsGoneFromTheIdentityLineTests: XCTestCase {

    /// Claim 1 — the identity block records the deletion, and records that it is retracting an
    /// earlier CORRECTION rather than an original claim.
    func testTheIdentityBlockRecordsTheDeletion() throws {
        let law = try text("CLAUDE.md")
        XCTAssertTrue(
            law.contains("**GELÖSCHT mit #1302** (Founder 2026-09-12, kein Mikrofon mehr): `MultiTrackRecorder` ist als DATEI weg"),
            "CLAUDE.md's identity block no longer records that `MultiTrackRecorder` was deleted "
            + "by #1302. That paragraph is the first thing a session reads; a claim there that "
            + "the recorder is 'gebaut, flag-gated AUS, türlos' sends the next cycle looking "
            + "for a door onto a type that is not in the tree.")
        XCTAssertTrue(
            law.contains("eine KORREKTUR veraltet genauso wie das, was sie korrigierte"),
            "the lesson is gone. It is the point of the entry: the struck sentence was itself a "
            + "2026-07-31 correction of 'nie gebaut', and nothing in this repo re-checks a "
            + "correction the way it re-checks an original claim.")
    }

    /// Claim 2 — counterweight, and the half that is checkable against code: no production
    /// Swift references the type. Comments are stripped, because several files mention it in
    /// their own tombstones and those must stay legal.
    func testNoProductionCodeNamesTheRecorder() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: sources.path) else {
            XCTFail("ANCHOR MISSING: could not walk Sources/ (#454)")
            return
        }
        var offenders: [String] = []
        var files = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let body = try? String(contentsOf: sources.appendingPathComponent(relative),
                                         encoding: .utf8) else { continue }
            files += 1
            if SourceText.codeOnly(body).contains("MultiTrackRecorder") {
                offenders.append(relative)
            }
        }
        XCTAssertGreaterThan(files, 100,
                             "ANCHOR MISSING: read \(files) Swift files under Sources/ — too few "
                             + "for claim 2's absence to mean anything (#454/#926).")
        XCTAssertEqual(offenders, [],
                       "`MultiTrackRecorder` is referenced in CODE again by \(offenders). This "
                       + "guard forbids rebuilding it (#364) — it reports it: move CLAUDE.md's "
                       + "identity line in the SAME commit, and say which of built / "
                       + "flag-gated / doorless it actually is.")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
