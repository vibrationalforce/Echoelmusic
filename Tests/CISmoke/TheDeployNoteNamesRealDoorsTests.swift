// TheDeployNoteNamesRealDoorsTests.swift
// Echoel — #820: the build note sent the founder to a chip that does not exist.
//
// WHY THIS EXISTS. `.deploy/release` is the ONE document the founder follows with the phone in
// hand. v10.79.419's note said "Visual-Panel → Full screen". There is no chip called "Visual";
// the strip reads **Sound · FX · Mix · Master · Mood · Tempo · Field · Save/Export**, and the
// visual surface is behind **Field**. Two of its three new paths were fine and the third was
// unfollowable — the exact cost #816 measured on the device checklist, on the document that
// matters most, written by the same session that had just fixed the checklist.
//
// ⭐ IT ALSO EXPOSED A GAP, not just an error: the note said "then send the diagnostics log" and
// never said WHERE it is (Save/Export → "Diagnostics" → Share). That is the single most
// important pending action in the project, and four builds shipped without the path.
//
// ⛔ THREE DRAFTS OF THIS GUARD FAILED BEFORE IT WORKED, all found by DRIVING, none by reading:
// 1. A scan for `Visual-Panel` matched the corrected note's own retraction of that name (#491).
//    The note is phrased to avoid the hyphenated form rather than teaching this guard an
//    exemption — an exemption is a hole someone else walks through later.
// 2. The corrected note writes paths as `**Master**-Chip`, so the emphasis markers sit between
//    the word and the hyphen and a naive scan found ZERO tokens: a guard passing vacuously,
//    forever, on a document it never read (#808). Emphasis is stripped first, and claim 2
//    asserts it found something.
// 3. A scripted edit anchored on `var tokens: Set<String> = []` — a line the replacement's own
//    new helper also contained — and ate two claims. Same self-collision family as 1: **an
//    anchor that the new text also matches is not an anchor.**
//
// #364 — NOTHING HERE FORBIDS A RENAME. If a chip is relabelled, claim 1 goes red on purpose and
// names the note as the prose to pull along in the same commit.
//
// ⭐ CLAIM 2 READS THE CURRENT BUILD'S NOTE, NOT THE ARCHIVE (slice F, 2026-10-02). `.deploy/release`
// keeps every earlier build's "── WAS IN DIESEM BUILD NEU IST" section below the newest one, and
// those sections describe their own builds: 10.79.484–486 sent the founder along "Workstation-Chip"
// because that chip existed then. Read whole, the note forbids retiring ANY chip without rewriting
// shipped history — #364, a guard that forbids correct work. The founder follows the section on
// top, with the phone in hand; that section plus the preamble above it is what claim 2 now reads,
// and it is ANCHORED: the first section's header must carry the version on line 1, so a note whose
// newest section is not on top, or whose header lost its version, fails rather than passing on the
// wrong text. The ≥1-token counterweight stays.
//
// ⭐ AND THE ARCHIVE IS NOT LEFT UNREAD, because narrowing claim 2 alone would have WEAKENED the
// guard ("Keine Tests … abschwächen"). Claim 2b reads the WHOLE note again and admits exactly one
// set beyond the shipped labels: `retiredLabels`, each entry dated with the slice that retired
// its chip, required to be DISJOINT from the shipped strip (a label cannot be both) and to OCCUR
// in the note (an exemption that exempts nothing is a hole — remove it). A typo in an old
// section, or a chip that never existed, is still red. Claims 3–5 still read the whole note.
//
// KIND (§1): **REGRESSION, source-text scans.** Claim 2 driven against the v419 note: it finds
// `Visual` and fails; against the corrected note it finds four tokens and passes.
//
// SLICE F GRADING (§3; transcribed against the parent `3deb54e77` and the slice tree, the note
// itself unchanged): claim 1 RED on the parent for its named reason — the strip still lists
// "Workstation" (a FORWARD edit of the expectation, one finding). Claim 2 GREEN on both: the
// current section names FX · Field · Master · Save/Export, shipped on both trees. Claim 2b: its
// disjointness assertion RED on the parent for its named reason (Workstation still ships there);
// its non-empty, every-token and no-dead-exemption assertions GREEN on both — counterweights.
// Claims 3–5 untouched, GREEN on both.

