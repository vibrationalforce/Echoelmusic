//
//  TheMeterReadersAreNamedWhereTheyAreClearedTests.swift
//  Echoelmusic — CISmoke (blocking)
//
//  WHAT THIS IS (§1): a SOURCE-TEXT SCAN. It proves that a prose note and the code it
//  reasons about still describe the same set of files. It proves NOTHING about rendering,
//  about SwiftUI observation at runtime, or about whether a menu actually stays open —
//  that is a DEVICE PROBE and stays open.
//
//  WHY IT EXISTS (#886, 2026-08-30). `scratchpads/BAUSTELLEN_BOARD.md` carried the
//  architecture-audit note for AU5 ("AudioEngine meter props are a 60 Hz freeze landmine").
//  It cleared the item with a premise: the props are read *only* by `MasterLoudnessGrid`,
//  a visibility-gated leaf, so `EchoelStudioView` never observes them. The CONCLUSION was
//  and is right. The PREMISE went false without anyone touching the note: `SpectralDonutView`
//  reads `masterLevel`/`masterLevelR` too, and #747 gave it a door ("Full screen" in
//  `visualPanel`), so a reader that was unreachable when the note was written now renders.
//
//  This is the #756 shape — the conclusion holds, the witness does not — and it is the
//  expensive kind, because a later session uses the premise ("nothing else reads the meters")
//  to clear a DIFFERENT change. Nothing could have gone red: no guard read that note.
//
//  ⚠️ THE LIMIT, STATED BEFORE THE CLAIM (#408). The needle is `.masterLevelR`, the STEREO
//  half, and that is deliberate. `.masterLevel` alone is NOT usable as an anchor: measured
//  across `Sources/` with comments stripped it selects seven files, and five of them read a
//  DIFFERENT property of the same name — `MusicalFrame.masterLevel` (`HeaderMonitors`,
//  `MusicMediaMapping`, `MetalBioView`), plus an `AutomationPlayer` enum case spelled
//  `.masterLevel`. Keying on it would have made this guard red on a correct tree.
//  The cost of the narrower needle is real and is written down rather than hidden: a future
//  view that reads ONLY the mono meter is invisible here. Claim 2 pins the discriminator so
//  the day `MusicalFrame` grows a `masterLevelR` this file says so instead of drifting.
//
//  Also NOT part of the needle: the receiver name. Both readers today spell it
//  `audioEngine.masterLevelR`, and anchoring on that would be tighter — and would silently
//  miss a view that binds the engine under another name. A needle that cannot match the
//  thing it is pointed at is the defect this bundle exists to prevent (#679/#738).
//
//  GRADING AGAINST THE PARENT (§3), transcribed in Python and driven against
//  `git show HEAD:<path>` and the worktree:
//   · claim 1 — REGRESSION. The parent note names `MasterLoudnessGrid` and not
//     `SpectralDonutView`, while the parent SOURCE already contained both readers.
//   · claim 3 — REGRESSION by the same absence (#486: one absence, reported twice, is ONE
//     finding — the parent note has neither "GESCHWISTER" nor "#747").
//   · claims 2 and 4 — COUNTERWEIGHTS, green on both trees. That is the point of them
//     (#343): claim 1 is only meaningful while `masterLevelR` still discriminates, and the
//     AU6 row is only closed while the third `applyBioReactive` owner stays gone.
//
//  ⭐ CLAIMS 5–7 ADDED BY #1197 (2026-09-09), same law family: the AU5 note is about these
//  nine meter properties being a 60 Hz landmine, and #1197 is the slice that stopped them
//  being one. One home per law (#416) — they belong here, not in a new bundle.
//
//  GRADING of 5–7, transcribed in Python and driven against `git show HEAD:<path>` and the
//  worktree. 4 assertions (claim 5: 1, claim 6: 2, claim 7: 1):
//   · claim 5 — REGRESSION. On the parent ALL NINE properties were bare assignments
//     (a=1, g=0 each). One finding, nine witnesses — not nine findings (#486).
//   · claim 7 — REGRESSION. The parent `AudioEngine.swift` never named `Transport.setTempo`,
//     so nothing stopped the compare-then-assign from being read as a repo-wide rule.
//   · claim 6 — COUNTERWEIGHT, green on both trees, and deliberately so (#343/#433): it
//     exists to make the tempting NEXT move (delete the two readerless meters) go red, not
//     to claim a catch it does not have.
//

