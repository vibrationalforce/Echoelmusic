// TheCellularSeedSharesNoBufferTests.swift
// Echoel — 2026-09-24 (overnight P8): `EchoelCellular` never lets two of its cell arrays share
// one buffer, so the render thread never pays a copy-on-write. Blocking bundle.
//
// THE DEFECT (measured before the repair). #1385 removed `cellsPrev = cells` from `evolve1D()`
// because it made the next in-place `cells[i] = …` copy on the AUDIO thread. The same line
// survived in `seed()`, described as a harmless "control-thread write". It is not harmless: a
// whole-array assignment gives the buffer a second owner WHERE it is written, and the copy is
// paid where the buffer is next MUTATED — the first `evolve1D()` after the seed, on the render
// thread. `EchoelCellular.init` seeds (`seed(.singleCenter)`), and the AUv3 constructs its
// texture in a stored-property initialiser, so every AUv3 instance paid one malloc + memcpy +
// free at its first evolution (~1/8 s into playback at the AU's 8 evolutions/s). One per seed,
// not one per evolution — rarer than the #1385 case, the same priority-inversion risk.
//
// THE REPAIR. `seed()` copies element-wise into `cellsPrev`'s own buffer. `cellsPrev` still has
// no reader, so the rendered output is bit-identical; only the allocation is gone.
//
// WHAT KIND OF GREEN (§1): all three claims are SOURCE-TEXT SCANS (comment-stripped). Buffer
// uniqueness of a private array is not observable from a test, and an allocation on the render
// thread is reproduced by no unit test — which is why the scan pins the ASSIGNMENT FORM, the
// thing that decides it. DEVICE/HOST: nothing to hear; the change is sound-neutral.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not forbid a real double buffer. A future
// evolution that writes into `cellsPrev` and then SWAPS the two arrays shares nothing and passes
// claim 1; it would move claim 3's needle, and the message says so.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `9b04840e5`: claims 1 and 2
// are REGRESSIONS and ONE finding (#486) — the parent's code carries two whole-array `cellsPrev`
// assignments (init and `seed()`) and no index copy. Claim 3 is a COUNTERWEIGHT, green on both
// trees: the in-place write is what makes a shared buffer cost anything. The stripper is
// TRAGEND for claim 1: raw text holds THREE `cellsPrev = ` (two in the ⛔ comments), code holds one.

import Foundation
import XCTest

final class TheCellularSeedSharesNoBufferTests: XCTestCase {

    private static let cellular = "Sources/Echoelmusic/DSP/EchoelCellular.swift"

    // MARK: - claim 1

    func testNoWholeArrayAssignmentAliasesTheCells() throws {
        let code = SourceText.codeOnly(try text(Self.cellular))
        XCTAssertEqual(code.components(separatedBy: "cellsPrev = ").count - 1, 1, """
            `cellsPrev` is assigned as a whole array somewhere other than `init`. Outside `init` \
            that makes it share a buffer with the array it was assigned from, and the next \
            in-place write — in `evolve1D()`, on the render thread — copy-on-writes.
            """)
        // The count spelling moved with ASmallCellularTextureCannotTrapTests (init now floors the
        // count into a local, `cellTotal`); the fact pinned is unchanged — a FRESH buffer in init.
        XCTAssertTrue(code.contains("self.cellsPrev = [UInt8](repeating: 0, count: cellTotal)"),
                      "the one legitimate assignment (a FRESH buffer in init) is gone — re-anchor (#456)")
        let aliasing = code.split(separator: "\n").filter {
            $0.trimmingCharacters(in: .whitespaces).hasSuffix("= cells")
        }
        XCTAssertEqual(aliasing, [], """
            Another array is assigned from `cells` as a whole: \(aliasing). The render thread then \
            pays for the copy the first time `cells` is mutated.
            """)
    }

    // MARK: - claim 2

    func testTheSeedCopiesByIndex() throws {
        let code = SourceText.codeOnly(try text(Self.cellular))
        let seed = try XCTUnwrap(Self.body(startingWith: "public func seed(_ pattern: SeedPattern) {",
                                           in: code),
                                 "`seed(_:)` not found — re-anchor this guard (#456)")
        XCTAssertTrue(seed.contains("cellsPrev[i] = cells[i]"), """
            `seed()` no longer copies into `cellsPrev` element by element. The index copy is \
            what keeps the two arrays on separate buffers.
            """)
    }

    // MARK: - claim 3 (COUNTERWEIGHT)

    func testTheEvolutionStillWritesTheCellsInPlace() throws {
        let code = SourceText.codeOnly(try text(Self.cellular))
        let evolve = try XCTUnwrap(Self.body(startingWith: "private func evolve1D() {", in: code),
                                   "`evolve1D()` not found — re-anchor this guard (#456)")
        XCTAssertTrue(evolve.contains("cells[i] = rule.evaluate("), """
            `evolve1D()` no longer writes `cells` in place. That write is what makes a shared \
            buffer cost an allocation; if the evolution now double-buffers (write `cellsPrev`, \
            then swap), move this needle to the new write and keep claim 1.
            """)
    }

    // MARK: - helpers

    private static func body(startingWith anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor) else { return nil }
        var depth = 0
        var out = ""
        for ch in code[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { out.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return out }
            }
        }
        return nil
    }

    private func text(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — source-text claim cannot run (#454)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
