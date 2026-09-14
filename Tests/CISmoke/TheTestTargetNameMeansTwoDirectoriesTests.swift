// TheTestTargetNameMeansTwoDirectoriesTests.swift
// Echoel — #1316. Blocking bundle. FILE-CONTENT scan over `Package.swift`, `project.yml` and
// `.github/workflows/ci.yml` (`Tests/CISmoke/CLAUDE.md` §1). It proves what those three files
// SAY about which directory a target builds; it cannot run either build system.
//
// ⭐ WHY THIS FILE EXISTS. The name `EchoelmusicTests` means TWO DIFFERENT DIRECTORIES depending
// on which build system is asking, and nothing in the tree said so in one place:
//   · `project.yml` → target `EchoelmusicTests`, `sources: - path: Tests/CISmoke` — the BLOCKING
//     bundle, the one every CI gate builds and the one a guard must land in to gate a push.
//   · `Package.swift` → `.testTarget(name: "EchoelmusicTests")` with NO `path:`, so SwiftPM
//     resolves it to its default `Tests/EchoelmusicTests` — the non-blocking suite.
// So "EchoelmusicTests is green" is an ambiguous sentence, and the two suites differ by hundreds
// of files. This is the repo's own documented defect shape — one name, two answers — applied to
// the thing that decides whether a red test can block anything.
//
// ⭐ AND THE CONSEQUENCE RUNS IN BOTH DIRECTIONS, which is why claim 3 exists. No CI gate runs
// SwiftPM at all — every step in `ci.yml` is `xcodebuild` — so `Tests/EchoelmusicTests` is
// compiled by NO gate. But it IS compiled by `swift test`, which is step 5 of the Ralph loop on
// the founder's Mac. A break there is invisible to CI and visible to exactly one person. Reading
// only half of that produces either "those 300 files don't matter" or "SwiftPM covers us".
//
// ⚠️ IT FORBIDS NEITHER ARRANGEMENT (#364). Give the SwiftPM target an explicit
// `path: "Tests/EchoelmusicTests"` and claim 2 still passes — it asks where the target RESOLVES,
// not that the key is absent. Rename either target, or point one at the other's directory, and
// the matching claim goes red with a message naming the comment in `Package.swift` that must be
// pulled through in the same commit. Renaming is NOT free: `.github/workflows/**` names these
// targets and is founder-gated — report, do not edit.
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **Seven assertions across three claims**
// (claim 1 = 2, claim 2 = 3, claim 3 = 2), each transcribed in Python and driven against both
// trees. On the PARENT tree (`37b31df`) ONE assertion is red — the `Package.swift` comment did
// not exist — which is ONE finding (#486), the gap this slice closes. The other six are green on
// both and are COUNTERWEIGHTS (#343): they pin that the two directories really are different and
// that no gate runs SwiftPM, so the comment cannot quietly become false.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTestTargetNameMeansTwoDirectoriesTests: XCTestCase {

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Package.swift").path) else {
            throw XCTSkip("Package.swift not present under \(root.path)")
        }
        return root
    }

    private func text(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        guard let body = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read — a missing anchor is a "
                    + "finding, not a pass (#454).")
            return ""
        }
        return body
    }

    /// claim 1 — the Xcode side: the target named `EchoelmusicTests` builds `Tests/CISmoke`.
    /// This is the half that gates a push, so it is asserted rather than assumed.
    func testTheXcodeTargetOfThatNameBuildsCISmoke() throws {
        let yml = try text("project.yml")
        guard let range = yml.range(of: "  EchoelmusicTests:\n") else {
            XCTFail("project.yml no longer declares a target named EchoelmusicTests. If the "
                    + "blocking bundle was renamed, pull the comment in Package.swift through in "
                    + "the same commit — it names this target by name.")
            return
        }
        let rest = String(yml[range.upperBound...])
        let block = String(rest.prefix(700))
        XCTAssertTrue(
            block.contains("path: Tests/CISmoke"),
            "project.yml's EchoelmusicTests target no longer lists Tests/CISmoke as its sources. "
            + "The blocking bundle moved; Package.swift's comment and Tests/CISmoke/CLAUDE.md "
            + "both describe the old arrangement and must move with it.")
        XCTAssertFalse(
            block.contains("path: Tests/EchoelmusicTests"),
            "project.yml's EchoelmusicTests target now points at Tests/EchoelmusicTests. If the "
            + "two suites were merged, the whole one-name-two-directories note in Package.swift "
            + "is obsolete and must be removed in this commit rather than left to mislead.")
    }

    /// claim 2 — the SwiftPM side: the same name resolves to `Tests/EchoelmusicTests`, whether by
    /// SwiftPM's default (no `path:`) or by an explicit one. Both arrangements are correct.
    func testTheSwiftPMTargetOfThatNameResolvesToTheOtherDirectory() throws {
        let manifest = try text("Package.swift")
        guard let range = manifest.range(of: ".testTarget(") else {
            XCTFail("Package.swift declares no test target at all — claim 3's premise and the "
                    + "comment above the target both assume one exists.")
            return
        }
        let block = String(manifest[range.upperBound...].prefix(420))
        XCTAssertTrue(
            block.contains("name: \"EchoelmusicTests\""),
            "Package.swift's test target is no longer named EchoelmusicTests. The collision this "
            + "file documents may be gone — which is good — but the comment above the target and "
            + "Tests/CISmoke/CLAUDE.md still describe it and must be pulled through here.")
        if let pathKey = block.range(of: "path:") {
            let tail = String(block[pathKey.upperBound...].prefix(60))
            XCTAssertTrue(
                tail.contains("Tests/EchoelmusicTests"),
                "Package.swift's test target now carries an explicit `path:` that is not "
                + "Tests/EchoelmusicTests. That changes which files `swift test` compiles on the "
                + "founder's Mac — say so in the comment above the target in this commit.")
        }
        XCTAssertTrue(
            manifest.contains("ONE NAME, TWO DIRECTORIES"),
            "Package.swift no longer carries the note that its `EchoelmusicTests` is a DIFFERENT "
            + "directory from the Xcode target of the same name. Without it, the next reader of "
            + "this manifest reasonably concludes that SwiftPM builds the blocking bundle. "
            + "Restore the note rather than deleting it (#1316).")
    }

    /// claim 3 — counterweight, and the fact that makes the collision matter: no CI gate runs
    /// SwiftPM, so the SwiftPM-resolved suite is compiled by nothing here.
    func testNoCIGateRunsSwiftPM() throws {
        let ci = try text(".github/workflows/ci.yml")
        XCTAssertFalse(ci.isEmpty, "read ci.yml and got nothing — that is a finding, not a pass.")
        for needle in ["swift build", "swift test"] {
            XCTAssertFalse(
                ci.contains(needle),
                "ci.yml now runs `\(needle)`, so Tests/EchoelmusicTests IS gated after all. That "
                + "is an improvement and it makes the comment in Package.swift — which says no "
                + "gate compiles it — false. Update the comment in the same commit (#364: this "
                + "assertion exists to force the pull-through, not to keep SwiftPM out of CI).")
        }
    }
}
