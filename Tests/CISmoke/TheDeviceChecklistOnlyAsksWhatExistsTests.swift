// TheDeviceChecklistOnlyAsksWhatExistsTests.swift
// Echoel — #816: the founder's ONE device checklist asked for four things that cannot be
// done at all, and nothing in the repo could say so.
// ⚠️ 2026-11-05: the checklist moved to the private working repository (`echoelmusic-intern`).
// Claims 1, 3, 7 and the checklist half of claim 2 moved with it (`echoelmusic-intern/guards/`);
// what reads only `Sources/`, `Tests/` and `scripts/` stays here.
//
// WHY THIS EXISTS. `scratchpads/FOUNDER_DEVICE_SESSION.md` was written 2026-07-16 to bundle
// every device-bound question into a single session, because the founder is the only device
// tester and device time is this project's scarcest resource. Measured 2026-08-25, four of its
// seven sections asked for probes on surfaces that no longer exist: the piano-roll editor
// (`struct PianoRollView` deleted, #475), a drum lane (`DrumSynthVoice`/`LaneDrumKitVoice`/
// `DrumNoteMap` deleted, #166/#167), an AUv3 host test (target removed 2026-07-24 — ⭐ BACK
// since #1385; that half is HISTORY now, not a current absence, and the ⛔ tombstone on
// `struckSurfaces` says what it cost to notice late), a
// `laneAUInstruments` flag (zero occurrences in `Sources`+`Tests`), and a warp hearing test in
// an audio-clip editor whose door went with #121 Slice 4.
//
// ⭐ THE DEFECT CLASS IS #525 AT DOCUMENT SCALE. That entry names the cost exactly: "ein
// Verify-Posten, der auf ein entferntes Bedienelement zeigt, kostet den Founder eine
// Geräteprobe, die nichts entscheiden kann". Here it was not one item but four sections, and
// the reason it survived is structural rather than careless: `scripts/founder-verify.py`
// deliberately does NOT scan `scratchpads/` (its own head: scratchpads are session prose, not
// asks). So this file was a SECOND checklist that the tool printing the founder's shopping
// list could not see, and no guard watched. Claim 4 pins that exclusion, because it is the
// whole reason the document now has to carry a pointer to the tool.
//
// ⚠️ THE SCAN IS SCOPED TO CHECKBOX ITEMS, and that is not fussiness — it is #491. The
// document's ⛔ table QUOTES every struck name in order to withdraw it, so a naive
// file-wide negative scan would match its own retraction and go red on a correct tree. An ask
// is a checkbox; the retraction is prose. An item is the `- [ ]` line plus its indented
// continuation lines, because the ask is written across both (the old `laneAUInstruments`
// entry ran to a second line).
//
// ⚠️ HONEST LIMIT, and it runs toward FALSE GREENS. The needle list is FIXED and names five
// surfaces known to be gone. A stale ask about some sixth deleted surface passes unseen. This
// guard makes the KNOWN rot impossible to re-introduce; it does not make the document
// self-checking. The only real fix for that would be markers the tool can scan, which is the
// direction the rewritten document points.
//
// ⛔ THE OPPOSITE ERROR IS THE ONE I ACTUALLY MADE, and this guard can encourage it. The
// first draft of the rewritten checklist deleted the four impossible sections AND seven asks
// that are perfectly performable (multiRoll double lane, bass at A≠440, poly unchanged, stuck
// note on a mid-take instrument change, live same-region change, silent launch), on the
// reasoning that they "belong in the NEEDS-FOUNDER-VERIFY markers". Measured: the tool covers
// none of them, and nothing had been written there. **A removal justified by "it belongs
// elsewhere" is only a removal once the move has happened.** Claim 1 going red means the ask
// names a surface that is GONE — it never means an ask should be dropped because it is
// inconvenient. If the surface exists, the ask stays.
//
// #364 — NOTHING HERE FORBIDS A RETURN. If the roll, the drums, an AUv3 target or a clip
// editor is rebuilt, claim 2 goes red on purpose and its message names the ⛔ table as the
// prose to update in the same commit; the checklist may then ask for that probe again.
//
// ⛔ **THE HONEST LIMIT ABOVE CAME TRUE THREE WEEKS LATER, AND WORSE THAN IT PREDICTED
// (#1346, 2026-09-16).** It said a stale ask about "some sixth deleted surface" would pass
// unseen. Four founder deletions later (#1069 fullscreen visual, #1301 face, #1302 audio
// input, #1305 harmonizer/granular) the document again asked for things nobody can do — and
// the biggest one was invisible to claim 1 for a REASON THE LIMIT DID NOT NAME: **§1 was
// never a checkbox.** It was a whole section, headed "Der eine Handgriff — er blockiert die
// ganze Vokal-Kette", pointing at `Mix-Panel → "Choose input…" → Live monitoring`. Widening
// the needle list would not have caught it; the SCOPE was the blind spot, not the list.
//
// ⭐ SO THE FIX IS A SECOND SCOPE, NOT A LONGER LIST (claim 7): section HEADINGS. A heading
// is one line, it is what the founder plans the session from, and — unlike the ⛔ tables —
// no retraction is ever written as one, so it can carry a negative scan without tripping
// #491 on its own withdrawal. Claim 7 is red on the parent for exactly the one heading that
// caused this.
//
// ⚠️ THE LIMIT THAT REMAINS IS NARROWER AND STILL REAL: rot in ordinary PROSE — a pointer
// paragraph, a "why this is a blocker" argument — is caught by neither scope. §1's dead
// pointers (`Audio/MonitorInsertAU.swift:174`, a line number 43 lines stale) were of that
// kind. The document's answer to that is not a guard but an address: the checklist names
// `scripts/founder-verify.py` as the way to reach a code ask, never a line number.
//
// KIND (§1): **REGRESSION, source-text scans.** Claim 1 would have fired on each deletion
// commit — the document already named these surfaces, so the moment the code went, the guard
// goes red. It is graded as a real regression guard for this defect, not a preventive one.
//
// ────────────────────────────────────────────────────────────────────────────────────────
// GRADING OF THE #1394 CHANGE (§3), transcribed in Python against BOTH trees — there is no
// Swift toolchain in a web session (§0). Parent = `a0152da25`.
//
// · Claim 1 was **RED ON THE PARENT**, and not by anchor absence — it parsed 24 checkbox asks
//   (its own `> 3` floor holds) and one of them, the `ownAUv3` diag-log ask, matched the
//   `"AUv3"` needle. **One finding, one assertion** (#486 does not apply; it really is one).
//   It is GREEN on this tree. That is the whole slice: a guard red on a correct tree, in the
//   blocking bundle, invisible because `Run Tests` is red on every push (#396).
// · Claim 10 is **RED ON THE PARENT** too, for the same needle and measured separately:
//   `"AUv3"` scores **2 paths** (`Sources/EchoelmusicAUv3/…`) and **39 files** there. On this
//   tree every remaining needle scores 0/0. It is a REGRESSION guard, not a forward one — it
//   would have fired the moment #1385 landed.
// · Claims 2–9 are **COUNTERWEIGHTS, green on both trees** (#343), and they are the point: the
//   repair must not have loosened the four needles that are still correct, nor the positive
//   AUv3 pin claim 2 added, nor the BLOCKED-mark machinery of claims 8/9.
// · **NOT covered:** that the founder can actually perform the AUv3 probe. That is a device
//   question and stays open in `FOUNDER_DEVICE_SESSION.md` §2b (answered for AUM, #1386; open
//   for GarageBand).
// ────────────────────────────────────────────────────────────────────────────────────────