import XCTest

final class TheMeterReadersAreNamedWhereTheyAreClearedTests: XCTestCase {

    private static let board = "scratchpads/BAUSTELLEN_BOARD.md"
    private static let owner = "Sources/Echoelmusic/Audio/AudioEngine.swift"

    /// The AU5 note, delimited by content and not by a line count: a fixed window is unsound
    /// in this repo (#408), and this block grew from 4 lines to 23 in the commit that wrote
    /// this guard.
    private func au5Note() throws -> String {
        let text = try boardText()
        guard let start = text.range(of: "> **AU5**") else {
            throw Anchor(reason: """
                \(Self.board) no longer contains the "> **AU5**" note. It was renamed or \
                removed — re-anchor this scan rather than letting it skip (#454).
                """)
        }
        guard let end = text.range(of: "> PLAUSIBLE/",
                                   range: start.upperBound..<text.endIndex) else {
            throw Anchor(reason: """
                the AU5 note is no longer terminated by the "> PLAUSIBLE/" line. Give this \
                scan a new terminator; do NOT fall back to a character count.
                """)
        }
        return String(text[start.lowerBound..<end.lowerBound])
    }

    // MARK: - 1. every stereo-meter reader is named in the note that cleared the item

    func testEveryMeterReaderIsNamedInTheNoteThatClearedTheItem() throws {
        let note = try au5Note()
        let readers = try stereoMeterReaders()

        XCTAssertFalse(readers.isEmpty, """
            no file under Sources/ reads `.masterLevelR` outside AudioEngine.swift. Either \
            the meter was renamed or this scan stopped matching — a vacuous green here is \
            worse than a red, because the AU5 note would keep clearing itself on nothing.
            """)

        let unnamed = readers.filter { !note.contains($0) }
        XCTAssertTrue(unnamed.isEmpty, """
            \(Self.board)'s AU5 note clears a 60 Hz freeze risk with a premise about WHICH \
            views read the master meters, and it does not name: \(unnamed.joined(separator: ", ")).

            Today's readers, derived from Sources/ with comments stripped: \
            \(readers.joined(separator: ", ")).

            This is not a request to delete the reader. Add it to the note WITH the reason it \
            is safe — the standing argument is that each reader is its own View struct (a real \
            observation boundary) and a SIBLING of the menu host, never its ancestor. If a new \
            reader is an ANCESTOR of a Picker, the freeze law (10.76.41/50) applies and the \
            note's conclusion has to change, not just its list.
            """)
    }

    // MARK: - 2. counterweight — the needle still discriminates (green on both trees)

    func testTheStereoMeterNameBelongsToTheEngineAlone() throws {
        let engine = try codeText(Self.owner)
        XCTAssertTrue(engine.contains("masterLevelR"), """
            `masterLevelR` is no longer declared in AudioEngine.swift. Claim 1 selects files \
            by that name; if the engine dropped it, claim 1 is measuring nothing.
            """)

        let frame = "Sources/Echoelmusic/Core/MusicalFrame.swift"
        if let musical = try? codeText(frame) {
            XCTAssertFalse(musical.contains("masterLevelR"), """
                \(frame) now also declares `masterLevelR`. That breaks the discriminator claim 1 \
                relies on: `masterLevel` alone is ALREADY shared between AudioEngine and \
                MusicalFrame (measured: 7 files, 5 of them the frame's), and the stereo half was \
                the only unambiguous half. Re-anchor claim 1 on the receiver or on a new name \
                before trusting it again.
                """)
        }
    }

    // MARK: - 3. counterweight — the note still carries the reason, not just the list

    func testTheNoteKeepsTheReasonItsConclusionRestsOn() throws {
        let note = try au5Note()
        for token in ["GESCHWISTER", "#747"] {
            XCTAssertTrue(note.contains(token), """
                the AU5 note lost "\(token)". Its conclusion ("no live freeze today") does not \
                rest on the list of readers — it rests on WHERE they sit: siblings of the VJ \
                overlay inside the fullScreenCover's ZStack, not ancestors of it, and on the \
                fact that #747 is what made the second reader reachable at all. A list without \
                that reason is the premise-without-witness defect this file was written for.
                """)
        }
    }

    // MARK: - 4. counterweight — AU6 stays closed only while its premise holds

