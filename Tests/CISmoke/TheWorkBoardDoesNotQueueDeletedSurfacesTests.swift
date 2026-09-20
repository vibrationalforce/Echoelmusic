// TheWorkBoardDoesNotQueueDeletedSurfacesTests.swift
// Echoel — #819: the board a session is told to pull work from had nine rows pointing at
// surfaces that no longer exist.
//
// WHY THIS EXISTS. `.claude/skills/baustellen/SKILL.md` says: read the board, pull the top open
// slice. `scratchpads/BAUSTELLEN_BOARD.md` calls itself "die eine Übersicht". It was last kept on
// 2026-07-21; since then #121 Slice 4 (clips + arrangement), #166/#167 (drums), #475 (the note
// editor) and the 2026-07-24 AUv3 removal deleted the surfaces NINE of its waiting rows still
// name — including A1, the FIRST row a session would pull. Measured 2026-08-25:
// `git grep -l launchGlyphOverlay -- Sources` → 0, `git grep -n "RollChordStamp(" -- Sources` → 0
// construction sites, no AUv3 target in `project.yml`, no clip-editor door.
// ⛔ THE `RollChordStamp(` HALF OF THAT MEASUREMENT WAS NEVER A MEASUREMENT (#1395). It is a
// caseless enum — a namespace, never constructed — so that needle returns 0 for every possible
// state of this repo, including one where the stamp runs in five surfaces. The type is alive
// and so is its consumer; what died is the editor around them. The needle it justified is gone
// (see `deletedSurfaces`), and the reading stays as the record of what was believed that day.
// ⛔ THE AUv3 HALF OF THAT MEASUREMENT EXPIRED on 2026-09-20 (#1385): `project.yml` carries
// the `EchoelmusicAUv3` target again. The 2026-08-25 reading stays as the record of WHEN it
// was true — the needle it justified is gone (see `deletedSurfaces`), the sentence is not
// rewritten, because a dated measurement is a date and not a standing claim.
//
// ────────────────────────────────────────────────────────────────────────────────────────
// GRADING OF THE #1395 CHANGE (§3), driven in Python against the live board — and it is
// **PREVENTIVE, NOT A REGRESSION**, which is the honest label and the less flattering one.
// Both the old and the new needle list are GREEN on today's board (26 waiting rows, no hit),
// because A1 still carries its VOID marker. Nothing was red; what was wrong was a CLAIM.
// Three drives, each a pair (#739 — an exemption that only feeds itself its own positive is
// not a check):
//   · today's board:            OLD green · NEW green            → no regression either way
//   · A1 with its VOID stripped: OLD catches it · NEW catches it → coverage SWAPPED, not lost
//   · a legitimate cleanup row ("retire the callerless RollChordStamp consumers"):
//                                OLD FORBIDS it · NEW allows it  → the #364 defect, removed
// NOT covered: whether the board's other four needles still name dead things. Three were
// re-measured (0 hits in `Sources/` by path and text); `.patch(lane)` is a UI door token that
// no Swift file carries by construction, so it is asserted by the board's own VOID row, not here.
// ────────────────────────────────────────────────────────────────────────────────────────
//
// ⭐ SAME DEFECT CLASS AS #816, ONE LEVEL UP. That slice fixed a checklist that spent the
// founder's DEVICE time on impossible probes. This one is a queue that spends a SESSION's cycle
// on impossible work — and it is worse in one respect: the board presents itself as the single
// overview, so a session that trusts it never looks for the live queue at all.
//
// ⚠️ SCOPE IS THE THREE WAITING TABLES, and it has to be. The board's law is that nothing is
// deleted — its ERLEDIGT and audit tables name the removed surfaces on purpose, forever. A
// file-wide negative scan would match the board's own history (#491). A row counts as LIVE only
// while it carries no VOID marker, which is exactly the annotation this slice added.
//
// ⛔ TWO ANCHOR FAULTS IN THE FIRST DRAFT, both caught by DRIVING and neither by re-reading:
// 1. The range was taken with `split("## AKTIV")`, and the board's new status paragraph NAMES
//    "## AKTIV" in prose — so the range opened inside the documentation of the guard and
//    collapsed to three rows. Headings are matched at LINE START here for that reason.
// 2. Fixing that dropped the needle count from six to three, because resetting at every `## `
//    heading also closed the range at `## OFFEN`. **A needle set that suddenly stops matching is
//    a signal that the SCOPE moved, not that the file got clean** — the tempting read is the
//    reassuring one. All six needles are driven against the pre-#819 board: 8 findings over 8
//    rows, and zero over the annotated one.
//
// #364 — NOTHING HERE FORBIDS A RETURN. If clips, the roll or an AUv3 target come back, the
// matching row stops being void and the VOID marker has to go; this guard then goes red and says
// so, which is the correct moment to re-open that row.
//
// KIND (§1): **REGRESSION, source-text scans.** Claim 1 would have fired on each deletion
// commit — the rows already named these surfaces.

