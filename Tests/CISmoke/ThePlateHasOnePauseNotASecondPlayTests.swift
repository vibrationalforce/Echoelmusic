// ThePlateHasOnePauseNotASecondPlayTests.swift
// Echoel — interface audit 2026-09-30, Gestaltung rule 2 ("Ein Transport"). BLOCKING bundle.
// Mixed: claims 1–2 and 4 are SOURCE-TEXT SCANS, claim 3 is END-TO-END on `ProjectTransport`
// (a shipped, Foundation-only value type).
//
// THE MEASUREMENT. The head (`ProjectHeader`) carries exactly ONE Play/Stop button, with a word
// ("Play"/"Stop", `ProjectTransport.buttonWord`) — rule 2's check holds there. Under it, on the
// instrument plate, `PlaybackToggleButton` toggled the music transport while the instrument ran:
// PLAYING → a pause glyph (music off, pulse reading kept — a job the head's Stop does not do,
// #179), PAUSED → a play glyph that called `pattern.play(cause: .transportButton)` — the very
// call the head's "Play" makes in that state (`ProjectTransport.playAction` → `.resumeInstrument`).
// Two Play buttons, one action, one screen: the founder's "zu viele Play Knöpfe" (2026-07-15),
// "3 Knöpfe zum Start" (07-29), "Einfaches start stop" (07-31), a fourth time.
//
// THE DECISION. The plate keeps the ONE job the head cannot do — Pause the music, keep the body
// — and says so with a word ("Pause", rule 3). It shows only while the music plays; the resume
// is the head's "Play" (hint: "Brings the music back. Your pulse reading keeps running."). So
// at any moment exactly one button on screen starts playback.
//
// WHAT THIS GUARDS.
//   1. `PlaybackToggleButton` renders `Text("Pause")` with `"pause.fill"`, draws no `"play.fill"`
//      and calls no `pattern.play(` — it does not resume.
//   2. It is gated on BOTH `bus.instrumentRunning` and `transport.isPlaying`.
//   3. END-TO-END counterweight: the head resolves the paused-instrument state to a Play that
//      resumes — `playAction` gives `.resumeInstrument`, the word is "Play", and while running
//      the word is "Stop".
//   4. Exactly ONE production caller of `pattern.play(cause: .transportButton)` remains in
//      `Sources/` — `ProjectTransport.resumeInstrument` — and `ProjectHeader` routes
//      `.resumeInstrument` to it. One resume producer, not two.
//
// GRADING against the parent: claims 1, 2 and 4 RED for their named reason (the parent's
// toggle draws `play.fill`, calls `pattern.play(`, is gated on `instrumentRunning` alone, and is
// the second caller); claim 3 green on both trees (the head already had the resume).
// LIMIT: the device look — a Pause that leaves when the music stops, with the head's Play one
// band up — is a founder look. NEEDS-FOUNDER-VERIFY.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePlateHasOnePauseNotASecondPlayTests: XCTestCase {

    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let header = "Sources/Echoelmusic/Studio/ProjectHeader.swift"
    private static let transport = "Sources/Echoelmusic/Studio/ProjectTransport.swift"

    // MARK: 1 — the plate control is a Pause with a word, and it does not resume

    func testThePlateControlIsAPauseWithAWordAndDoesNotResume() throws {
        let body = try toggleDeclaration()
        XCTAssertTrue(body.contains("Text(\"Pause\")"), "PlaybackToggleButton no longer shows the word \"Pause\" (rule 3: symbol plus word)")
        XCTAssertTrue(body.contains("\"pause.fill\""), "PlaybackToggleButton no longer draws `pause.fill` — `OneStartControlTests` explains why the glyph is the pause, never a stop")
        XCTAssertFalse(body.contains("\"play.fill\""), """
            PlaybackToggleButton draws `play.fill` again. In the paused state that is a SECOND \
            Play beside the head's "Play" (rule 2 — one transport). The head resumes; this \
            control only pauses.
            """)
        XCTAssertFalse(body.contains("pattern.play("), "PlaybackToggleButton calls `pattern.play(` — the resume belongs to the head (`ProjectTransport.resumeInstrument`), not here")
        XCTAssertTrue(body.contains("requestPlaybackOnlyStop()"), "PlaybackToggleButton no longer raises the playback-only stop — without it the pause ends the whole session (#179)")
    }

    // MARK: 2 — visible only while the music plays

    func testThePauseShowsOnlyWhileTheMusicPlays() throws {
        let body = try toggleDeclaration()
        let gate = body.components(separatedBy: "\n").first {
            $0.contains("if ") && $0.contains("bus.instrumentRunning")
        }
        let line = try XCTUnwrap(gate, "PlaybackToggleButton has no `if … bus.instrumentRunning` gate any more")
        XCTAssertTrue(line.contains("transport.isPlaying"), """
            The pause is gated on `instrumentRunning` alone: `\(line.trimmingCharacters(in: .whitespaces))`. \
            While the music is paused it would show a control beside the head's "Play" — gate it \
            on `transport.isPlaying` too, so it leaves when there is nothing to pause.
            """)
    }

    // MARK: 3 — the head resumes (end-to-end on the pure type)

    func testTheHeadResumesThePausedInstrument() {
        let paused = ProjectTransport.Facts(clockRunning: false, songPlaying: false, recording: false,
                                            sessionRunning: true, songStartable: false)
        XCTAssertEqual(ProjectTransport.playAction(paused), .resumeInstrument,
                       "a running instrument with a stopped clock must resolve to the head's resume — otherwise removing the plate's Play leaves no resume at all")
        XCTAssertEqual(ProjectTransport.status(paused), .paused)
        XCTAssertEqual(ProjectTransport.buttonWord(running: false), "Play")
        XCTAssertEqual(ProjectTransport.buttonWord(running: true), "Stop")
        XCTAssertTrue(ProjectTransport.buttonHint(running: false, play: .resumeInstrument).contains("pulse reading keeps running"),
                      "the head's resume hint must say the pulse reading survives — that is the promise the plate's Pause makes")
    }

    // MARK: 4 — one resume producer

    func testExactlyOneProductionCallerResumesTheTransport() throws {
        let root = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Sources/ not enumerable")
        }
        var callers: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            let n = code.components(separatedBy: "play(cause: .transportButton)").count - 1
            if n > 0 { callers.append("\(url.lastPathComponent) ×\(n)") }
        }
        XCTAssertEqual(callers, ["ProjectTransport.swift ×1"], """
            `play(cause: .transportButton)` has these production callers: \(callers). Rule 2 — one \
            transport: the ONE resume is `ProjectTransport.resumeInstrument`, reached from the \
            head's Play. A second caller is a second Play.
            """)
        let header = try codeOnly(Self.header)
        XCTAssertTrue(header.contains("case .resumeInstrument: ProjectTransport.resumeInstrument(pattern:"),
                      "ProjectHeader no longer routes `.resumeInstrument` to `ProjectTransport.resumeInstrument` — the head lost the resume")
    }

    // MARK: - helpers

    /// `PlaybackToggleButton`'s declaration, comment-stripped, from its opening line to the next
    /// top-level type or MARK (the same walk `ControlBoundaryIsInteractiveTests` uses).
    private func toggleDeclaration() throws -> String {
        let lines = try codeOnly(Self.workspace).components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.contains("struct PlaybackToggleButton: View {") }) else {
            throw XCTSkip("`struct PlaybackToggleButton: View {` not found in WorkspaceView.swift — re-point this guard at its new home; do not let it pass on nothing")
        }
        var end = lines.count
        for i in (start + 1)..<lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if ["struct ", "private struct ", "final class ", "extension ", "enum "].contains(where: { t.hasPrefix($0) }) { end = i; break }
        }
        return lines[start..<end].joined(separator: "\n")
    }

    private func repoRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) else {
            throw XCTSkip("repository root not found from \(#filePath) — source scan skipped, not passed")
        }
        return url
    }

    private func codeOnly(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(relativePath) is absent — the file moved; update the path, do not let the scan pass on nothing")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
