// ThePieceStageHasOnePlayTests.swift
// Echoel — Workstation redesign A3b (founder 2026-10-01, plan `PLAN_WORKSTATION_REDESIGN_2026-10-01.md`:
// "Kopf-Play und Leisten-Play doppeln sich auf der Stück-Bühne — Kopf-Play bleibt für die
// Instrument-Bühne"). BLOCKING bundle.
//
// THE MEASUREMENT (HEAD aea9096f6). On the Piece stage two Play/Stop buttons stood on one screen:
// the head's (`ProjectHeader.playStopButton`, mounted in `WorkspaceView` above both stages) and the
// pinned bar's (`WorkstationView.transportRow`, A3). Same clock, same Stop — but two objects that
// already disagreed: the head resumed a held instrument (`.resumeInstrument`) and owned the space
// bar; the bar did neither, and said "Play timeline" where the head said "Play the piece". The
// founder has asked for ONE Play four times ("zu viele Play Knöpfe", 2026-07-15 · "3 Knöpfe",
// 07-29 · "Einfaches start stop", 07-31 · rule 2, 09-30).
//
// THE DECISION. The head's button becomes its own leaf, `ProjectPlayStopButton`, and stands in
// exactly ONE place per stage: in the head on the Instrument stage, in the bar on the Piece stage.
// One definition — so the word, the label, the resume, the Stop and the ONE space-bar shortcut
// (`TheHeadPlayOwnsTheSpaceKeyTests`, whose count law is untouched) follow it. The compact Record
// leaves the head with it on the Piece stage; the bar has the full one.
//
// WHAT KIND OF GREEN THIS IS (Tests/CISmoke/CLAUDE.md §1), per claim:
// · 1 END-TO-END on `StudioStage.headCarriesTransport` (shipped, public, Foundation-only).
// · 2–7 SOURCE-TEXT SCANS — the seam mounts the bar on the Piece stage only and shares the head's
//   fallback, one definition and two mounts, the head's gate, the bar's mount, where the space key
//   lives, and the moved button's own lines. They prove where text sits, not that SwiftUI renders
//   one button per stage.
// · DEVICE PROBE, OPEN — NEEDS-FOUNDER-VERIFY: on the Piece stage the head shows no Play and no
//   Record (name · status · position · tempo · pill · Undo only; the ⓘ moved to the ≡ menu in S1b-1) and the bar's Play reads
//   "Play"/"Stop" with its word; flipping to Instrument brings Play + Record back to the head with
//   no flicker of two; with a hardware keyboard, space plays/stops on BOTH stages; with an
//   instrument session paused on the Instrument stage, switching to Piece and tapping the bar's
//   Play brings the music back (the resume moved with the button).
//
// HONEST GRADING (§3), against the parent tree (aea9096f6): this file names
// `StudioStage.headCarriesTransport`, which this commit creates, so it DOES NOT COMPILE there and
// no assertion has a verdict. Transcribed in Python against both trees instead:
// · claim 1 FORWARD (drives the new symbol; could never have been red).
// · claim 5 has 2 REGRESSIONS, run before its anchor on purpose: the parent's `transportRow`
//   carries `"play.fill"` and builds its own `Button {` — the second Play this slice removes — red
//   there for that named reason. Its third needle (no `.keyboardShortcut(.space` in the file) is a
//   counterweight: 0 on both trees.
// · claims 3, 4, 6 and 7, plus claim 5's mount anchor, are red on the parent by ONE ABSENCE —
//   `ProjectPlayStopButton` does not exist there (#486), booked once. Claim 7's needles are the
//   moved button's own lines: on the patched tree a counterweight (gate, resume, one Stop, cold
//   body survive the move), on the parent part of that absence.
// · claim 2 is the COUNTERWEIGHT green on both trees: the seam mounts the arrangement on the
//   Piece stage only — the premise that makes "one Play per stage" true — and spells the same
//   unknown-raw fallback the head's gate spells (claim 4), so the two cannot land on different stages.
// Transcribed against HEAD aea9096f6 and HEAD + the A3b patch: every assertion green on the patched
// tree; on HEAD claim 2 green, claim 5's two regression needles red, the rest absent as stated.
// Stripper `SourceText.codeOnly`: PROPHYLAKTISCH (0 verdicts flip raw vs. stripped today) — the
// A3b prose spells the type in backticks without a parenthesis, so neither the construction count
// nor the declaration scan meets a comment; it is there for the day a doc line spells
// `ProjectPlayStopButton(` and would otherwise count as a third mount.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePieceStageHasOnePlayTests: XCTestCase {

    private static let header = "Sources/Echoelmusic/Studio/ProjectHeader.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let seam = "Sources/Echoelmusic/Studio/StageShell.swift"
    private static let buttonDecl = "struct ProjectPlayStopButton: View {"
    private static let headMount = "ProjectPlayStopButton(source: \"project header\")"
    private static let barMount = "ProjectPlayStopButton(source: \"workstation\")"
    private static let fallback = "StudioStage(rawValue: stageRaw) ?? StudioDefaultKeys.stage.value"

    // MARK: 1 — END-TO-END: the head carries the transport on every stage but the Piece stage

    func testTheHeadCarriesTheTransportOnlyWhereTheBarIsAbsent() {
        XCTAssertEqual(StudioStage.allCases.filter { !$0.headCarriesTransport }, [.piece], """
            The head drops its Play/Stop and Record on exactly the Piece stage — the one stage \
            whose arrangement carries the pinned transport bar. Any other set is either two Plays \
            on one screen or a stage with none.
            """)
        XCTAssertTrue(StudioStage.instrument.headCarriesTransport,
                      "the Instrument stage has no bar — its Play is the head's, or it has no Play at all")
        XCTAssertEqual(StudioDefaultKeys.stage.value, .piece, """
            ANCHOR: a fresh install opens on the Piece stage, so the FIRST Play a newcomer meets is \
            the bar's. If the default stage moved, re-read this slice's reasoning before re-anchoring.
            """)
    }

    // MARK: 2 — COUNTERWEIGHT: the bar exists on the Piece stage only (the seam's own `if`)

    func testTheSeamMountsTheArrangementOnThePieceStageOnly() throws {
        let seam = try code(Self.seam)
        let shell = try member("struct StageShell: View {", in: seam)
        guard let gate = shell.range(of: "if stage == .piece {"),
              let mount = shell.range(of: "ArrangeStage()", range: gate.upperBound..<shell.endIndex) else {
            return XCTFail("ANCHOR MISSING: `StageShell` no longer mounts `ArrangeStage()` behind `if stage == .piece {` (#454)")
        }
        let lead = shell[gate.upperBound..<mount.lowerBound]
        XCTAssertEqual(lead.filter { $0 == "{" }.count - lead.filter { $0 == "}" }.count, 0,
                       "`ArrangeStage()` is a direct child of the Piece-stage branch")
        XCTAssertEqual(shell.components(separatedBy: "ArrangeStage()").count - 1, 1,
                       "one arrangement mount — a second one outside the branch puts the bar on the Instrument stage")
        XCTAssertTrue(seam.contains(Self.fallback), """
            The seam resolves an unknown stage raw value with `\(Self.fallback)` — the SAME \
            spelling the head's gate uses (claim 4). If one fallback moves, an unknown raw value \
            puts the seam and the head on different stages: zero Plays, or two.
            """)
        let stage = try member("struct ArrangeStage: View {", in: seam)
        XCTAssertTrue(stage.contains("WorkstationView()"), "the Piece stage is the Workstation, which carries the bar")
    }

    // MARK: 3 — one definition, exactly two mounts, one per stage

    func testThePlayStopIsDefinedOnceAndMountedTwice() throws {
        var declarations: [String] = []
        var mounts: [String: Int] = [:]
        for path in try swiftFiles() {
            let text = try code(path)
            if text.contains(Self.buttonDecl) { declarations.append(path) }
            let n = text.components(separatedBy: "ProjectPlayStopButton(").count - 1
            if n > 0 { mounts[path] = n }
        }
        XCTAssertEqual(declarations, [Self.header], "`ProjectPlayStopButton` is declared once, beside the head that used to own it")
        XCTAssertEqual(mounts, [Self.header: 1, Self.workstation: 1], """
            `ProjectPlayStopButton(` is constructed at \(mounts). Exactly two mounts are the design: \
            the head (Instrument stage) and the Workstation's bar (Piece stage). A third is a second \
            Play on some screen; a missing one is a stage with no Play.
            """)
        XCTAssertEqual(try code(Self.header).components(separatedBy: Self.headMount).count - 1, 1,
                       "the head's mount names its own crash-log source")
        XCTAssertEqual(try code(Self.workstation).components(separatedBy: Self.barMount).count - 1, 1,
                       "the bar's mount names its own crash-log source")
    }

    // MARK: 4 — the head mounts it, and its compact Record, behind the stage gate

    func testTheHeadMountsTheTransportBehindTheStageGate() throws {
        let header = try code(Self.header)
        let head = try member("struct ProjectHeader: View {", in: header)
        XCTAssertTrue(head.contains("@AppStorage(StudioDefaultKeys.stage.key)"),
                      "the head reads the stage through the ONE key (#416)")
        XCTAssertEqual(head.components(separatedBy: "stageRaw = ").count - 1, 1,
                       "the head READS the stage — its only `stageRaw = ` is the declaration's default")
        XCTAssertTrue(head.contains("let carriesTransport = (\(Self.fallback)).headCarriesTransport"),
                      "the gate asks the stage's own rule (claim 1) through the seam's own fallback (claim 2)")
        guard let gate = head.range(of: "if carriesTransport {"),
              let play = head.range(of: Self.headMount, range: gate.upperBound..<head.endIndex),
              let record = head.range(of: "RecordTakeButton(", range: play.upperBound..<head.endIndex),
              let groupEnd = head.range(of: "return Group {", range: record.upperBound..<head.endIndex) else {
            return XCTFail("ANCHOR MISSING: `if carriesTransport {` → Play → Record → `return Group {` in `ProjectHeader` (#454)")
        }
        let toRecord = head[gate.upperBound..<record.lowerBound]
        XCTAssertEqual(toRecord.filter { $0 == "{" }.count - toRecord.filter { $0 == "}" }.count, 0,
                       "Play and the compact Record both sit directly inside the stage gate")
        // DAW shell S1b-1: the ⓘ that anchored this claim left the head for the mark's ≡ menu, so
        // the claim moves to what it protected — the controls that must stay on BOTH stages. The
        // gate's `Group` must close (if-close + Group-close = −2) before the shapes are built, so
        // Undo · Redo (`history`) and the pill can never fall inside it.
        let toShapes = head[gate.upperBound..<groupEnd.lowerBound]
        XCTAssertEqual(toShapes.filter { $0 == "{" }.count - toShapes.filter { $0 == "}" }.count, -2, """
            The stage gate and its `Group` no longer both close before the head's shapes are \
            built — whatever the shapes hold would vanish with Play on the Piece stage.
            """)
        XCTAssertFalse(toShapes.contains("history") || toShapes.contains("pulsePill"), """
            Undo · Redo or the pulse pill sit inside the transport gate — they would vanish with \
            Play on the Piece stage.
            """)
        XCTAssertFalse(head.contains("playStopButton("),
                       "the head builds no inline Play of its own any more — the one button is `ProjectPlayStopButton`")
    }

    // MARK: 5 — the bar mounts the SAME button and draws no Play of its own (REGRESSION)

    func testTheBarMountsTheOneButtonAndNoSecondPlay() throws {
        let workstation = try code(Self.workstation)
        guard let start = workstation.range(of: "private var transportRow: some View {"),
              let end = workstation.range(of: "private var addTrackRow: some View {",
                                          range: start.upperBound..<workstation.endIndex) else {
            return XCTFail("ANCHOR MISSING: `transportRow` before `addTrackRow` (#454)")
        }
        let row = workstation[start.upperBound..<end.lowerBound]
        // The two REGRESSION needles run BEFORE the mount anchor, so on the parent tree they are red
        // for their own named reason (the bar's own Play), not hidden behind the absence below.
        XCTAssertFalse(row.contains("\"play.fill\""), """
            `transportRow` draws a play glyph of its own again — a second Play beside the one \
            button (A3b). The bar's Play IS `ProjectPlayStopButton`.
            """)
        XCTAssertFalse(row.contains("Button {"), """
            `transportRow` builds a `Button { … }` of its own again. Its Play/Stop is the head's \
            button, mounted here; everything else on the row is a leaf (Click, position, meter, Record).
            """)
        XCTAssertFalse(workstation.contains(".keyboardShortcut(.space"),
                       "the Workstation binds no space key — it comes WITH the one button")
        guard let group = row.range(of: "controls {"),
              let mount = row.range(of: Self.barMount, range: group.upperBound..<row.endIndex),
              row.range(of: "WorkstationClickToggle()", range: mount.upperBound..<row.endIndex) != nil else {
            return XCTFail("ANCHOR MISSING: the one Play/Stop is not mounted first inside `controls { … }`, before the Click switch (#454)")
        }
        let lead = row[group.upperBound..<mount.lowerBound]
        XCTAssertEqual(lead.filter { $0 == "{" }.count - lead.filter { $0 == "}" }.count, 0,
                       "the button is a direct, unconditional child of the bar's Play group")
    }

    // MARK: 6 — the space key lives on the one button, so it follows it to both stages

    func testTheSpaceKeyLivesOnTheOneButton() throws {
        let header = try code(Self.header)
        let button = try member(Self.buttonDecl, in: header)
        XCTAssertEqual(button.components(separatedBy: ".keyboardShortcut(.space, modifiers: [])").count - 1, 1,
                       "the bare-space shortcut sits inside `ProjectPlayStopButton` — wherever it is mounted, the key is")
        let head = try member("struct ProjectHeader: View {", in: header)
        XCTAssertFalse(head.contains(".keyboardShortcut(.space"),
                       "the head's own body binds no space key; it arrives with the mounted button")
    }

    // MARK: 7 — COUNTERWEIGHT: the moved button is the same button

    func testTheMovedButtonKeepsItsGateItsResumeAndItsColdBody() throws {
        let button = try member(Self.buttonDecl, in: try code(Self.header))
        XCTAssertTrue(button.contains("let available = running || play != .unavailable"))
        XCTAssertTrue(button.contains(".disabled(!available)"), "an unavailable Play swallows tap and key alike")
        XCTAssertTrue(button.contains("case .resumeInstrument: ProjectTransport.resumeInstrument(pattern:"),
                      "the resume of a held instrument moved WITH the button — the bar resumes too")
        XCTAssertTrue(button.contains("case .startSong, .startSongAndInstrument: startSong()"))
        XCTAssertTrue(button.contains("ProjectTransport.stop(song: player, pattern: beatPlayer.pattern, source: source)"),
                      "the ONE Stop, logging which mount was tapped")
        XCTAssertTrue(button.contains(".accessibilityLabel(ProjectTransport.buttonLabel(running: running, play: play))"))
        let body = try member("var body: some View {", in: button)
        for hot in ["beatPlayer", "pianoRoll", "currentTick", "tempo"] {
            XCTAssertFalse(body.contains(hot), """
                `ProjectPlayStopButton.body` reads `\(hot)` — it now also stands in the Workstation's \
                root; a hot read here rebuilds the bar and tears down open menus (10.76.41/50).
                """)
        }
        for modal in [".sheet(", ".fullScreenCover(", ".alert(", ".popover(", ".confirmationDialog("] {
            XCTAssertFalse(button.contains(modal), "no modal on the transport (the black-screen law): `\(modal)`")
        }
    }

    // MARK: - helpers

    private struct AnchorMissing: Error, CustomStringConvertible {
        let description: String
    }

    private func repoRoot() throws -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw AnchorMissing(description: "ANCHOR MISSING: no Sources/ under \(root.path) — re-anchor, do not skip (#454)")
        }
        return root
    }

    private func code(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw AnchorMissing(description: "ANCHOR MISSING: \(relativePath) could not be read — re-anchor, do not skip (#454)")
        }
        return SourceText.codeOnly(text)
    }

    private func swiftFiles() throws -> [String] {
        let root = try repoRoot()
        guard let walker = FileManager.default.enumerator(at: root.appendingPathComponent("Sources"),
                                                          includingPropertiesForKeys: nil) else {
            throw AnchorMissing(description: "ANCHOR MISSING: cannot enumerate Sources/")
        }
        var out: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            // Relative from the LAST `/Sources/`, so a resolved symlink in the checkout prefix
            // cannot shift the cut (the walker may hand back a canonicalised path).
            guard let cut = url.path.range(of: "/Sources/", options: .backwards) else { continue }
            out.append(String(url.path[url.path.index(after: cut.lowerBound)...]))
        }
        XCTAssertGreaterThan(out.count, 250, "the walk over Sources/ returned almost nothing — a scan that matches nothing is a finding, never a pass")
        return out.sorted()
    }

    /// The brace-matched body after `anchor` (#408), string-literal aware so a `"{"` in a literal
    /// cannot close it early. The text is already comment-stripped by `SourceText.codeOnly`.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            throw AnchorMissing(description: "ANCHOR MISSING: `\(anchor)` (#454)")
        }
        var depth = 1
        var index = start.upperBound
        var inString = false
        while index < code.endIndex {
            let ch = code[index]
            if inString, ch == "\\" {
                index = code.index(after: index)
                if index < code.endIndex { index = code.index(after: index) }
                continue
            }
            if ch == "\"" { inString.toggle() }
            if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(code[start.upperBound..<index]) }
                }
            }
            index = code.index(after: index)
        }
        throw AnchorMissing(description: "UNBALANCED: `\(anchor)` never closes (#454)")
    }
}
