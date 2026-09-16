// TheClaimsFileHasNoExpiredPermissionTests.swift
// Echoel — #1347: `ContentPipeline/CLAIMS.md` stated a law and then broke it four times.
//
// WHY THIS EXISTS. That file is the ONE list of what may be claimed today; `CLAUDE.md` names it
// as required reading before any script, caption, hashtag set, page copy or store line, because
// a false claim there is an App Store 2.3 rejection. Four of its struck rows carried a
// CONDITIONAL PERMISSION added on 2026-09-11 (#1247): *"die Zeile bleibt gestrichen, bis ein
// `VERIFIED-`Datum an `setInputMonitoring` steht."* One day later #1302 deleted the audio input,
// and with it `setInputMonitoring`, `showInput`, `AudioInputPickerView`, `VoicePitchCorrector`
// and `isInputMonitoring` — every one of them **0** in comment-stripped `Sources/`.
//
// ⭐ THE DEFECT IS A DIRECTION, NOT A DATE, AND THE FILE ITSELF NAMES IT TWO ROWS ABOVE: *"eine
// Ausnahme in dieser Datei zeigt auf einen Codepfad und muss mitsterben, wenn der Pfad stirbt.
// Ein überlebender '… darf weiter behauptet werden'-Satz ist die 2.3-Klasse und liest sich wie
// eine Erlaubnis, nicht wie eine Ruine."* A conditional permission is that sentence in the
// future tense, and it is worse: a stale claim reads as wrong, a stale PERMISSION reads as a
// plan. A copywriter meeting it concludes "this comes back after a device session" — for a
// condition that can never be met, because the symbol it names no longer exists.
//
// ⚠️ THE SCOPE IS A TABLE ROW, AND THE RULE IS THE FILE'S OWN MARKER GRAMMAR: of the two
// markers that can precede the dead symbol on that row, the NEAREST one must be ⛔ (withdrawn),
// never ⭐ (a live, important fact). That is not decoration — it is how every other row in this
// file is read, and it is the only thing that separates a quoted ruin from a standing promise.
//
// ⛔ **MY FIRST DRAFT OF CLAIM 1 WAS GREEN ON THE TREE THAT CARRIED THE DEFECT, which is the
// #367 mirror case and would have shipped a guard that can never fire for its named reason.**
// It asked only "does a ⛔ appear BEFORE the symbol on this row" — and it does, in the parent
// too: every one of those rows OPENS with `⛔ **GESTRICHEN 2026-09-12 …**` and the stale
// permission was appended 500–1500 characters LATER. Measured: 4 rows named the symbol, **0**
// offenders on the parent. Only the NEAREST-marker form separates them (parent: ⛔@527 vs
// ⭐@1030 → offender; worktree: ⛔@1089, no ⭐ after it → clean).
//
// ⭐ THE LESSON GENERALISES BEYOND THIS FILE: in a document whose rows are 2,000 characters
// long and carry a dozen markers, "the marker appears before the phrase" is satisfied by
// ACCIDENT. A position test needs a NEAREST, not an ANY. And it is invisible while reading —
// only §0's drive against BOTH trees says so.
//
// ⚠️ #491 is still why the scope is a row and not the file: the repair QUOTES the withdrawn
// permission verbatim, so a bare `XCTAssertFalse(text.contains(…))` would match its own
// retraction and go red on a correct tree — #1344's first draft did exactly that, in this
// session.
//
// ⚠️ ONE NEEDLE, NOT FIVE, AND THE CHOICE IS DELIBERATE. `setInputMonitoring` is the symbol the
// permission's CONDITION named, and it occurs nowhere else in the repo's prose. `showInput` or
// `Audio input` would also match live, legitimate text (`TrackInstrument.audioInput` still
// renders the label "Audio input" for a persisted lane, exactly the `.drums` case) — a needle
// that matches something PLAUSIBLE is worse than one that matches nothing, because it returns a
// believable number instead of announcing itself.
//
// #364 — NOTHING HERE FORBIDS THE INPUT COMING BACK. Claim 3 goes red the day a caller
// reappears in `Sources/`, and its message names the prose that travels with it. The claims
// file may then un-strike those rows on a founder ask; this guard asks only that the two move
// together (#456).
//
// KIND (§1): **SOURCE-TEXT SCAN** over a markdown file plus a code-presence measurement. It
// proves what the claims file SAYS and what `Sources/` CONTAINS, never that any of it sounds
// right on a device.
//
// §0 HONEST GRADING (no local Swift toolchain; transcribed and driven against BOTH trees,
// parent = `dd2b89a`). Claim 1: **RED on the parent, 4 offenders — a real REGRESSION**, and
// the four are ONE finding reported four times (#486), not four findings. The first draft of
// that same claim scored 0 offenders there; see the ⛔ block above. Claim 2 (the rows are
// still struck) and claim 3 (the five symbols are absent from code): GREEN on both trees —
// COUNTERWEIGHTS, and they are the content (#343): without claim 2 this file stays green on a
// tree that resolved the contradiction by UN-striking the claims, which is the expensive
// direction.

import Foundation
import XCTest

final class TheClaimsFileHasNoExpiredPermissionTests: XCTestCase {

    /// The condition's own symbol. See the ⚠️ block above for why it is the only needle.
    private static let deadCondition = "setInputMonitoring"

