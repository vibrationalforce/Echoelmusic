// TheWireContractMatchesTheLawTests.swift
// Echoel — #1157. Blocking bundle. SOURCE-TEXT SCAN (`Tests/CISmoke/CLAUDE.md` §1): it proves
// which address strings EXIST in code and in the law file, never that a packet leaves the phone.
//
// ⭐ WHY THIS FILE EXISTS, AND THE DEFECT IS RECORDED, NOT IMAGINED. `CLAUDE.md`'s OSC section
// says so about itself: "corrected 2026-07-04; the old list named eeg/{band}, audio/rms,
// audio/pitch which are NEVER sent". Three phantom addresses stood in the integration contract
// for months. That contract is read by PEOPLE OUTSIDE this repo — a lighting desk, a spatial
// renderer, someone's Max patch — and a phantom entry there costs them a debugging session
// against a socket that will never speak. Nothing re-derives the list; a rename in
// `OSCSender` breaks it with no compiler error and no failing test.
//
// ⚠️ IT GUARDS THE DIRECTION THAT ACTUALLY FAILED, and the other one more weakly, on purpose.
// · claim 1 (doc -> code) is EXACT: every address token written in the OSC section must exist
//   in `Sources/`. That is the 2026-07-04 defect, and an exact check is possible because the
//   law file spells those tokens out.
// · claim 2 (code -> doc) is at FAMILY level, because the law file writes the four event leaves
//   in a compact alternation (`heartbeat | breath/inhale | …`) rather than as four full paths.
//   Demanding each full path would fail on a notation the law file chose deliberately. The
//   family check still catches the expensive case: a WHOLE new address space appearing on the
//   wire with nothing about it in the contract.
//
// ⚠️ AND IT CHECKS THAT IT CAN FIRE AT ALL (claim 3). Both scans are regex over text; if the
// heading moves, or the code-stripper changes, an empty token set would make claims 1 and 2
// pass vacuously. An empty scan is a finding, never a pass (`.claude/rules/context.md` §2).
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It forbids no new address. Adding one is a normal
// slice — it fails only if the code and the contract disagree, and the message says which side
// to move.
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **7 `XCTAssert*` across 4 claims** plus 1
// `XCTFail` anchor. ⛔ BOTH HALVES OF THAT SENTENCE WERE WRONG IN THE FIRST DRAFT, and the two
// errors are different. (a) I wrote EIGHT from memory; the tool says seven (1+1+2+3). (b) The
// recipe was bare, so it counted this paragraph as well. Anchored, it is honest:
// `grep -c '^ *XCTAssert'` = 7, `grep -c '^ *XCTFail'` = 1, `grep -c '^    func test'` = 4.
// A bare `grep -c XCTAssert` gives more, because prose about a token matches the token — the
// #1156 trap one file over. A count recipe can catch itself, and a count from the head is not
// a count at all. Every claim was transcribed in Python against today's tree BEFORE the Swift was
// written: 15 documented tokens, 0 missing from code; 8 code families, 0 undocumented; one
// `/adm/obj/` formatter with exactly one caller. FIVE mutants driven, not read: an address
// deleted from code (claim 1 red), an address renamed to a SUPERSTRING of itself (claim 1 was
// GREEN on the first draft — see the ⛔ at that claim), a bogus family added to code (claim 2
// red), the heading renamed so the extraction yields nothing (claim 3 red), a second formatter
// caller (claim 4 red). Green on today's tree and on the tree before
// this slice, i.e. **0 regression catches, 7 COUNTERWEIGHTS (#343)** — they buy the day someone
// renames an address, not today.

import Foundation
import XCTest

final class TheWireContractMatchesTheLawTests: XCTestCase {

