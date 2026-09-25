// TheAUv3SuppliesItsOwnOutputBuffersTests.swift
// Echoel — 2026-09-24 (overnight P8g): when a host hands the AUv3 a null output pointer, the
// render block renders into memory the AU owns and points `mData` at it. Blocking bundle.
//
// THE CONTRACT (Apple, `AURenderBlock`, `outputData`, fetched 2026-09-24): "The buffer pointers
// may be null on entry, in which case the block will render into memory it owns and modify the
// `mData` pointers to point to that memory. The block is responsible for preserving the validity
// of that memory until it is next called to render, or until the `deallocateRenderResources()`
// method is called."
//
// THE DEFECT (measured before the repair). The mix loop read
// `guard let data = buf.mData?.assumingMemoryBound(to: Float.self) else { continue }` — a null
// pointer was SKIPPED, so a host that asks the AU for its buffers received none: silence at best,
// a null read in the host at worst. `mDataByteSize` was never written either. AUM, the one host
// measured (#1386), evidently passes its own buffers; whether Logic/GarageBand/AVAudioEngine pass
// null is NOT measured here — the contract says they may, which is the reason to honour it.
//
// THE REPAIR. `RenderScratch` allocates `ownedChannels` × `capacity` floats ONCE (init), frees
// them in `deinit`; the render block stores a pointer into it for each null channel below
// `ownedChannels` and writes `mDataByteSize` for every channel it fills. Pointer and size stores
// only — nothing allocates on the render thread.
//
// WHAT KIND OF GREEN (§1): all claims are SOURCE-TEXT SCANS (comment-stripped). The extension
// cannot be instantiated in this bundle, so the render block cannot be driven. HOST: a host that
// passes null `mData` must be run (WA3 host queue) — this file does not prove it sounds there.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not freeze the channel cap at 8 or the
// ceiling at 4096; it pins that the owned stride is the scratch's own `capacity`, so the two
// cannot drift apart.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `a4cea87de`: claims 1 and 2
// are REGRESSIONS and ONE finding (#486) — no owned output memory exists there and the loop
// skips a null pointer. Claim 3 is a COUNTERWEIGHT, green on both trees (the render block never
// allocates). The file names no `Sources/` symbol, so it compiles on both trees.
//
// ⭐ 2026-09-25 (overnight P8u) — claim 4: the returned render CLOSURE reads no
// `RenderScratch.` static; the getter captures `ownedChannels` into a local before `return {`.
// A `static let` is a lazily initialised global, and in a Debug build its first read runs a
// one-time initialiser (`swift_once`) — on the audio thread, if the null-mData branch touches it
// first. Found by tonight's read-only audio-thread review (its finding 3). SOURCE-TEXT SCAN.
// Grading, parent `84c899af6`: REGRESSION — one finding (the closure read
// `RenderScratch.ownedChannels` directly there). Claims 1–3 unchanged.

import Foundation
import XCTest

final class TheAUv3SuppliesItsOwnOutputBuffersTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    // MARK: - claim 1

    func testANullOutputPointerIsReplacedBeforeTheMixWritesIt() throws {
        let render = try renderBlock()
        let replace = try XCTUnwrap(render.range(of: "ablPointer[channel].mData = UnsafeMutableRawPointer("), """
            The render block no longer points a null output buffer at AU-owned memory. The \
            AURenderBlock contract lets a host pass null `mData` and expects the AU to supply it.
            """)
        XCTAssertTrue(render.contains("ablPointer[channel].mData == nil"),
                      "the replacement is no longer conditional on a null pointer — a host's own buffer would be discarded")
        let write = try XCTUnwrap(render.range(of: "guard let data = ablPointer[channel].mData"),
                                  "the mix loop's buffer read moved — re-anchor this guard (#456)")
        XCTAssertLessThan(replace.lowerBound, write.lowerBound,
                          "the owned pointer is stored AFTER the mix reads `mData` — a null channel is still skipped")
        XCTAssertTrue(render.contains("mDataByteSize = UInt32(count * MemoryLayout<Float>.size)"),
                      "the render block no longer reports how many bytes it wrote")
        XCTAssertTrue(render.contains("channel * scratch.capacity"), """
            The owned stride is no longer the scratch's own capacity. The owned memory and the \
            frame ceiling would then drift apart (TheAUv3RegistersAndStaysIsolatedTests claim 6).
            """)
    }

    // MARK: - claim 2

    func testTheOwnedMemoryLivesAsLongAsTheScratch() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let scratch = try XCTUnwrap(Self.body(startingWith: "private final class RenderScratch {", in: code),
                                    "`RenderScratch` not found — re-anchor this guard (#456)")
        XCTAssertTrue(scratch.contains("ownedOutput = UnsafeMutablePointer<Float>.allocate(capacity: capacity * Self.ownedChannels)"),
                      "the owned output memory is no longer allocated once, with the scratch")
        XCTAssertTrue(scratch.contains("ownedOutput.deallocate()"),
                      "the owned output memory is never freed")
    }

    // MARK: - claim 3 (COUNTERWEIGHT)

    func testTheRenderBlockStillAllocatesNothing() throws {
        let render = try renderBlock()
        XCTAssertFalse(render.contains(".allocate("), """
            The render block allocates. Owned output memory belongs in `RenderScratch.init`; \
            malloc on the render thread is a priority inversion.
            """)
    }

    // MARK: - claim 4

    func testTheRenderClosureReadsNoStaticOnTheAudioThread() throws {
        let getter = try renderBlock()
        let marker = "return { (actionFlags"
        let closureStart = try XCTUnwrap(getter.range(of: marker),
                                         "the returned render closure is not found — re-anchor this guard (#456)")
        let captures = getter[..<closureStart.lowerBound]
        let closure = try XCTUnwrap(Self.body(startingWith: marker, in: String(getter[closureStart.lowerBound...])),
                                    "the render closure has no body — re-anchor this guard (#456)")
        XCTAssertTrue(captures.contains("let ownedChannels = RenderScratch.ownedChannels"), """
            The owned-channel count is no longer captured before the render closure.
            """)
        XCTAssertTrue(closure.contains("channel < ownedChannels"),
                      "the null-mData branch no longer compares against the captured count")
        XCTAssertFalse(closure.contains("RenderScratch."), """
            The render closure reads a `RenderScratch` static. A `static let` is lazily \
            initialised; in a Debug build its first read runs `swift_once` on the audio thread. \
            Capture it into a local above `return {`.
            """)
    }

    // MARK: - helpers

    private func renderBlock() throws -> String {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        return try XCTUnwrap(Self.body(startingWith: "public override var internalRenderBlock", in: code),
                             "the render block is not found — re-anchor this guard (#456)")
    }

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