    /// Deleted with the audio input (#1302). Measured 0 each in comment-stripped `Sources/`
    /// on 2026-09-16, before this guard was written.
    private static let deletedSymbols = [
        "setInputMonitoring", "showInput", "AudioInputPickerView",
        "VoicePitchCorrector", "isInputMonitoring"
    ]

    private func root() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func claims() throws -> String {
        let url = root().appendingPathComponent("ContentPipeline/CLAIMS.md")
        guard let s = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: ContentPipeline/CLAIMS.md could not be read. A missing "
                    + "anchor is a finding, not a pass (§4).")
            return ""
        }
        return s
    }

    // 1 — every mention of the dead condition is a RETRACTION, never a standing permission.
    func testNoRowPromisesAClaimBackOnADeadCondition() throws {
        let rows = try claims().components(separatedBy: "\n")
        let naming = rows.filter { $0.contains(Self.deadCondition) }
        XCTAssertFalse(naming.isEmpty,
            "ANCHOR MISSING: no row names `\(Self.deadCondition)` at all. Either the retraction "
            + "was deleted rather than marked — which loses the record of what was withdrawn and "
            + "why — or this needle no longer selects anything and the claim is vacuously green "
            + "(#926). Re-anchor it deliberately; do not delete it.")

        var offenders: [String] = []
        for row in naming {
            guard let symbol = row.range(of: Self.deadCondition) else { continue }
            let head = row[row.startIndex..<symbol.lowerBound]
            // NEAREST, not ANY (see the ⛔ block in the header): these rows open with a ⛔ and
            // the stale permission was appended far later, so `any ⛔ before` is satisfied by
            // accident and the guard could never fire.
            let lastStop = head.range(of: "⛔", options: .backwards)
            let lastStar = head.range(of: "⭐", options: .backwards)
            switch (lastStop, lastStar) {
            case (nil, _):
                offenders.append(String(row.prefix(120)))
            case (let stop?, let star?) where star.lowerBound > stop.lowerBound:
                offenders.append(String(row.prefix(120)))
            default:
                break
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "A row of the claims file names `\(Self.deadCondition)` with a ⭐ nearer to it than "
            + "any ⛔ — i.e. as a live condition rather than a withdrawn one: \(offenders). "
            + "That symbol "
            + "was deleted by #1302, so the condition can never be met — and a permission whose "
            + "condition cannot be met reads to a copywriter as a plan, not as a ruin. This is "
            + "the file's own law, stated in the Harmonizer row: an exception points at a code "
            + "path and must die with it. If an audio input came back, the honest move is to "
            + "un-strike the rows deliberately on a founder ask and retire this guard in the "
            + "same commit (#364) — not to leave the sentence standing.")
    }

    // 2 — counterweight (#343): the four claims are still STRUCK. Without this, claim 1 stays
    // green on a tree that resolved the contradiction by granting the claims instead.
    func testTheVoiceClaimsAreStillWithdrawn() throws {
        let text = try claims()
        for phrase in ["Deine Stimme wird die Klangfarbe des Instruments",
                       "Harmoniestimmen auf deiner Stimme",
                       "Granular-Textur auf deiner Stimme",
                       "Feedback-Schutz"] {
            guard let at = text.range(of: phrase) else {
                XCTFail("ANCHOR MISSING: the claims file no longer contains the row \"\(phrase)\". "
                        + "A withdrawn claim is kept and marked, never deleted — the ⛔ IS the "
                        + "record of what may not be said and why.")
                continue
            }
            let row = text[text.lineRange(for: at)]
            XCTAssertTrue(row.contains("GESTRICHEN"),
                "The row \"\(phrase)\" is no longer marked GESTRICHEN. The microphone is gone "
                + "(#1302) and every one of these stages sat in the monitor path, so nothing a "
                + "user can reach produces them. Un-striking one needs a founder ask and a door, "
                + "and then this counterweight is what must be pulled with it.")
        }
    }

    // 3 — counterweight: the premise. The five symbols really are absent from `Sources/` CODE.
    func testTheRetractionsPremiseStillHolds() {
        let base = root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            XCTFail("ANCHOR MISSING: Sources/ could not be walked.")
            return
        }
        var alive: [String] = []
        var scanned = 0
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            let path = base.appendingPathComponent(rel).path
            guard let body = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            scanned += 1
            let code = SourceText.codeOnly(body)
            for symbol in Self.deletedSymbols where code.contains(symbol) {
                alive.append("\(symbol) in \(rel)")
            }
        }
        XCTAssertGreaterThan(scanned, 100,
            "ANCHOR MISSING: only \(scanned) Swift files walked — the enumeration found almost "
            + "nothing and this claim would be vacuously green (#926).")
        XCTAssertTrue(alive.isEmpty,
            "An audio-input symbol is back in shipping code: \(alive.sorted()). That is not a "
            + "defect — it means the input is being rebuilt. But the claims file currently says "
            + "those stages are unreachable, and the founder device ask in "
            + "`Audio/AudioConfiguration.swift` carries `BLOCKED-BY-#1302` (#1346). Both travel "
            + "with the return, in the same commit (#456): un-strike the rows the founder "
            + "approves, drop the BLOCKED mark, and pull §1 of "
            + "`scratchpads/FOUNDER_DEVICE_SESSION.md`.")
    }
}
