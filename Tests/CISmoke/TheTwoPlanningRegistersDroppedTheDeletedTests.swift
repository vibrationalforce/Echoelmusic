// TheTwoPlanningRegistersDroppedTheDeletedTests.swift
// Echoel — #1342. Two registers that are NOT the hook-loaded five, and that #1341's guard
// therefore cannot reach, each carried a founder-deleted capability as present tense:
//
//   · `ContentPipeline/CLAIMS.md` — the one list CLAUDE.md orders read BEFORE any script,
//     caption or hashtag. It listed `MultiTrackRecorder` under "Gebaut und konstruiert, aber für
//     den Nutzer TÜRLOS", described as "in `AudioEngine` bedingungslos angelegt". The file is
//     DELETED (#1302). This is the register whose whole purpose is that a false claim on a store
//     page is a 2.3 rejection.
//   · `docs/dev/ROADMAP.md` — item 7, under **NEXT (authorized direction)**: "[Sound/flagship]
//     **Audiovisual Vocoder** wiring (`VocoderCore`/`FeedbackGuard`/`BioModulation` cores exist)".
//     Two of those three are gone as files, and its input half — the microphone — with them.
//     Item 3 was a ✅ DONE row pointing at `SampleBrowserView` through a Tools grid; the grid went
//     2026-07-02, the drums with #166/#167, the view with #167.
//
// ⭐ WHY THESE TWO ARE WORTH A GUARD OF THEIR OWN, rather than widening #1341's scan to the whole
// repo: that scan was MEASURED over `docs/dev/` + `ContentPipeline/` before this slice and came
// back with **104 bare names over 21 files**, nearly all correct — test-bundle names, `Codable`,
// `HaishinKit` in an explicitly-unlinked plan, banned-word lists in a triage doc, table markers
// like `LIVE`/`ROADMAP` in backticks. Widening it would have shipped a checker whose output is
// mostly noise, which is worse than none (#665). So the general rule stays on the five
// always-loaded files, and these two registers get NAMED pins instead. That asymmetry is the
// finding, not a compromise.
//
// ⭐ AND THE SHAPE THE ROADMAP ITEM LEAVES BEHIND, which outlives this cycle: its own note named
// the blocker in June — "`VocoderCore` also needs a voice analyzer (mic pitch/energy/brightness)
// which was removed in the soundscape refactor". **A prerequisite that was already absent was
// carried for three months as a flagship NEXT.** An item whose note names a missing dependency is
// blocked, not next, and nothing in this repo re-reads a ✅ or a NEXT row to notice.
//
// ⚠️ FORBIDS NOTHING (#364). Rebuilding a recorder or a vocoder is the founder's call; if it comes
// back, these assertions go red and their messages say which register lines move in the same
// commit. Positive pins only, because both files strike claims by QUOTING them (#491).
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **7 assertions across three claims**
// (claim 1 = 1 anchor + 2 pins, claim 2 = 1 anchor + 2 pins, claim 3 = 1). On the parent
// (`99de158`) **4 are red and they are THREE findings** (#486): CLAIMS' recorder entry, ROADMAP
// item 7, ROADMAP item 3 — and claim 1's two pins split ONE of those (the CLAIMS repair is pinned
// by its retraction line alone, item 7 and item 3 by one pin each). The other **3 are
// COUNTERWEIGHTS** (#343), green on both trees: the two anchors, plus claim 3, which keeps the
// surviving true half of the CLAIMS entry from being deleted along with the false one.
// SOURCE-TEXT SCAN (§1). Prose only; nothing here runs app code.

import Foundation
import XCTest

final class TheTwoPlanningRegistersDroppedTheDeletedTests: XCTestCase {

    private static let claims = "ContentPipeline/CLAIMS.md"
    private static let roadmap = "docs/dev/ROADMAP.md"

    /// Claim 1 — the claim register records the deletion instead of listing a removed file as
    /// "built and unconditionally constructed".
    func testTheClaimRegisterDroppedTheRecorder() throws {
        let text = try Self.text(Self.claims)
        XCTAssertFalse(text.isEmpty, "ANCHOR MISSING: could not read \(Self.claims) (#454).")
        XCTAssertTrue(
            text.contains("`MultiTrackRecorder` stand hier an erster Stelle und ist GELÖSCHT"),
            "`ContentPipeline/CLAIMS.md` no longer records that the multitrack recorder is gone. "
            + "It listed the file as constructed in `AudioEngine` for four days after #1302 "
            + "deleted it — in the register a session is ordered to read before writing any "
            + "caption, on the surface where a false claim is a 2.3 rejection.")
        XCTAssertTrue(
            text.contains("es ist wirklich weg"),
            "the retraction no longer says which DIRECTION the correction runs. The paragraph "
            + "below it warns that \"nie gebaut\" invites a session to rebuild something that "
            + "already exists; for this entry the opposite is now true, and leaving that "
            + "unstated turns the surrounding advice against the reader.")
    }

    /// Claim 2 — the roadmap does not hold a NEXT item or a ✅ DONE row for deleted code.
    func testTheRoadmapHoldsNoOrderForDeletedCode() throws {
        let text = try Self.text(Self.roadmap)
        XCTAssertFalse(text.isEmpty, "ANCHOR MISSING: could not read \(Self.roadmap) (#454).")
        XCTAssertTrue(
            text.contains("CUT — [Sound/flagship] Audiovisual Vocoder wiring"),
            "roadmap item 7 no longer records that the flagship vocoder is CUT. It sat under "
            + "**NEXT (authorized direction)** saying the cores exist. `VocoderCore` and "
            + "`FeedbackGuard` are deleted files and the microphone they needed is gone — an "
            + "authorized NEXT is the strongest instruction this document can give.")
        XCTAssertTrue(
            text.contains("VOID — the item, the door and the view are all gone"),
            "roadmap item 3 no longer records that its ✅ DONE is void. It claimed "
            + "`SampleBrowserView` reachable via Tools → Drum Samples; the grid went 2026-07-02, "
            + "the drums with #166/#167 and the view with #167. A ✅ row is the last place anyone "
            + "re-checks, which is exactly why it outlived three deletions.")
    }

    /// Claim 3 — counterweight: the TRUE half of the edited CLAIMS entry must survive the edit.
    /// Without this, removing the false first item could take the honest one with it.
    func testTheDoorlessSamplerVoiceStillStandsInTheRegister() throws {
        let text = try Self.text(Self.claims)
        XCTAssertTrue(
            text.contains("`SamplerVoice` (in `BeatPlayer`"),
            "the `SamplerVoice` line is gone from `CLAIMS.md`. It shared a bullet with the "
            + "deleted recorder and is STILL TRUE — the voice is constructed, there is simply no "
            + "surface that hands the user a sample. Losing it while striking its neighbour is "
            + "the standard cost of editing a shared bullet (#472), and it would quietly remove "
            + "a real \"do not claim this\" line from the register that governs content.")
    }

    private static func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