import XCTest

final class TheWorkBoardDoesNotQueueDeletedSurfacesTests: XCTestCase {

    /// Spelled the way the BOARD spells them, not the way the code does — every one is driven
    /// against the pre-#819 board and matches there.
    ///
    /// ⭐ `"AUv3"` LEFT THIS LIST ON 2026-09-20 (#1386), and the removal is this guard's own
    /// written instruction being followed, not a weakening of it. The header says: *"If clips,
    /// the roll or an AUv3 target come back … this guard then goes red and says so, which is
    /// the correct moment to re-open that row."* #1385 brought the target back AND added a
    /// waiting row (A10) that names it — so claim 1 was RED on a correct tree from that commit
    /// onward. A surface that exists cannot be queued "impossibly"; keeping the needle would
    /// forbid the board from tracking live work (#364).
    ///
    /// ⚠️ THE PART WORTH KEEPING IS HOW LONG IT STAYED INVISIBLE. `Run Tests` reports failure
    /// on EVERY push (#396) and the job log is `tail -200` (#807), so a red claim here is not
    /// something a gate reading can surface. #1360 was the same shape (a genre gained a lead
    /// voice, the guard denying it went red, nobody saw it) — and #1385's own commit message
    /// says it retired "the negative pin" of THIS file, which was true of a different claim
    /// and left this needle standing. **Retiring one negative pin in a file is not retiring
    /// the file's negative pins**: the deletion that frees a name has to sweep every needle
    /// that spells it, and the only way to know is to DRIVE the guard, not to read the diff.
    /// Found by transcription while folding a device measurement into A10/A11.
    ///
    /// ⛔ **`"RollChordStamp"` STOOD HERE AND IS REPLACED BY `"Piano Roll"` (#1395) — the needle
    /// named a LIVING core, and the evidence that put it here could not have said otherwise.**
    /// The header above cites `git grep -n "RollChordStamp(" -- Sources` → 0. That is true and
    /// will be true forever: `RollChordStamp` is a **caseless enum** used as a namespace
    /// (`public enum RollChordStamp {`, `Sequencer/RollChordStamp.swift`), so it is never
    /// CONSTRUCTED — the parenthesis form cannot match in any possible state of this repo. The
    /// #1376 defect exactly, one file over: *a parser that matches nothing is a finding, never
    /// a pass*. Measured instead by the CALL form: `RollChordStamp.stamp(` has **two** sites,
    /// both in `PianoRollModel.stampChord`/`stampArp` — themselves callerless since #475 and
    /// named as such in that file's own head, which is the honest statement of this situation.
    ///
    /// ⚠️ **WHY THAT IS NOT PEDANTRY: the board says the opposite of the needle, in the very row
    /// the needle was written for.** A1's VOID marker reads *"Die KERNE leben (`RollChordStamp`,
    /// `BreathArp`, `setChance`, `setOccurrence` in `PianoRollModel`) — der HÖRTEST ist
    /// unausführbar."* So the impossible thing is the **hearing test behind the deleted editor**,
    /// not the stamp core. With `"RollChordStamp"` on this list, a perfectly legitimate future
    /// row — *"retire the callerless stamp consumers"*, the cleanup `PianoRollView.swift`'s head
    /// explicitly calls "its own pass" — would have been forbidden. That is #364: a guard
    /// turning correct work red.
    ///
    /// ⭐ **COVERAGE IS SWAPPED, NOT DROPPED, and it was driven rather than argued.** With A1's
    /// VOID marker stripped (the only way that row becomes a waiting row again), BOTH the old
    /// and the new needle catch it — `"Piano Roll"` sits in the row's TITLE,
    /// *"**Piano Roll adaptiv + Pro-Funktionen**"*, which survives an un-VOID because the VOID
    /// text is what gets removed. And `"Piano Roll"` carries a SPACE, so it matches neither
    /// `PianoRollModel` nor `PianoRollView` nor `RollChordStamp`: the cleanup rows stay legal
    /// while the re-queueing of the deleted editor does not.
    private static let deletedSurfaces = [
        "launchGlyphOverlay", "Audio-Clip-Editor",
        "Piano Roll", "Velocity-Lane", ".patch(lane)"
    ]

    /// The three tables that mean "someone still has to act on this".
    private static let waitingTables = ["## AKTIV", "## OFFEN", "## BLOCKIERT"]

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