    private static let heading = "## OSC (EchoelSync)"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    /// Comment-stripped text of every `.swift` file under `Sources/`, one string. Prose that
    /// QUOTES an address must not count as code that sends it (#762).
    private func sourcesCode() throws -> String {
        let dir = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: dir.path) else {
            XCTFail("Sources/ is present but not enumerable — re-anchor rather than skip (#454).")
            return ""
        }
        var out = ""
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            let text = try String(contentsOf: dir.appendingPathComponent(rel), encoding: .utf8)
            out += SourceText.codeOnly(text) + "\n"
        }
        return out
    }

    /// The OSC section of `CLAUDE.md`, from its heading to the next top-level heading.
    private func lawSection() throws -> String {
        let law = try String(contentsOf: try repoRoot().appendingPathComponent("CLAUDE.md"),
                             encoding: .utf8)
        guard let start = law.range(of: Self.heading) else { return "" }
        let rest = law[start.upperBound...]
        if let end = rest.range(of: "\n## ") { return String(rest[..<end.lowerBound]) }
        return String(rest)
    }

    /// Address-shaped tokens in a text: `/echoelmusic/…` or `/adm/…`.
    private func addressTokens(in text: String) -> [String] {
        let pattern = "/(?:echoelmusic|adm)[A-Za-z0-9_/{}<>|+-]*"
        guard let rx = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return rx.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
    }

    /// claim 1 — every address the CONTRACT names exists in the code. This is the 2026-07-04
    /// defect: three addresses documented that nothing ever sent.
    func testEveryDocumentedAddressExistsInTheCode() throws {
        let code = try sourcesCode()
        let documented = Set(addressTokens(in: try lawSection()))
        var missing: [String] = []
        for token in documented.sorted() {
            // `<key>` and `{n}` are placeholders the code fills by interpolation; compare the
            // literal prefix that precedes them.
            let needle = token.components(separatedBy: CharacterSet(charactersIn: "<{"))[0]
            // ⛔ A BARE `contains` IS NOT ENOUGH, and the mutant proved it: renaming
            // `…/heart/sdnn` to `…/heart/sdnn2` in the code left this claim GREEN, because the
            // old address is a PREFIX of the new one. An address must end where the code ends
            // it — at the closing quote, at a `/`, or at the start of an interpolation.
            let ends = ["\"", "/", "\\("]
            if !ends.contains(where: { code.contains(needle + $0) }) {
                missing.append("\(token) (looked for \(needle) followed by \" / or \\()")
            }
        }
        XCTAssertTrue(missing.isEmpty, """
            CLAUDE.md's OSC section documents \(missing.count) address(es) that no code in \
            Sources/ can send: \(missing.joined(separator: ", ")). This is the 2026-07-04 defect \
            repeating — an integrator wiring to one of these listens to a socket that never \
            speaks. Either restore the sender or strike the line, in this commit.
            """)
    }

    /// claim 2 — and no WHOLE address space is on the wire that the contract says nothing about.
    /// Family level on purpose: the law file writes the four event leaves in one compact
    /// alternation, so demanding each full path would fail on its own chosen notation.
    func testNoUndocumentedAddressFamilyIsSent() throws {
        let law = try lawSection()
        var undocumented: [String] = []
        for token in Set(addressTokens(in: try sourcesCode())).sorted() {
            let parts = token.components(separatedBy: "/")           // ["", "echoelmusic", …]
            let depth = token.hasPrefix("/adm") ? 3 : 4
            guard parts.count >= depth else { continue }
            let family = parts.prefix(depth).joined(separator: "/")
            // An interpolation can start inside the family segment (`/echoelmusic/mod/\(key)`);
            // compare the literal part before it.
            let literal = family.components(separatedBy: "\\")[0]
            if !law.contains(literal) { undocumented.append(literal) }
        }
        XCTAssertTrue(undocumented.isEmpty, """
            Code sends address families the OSC contract does not name: \
            \(Set(undocumented).sorted().joined(separator: ", ")). Adding an address is a normal \
            slice (#364) — this asks only that the contract move in the same commit, because it \
            is read by people outside this repo.
            """)
    }

    /// claim 3 — both scans actually found something. An empty token set would make claims 1
    /// and 2 pass while measuring nothing.
    func testBothScansCanFire() throws {
        let documented = addressTokens(in: try lawSection())
        XCTAssertGreaterThan(documented.count, 5, """
            The OSC section of CLAUDE.md yielded \(documented.count) address tokens. It carries \
            more than that; the heading anchor "\(Self.heading)" or the section boundary has \
            moved, and claim 1 is now vacuous rather than green.
            """)
        let emitted = addressTokens(in: try sourcesCode())
        XCTAssertGreaterThan(emitted.count, 5, """
            Sources/ yielded \(emitted.count) address tokens. OSCSender alone writes more than \
            that; the code walk or the comment stripper is broken, and claim 2 is vacuous.
            """)
    }

    /// claim 4 — exactly one place formats the immersive object address, and exactly one place
    /// calls it. The contract names ONE sender; two producers on the same object indices would
    /// fight over object numbers on a real rig.
    func testTheImmersiveObjectAddressHasOneFormatterAndOneCaller() throws {
        let root = try repoRoot()
        let formatter = SourceText.codeOnly(try String(
            contentsOf: root.appendingPathComponent("Sources/Echoelmusic/Sync/SpatialSceneOSC.swift"),
            encoding: .utf8))
        XCTAssertTrue(formatter.contains("/adm/obj/"), """
            SpatialSceneOSC no longer formats the immersive object address. If the formatting \
            moved, claim 4's "one formatter" reasoning must move with it.
            """)
        var callers: [String] = []
        let dir = root.appendingPathComponent("Sources")
        let walker = FileManager.default.enumerator(atPath: dir.path)
        while let rel = walker?.nextObject() as? String {
            guard rel.hasSuffix(".swift"), !rel.hasSuffix("SpatialSceneOSC.swift") else { continue }
            let text = SourceText.codeOnly(
                try String(contentsOf: dir.appendingPathComponent(rel), encoding: .utf8))
            if text.contains("SpatialSceneOSCFormatter") { callers.append(rel) }
        }
        XCTAssertEqual(callers.count, 1, """
            The immersive object formatter now has \(callers.count) callers \
            (\(callers.joined(separator: ", "))). CLAUDE.md names ADMOSCSender as THE sender of \
            that address space; a second producer must be documented, or the object indices of \
            two senders will collide on a real rig.
            """)
        XCTAssertTrue(callers.first?.hasSuffix("ADMOSCSender.swift") ?? false, """
            The one caller is no longer ADMOSCSender (\(callers.first ?? "none")). The contract \
            names that type; move the contract line in this commit.
            """)
    }
}