import XCTest

final class TheDeviceChecklistOnlyAsksWhatExistsTests: XCTestCase {

    /// Surfaces measured absent on 2026-08-25, spelled the way the old checklist spelled them.
    /// ⚠️ The sentence that stood here — "all FIVE match there (six findings across four asks)"
    /// — is kept as HISTORY and is no longer a description of this array: it measured the
    /// five-needle list of #816 against the pre-#816 document, and one of those five has since
    /// come back (below). Re-deriving it against today's list would be inventing a measurement
    /// nobody made; a historical figure stays attached to the thing it measured (#818).
    ///
    /// ⛔ **`"AUv3"` STOOD IN THIS LIST AND IS REMOVED (#1394, 2026-09-20) — the list had gone
    /// RED ON A CORRECT TREE, and this file's own two claims had started contradicting each
    /// other.** #1385 brought the target back the same day; claim 2 was updated to REQUIRE the
    /// probe (`doc.contains("EchoelBodyVibe")`) while this needle still FORBADE any checkbox ask
    /// from naming it. The checklist duly grew the probe, one of whose asks reads *"Die Zeile mit
    /// `ownAUv3` sagt, ob das Gerät die Komponente überhaupt kennt"* — and `"ownAUv3"` contains
    /// `"AUv3"`, so claim 1 failed for a surface that exists. That is #364 exactly: a guard
    /// forbidding the correct work its own neighbour demands.
    ///
    /// ⚠️ **WHY NOBODY SAW IT, and it is the reason this tombstone is long.** The failure is at
    /// RUN time, and `Run Tests` reports `failure` on every push (#396) — so a genuinely red
    /// assertion in the blocking bundle is indistinguishable from the standing red. The gate a
    /// session actually reads is `Build for Testing`, which only COMPILES. A needle list is
    /// therefore the one part of a guard that no gate can keep honest; it has to be pulled along
    /// by hand in the commit that changes the world, and #1385 pulled claim 2 and forgot this.
    ///
    /// ⚠️ **IT IS NOT REPLACED BY A POSITIVE PIN HERE (#416).** That the target exists is pinned
    /// ONCE, in `ContentPipelineClaimsTests`; if it is ever cut again, that guard goes red and
    /// claim 2's message below names what to do. A second copy here is the duplication this repo
    /// keeps paying for, and the stale one is always the copy nobody remembers owning.
    private static let struckSurfaces = [
        "laneAUInstruments",
        "Drums-Spur",
        "Audio-Clip-Editor",
        "Velocity-Lane"
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

    private func text(_ relative: String) throws -> String {
        let url = root().appendingPathComponent(relative)
        guard let s = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read. This guard fails rather "
                    + "than skips (§4) — a missing anchor is a finding, not a pass.")
            return ""
        }
        return s
    }

    // 1 — MOVED (2026-11-05). `testNoDeviceAskPointsAtARemovedSurface` read the checklist
    // itself, `scratchpads/FOUNDER_DEVICE_SESSION.md`, which now lives in the project's private
    // working repository; the claim moved with it (`echoelmusic-intern/guards/`, a spec).

    // 2 — the struck surfaces really are gone, so the checklist guard fails for its named reason (#367).
    func testTheStruckSurfacesAreStillAbsentFromTheApp() throws {
        let recovery = "If this is red because the surface RETURNED, that is correct and "
            + "expected (#364): update the ⛔ table of the device checklist "
            + "(private working repository) in the same commit, and the checklist may ask for "
            + "its probe again."

        let roll = try text("Sources/Echoelmusic/Studio/PianoRollView.swift")
        XCTAssertFalse(roll.contains("struct PianoRollView"),
                       "The note editor is back. \(recovery)")
        XCTAssertTrue(roll.contains("PianoRollModel"),
                      "PianoRollModel is the note engine and the MusicalFrame publisher — if it "
                      + "left this file, this guard is reading the wrong anchor.")

        let fm = FileManager.default
        for gone in ["Sources/Echoelmusic/Tools/DrumSynthVoice.swift",
                     "Sources/Echoelmusic/Sequencer/LaneDrumKitVoice.swift",
                     "Sources/Echoelmusic/Sequencer/DrumNoteMap.swift"] {
            XCTAssertFalse(fm.fileExists(atPath: root().appendingPathComponent(gone).path),
                           "\(gone) exists again. \(recovery)")
        }

        // The AUv3 half: the target came back in #1385 and is pinned POSITIVELY, once, in
        // `ContentPipelineClaimsTests`. The assertion that the checklist ASKS for the
        // EchoelBodyVibe probe read the checklist and moved with it (2026-11-05).
    }

    // 3 — MOVED with the checklist (2026-11-05): the document names `scripts/founder-verify.py`
    // and the marker convention. Spec in `echoelmusic-intern/guards/`.

    // 4 — the tool scans only the code and the map. The private checklist (claim 3, moved)
    // depends on that, and claim 6 below states its second consequence.
    func testTheToolDeliberatelyDoesNotScanScratchpads() throws {
        let tool = try text("scripts/founder-verify.py")
        XCTAssertTrue(tool.contains("ROOTS = [\"Sources\", \"Tests\", \"CLAUDE.md\"]"),
            "founder-verify.py's ROOTS line changed. If scratchpads/ was ADDED, the rewritten "
            + "checklist's framing ('the tool cannot see this file') is now false and must be "
            + "corrected in the same commit.")
    }

    // 5 — the tool does not count THIS FILE's own assertion as a job for the founder.
    //
    // WHY THIS CLAIM SITS HERE AND NOT IN A NEW FILE (#416): the defect is about the
    // relationship between this guard and the tool, and this guard is one of its two halves.
    // Claim 3 above asserts the checklist NAMES the marker convention — it does so by
    // asserting a bare `"NEEDS-FOUNDER-VERIFY"` literal, and until #887 `founder-verify.py`
    // read that literal as a 62nd device probe. The guard that polices the checklist was
    // sitting IN the checklist, addressed to a founder who cannot perform it. That is #753
    // one layer further out, and it is invisible from either side alone.
    //
    // ⚠️ THE ASSERTION IS ON THE RULE, NOT ON THE COUNT. A count ("61 open asks") goes stale
    // the first time anyone writes or retires an ask, and this repo has paid for that class
    // of pin repeatedly. The rule is the durable fact; `--selftest` covers its behaviour,
    // and no XCTest here can run Python, so this scan is what a push actually gates on.
    func testTheToolDoesNotCountThisGuardsOwnAssertion() throws {
        let tool = try text("scripts/founder-verify.py")
        XCTAssertTrue(tool.contains("BARE_LITERAL"), """
            founder-verify.py lost its bare-string-literal rule. Claims 6 and 8 in THIS file use a \
            naked "NEEDS-FOUNDER-VERIFY" literal, and without that rule the tool files such a \
            line as a device probe — a job nobody can perform, in the queue the founder works \
            from. If the rule was deliberately replaced, point this claim at whatever replaced \
            it in the same commit; do not delete it.
            """)
        XCTAssertTrue(tool.contains("before.endswith") && tool.contains("after.startswith"), """
            founder-verify.py still names BARE_LITERAL but no longer decides it by what sits \
            immediately either side of the marker. The narrowness IS the safety property: a \
            looser rule ("the marker anywhere inside a string") hides real asks written into \
            assertion messages, and hiding one costs a device session while over-counting costs \
            a glance. Re-derive with `python3 scripts/founder-verify.py --selftest`, whose case \
            5b drives exactly that rejected variant.
            """)
    }

    // 6 — an ask may not DEFER its instruction to a file the tool cannot read (#983 S3).
    //
    // WHY THIS CLAIM SITS HERE (#416): claim 4 above pins that `founder-verify.py` skips
    // `scratchpads/`. That exclusion has a second consequence nobody had written down — an ask
    // whose instruction lives in a scratchpad reaches the printed checklist as an entry with no
    // question in it. This file already owns the "an ask must be performable" law at document
    // scale (#816); this is the same law at LINE scale, and it belongs beside the exclusion that
    // causes it rather than in a file of its own.
    //
    // MEASURED, and the needle is load-bearing rather than decorative: on `2b0b508` exactly ONE
    // line matched — `GenreDeepTechTests`' header, which shipped the marker as
    // "the founder's ear (…, plan §2 S3)". Three sibling genre guards shipped the same shape
    // without the pointer, so the founder's list gained four entries and three questions, none
    // of them on the list. The repair put the German ear-question on each marker line.
    //
    // ⚠️ THE NEEDLE IS DELIBERATELY NARROW, for the #491 reason this file already carries: the
    // repaired headers QUOTE what they retracted ("not in the plan", "a plan file the tool cannot
    // read"), so a scan for the word "plan" near the marker would match its own withdrawal and go
    // red on a correct tree. Only a POINTER SHAPE counts — a section reference ("plan §…") or a
    // literal `scratchpads/` path on the marker's own line. Prose about the backlog reads neither.
    //
    // ⚠️ HONEST LIMIT, running toward false greens like claim 1's: this cannot tell a real
    // question from a bare marker. An ask that simply says "NEEDS-FOUNDER-VERIFY: sounds right?"
    // passes. It makes the KNOWN shape — deferring to an unreadable file — impossible to
    // reintroduce; it does not make every ask useful.
    func testNoAskDefersItsInstructionToAFileTheToolCannotRead() {
        var offenders: [String] = []
        for root in ["Sources", "Tests"] {
            let base = self.root().appendingPathComponent(root)
            guard let walker = FileManager.default.enumerator(atPath: base.path) else { continue }
            for case let rel as String in walker where rel.hasSuffix(".swift") {
                let path = base.appendingPathComponent(rel).path
                guard let body = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
                for (n, line) in body.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
                where line.contains("NEEDS-FOUNDER-VERIFY")
                    && (line.contains("plan §") || line.contains("scratchpads/")) {
                    offenders.append("\(root)/\(rel):\(n + 1)")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "These device asks point at a file `scripts/founder-verify.py` does not walk "
            + "(claim 4 pins that it skips scratchpads/), so the founder's printed "
            + "checklist shows an entry with no question in it: \(offenders.sorted()). "
            + "Put the instruction ON the marker line — the tool prints that line, and a "
            + "plan is not in front of the founder while they hold the phone. Keep the "
            + "plan reference in the surrounding prose if it helps a future reader; just "
            + "do not make it the ask.")
    }

    // 7 — MOVED with the checklist (2026-11-05): no section heading of the checklist names a
    // removed capability (#1346). Spec in `echoelmusic-intern/guards/`.

    // 8 — the one ask #1302 stranded is marked BLOCKED, not deleted, and its machine stands.
    func testTheStrandedAskIsBlockedRatherThanDeleted() throws {
        let file = "Sources/Echoelmusic/Audio/AudioConfiguration.swift"
        let code = try text(file)

        guard let line = code.components(separatedBy: "\n")
            .first(where: { $0.contains("NEEDS-FOUNDER-VERIFY") && $0.contains("Bluetooth-Kopfhörer") })
        else {
            XCTFail("ANCHOR MISSING: no Bluetooth device ask in \(file). A missing anchor is "
                    + "a finding, not a pass (§4).")
            return
        }
        XCTAssertTrue(line.contains("BLOCKED-BY-#1302"),
            "The Bluetooth/A2DP ask is back in the OPEN queue. It cannot be performed: "
            + "`recordOptions` applies only in `.playAndRecord`, and the only way in is "
            + "`upgradeToPlayAndRecord()`, which #1302 left without a production caller — so "
            + "there is no monitoring switch to turn on. If an audio input came back, remove "
            + "the mark deliberately and pull the ⛔ block above it plus §1 of the device "
            + "checklist (private working repository) in the same commit (#456).")

        // Counterweights (#343): BLOCKED means the door died, never that the machine did. If
        // either of these goes, the honest move is to DELETE the ask, not to keep it blocked —
        // and this assertion is what makes that decision visible instead of silent.
        XCTAssertTrue(code.contains("static let recordOptions"),
            "`recordOptions` is gone — the ask no longer has a machine to come back to.")
        XCTAssertTrue(code.contains("static func routeCodec("),
            "`routeCodec` is gone — the [HFP] half of the ask can no longer be answered even "
            + "once a door returns.")
    }

    // 9 — the stranded ask has NO caller anywhere, which is the fact claim 8 rests on.
    func testNothingRaisesTheRecordRouteAnyMore() {
        var callers: [String] = []
        let base = root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            XCTFail("ANCHOR MISSING: Sources/ could not be walked.")
            return
        }
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            if rel.hasSuffix("AudioConfiguration.swift") { continue }   // its own declaration
            let path = base.appendingPathComponent(rel).path
            guard let body = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            for (n, raw) in body.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("//") || line.hasPrefix("///") { continue }
                if line.contains("upgradeToPlayAndRecord(") { callers.append("\(rel):\(n + 1)") }
            }
        }
        XCTAssertTrue(callers.isEmpty,
            "Something raises the record route again: \(callers.sorted()). That is not a "
            + "defect — it means an audio input is back. But then the Bluetooth ask in "
            + "AudioConfiguration.swift is performable again and must LOSE its "
            + "`BLOCKED-BY-#1302` mark, or the founder's queue hides a job he can now do. "
            + "#364: this guard does not forbid the return, it names the prose that travels "
            + "with it (claim 8's message lists the rest).")
    }
    // 10 — the struck list is SELF-CHECKING: a name on it must be absent from `Sources/`.
    //
    // ⭐ THIS IS THE CLAIM THAT WOULD HAVE CAUGHT #1394 BY ITSELF. Claim 2 anchors two of the
    // struck surfaces by hand (the roll, the three drum files) and says nothing about the rest,
    // so `"AUv3"` could sit on the list for the whole day after #1385 restored the target while
    // claim 1 quietly forbade the probe claim 2 demands. A list maintained by hand is the one
    // part of a guard no gate keeps honest (#396: a run-time failure in this bundle is
    // indistinguishable from the standing red). This turns it into a measurement.
    //
    // ⚠️ IT SCANS PATHS AS WELL AS TEXT, and the path half is the load-bearing one: #1385 came
    // back as a DIRECTORY (`Sources/EchoelmusicAUv3/`), and a target can exist before any file
    // in it happens to spell its own name. Measured on the parent tree, `"AUv3"` scores 2 paths
    // and 39 files — so this claim is RED there for exactly the needle that caused the defect,
    // and the other four score 0/0 on both trees (#343: the counterweights are the point).
    //
    // ⚠️ IT WORKS BECAUSE THE NEEDLES ARE DOCUMENT SPELLINGS. `Drums-Spur`, `Audio-Clip-Editor`
    // and `Velocity-Lane` are German UI names that Swift never carries, so a text scan cannot
    // trip on prose about them. Adding a needle that IS a plausible Swift token would make this
    // claim fragile — if that is ever needed, anchor it by path only and say so here.
    //
    // #364 — a red here does NOT mean delete the needle. It means the surface came back, and
    // the repair is the one claim 2 spells out: move it out of the ⛔ table in the checklist in
    // the same commit, and let the checklist ask for its probe again.
    func testEveryStruckSurfaceIsAbsentFromTheApp() throws {
        let sources = root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: sources.path) else {
            return XCTFail("ANCHOR MISSING: could not walk \(sources.path) — a missing anchor "
                           + "is a finding, not a pass (#454).")
        }
        var paths: [String] = []
        for case let rel as String in walker where rel.hasSuffix(".swift") { paths.append(rel) }
        XCTAssertGreaterThan(paths.count, 100,
            "Only \(paths.count) Swift files under Sources/ — the walk is measuring nothing.")

        // Read ONCE, not once per needle. Four needles × ~360 files is 1,400 file reads for a
        // question that needs 360 — and a slow guard is a guard someone eventually deletes.
        var bodies: [(String, String)] = []
        for rel in paths {
            let full = sources.appendingPathComponent(rel).path
            guard let body = try? String(contentsOfFile: full, encoding: .utf8) else { continue }
            bodies.append((rel, body))
        }

        for surface in Self.struckSurfaces {
            let inPath = paths.filter { $0.contains(surface) }
            XCTAssertTrue(inPath.isEmpty,
                "`\(surface)` is on `struckSurfaces` — the list of things that do NOT exist — "
                + "but it names a live path: \(inPath.sorted().prefix(3).joined(separator: ", ")). "
                + "The checklist guard would therefore forbid asking the founder about a surface "
                + "that is back. Remove the needle here and update the ⛔ table of the device "
                + "checklist (private working repository) in the same commit.")

            var hits: [String] = []
            for (rel, body) in bodies where body.contains(surface) {
                hits.append(rel)
                if hits.count >= 3 { break }
            }
            XCTAssertTrue(hits.isEmpty,
                "`\(surface)` is on `struckSurfaces` but occurs in Sources/: "
                + "\(hits.sorted().joined(separator: ", ")). Same repair as above — and if the "
                + "occurrence is only a tombstone COMMENT about the removal, the needle is too "
                + "generic to stay a needle; anchor it by path only and record that here.")
        }
    }
}