import XCTest

final class TheDeployNoteNamesRealDoorsTests: XCTestCase {

    /// The chip strip as shipped. Pinned here so a rename cannot silently make claim 2 weaker.
    ///
    /// ⛔ "Video" STOOD HERE AND MADE CLAIM 1 RED FOR FOUR COMMITS (#1304 → #1309). The founder
    /// withdrew video capture on 2026-09-12 ("Kein Video Capture"); that slice deleted the
    /// `videoPanel`, the `.video` menu case and the chip — and left this list at ten while the
    /// strip shipped nine. Claim 1 asserts ARRAY EQUALITY, so it went red on a correct tree
    /// immediately, exactly as its own message demands ("this list with it, in the SAME
    /// commit"). The message was right; nobody read it, because `Run Tests` reports `failure`
    /// on EVERY push (#396) and the job log is a 200-line tail (#807).
    ///
    /// ⭐ WHY NO NEEDLE CHECKER CAUGHT IT, which is the transferable part. The expectation is a
    /// hand-written Swift ARRAY compared against a list PARSED out of `EchoelStudioView`, not a
    /// string literal asserted to be present in a file — so `dead-needles.py`,
    /// `moved-needles.py` and `foreign-needles.py` have nothing to bind, and `count-pins.py`
    /// reads counts, not membership. **A list pin is a pin.** After a removal, re-derive every
    /// hand-written expectation whose other side is parsed from the tree; the cheap form here is
    /// the state machine in `shippedLabels()`, transcribed in Python.
    ///
    /// ⚠️ It stays HAND-WRITTEN on purpose — deriving it from the same parse would make the file
    /// agree with itself and never fail. The literal IS the second opinion (the argument
    /// `scripts/check-infoplist.sh` states for its own list).
    // ⚠️ THE ORDER IS PART OF THE CLAIM — `shippedLabels()` returns the switch in source
    // order and claim 1 compares with `XCTAssertEqual`, so a reordered strip is a finding too.
    // ⛔ "Workstation" was MISSING here from #1436 (the chip's own slice) until 10.79.48x, and
    // claim 1 was RED on a correct tree for the whole Phase-4 run without a gate saying so (the
    // bundle is BUILT by CI/CD `Build for Testing`, never RUN — #396/#807). Slice F (2026-10-02)
    // retired the chip, so it leaves this list in the SAME commit, as claim 1's message demands.
    private static let expectedLabels = [
        "Bio", "Tempo", "Sound", "Mix", "FX", "Master", "Mood", "Save/Export", "Field"
    ]

