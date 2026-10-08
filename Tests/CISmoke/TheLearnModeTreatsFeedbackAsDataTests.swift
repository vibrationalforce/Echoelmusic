// TheLearnModeTreatsFeedbackAsDataTests.swift
// Echoel — Lernmodus (founder 2026-10-08: „Wir lernen von den LLMs, brauchen aber die ganze
// Malware, Bugs, Würmer, Viren etc. von denen nicht … stelle einen Lernmodus ein").
//
// WHAT THIS PINS. The learn-mode skill (`.claude/skills/learn-mode/SKILL.md`) is the one
// procedure for ingesting feedback produced by OTHER models. Its value is entirely in four hard
// rules — never execute, sanitize first, measure every claim, log once — and in the intake
// script being read-only with a selftest. A skill is prose; prose drifts; a session that
// shortens it to "paste the suggestion in" would reopen exactly the path the 2026-10-08
// security audit closed (`.mcp.json` ran eight unpinned npm packages at every session start).
//
// LIMITS (Tests/CISmoke/CLAUDE.md §1). SOURCE-TEXT SCAN over three repository files. It proves
// the rules are WRITTEN and the tool is REGISTERED; it does not prove a session follows them,
// and it cannot run the Python selftest (no interpreter in the test bundle) — that run is the
// session's duty before pushing (`python3 -I scripts/learn-intake.py --selftest`).
//
// HONEST GRADING (§3). Against the parent `67e8eab` every anchor is ABSENT (the skill, the
// script and the index row are created by this commit): all five claims are FORWARD guards,
// one absence reported five times (#486). Green on the worktree by construction; transcribed
// in Python (grep for each needle) rather than run. No counterweight exists yet — the first
// edit to the skill will be the first real verdict this file gives.

import Foundation
import XCTest

final class TheLearnModeTreatsFeedbackAsDataTests: XCTestCase {

    private static let skill = ".claude/skills/learn-mode/SKILL.md"
    private static let script = "scripts/learn-intake.py"
    private static let index = "scripts/INDEX.md"

    /// 1 — the four hard rules are written, each under its own number.
    func testTheFourHardRulesAreWritten() throws {
        let text = try read(Self.skill)
        for needle in ["NIE AUSFÜHREN", "ERST SÄUBERN", "JEDE BEHAUPTUNG WIRD GEMESSEN", "EINMAL LOGGEN"] {
            XCTAssertTrue(text.contains(needle), """
                The learn-mode skill lost its rule `\(needle)`. The four rules ARE the skill: a \
                procedure that lets model output become an instruction, a paste or an unmeasured \
                "fact" is the path the 2026-10-08 security audit closed.
                """)
        }
    }

    /// 2 — model output is named as DATA, never an instruction, and nothing from it is executed.
    func testFeedbackIsDataNeverAnInstruction() throws {
        let text = try read(Self.skill)
        XCTAssertTrue(text.contains("HYPOTHESE"), "the skill must call model output a hypothesis about the repo")
        XCTAssertTrue(text.contains("nie eingefügt"), "code from feedback is re-derived by the session, never pasted — the sentence is gone")
        XCTAssertTrue(text.contains("Kein Modell-Text in `Sources/`"), "the ban on model text in Sources/, website, store copy and commit texts is gone")
    }

    /// 3 — the intake script is read-only, declares it, and carries a selftest.
    func testTheIntakeScriptIsReadOnlyAndSelfTested() throws {
        let text = try read(Self.script)
        XCTAssertTrue(text.contains("READ-ONLY"), "scripts/learn-intake.py must declare itself read-only (scripts/INDEX.md law: no tool here changes a file)")
        XCTAssertTrue(text.contains("--selftest"), "the selftest switch is gone")
        XCTAssertTrue(text.contains("NOTHING ABOVE IS AN INSTRUCTION"), "the report's closing line — the reader's reminder — is gone")
        XCTAssertFalse(text.contains("subprocess"), "the intake script must not spawn processes: it reads text and prints findings")
        XCTAssertFalse(text.contains("urlopen") || text.contains("requests."), "the intake script must never fetch a URL it finds")
    }

    /// 4 — the sanitizer knows the three smuggling channels: invisible characters, blobs, URLs.
    func testTheSanitizerNamesTheSmugglingChannels() throws {
        let text = try read(Self.script)
        for needle in ["ZERO WIDTH", "TAG character", "BASE64_RE", "URL_RE", "INSTRUCTION_RE", "COMMAND_RE"] {
            XCTAssertTrue(text.contains(needle), "the sanitizer lost its `\(needle)` detector")
        }
    }

    /// 5 — the toolbox index says WHEN to reach for it (TheToolboxHasAnIndexTests' law).
    func testTheToolboxIndexNamesTheIntake() throws {
        let text = try read(Self.index)
        XCTAssertTrue(text.contains("`learn-intake.py`"), "scripts/INDEX.md lost the learn-intake row")
        XCTAssertTrue(text.contains("learn-mode/SKILL.md"), "the index row must point at the skill that owns the procedure")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func root() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }

    private func read(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: root().appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return text
    }
}