    private func text(_ relative: String) throws -> String {
        let url = root().appendingPathComponent(relative)
        guard let s = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read. This guard fails rather "
                    + "than skips (§4) — a missing anchor is a finding, not a pass.")
            return ""
        }
        return s
    }

    /// Table rows inside the waiting tables that carry no VOID marker.
    private func liveRows(in board: String) -> [String] {
        var rows: [String] = []
        var inside = false
        for line in board.components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                inside = Self.waitingTables.contains { line.hasPrefix($0) }
                continue
            }
            guard inside else { continue }
            let row = line.trimmingCharacters(in: .whitespaces)
            guard row.hasPrefix("|") else { continue }
            guard !row.hasPrefix("|---"), !row.hasPrefix("| # |") else { continue }
            guard !row.contains("VOID") else { continue }
            rows.append(row)
        }
        return rows
    }

    // 1 — no row still waiting for action names a surface that is gone.
    func testNoWaitingRowNamesADeletedSurface() throws {
        let board = try text("scratchpads/BAUSTELLEN_BOARD.md")
        let rows = liveRows(in: board)
        XCTAssertGreaterThan(rows.count, 5, """
            The waiting tables parsed to \(rows.count) live rows. Either the board lost its \
            content or its headings changed — in both cases this guard is measuring nothing. \
            The range is matched at LINE START on \(Self.waitingTables); prose naming those \
            headings must not open a range (that was the first draft's fault).
            """)
        for row in rows {
            for surface in Self.deletedSurfaces {
                XCTAssertFalse(row.contains(surface), """
                    A waiting row still queues work on "\(surface)", which no longer exists: \
                    \(row.prefix(90))… Mark the row VOID with its measurement (the board deletes \
                    nothing), or — if the surface came back — remove the marker and update this \
                    guard in the same commit.
                    """)
            }
        }
    }

    // 2 — the surfaces really are gone, so claim 1 fails for its named reason (#367).
    //
    // ⛔ THE FIRST DRAFT CHECKED TWO NAMED FILES and would have passed while its own premise was
    // false — a symbol reintroduced anywhere else in `Sources/` was invisible to it. A claim that
    // can pass on a broken premise is not a claim. It walks the tree now.
    func testTheQueuedSurfacesAreStillAbsentFromTheApp() throws {
        let recovery = "If this is red because the surface RETURNED, that is correct (#364): "
            + "un-void the matching board row in the same commit."
        let sources = root().appendingPathComponent("Sources")
        guard let walk = FileManager.default.enumerator(atPath: sources.path) else {
            XCTFail("ANCHOR MISSING: Sources/ could not be walked. This guard fails rather than "
                    + "skips (§4).")
            return
        }
        var swiftFiles = 0
        var offenders: [String] = []
        for case let relative as String in walk where relative.hasSuffix(".swift") {
            let url = sources.appendingPathComponent(relative)
            guard let body = try? String(contentsOf: url, encoding: .utf8) else { continue }
            swiftFiles += 1
            for symbol in ["launchGlyphOverlay", "RollChordStamp("] where body.contains(symbol) {
                offenders.append("\(relative): \(symbol)")
            }
        }
        XCTAssertGreaterThan(swiftFiles, 300, """
            Walked only \(swiftFiles) Swift files under Sources/ — the walk is broken, so the \
            absence it reports means nothing.
            """)
        XCTAssertTrue(offenders.isEmpty, """
            A queued surface is constructed again: \(offenders.joined(separator: ", ")). \(recovery)
            """)

        // ⭐ THE AUv3 ABSENCE PIN IS GONE FROM HERE, 2026-09-20 (#1385), per this guard's own
        // `recovery` text (#364: a guard that reddens on CORRECT work is the defect). The
        // target returned; it is pinned positively, exactly once, in
        // `ContentPipelineClaimsTests`. This file's subject is the BOARD, and the board's
        // three AUv3 rows (A8, A9, B1) were un-VOIDed in the same commit — a ⛔ VOID whose
        // premise has expired queues nothing, but it does teach the next reader something
        // false, which is the more expensive failure.
    }

    // 3 — the board says where the live queue actually is.
    func testTheBoardPointsAtTheLiveQueue() throws {
        let board = try text("scratchpads/BAUSTELLEN_BOARD.md")
        for pointer in ["scripts/founder-verify.py",
                        "scratchpads/FOUNDER_DEVICE_SESSION.md",
                        ".deploy/release"] {
            XCTAssertTrue(board.contains(pointer), """
                The board must name \(pointer). It calls itself "die eine Übersicht" while being \
                a month behind; without these pointers a session trusting it never looks for the \
                queue that is actually current.
                """)
        }
    }
}