    func testTheThirdBioOwnerIsStillGone() throws {
        var offenders: [String] = []
        for path in try swiftFiles() {
            guard let code = try? codeText(path) else { continue }
            if code.contains("BioMirror") { offenders.append(path) }
        }
        XCTAssertTrue(offenders.isEmpty, """
            `BioMirror` is back in CODE (not just in the tombstone comment) at: \
            \(offenders.joined(separator: ", ")).

            That name belonged to the AUv3 KVO poll — the THIRD caller of `applyBioReactive`, \
            and the only one that ran off the render thread. Its removal (#121 Slice 1) is what \
            closed audit item AU6 (cross-thread COW hazard on `harmonicAmplitudes`), and \
            `\(Self.board)` now records AU6 as closed on exactly that ground.

            This does NOT forbid the work (#364). It says: if a third owner comes back, the AU6 \
            row and the `EchoelDDSP.swift` header invariant must be reopened in the SAME commit.
            """)
    }

    // MARK: - 5. the 60 Hz poll republishes nothing that did not move

    /// REGRESSION (#1197). `@Observable` invalidates on ASSIGNMENT, not on change: a write
    /// of the identical value still takes the registrar lock, looks the keypath up and marks
    /// every observing view dirty. `startMeterPollTimer` fires 60x per second for the whole
    /// life of the process, and SEVEN of its nine values are frozen whenever detailed
    /// metering is off — which is the DEFAULT. So the poll spent main-actor time, 60 times a
    /// second, republishing bytes that had not changed, in competition with the render loop.
    ///
    /// This claim says: every one of the nine publications is compare-then-assign.
    func testTheMeterPollAssignsOnlyWhatMoved() throws {
        let body = try meterPollBody()
        var unguarded: [String] = []
        for name in Self.polledMeters {
            let assignments = Self.occurrences(of: "self.\(name) =", in: body)
            // The trailing " {" is NOT cosmetic. `masterLevel` is a PREFIX of
            // `masterLevelR`, so the bare needle counts the stereo guard as a second mono
            // guard and reports a correctly guarded property as unguarded — a red on a
            // clean tree. Every guard in the block is `!= self.<prop> {`.
            let guards = Self.occurrences(of: "!= self.\(name) {", in: body)
            if assignments != 1 || guards != 1 {
                unguarded.append("\(name) (\(assignments) assignment(s), \(guards) guard(s))")
            }
        }
        XCTAssertTrue(unguarded.isEmpty, """
            the 60 Hz meter poll assigns without first comparing: \(unguarded.joined(separator: ", ")).

            Expected shape per value, exactly once each:
                let next<X> = <source>
                if next<X> != self.<prop> { self.<prop> = next<X> }

            A bare assignment here is not a style question. It is one registrar mutation per
            property per tick, 60 ticks a second, forever — the churn half of the founder's
            2026-09-09 "zu viel Arbeitsspeicher / Störungen im Sound" report.

            ⚠️ This does NOT say every `@Observable` write must be guarded (#364).
            `Transport.setTempo` DEPENDS on same-value writes reaching its observers. The
            claim is scoped to these nine meter properties inside this one timer.
            """)
    }

    // MARK: - 6. counterweight — the two readerless meters are kept, not deleted

    /// COUNTERWEIGHT. `masterPeakDb` and `masterLUFS` have ZERO readers outside the engine
    /// today (measured, not assumed). The tempting follow-up is to delete them — and that
    /// would be wrong twice: a mastering surface is the natural next reader, and deleting a
    /// published value to save a write is the opposite of what #1197 did (it kept the value
    /// and stopped paying for the repeat).
    func testTheReaderlessMetersAreStillPublished() throws {
        let body = try meterPollBody()
        for name in ["masterPeakDb", "masterLUFS"] {
            XCTAssertTrue(body.contains("self.\(name) ="), """
                `\(name)` is no longer published by the meter poll. It has no reader outside
                `\(Self.owner)` today, so nothing would have gone red — but "no reader today"
                is not "no reader" (#756: the conclusion can hold while the witness rots).
                If this removal is deliberate, remove the property and its pointer too, and
                say so here — a half-removal leaves a declared value that silently freezes.
                """)
        }
    }

    // MARK: - 7. counterweight — the warning against generalising stays at the site

