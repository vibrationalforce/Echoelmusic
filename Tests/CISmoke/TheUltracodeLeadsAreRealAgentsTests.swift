// TheUltracodeLeadsAreRealAgentsTests.swift
// Echoel — a lead named in the ultracode skill must be an agent that exists.
//
// WHY. A 16-agent sweep (the TestFlight-ready pass) spawned `echoel-marketing`
// as an agent type. That name is a skill. The run died on it, and the skill's
// marketing row kept listing the skill as its lead, so the next "ultracode"
// would do it again. The same skill also said an hourly cron already ran the
// loop. No workflow has a `schedule:` key.
//
// CLAIMS
// 1. The roster between the markers equals the `name:` of every file in
//    `.claude/agents/`, plus the host builtin `general-purpose` and nothing else.
// 2. The marketing row does not name that skill as a lead agent.
// 3. The skill does not claim a cron, and no workflow is scheduled.
//
// Green on the parent would be a lie: the parent roster does not exist and the
// parent marketing cell is the skill name. Not compiled here.
//

import Foundation
import XCTest

final class TheUltracodeLeadsAreRealAgentsTests: XCTestCase {

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    private func text(_ relativePath: String) -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let t = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return t
    }

    /// `name:` from the frontmatter only. A later mention of another agent must
    /// not become a second identity.
    private func agentNames() -> Set<String> {
        let dir = repoRoot().appendingPathComponent(".claude/agents")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            XCTFail("ANCHOR MISSING: .claude/agents (#454)")
            return []
        }
        var found: Set<String> = []
        for name in names where name.hasSuffix(".md") {
            let raw = text(".claude/agents/\(name)")
            let head = raw.split(separator: "\n", omittingEmptySubsequences: false).prefix(8)
            guard let line = head.first(where: { $0.hasPrefix("name:") }) else {
                XCTFail("\(name) has no frontmatter name:")
                continue
            }
            let value = line.dropFirst("name:".count).trimmingCharacters(in: .whitespaces)
            found.insert(value)
        }
        return found
    }

    private func roster(_ skill: String) -> Set<String>? {
        guard let start = skill.range(of: "<!-- ultracode-roster: begin -->"),
              let end = skill.range(of: "<!-- ultracode-roster: end -->"),
              start.upperBound < end.lowerBound else { return nil }
        let body = skill[start.upperBound..<end.lowerBound]
        return Set(body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    func testTheRosterIsExactlyTheAgentsThatExist() {
        let skill = text(".claude/skills/ultracode-teams/SKILL.md")
        guard let listed = roster(skill) else {
            return XCTFail("ANCHOR MISSING: ultracode-roster markers (#454)")
        }
        let files = agentNames()
        XCTAssertGreaterThan(files.count, 8, "the agent directory was not walked")
        XCTAssertEqual(listed, files.union(["general-purpose"]), """
            The ultracode roster and `.claude/agents/` disagree.
            Only in the roster: \(listed.subtracting(files).subtracting(["general-purpose"])).
            Only on disk: \(files.subtracting(listed)).
            Spawn a lead from the roster, or add the file and the roster line in the same commit.
            `general-purpose` is the host builtin and is the only name allowed without a file.
            """)
        XCTAssertFalse(files.contains("general-purpose"),
                       "a file named general-purpose would make the builtin exception a lie")
        XCTAssertFalse(files.contains("echoel-marketing"),
                       "echoel-marketing is a skill; a file of that name would revive the bad spawn")
    }

    func testMarketingIsNotSpawnedAsAnAgent() {
        let skill = text(".claude/skills/ultracode-teams/SKILL.md")
        guard let row = skill.range(of: "| **MARKETING**") else {
            return XCTFail("ANCHOR MISSING: the MARKETING team row (#454)")
        }
        let line = skill[row.lowerBound...].prefix(while: { $0 != "\n" })
        let cells = line.split(separator: "|", omittingEmptySubsequences: false)
        XCTAssertGreaterThanOrEqual(cells.count, 3, "the MARKETING row is not a table row")
        XCTAssertFalse(cells[2].contains("echoel-marketing"), """
            The MARKETING lead cell names echoel-marketing. That is a skill. \
            The PM reads `.claude/skills/echoel-marketing/SKILL.md` and does not spawn it.
            """)
        XCTAssertFalse(skill.contains("agentType: echoel-marketing"),
                       "a spawn recipe still passes the skill name as an agent type")
    }

    func testTheLoopIsNotACron() {
        let skill = text(".claude/skills/ultracode-teams/SKILL.md")
        XCTAssertFalse(skill.contains("24h cron"), "the skill still claims a nightly cron runs the loop")
        XCTAssertFalse(skill.contains("hourly cron"), "the skill still claims an hourly cron runs the loop")
        XCTAssertTrue(skill.contains("No workflow is scheduled."),
                      "the skill must say the loop is not a scheduled workflow")
        let dir = repoRoot().appendingPathComponent(".github/workflows")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            return XCTFail("ANCHOR MISSING: .github/workflows (#454)")
        }
        let scheduled = names.filter { name in
            guard name.hasSuffix(".yml") || name.hasSuffix(".yaml") else { return false }
            return text(".github/workflows/\(name)").contains("schedule:")
        }
        XCTAssertTrue(scheduled.isEmpty, """
            \(scheduled) now has a schedule:. The skill says none does. Either delete the \
            schedule or rewrite the skill in the same commit — a session must not be told \
            both that a cron runs and that it does not.
            """)
    }
}