    /// Chips the note may still name because an EARLIER build's section sent the founder along
    /// them while they existed. Each entry is dated with the slice that retired it. Hand-written
    /// for the reason `expectedLabels` is: deriving it from the tree would agree with itself.
    private static let retiredLabels: Set<String> = [
        "Workstation"   // slice F, 2026-10-02 — the stage seam is the arrangement's one door
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
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read. This guard fails rather "
                    + "than skips (§4) — a missing anchor is a finding, not a pass.")
            return ""
        }
        return contents
    }

    /// The `StudioMenu.label` switch, read line by line from its declaration to the next member.
    /// Deliberately a plain state machine: this repo has no local Swift toolchain, so clever
    /// Substring index arithmetic is a thing nobody can check before CI.
    private func shippedLabels() throws -> [String] {
        let view = try text("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        var labels: [String] = []
        var inside = false
        var sawDeclaration = false
        for line in view.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !inside {
                if trimmed.hasPrefix("var label: String") { inside = true; sawDeclaration = true }
                continue
            }
            if trimmed.hasPrefix("var ") { break }
            guard trimmed.hasPrefix("case ."),
                  let openQuote = trimmed.range(of: "return \"") else { continue }
            let tail = trimmed[openQuote.upperBound...]
            guard let closeQuote = tail.firstIndex(of: "\"") else { continue }
            labels.append(String(tail[..<closeQuote]))
        }
        if !sawDeclaration {
            XCTFail("ANCHOR MISSING: `var label: String` is gone from EchoelStudioView — the "
                    + "chip labels moved. Re-anchor this guard; do not let it skip (#454).")
        }
        return labels
    }

    /// Capitalised words the note uses as a path, e.g. `Master-Chip` or `Field-Panel`.
    private func pathTokens(in note: String) -> Set<String> {
        var found: Set<String> = []
        for marker in ["-Chip", "-Panel"] {
            for piece in note.components(separatedBy: marker).dropLast() {
                var word = ""
                for character in piece.reversed() {
                    guard character.isLetter || character == "/" else { break }
                    word.insert(character, at: word.startIndex)
                }
                if let first = word.first, first.isUppercase { found.insert(word) }
            }
        }
        return found
    }

    // 1 — the chip strip is the one this guard thinks it is.
    func testTheChipLabelsAreTheOnesThisGuardChecksAgainst() throws {
        XCTAssertEqual(try shippedLabels(), Self.expectedLabels, """
            The chip labels changed. That is allowed (#364) — but `.deploy/release` sends the \
            founder along these names with the phone in hand, so the note has to be corrected \
            in the SAME commit, and this list with it.
            """)
    }

    /// The first build section's header, as `.deploy/release` writes it.
    private static let sectionMarker = "── WAS IN DIESEM BUILD NEU IST"

    /// The part of the note the founder follows for THIS build: the preamble plus the newest
    /// section — everything above the SECOND section marker. Fails, and returns "", when the
    /// marker is missing or the first section's header does not carry the version line 1 names.
    private func currentBuildNote() throws -> String {
        let whole = try text(".deploy/release")
        let sections = whole.components(separatedBy: Self.sectionMarker)
        guard sections.count >= 2 else {
            XCTFail("""
                ANCHOR MISSING: `\(Self.sectionMarker)` is not in .deploy/release — the note lost its \
                per-build sections, so claim 2 cannot tell this build from the archive. Re-anchor; \
                do not let it pass on the whole file or on nothing (#454).
                """)
            return ""
        }
        let firstLine = String(whole.prefix { $0 != "\n" })
        let version = firstLine
            .split(whereSeparator: { !($0.isNumber || $0 == ".") })
            .map(String.init)
            .first { $0.split(separator: ".").count == 3 }
        guard let version else {
            XCTFail("ANCHOR MISSING: line 1 of .deploy/release names no build version (read: \(firstLine))")
            return ""
        }
        let header = String(sections[1].prefix { $0 != "\n" })
        XCTAssertTrue(header.contains(version), """
            The first build section (\(Self.sectionMarker)\(header)) is not this build's \
            (\(version), line 1). The newest section must sit on top — claim 2 reads it as the \
            note the founder follows.
            """)
        return sections[0] + Self.sectionMarker + sections[1]
    }

    // 2 — every door the CURRENT build's note names is a door that exists.
    func testEveryPathInTheCurrentBuildNoteNamesARealChip() throws {
        let labels = try shippedLabels()
        let note = try currentBuildNote().replacingOccurrences(of: "*", with: "")
        let tokens = pathTokens(in: note)
        XCTAssertFalse(tokens.isEmpty, """
            This build's note names no `X-Chip`/`X-Panel` path at all. Either the note stopped \
            giving the founder a route, or this scan can no longer match its formatting — the \
            second is how a guard passes forever on a document it never read (#808).
            """)
        for token in tokens.sorted() {
            XCTAssertTrue(labels.contains(token), """
                The build note sends the founder to "\(token)", which is not a chip. The strip \
                reads \(labels.joined(separator: " · ")). This is the document read with the \
                phone in hand — a path that cannot be followed costs a device session (#816).
                """)
        }
    }

    // 2b — the WHOLE note, archive included, names only chips that exist or that existed.
    func testTheArchivedBuildNotesNameOnlyRealOrRetiredChips() throws {
        let labels = Set(try shippedLabels())
        XCTAssertTrue(Self.retiredLabels.isDisjoint(with: labels), """
            A chip is listed as retired AND ships: \(Self.retiredLabels.intersection(labels).sorted()). \
            Either it came back — remove it from `retiredLabels` — or the retirement never happened.
            """)
        let note = try text(".deploy/release").replacingOccurrences(of: "*", with: "")
        let tokens = pathTokens(in: note)
        XCTAssertFalse(tokens.isEmpty, """
            The whole note names no `X-Chip`/`X-Panel` path at all — the scan no longer matches \
            its formatting, which is how a guard passes forever on a document it never read (#808).
            """)
        for token in tokens.sorted() {
            XCTAssertTrue(labels.contains(token) || Self.retiredLabels.contains(token), """
                The build note (an earlier section included) names "\(token)", which is neither a \
                chip nor a retired one. An archived path was still a path the founder was sent \
                along; a name that never existed is a typo in shipped history, not history.
                """)
        }
        for retired in Self.retiredLabels.sorted() {
            XCTAssertTrue(tokens.contains(retired), """
                `retiredLabels` exempts "\(retired)" and the note no longer names it. An exemption \
                that exempts nothing is a hole someone else walks through later — remove the entry.
                """)
        }
    }

    // 3 — the note says where the diagnostics log is, because that ask gates everything else.
    func testTheBuildNoteSaysWhereTheDiagnosticsLogIs() throws {
        let note = try text(".deploy/release")
        guard note.contains("Diagnose-Log") || note.contains("diagnostics log") else { return }
        XCTAssertTrue(note.contains("Diagnostics"), """
            The note asks for the diagnostics log without naming the door that produces it. \
            The path is Save/Export → "Diagnostics" → Share; four builds shipped without it \
            while the log was the one thing being waited on.
            """)
    }

    /// 4 — the note tells the next session HOW to list what this build made testable (#1150).
    ///
    /// `founder-verify.py --since <sha>` has existed since #931 and lived ONLY inside the
    /// script. CLAUDE.md names the tool, not the flag, and the place a session actually writes
    /// a build note pointed at neither. With a three-digit backlog that is the difference
    /// between a pointed device session and the same unsorted wall every time.
    ///
    /// ⛔ POSITIVE SCAN, for the #1148 reason: asserting an instruction is PRESENT has no
    /// self-referential failure mode, while asserting one is absent does.
    func testTheBuildNoteSaysHowToListWhatThisBuildMadeTestable() throws {
        let note = try text(".deploy/release")
        XCTAssertTrue(note.contains("founder-verify.py --since"), """
            The build note no longer prints the command that lists the asks this build made \
            newly testable. Without it the founder gets the whole backlog every round, which \
            is how a checklist stops being read. If the flag was renamed, rename it here in \
            the same commit — this file and the note are the only two homes it has.
            """)
    }

    /// 5 — the note warns that ANY touch of it ships a build, not only a version bump (#1151).
    ///
    /// Measured the hard way: commit 35193c43 touched only this note's header, a guard and the
    /// session log — zero bytes under `Sources/` — and `testflight.yml` archived, exported and
    /// UPLOADED. Its trigger is `push: paths: ['.deploy/release']`, which fires on any change;
    /// the workflow's own inline comment claims "only an explicit bump", an intent a path
    /// filter cannot express. TestFlight now holds two builds at marketing version 10.79.463.
    ///
    /// ⚠️ CLAIM 4 MAKES THIS MORE LIKELY, which is why the two live side by side: claim 4 asks
    /// a session to APPEND a list to this file. The warning is what keeps that append inside
    /// the bump commit instead of after it.
    ///
    /// ⛔ Repairing the trigger is founder-gated (`.github/workflows/**` = report, do not
    /// edit), so this prose is the only brake that exists. If the trigger is ever narrowed to
    /// a real bump, this claim goes red — and the repair is to retract the warning, not to
    /// widen the trigger back (#364).
    func testTheBuildNoteWarnsThatAnyTouchShipsABuild() throws {
        let note = try text(".deploy/release")
        XCTAssertTrue(note.contains("NICHT NUR EIN BUMP"), """
            The build note no longer warns that any change to it uploads to TestFlight. That \
            warning is the only brake on a duplicate build, because the trigger is a PATH \
            filter and fixing it is founder-gated. If the workflow was narrowed to a real \
            version bump, retract this claim in the same commit and say so here.
            """)
    }
}