    /// COUNTERWEIGHT (#364). The compare-then-assign is right for a meter and WRONG for a
    /// tempo. If the warning naming `Transport.setTempo` is lost, the next reader sees a
    /// tidy pattern and spreads it into a path that depends on same-value writes.
    func testTheSiteKeepsTheWarningAgainstGeneralising() throws {
        let owner = try codeText(Self.owner, stripComments: false)
        XCTAssertTrue(owner.contains("Transport.setTempo"), """
            `\(Self.owner)` no longer names `Transport.setTempo` next to the #1197
            compare-then-assign. That note is the only thing standing between this local
            optimisation and a repo-wide "guard every @Observable write" rule that would
            break the tempo path.
            """)
    }

    // MARK: - the polled block

    /// The nine `@Observable` values the 60 Hz timer publishes.
    private static let polledMeters = [
        "masterLevel", "masterLevelR", "masterPeakDb", "masterLUFS",
        "masterOutputLUFSShortTerm", "masterOutputTruePeakMaxDb",
        "masterOutputTruePeakDb", "masterOutputLUFSIntegrated", "masterOutputLRA",
    ]

    private static func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var cursor = text.startIndex
        while let found = text.range(of: needle, range: cursor..<text.endIndex) {
            count += 1
            cursor = found.upperBound
        }
        return count
    }

    /// The comment-stripped body of `startMeterPollTimer`, delimited by BRACE COUNT and not
    /// by a line count or a neighbouring declaration — both of which this repo has watched
    /// rot (#408). If the braces do not balance (a string literal carrying one would do it)
    /// this throws loudly rather than scanning a truncated block: a scan that silently sees
    /// less than the truth is not a measurement (`.claude/rules/context.md` §2).
    private func meterPollBody() throws -> String {
        let code = try codeText(Self.owner)
        guard let head = code.range(of: "private func startMeterPollTimer()") else {
            throw Anchor(reason: """
                `startMeterPollTimer` is gone from \(Self.owner) — renamed or restructured. \
                Re-anchor claims 5 and 6; do NOT let them skip (#454).
                """)
        }
        guard let open = code.range(of: "{", range: head.upperBound..<code.endIndex) else {
            throw Anchor(reason: "no opening brace after `startMeterPollTimer` — re-anchor.")
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let character = code[index]
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(code[open.upperBound..<index])
                }
            }
            index = code.index(after: index)
        }
        throw Anchor(reason: """
            the braces of `startMeterPollTimer` do not balance in the comment-stripped text. \
            Something carries an unpaired brace (a string literal is the usual cause). Fix the \
            extractor — do not widen it until it stops throwing.
            """)
    }

    // MARK: - source access

    private struct Anchor: Error { let reason: String }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func codeText(_ relativePath: String,
                          stripComments: Bool = true) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw Anchor(reason: """
                \(relativePath) is missing while the tree is present — renamed or moved. \
                Re-anchor this scan; do not let it skip (#454).
                """)
        }
        let raw = try String(contentsOf: path, encoding: .utf8)
        // Claim 7 reasons about a COMMENT and must not have it stripped; every other caller
        // reasons about code and must.
        return stripComments ? SourceText.codeOnly(raw) : raw
    }

    private func boardText() throws -> String {
        let path = try repoRoot().appendingPathComponent(Self.board)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw Anchor(reason: "\(Self.board) is missing — re-anchor this scan (#454).")
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func swiftFiles() throws -> [String] {
        let base = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            throw Anchor(reason: "cannot walk Sources/")
        }
        var out: [String] = []
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            out.append("Sources/" + rel)
        }
        guard out.count > 200 else {
            throw Anchor(reason: """
                only \(out.count) Swift files walked under Sources/; the tree holds well over \
                three hundred, so an "absent everywhere" result here would be vacuous.
                """)
        }
        return out.sorted()
    }

    /// File base names (no extension) that read the STEREO master meter in code.
    /// The engine itself is excluded: it declares and writes the property.
    private func stereoMeterReaders() throws -> [String] {
        var out: [String] = []
        for path in try swiftFiles() where path != Self.owner {
            guard let code = try? codeText(path) else { continue }
            guard code.contains(".masterLevelR") else { continue }
            // Pure-Swift split rather than NSString: this bundle should not depend on the
            // ObjC bridge for a path operation it can do itself.
            let base = path.split(separator: "/").last.map(String.init) ?? path
            out.append(String(base.dropLast(".swift".count)))
        }
        return out.sorted()
    }
}
