// TheAUv3RefusesAnOversizedBlockTests.swift
// Echoel — 2026-09-24 (overnight P8j): a render call for more frames than the AUv3's scratch holds
// is refused with `kAudioUnitErr_TooManyFramesToProcess` before anything renders. Blocking bundle.
//
// THE DEFECT (measured before the repair). #1385 put the defence on the contract — the
// `maximumFramesToRender` override clamps what the AU promises — and kept an in-block
// `min(Int(frameCount), 4096)` "as a belt-and-braces bound". The bound limits what the block
// WRITES, not what it CLAIMS: a host that breaks the contract still got `noErr`, with every sample
// past 4096 left exactly as it handed the buffer over — the burst of stale audio the override's
// own doc comment describes. Found by tonight's read-only audit agent (its finding 6).
//
// THE REPAIR. `guard Int(frameCount) <= scratch.capacity else { return
// kAudioUnitErr_TooManyFramesToProcess }` at the top of the block — the status Core Audio defines
// for exactly this, and the scratch's own capacity rather than a second literal (#416).
//
// WHAT KIND OF GREEN (§1): SOURCE-TEXT SCANS (comment-stripped). The extension cannot be
// instantiated in this bundle. HOST: whether any host sends an oversized block, and how it reacts
// to the refusal, is unmeasured — the contract override makes it rare.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not freeze 4096: it pins that the refusal
// compares against the scratch's capacity, so raising the capacity raises the refusal with it.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `835cb8e8c`: claim 1 is a
// REGRESSION — one finding (no refusal exists there). Claim 2 is a COUNTERWEIGHT, green on both
// trees. The file names no `Sources/` symbol, so it compiles on both.
//
// ⭐ 2026-09-25 (overnight P8v) — claim 1 also asserts the block names no `4096` of its own: after
// the refusal the frame count needs no second bound, and a literal there would re-cap the write if
// the scratch capacity were raised alone (#416). Found by tonight's read-only audio-thread review
// (its finding 4). Grading, parent `283dfb093`: REGRESSION — one finding (`min(Int(frameCount),
// 4096)` there). SOURCE-TEXT SCAN.

import Foundation
import XCTest

final class TheAUv3RefusesAnOversizedBlockTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    // MARK: - claim 1

    func testAnOversizedBlockIsRefusedBeforeAnythingRenders() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let render = try XCTUnwrap(Self.body(startingWith: "public override var internalRenderBlock", in: code),
                                   "the render block is not found — re-anchor this guard (#456)")
        let refusal = try XCTUnwrap(render.range(of: "guard Int(frameCount) <= scratch.capacity else {"), """
            The render block no longer refuses a block larger than its scratch. A host that \
            breaks `maximumFramesToRender` then gets `noErr` over a tail it never wrote.
            """)
        XCTAssertTrue(render.contains("return kAudioUnitErr_TooManyFramesToProcess"),
                      "the refusal no longer returns Core Audio's status for an oversized block")
        let firstRender = try XCTUnwrap(render.range(of: "synthRef.render("),
                                        "the synth render call moved — re-anchor this guard (#456)")
        XCTAssertLessThan(refusal.lowerBound, firstRender.lowerBound,
                          "the refusal comes after the voices have rendered — it must come first")
        XCTAssertFalse(render.contains("4096"), """
            The render block carries its own frame ceiling again. The refusal against \
            `scratch.capacity` is the one bound; a second literal re-caps the write when the \
            capacity alone is raised (#416).
            """)
    }

    // MARK: - claim 2 (COUNTERWEIGHT)

    func testTheContractAndTheScratchStillAgree() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        XCTAssertTrue(code.contains("private let renderScratch = RenderScratch(capacity: 4096)"),
                      "the scratch capacity changed — move the `maximumFramesToRender` clamp with it")
        XCTAssertTrue(code.contains("get { min(super.maximumFramesToRender, 4096) }"),
                      "the frame-ceiling contract no longer matches the scratch capacity")
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
