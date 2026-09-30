// TheTextSizesSitOnTheRampTests.swift
// Echoel — Zug 4 „Klarheit" (2026-09-30): six type steps, one decision.
//
// WHAT THIS PINS. `EchoelTheme.font(N)` was called with NINETEEN distinct sizes. Six of them
// carried the interface (11 · 12 · 13 · 15 · 18 · 22); six more had grown between the steps by
// accident — 14 · 16 · 17 · 20 · 24 · 26, 64 sites in 22 files, no two files agreeing on what
// 14 meant (a row title in the Routing view, a value in the tempo field, an icon in a chooser).
// A reader cannot learn a hierarchy that has a step every point. The ramp is now ONE array in
// the theme, `EchoelTheme.typeRamp`, with `displayFloor` above it for readout numerals (a BPM,
// a coherence figure — 28 pt and up, deliberately free). The in-between sizes were folded onto
// the nearest step: 14/16 → 15, 17 → 18, 20/24 → 22, 26 → 28.
//
// 1. SOURCE over the whole tree: every literal `EchoelTheme.font(N` under `Sources/Echoelmusic/`
//    (code, not comments) is a ramp step or at least `displayFloor`. The ramp is READ from
//    `EchoelTheme.swift` — never a copy here (#416): a designer changes the ramp in the theme and
//    every call site is measured against the new one; this file pins no size of its own (#364).
// 2. COUNTERWEIGHTS (#343): the ramp parses, is strictly ascending, starts at 11 (the chrome floor
//    of `TheChromeTextMeetsTheElevenPointFloorTests` — two laws sharing a number on purpose) and
//    ends below `displayFloor`; the walk saw the tree and the font is still called widely.
//
// Grading (§0, no Swift toolchain; transcribed in Python against both trees): claim 1 has no
// anchor on the parent (`typeRamp` does not exist there — not gradable, said as such) and is
// green here with 0 off-ramp sites; against the parent's SITES with this ramp it would be red
// 64 times (ONE finding, #486). Claim 2 green here. SOURCE-TEXT scan: it proves what the code
// asks for, never how the hierarchy reads on glass.
// NEEDS-FOUNDER-VERIFY: Routing view (row titles 14 → 15), the tempo field's value (14 → 15),
// Onboarding titles (24 → 22), the coherence figure in the breath guide (26 → 28) read as ONE
// hierarchy, nothing clips at the largest text size.

import Foundation
import XCTest

final class TheTextSizesSitOnTheRampTests: XCTestCase {

    private static let theme = "Sources/Echoelmusic/Studio/EchoelTheme.swift"

    // MARK: 1 — every size is a step or a display numeral

    func testEveryBrandFontSizeIsARampStepOrADisplayNumeral() throws {
        let ramp = try rampFromTheme()
        let pattern = try NSRegularExpression(pattern: #"EchoelTheme\.font\(\s*([0-9]+(?:\.[0-9]+)?)"#)
        var offRamp: [String] = []
        var seen = 0
        for file in try swiftFiles() {
            let ns = file.code as NSString
            for m in pattern.matches(in: file.code, range: NSRange(location: 0, length: ns.length)) {
                seen += 1
                guard let size = Double(ns.substring(with: m.range(at: 1))) else { continue }
                let onRamp = ramp.steps.contains { abs($0 - size) < 0.001 }
                if !onRamp && size < ramp.displayFloor {
                    let line = file.code[..<file.code.index(file.code.startIndex, offsetBy: m.range.location)]
                        .filter { $0 == "\n" }.count + 1
                    offRamp.append("\(file.rel):\(line) → \(size)")
                }
            }
        }
        XCTAssertGreaterThan(seen, 500, "the scan only means something while the app is typeset with `EchoelTheme.font(` — saw \(seen)")
        XCTAssertTrue(offRamp.isEmpty, """
            \(offRamp.count) `EchoelTheme.font(` call(s) ask for a size that is neither a step of \
            `EchoelTheme.typeRamp` \(ramp.steps.map { Int($0) }) nor a display numeral \
            (≥ \(Int(ramp.displayFloor))): \(offRamp.prefix(6).joined(separator: " | ")). Pick the \
            nearest step — or change the ramp in the theme, once, for everyone.
            """)
    }

    // MARK: 2 — counterweights

    func testTheRampIsOneAscendingDecisionStartingAtTheChromeFloor() throws {
        let ramp = try rampFromTheme()
        XCTAssertGreaterThanOrEqual(ramp.steps.count, 5, "a ramp with fewer than five steps is a pair of sizes, not a hierarchy")
        XCTAssertEqual(ramp.steps, ramp.steps.sorted(), "the steps are written ascending")
        XCTAssertEqual(Set(ramp.steps).count, ramp.steps.count, "no step is listed twice")
        XCTAssertEqual(ramp.steps.first, 11, "the ramp starts at the 11 pt chrome floor — the two laws share that number on purpose")
        XCTAssertLessThan(ramp.steps.last ?? .infinity, ramp.displayFloor, "the display floor sits above the last step, or the ramp and the numerals overlap")
        let files = try swiftFiles()
        XCTAssertGreaterThan(files.count, 200, "only \(files.count) files walked — a truncated walk makes claim 1 vacuous")
        XCTAssertGreaterThan(files.filter { $0.code.contains("EchoelTheme.font(") }.count, 20,
                             "the brand font is the app-wide ramp; if fewer than 20 files call it, the call was renamed")
    }

    // MARK: helpers

    private struct Ramp { let steps: [Double]; let displayFloor: Double }

    private func rampFromTheme() throws -> Ramp {
        let code = SourceText.codeOnly(try text(Self.theme))
        guard let r = code.range(of: #"static let typeRamp: \[CGFloat\] = \[([0-9., ]+)\]"#, options: .regularExpression),
              let f = code.range(of: #"static let displayFloor: CGFloat = ([0-9.]+)"#, options: .regularExpression) else {
            throw XCTSkip("ANCHOR MISSING: `typeRamp` / `displayFloor` in EchoelTheme — re-anchor this guard (#454)")
        }
        let steps = code[r].components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).compactMap(Double.init)
        let floor = code[f].components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).compactMap(Double.init).last
        guard !steps.isEmpty, let displayFloor = floor else { throw XCTSkip("ANCHOR MISSING: ramp parsed empty (#454)") }
        return Ramp(steps: steps, displayFloor: displayFloor)
    }

    private func repoRoot() throws -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources/Echoelmusic").path) else {
            throw XCTSkip("source tree not present under \(root.path) — this test inspects source text")
        }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        guard let s = try? String(contentsOf: try repoRoot().appendingPathComponent(relativePath), encoding: .utf8) else {
            throw XCTSkip("ANCHOR MISSING: cannot read \(relativePath) (#454)")
        }
        return s
    }

    private func swiftFiles() throws -> [(rel: String, code: String)] {
        let sources = try repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: sources.path) else { return [] }
        var out: [(rel: String, code: String)] = []
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            let t = try String(contentsOf: sources.appendingPathComponent(rel), encoding: .utf8)
            out.append((rel, SourceText.codeOnly(t)))
        }
        return out
    }
}
