import XCTest

/// ⭐ #1389 — **THE PUBLIC HALF OF THE CLAIMS REGISTER, AND THE ONE THING THAT KEEPS IT HONEST.**
///
/// `ContentPipeline/CLAIMS.md` is the internal list of what Echoelmusic may and may not claim.
/// It exists because #158 and #192 each spent a whole cycle removing ONE false claim (AUv3)
/// from the website, and #184 removed twelve from the App Store text, where a false claim is a
/// 2.3 rejection. `docs/claims.html` publishes the ⛔ half of that register.
///
/// A public page derived from a private file drifts the moment the private file grows — and
/// the drift is invisible, because the page still renders perfectly with an entry missing.
/// This guard makes the register the source: **every `### N.` section under the ⛔ heading must
/// have a matching `id="claim-N"` on the page.** Add a denial to the register and this goes red
/// with its number; there is no path where the internal list grows and the public one silently
/// does not.
///
/// ⚠️ **WHAT THIS DELIBERATELY DOES NOT CHECK: the WORDING.** The register is German and
/// internal, the page is English and public, and machine-translating one into the other would
/// produce worse copy than a human writing it. So the guard pins COVERAGE, not text. A page
/// entry that says the opposite of its register section would pass here — that is a real limit,
/// stated rather than hidden, and the honest mitigation is that the register section number is
/// printed on the page anchor, so the two are one grep apart.
///
/// ⚠️ **The section numbering is not contiguous and that is not a defect.** `6b` sits BEFORE `6`
/// in the file (it was inserted by #774 next to the claim it corrects), and the ids follow the
/// register rather than a tidy sequence. A guard that assumed `1...N` would have been wrong on
/// the tree it was written against — so it reads the headings that are actually there.
final class TheClaimsPageCoversEveryDenialTests: XCTestCase {

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("ContentPipeline/CLAIMS.md").path) else {
            throw XCTSkip("""
                `ContentPipeline/CLAIMS.md` is not present under \(root.path) — this guard \
                compares two text files, so it SKIPS rather than reporting a green it did \
                not earn (#454).
                """)
        }
        return root
    }

    /// The section numbers under the ⛔ heading, in file order. Read once and reused, because a
    /// disagreement between the two claims below about WHICH sections exist would be the most
    /// confusing possible failure.
    private func deniedSectionNumbers() throws -> [String] {
        let md = try String(contentsOf: try repoRoot()
            .appendingPathComponent("ContentPipeline/CLAIMS.md"), encoding: .utf8)
        guard let banned = md.range(of: "## ⛔ DARF NICHT behauptet werden") else {
            XCTFail("""
                `ContentPipeline/CLAIMS.md` no longer carries its `## ⛔ DARF NICHT behauptet \
                werden` heading, so this guard checked nothing (#454: a missing ANCHOR fails, \
                it does not skip). If the register was restructured, re-anchor this in the \
                SAME commit — do not delete the check.
                """)
            return []
        }
        // The ⛔ block ends at the next `## ` heading; everything after it is commentary.
        let after = md[banned.upperBound...]
        let block = after.range(of: "\n## ").map { String(after[..<$0.lowerBound]) }
            ?? String(after)

        var numbers: [String] = []
        for line in block.split(separator: "\n", omittingEmptySubsequences: false)
        where line.hasPrefix("### ") {
            // `### 6b. „spielt die Stimmen"` → "6b"
            let rest = line.dropFirst(4)
            let token = rest.prefix { $0 != "." }
            guard let first = token.first, first.isNumber else { continue }
            numbers.append(String(token))
        }
        return numbers
    }

    /// Claim 1 — the register HAS denials to publish. A scan that matches nothing is a finding,
    /// never a pass (`.claude/rules/context.md` §2), and without this the claim below would go
    /// green on an empty list the day the parser stops matching the heading format.
    func testTheRegisterStillListsDenials() throws {
        let numbers = try deniedSectionNumbers()
        XCTAssertGreaterThanOrEqual(numbers.count, 10, """
            Only \(numbers.count) denial section(s) parsed out of the ⛔ half of \
            `ContentPipeline/CLAIMS.md` (found: \(numbers.joined(separator: ", "))). The \
            register carried thirteen when this guard was written. Either the register was \
            gutted — in which case `docs/claims.html` has to shrink with it in the same \
            commit — or the `### <n>. ` heading format changed and this parser no longer \
            matches it, which would make the coverage claim below pass vacuously.
            """)
    }

    /// Claim 2 — every denial in the register is on the public page.
    func testEveryDeniedClaimIsPublished() throws {
        let numbers = try deniedSectionNumbers()
        guard !numbers.isEmpty else { return }   // claim 1 already failed and said why

        let html = try String(contentsOf: try repoRoot()
            .appendingPathComponent("docs/claims.html"), encoding: .utf8)
        let missing = numbers.filter { !html.contains("id=\"claim-\($0)\"") }

        XCTAssertTrue(missing.isEmpty, """
            \(missing.count) denial(s) from `ContentPipeline/CLAIMS.md` have no entry on \
            `docs/claims.html`: section(s) \(missing.joined(separator: ", ")). The public page \
            is the ⛔ half of the register made visible; a register that grows while the page \
            does not is exactly the drift this file exists to prevent. Add a \
            `<div class="platform-card" id="claim-<n>">` for each, in English, saying what is \
            NOT claimed and why — the register's own reasoning, not a translation of it.
            """)
    }

    /// Claim 3 — and nothing on the page invents a denial the register does not carry.
    ///
    /// ⚠️ This direction matters as much as the other and is easier to miss: a page entry with
    /// no register section behind it is a public commitment nobody reviewed, and it would
    /// survive every other check here.
    func testThePageInventsNoDenial() throws {
        let numbers = Set(try deniedSectionNumbers())
        guard !numbers.isEmpty else { return }

        let html = try String(contentsOf: try repoRoot()
            .appendingPathComponent("docs/claims.html"), encoding: .utf8)
        var published: [String] = []
        var search = html.startIndex..<html.endIndex
        while let hit = html.range(of: "id=\"claim-", range: search) {
            let rest = html[hit.upperBound...]
            published.append(String(rest.prefix { $0 != "\"" }))
            search = hit.upperBound..<html.endIndex
        }
        let orphans = published.filter { !numbers.contains($0) }
        XCTAssertTrue(orphans.isEmpty, """
            `docs/claims.html` publishes \(orphans.count) denial(s) with no matching section in \
            `ContentPipeline/CLAIMS.md`: \(orphans.joined(separator: ", ")). Either the register \
            lost a section the page still shows — restore it — or the page grew a commitment on \
            its own. The register is the source; the page is its publication.
            """)
    }
}
