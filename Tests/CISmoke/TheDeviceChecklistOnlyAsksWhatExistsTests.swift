// TheDeviceChecklistOnlyAsksWhatExistsTests.swift
// Echoel — #816: the founder's ONE device checklist asked for four things that cannot be
// done at all, and nothing in the repo could say so.
//
// WHY THIS EXISTS. `scratchpads/FOUNDER_DEVICE_SESSION.md` was written 2026-07-16 to bundle
// every device-bound question into a single session, because the founder is the only device
// tester and device time is this project's scarcest resource. Measured 2026-08-25, four of its
// seven sections asked for probes on surfaces that no longer exist: the piano-roll editor
// (`struct PianoRollView` deleted, #475), a drum lane (`DrumSynthVoice`/`LaneDrumKitVoice`/
// `DrumNoteMap` deleted, #166/#167), an AUv3 host test (target removed 2026-07-24), a
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

import XCTest

final class TheDeviceChecklistOnlyAsksWhatExistsTests: XCTestCase {

    /// Surfaces measured absent on 2026-08-25, spelled the way the old checklist spelled them.
    /// Every needle was driven against the pre-#816 document before it shipped: all five match
    /// there (six findings across four asks) and none matches the rewritten one.
    private static let struckSurfaces = [
        "laneAUInstruments",
        "AUv3",
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

    /// The `- [ ]` line plus the indented lines that continue it. No force unwrap: every
    /// branch binds `current` with `if let`, per the repo-wide ban.
    private func checkboxAsks(in document: String) -> [String] {
        var asks: [String] = []
        var current: String?
        for line in document.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [ ]") {
                if let open = current { asks.append(open) }
                current = trimmed
            } else if let open = current, line.hasPrefix("      "), !trimmed.isEmpty {
                current = open + " " + trimmed
            } else if let open = current, !line.hasPrefix(" ") {
                asks.append(open)
                current = nil
            }
        }
        if let open = current { asks.append(open) }
        return asks
    }

    // 1 — no ASK names a surface that no longer exists.
    func testNoDeviceAskPointsAtARemovedSurface() throws {
        let doc = try text("scratchpads/FOUNDER_DEVICE_SESSION.md")
        let asks = checkboxAsks(in: doc)
        XCTAssertGreaterThan(asks.count, 3,
            "The checklist parsed to \(asks.count) asks. Either the file lost its content or "
            + "the `- [ ]` convention changed — in both cases this guard is measuring nothing.")
        for ask in asks {
            for surface in Self.struckSurfaces {
                XCTAssertFalse(ask.contains(surface),
                    "The founder is asked to test \"\(surface)\", which does not exist: "
                    + "\(ask.prefix(90))… Device time is the scarcest resource in this project "
                    + "(#525) — either remove the ask or, if the surface came back, move it out "
                    + "of the ⛔ table in the same commit.")
            }
        }
    }

    // 2 — the struck surfaces really are gone, so claim 1 fails for its named reason (#367).
    func testTheStruckSurfacesAreStillAbsentFromTheApp() throws {
        let recovery = "If this is red because the surface RETURNED, that is correct and "
            + "expected (#364): update the ⛔ table in scratchpads/FOUNDER_DEVICE_SESSION.md "
            + "in the same commit, and the checklist may ask for its probe again."

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

        // ⭐ THE AUv3 ABSENCE PIN IS GONE FROM HERE, 2026-09-20 (#1385) — and that is this
        // guard's own `recovery` instruction being followed, not an assertion being dodged:
        // *"If this is red because the surface RETURNED, that is correct and expected (#364):
        // update the ⛔ table in scratchpads/FOUNDER_DEVICE_SESSION.md in the same commit, and
        // the checklist MAY ASK FOR ITS PROBE AGAIN."* Both halves happened in this commit.
        // The target is now pinned POSITIVELY, once, in `ContentPipelineClaimsTests` — a
        // second copy here would be the #416 duplication this repo keeps paying for, and the
        // one that goes stale is always the copy nobody remembers owning.
        //
        // What this file asserts INSTEAD is its actual subject: the checklist may only ask for
        // what exists. An AUv3 that ships un-probed is worse than one that is absent, because
        // the -3000 instantiation failure recorded in `EchoelmusicAUv3.entitlements` was never
        // resolved on device — it was made moot by deletion. So the probe is now MANDATORY.
        let doc = try text("scratchpads/FOUNDER_DEVICE_SESSION.md")
        XCTAssertTrue(doc.contains("EchoelBodyVibe"), """
        The device checklist does not ask the founder to open EchoelBodyVibe in a host. The \
        AUv3 target came back in #1385 and its ONE open question — does instantiating it still \
        return -3000 invalidComponentID, or did dropping the App-Group entitlement fix it — \
        cannot be answered by any test in this repo. It needs a phone, AUM or GarageBand, and \
        two minutes. If the target was cut again, delete this assertion together with the \
        target, the embed in project.yml and the compile_scheme line in testflight.yml.
        """)
    }

    // 3 — the document routes a reader to the tool instead of being a second list.
    func testTheChecklistPointsAtTheToolThatScansTheCode() throws {
        let doc = try text("scratchpads/FOUNDER_DEVICE_SESSION.md")
        XCTAssertTrue(doc.contains("scripts/founder-verify.py"),
            "The checklist must name the tool that prints the code-anchored asks. Without that "
            + "pointer it is again a second list, which is how it rotted for two months.")
        XCTAssertTrue(doc.contains("NEEDS-FOUNDER-VERIFY"),
            "The checklist must name the marker convention, so a reader knows which asks live "
            + "in the code and which live here.")
    }

    // 4 — the tool really does exclude scratchpads, which is WHY claim 3 is needed.
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
            founder-verify.py lost its bare-string-literal rule. Claim 3 in THIS file asserts a \
            naked "NEEDS-FOUNDER-VERIFY" literal, and without that rule the tool files this very \
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

    // MARK: - #1346 — the rot claim 1 could not see, because it was never a checkbox

    /// Capability words that name something a founder deletion removed. Each was measured
    /// ABSENT from `Sources/` code on 2026-09-16 before it was written here.
    ///
    /// ⭐ THE SCOPE IS HEADINGS, AND THAT IS THE WHOLE POINT OF CLAIM 7. Claim 1 scans
    /// `- [ ]` items, which is right for an ASK — and §1's rot was never an ask. It was a
    /// SECTION, headed "Der eine Handgriff — er blockiert die ganze Vokal-Kette", naming a
    /// handle (`Mix-Panel → "Choose input…" → Live monitoring`) that #1302 deleted. A
    /// document that calls something its BLOCKER in a heading costs more than a stale
    /// checkbox: the founder plans the whole session around it and never reaches §2.
    ///
    /// ⚠️ IT CANNOT BE A FILE-WIDE SCAN (#491). The ⛔ tables quote every struck name in
    /// order to withdraw it, and §1 now quotes its own former heading — a naive negative
    /// scan would go red on this very retraction. A heading is the narrowest scope that
    /// still catches the defect: it is one line, it is what a reader sees first, and no
    /// retraction is written as one.
    private static let removedCapabilities = [
        "Vokal-Kette",     // #1302 — the whole chain; the ONE known positive on the parent
        "Vocal chain",
        "Monitoring",      // #1302 — no monitor path, no switch
        "Mikrofon",        // #1302
        "Microphone",      // #1302
        "Harmonizer",      // #1305
        "Granular",        // #1305
        "Autotune",        // #1302 (VoicePitchCorrector went with the input)
        "Face-Tracking",   // #1301 — NOT the bare "Face": the match is case-insensitive
        "Gesichts",        //         and substring, so "Face" would fire on "Interface"
        "Video Capture"    // #1304
    ]

    // 7 — no SECTION HEADING names a capability the founder removed.
    func testNoSectionHeadingNamesARemovedCapability() throws {
        let doc = try text("scratchpads/FOUNDER_DEVICE_SESSION.md")
        let headings = doc.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("## ") || $0.hasPrefix("### ") }
        XCTAssertGreaterThan(headings.count, 4,
            "ANCHOR MISSING: fewer than five headings in FOUNDER_DEVICE_SESSION.md — the "
            + "extraction found nothing and this claim would be vacuously green (#926).")

        var offenders: [String] = []
        for heading in headings {
            for word in Self.removedCapabilities where heading.localizedCaseInsensitiveContains(word) {
                offenders.append("\(word) → \(heading)")
            }
        }
        XCTAssertTrue(offenders.isEmpty,
            "A section of the founder's device checklist is HEADED with a capability that "
            + "no longer exists: \(offenders). Device time is this project's scarcest "
            + "resource and the heading is what he plans the session from. Either the "
            + "capability came back — then strike this needle in the SAME commit and say so "
            + "in the ⛔ index of that document (#364: nothing here forbids a return) — or "
            + "the section is void and belongs in that index with its measurement, the way "
            + "#1346 moved §1 there.")
    }

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
            + "the mark deliberately and pull the ⛔ block above it plus §1 of "
            + "scratchpads/FOUNDER_DEVICE_SESSION.md in the same commit (#456).")

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
}
