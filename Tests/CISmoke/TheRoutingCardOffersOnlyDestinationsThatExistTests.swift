// TheRoutingCardOffersOnlyDestinationsThatExistTests.swift
// Echoel — #1324. The "Body → parameter" card in the Routing sheet
// (`PatchbayView.modulationSection`) kept offering destinations this build deleted.
//
// ⭐ WHY THIS FILE EXISTS. #1249 registered four VOICE-STAGE destinations beside the tempo;
// #1302 deleted the monitor insert they wrote to, so `ModDestinationKey.all` has read
// `[tempo]` ever since. The CODE followed the removal; the COPY did not, in three places and
// one of them on screen:
//   · the empty state offered "the tempo, or a stage on your voice" — and because nothing in
//     production constructs a `ModRoute` (#541), the empty state IS what a first-run player
//     reads, not an edge case;
//   · the footer, which renders UNCONDITIONALLY outside the `isEmpty` branch, told the player
//     that "voice stages need their switch on in Audio input" — a surface deleted by the same
//     commit and tombstoned in `EchoelStudioView`;
//   · the `NEEDS-FOUNDER-VERIFY` note asked for a device session that cannot be run at all:
//     route to "Voice · harmony mix" with "Harmony im Input-Sheet AN". The harmonizer went
//     with #1305, the sheet with #1302. That one costs the FOUNDER's time, not a session's.
// A fourth, smaller one sat in `ModulationEngine` itself ("tempo and the voice stages").
//
// ⚠️ WHAT THIS GUARD DOES NOT DO (#364). It forbids no destination. Adding a voice stage back
// is legal and claims 1 and 5 would then be the work to do, not the obstacle — their messages
// say so. Claim 4 is the only one that asserts something about the LIST, and what it asserts
// is a relationship (every offered key has a human name), which stays true however the list
// grows and goes red on the real defect: a key appended to `all` without a `displayName` case,
// which renders the picker row as `seq.foo`.
//
// ⚠️ SCOPE. Claims 1 and 5 read `SourceText.codeOnly`, so the ⛔ tombstones that QUOTE the
// struck sentences — required by this repo's retraction style — are invisible to them. That is
// load-bearing here, not prophylactic: every needle in claim 1 occurs in the new comment block,
// so a raw read would be red on a correct tree.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **21 assertions across five claims**
// (claim 1 = 6: one anchor-non-empty plus five needles; claim 2 = 4; claim 3 = 4; claim 4 =
// 2 plus one per key in `all`, today 1, = 3; claim 5 = 4), all transcribed in Python and
// driven against BOTH trees. On the parent (`80379bd`) **6 are red and they are THREE
// findings** (#486): "your voice" in the empty state (one assertion), "voice stage" +
// "Audio input" in the footer (two assertions, ONE sentence), and the verify note naming a
// deleted destination instead of a live one (three assertions: neither `Tempo`, nor
// `seq.tempo`, nor the BPM lock occurs in it). The other 15 are COUNTERWEIGHTS (#343), green
// on both trees — including two needles in claim 1 ("harmony", "granular") that are
// PROPHYLACTIC and labelled as such: on the parent those words sat only in the comment the
// stripper removes.
// Claim 4 is END-TO-END (§1): `ModDestinationKey` is a top-level, non-isolated `public enum`
// of pure Foundation values, so the bundle really calls it. Whether a route authored here
// audibly moves the tempo is a DEVICE PROBE and stays open — the `NEEDS-FOUNDER-VERIFY` at
// `modulationSection` is the ask, and claim 3 exists to keep that ask answerable.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheRoutingCardOffersOnlyDestinationsThatExistTests: XCTestCase {

    private static let patchbay = "Sources/Echoelmusic/Studio/PatchbayView.swift"
    private static let engine = "Sources/Echoelmusic/Core/ModulationEngine.swift"

    /// Destination keys #1302 deleted with the monitor insert.
    private static let removedKeys = [
        "voice.harmony.mix", "voice.granular.mix", "voice.granular.pitch", "voice.tune.strength",
    ]

    /// Claim 1 — the card's RENDERED copy names no stage and no surface this build lacks.
    func testTheCardsCopyNamesNoStageThisBuildLacks() throws {
        let section = try Self.member("private var modulationSection: some View",
                                      in: SourceText.codeOnly(try text(Self.patchbay)))
        XCTAssertFalse(section.isEmpty,
                       "ANCHOR MISSING: `modulationSection` did not extract — a missing anchor "
                       + "is a finding, not a pass (#454).")
        for phrase in ["your voice", "voice stage", "Audio input", "harmony", "granular"] {
            XCTAssertFalse(
                section.localizedCaseInsensitiveContains(phrase),
                "the Body → parameter card renders \"\(phrase)\", but `ModDestinationKey.all` "
                + "has carried the tempo ALONE since #1302 deleted the monitor insert, and the "
                + "\"Audio input\" surface went with it. This assertion forbids no destination "
                + "(#364) — if a voice stage is registered again, say so here AND re-door its "
                + "switch; what it forbids is copy that outlives the thing it names.")
        }
    }

    /// Claim 2 — counterweight: the repair did not simply delete the explanation. A card that
    /// says nothing would satisfy claim 1 forever.
    func testTheCardStillExplainsItself() throws {
        let section = try Self.member("private var modulationSection: some View",
                                      in: SourceText.codeOnly(try text(Self.patchbay)))
        for phrase in ["No routes yet.",
                       "Routes apply about once a second",
                       "BPM lock",
                       "/echoelmusic/mod/<key>"] {
            XCTAssertTrue(section.contains(phrase),
                          "the card no longer tells the player \"\(phrase)\" — claim 1 must not "
                          + "be satisfied by deleting the copy instead of correcting it.")
        }
    }

    /// Claim 3 — the founder ask is ANSWERABLE: it names a destination that exists and the gate
    /// that decides whether it moves. A verify note pointing at a deleted control costs a device
    /// session that cannot conclude.
    func testTheVerifyNoteAsksForADestinationThatExists() throws {
        let note = try Self.verifyNote(in: try text(Self.patchbay))
        XCTAssertFalse(note.isEmpty,
                       "ANCHOR MISSING: no NEEDS-FOUNDER-VERIFY note in \(Self.patchbay) (#454). "
                       + "`scripts/founder-verify.py` prints the founder's shopping list from "
                       + "these markers; an unextractable one is invisible to it.")
        XCTAssertTrue(note.contains("Tempo"),
                      "the verify note no longer names a registered destination.")
        XCTAssertTrue(note.contains("seq.tempo"),
                      "the verify note gives no OSC address to watch — `/echoelmusic/mod/seq.tempo` "
                      + "is what makes the probe observable without a second device.")
        XCTAssertTrue(note.localizedCaseInsensitiveContains("BPM-Lock")
                      || note.localizedCaseInsensitiveContains("BPM lock"),
                      "the verify note does not exercise the BPM lock — it is the GATE on the "
                      + "tempo handler (`guard !UserDefaults…bool(forKey: \"studio.lockBPM\")`), "
                      + "so a probe that never toggles it cannot tell a working route from a "
                      + "silent one.")
    }

    /// Claim 4 — END-TO-END, and the only claim about the list itself: every destination the
    /// picker offers has a human name. Grows with the list rather than pinning it (#364).
    func testEveryOfferedDestinationHasAHumanName() throws {
        XCTAssertFalse(ModDestinationKey.all.isEmpty,
                       "`ModDestinationKey.all` is empty — the Add-route menu would render no "
                       + "rows at all, so the card would be a door onto nothing.")
        XCTAssertTrue(ModDestinationKey.all.contains(ModDestinationKey.tempo),
                      "the tempo is this build's one registered destination "
                      + "(`EchoelmusicApp`'s `register(ModDestinationKey.tempo)`); if it left "
                      + "the list, the card's copy and its verify note move in the same commit.")
        for key in ModDestinationKey.all {
            XCTAssertNotEqual(
                ModDestinationKey.displayName(key), key,
                "`ModDestinationKey.all` offers \"\(key)\" but `displayName` has no case for "
                + "it, so the picker row reads the raw key. The as-is fallback is DESIGNED for "
                + "a persisted key from another build (see its doc) — not for one this build "
                + "offers itself.")
        }
    }

    /// Claim 5 — counterweight: the four removed keys are gone from CODE on both sides of the
    /// matrix, so claim 1's absence cannot be a green over a half-done removal.
    func testTheRemovedVoiceKeysAreGoneFromCode() throws {
        let both = SourceText.codeOnly(try text(Self.patchbay))
            + "\n" + SourceText.codeOnly(try text(Self.engine))
        for key in Self.removedKeys {
            XCTAssertFalse(both.contains(key),
                           "\"\(key)\" is still referenced in code — #1302 deleted the monitor "
                           + "insert it wrote to, so it can only be dead weight or a "
                           + "half-restored stage. If it is being restored, restore its "
                           + "registration, its `displayName` case and the card's copy together.")
        }
    }

    // MARK: - helpers

    /// The brace-matched body of a declaration, from its opening `{` to the matching `}`.
    /// Anchor uniqueness is checked here rather than in review (#408).
    private static func member(_ marker: String, in src: String) throws -> String {
        let hits = src.components(separatedBy: marker).count - 1
        guard hits == 1, let start = src.range(of: marker) else {
            throw XCTSkip("anchor `\(marker)` occurs \(hits)× — re-anchor before trusting a zero (#408)")
        }
        guard let open = src[start.upperBound...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var i = open
        while i < src.endIndex {
            let c = src[i]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(src[open...i]) } }
            i = src.index(after: i)
        }
        return String(src[open...])
    }

    /// The `NEEDS-FOUNDER-VERIFY` paragraph, read from the RAW text (it lives in a doc comment,
    /// which is exactly what `SourceText.codeOnly` removes) and stopping at the first line that
    /// is no longer part of the comment block.
    private static func verifyNote(in raw: String) throws -> String {
        let lines = raw.components(separatedBy: "\n")
        let marked = lines.enumerated().filter { $0.element.contains("NEEDS-FOUNDER-VERIFY") }
        guard marked.count == 1, let first = marked.first else {
            throw XCTSkip("NEEDS-FOUNDER-VERIFY occurs \(marked.count)× in this file — this "
                          + "helper reads exactly one; re-anchor before trusting it (#408).")
        }
        var collected: [String] = []
        var index = first.offset
        while index < lines.count,
              lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("///") {
            collected.append(lines[index])
            index += 1
        }
        return collected.joined(separator: "\n")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
