// TheReallocatedDroneIgnoresAStaleNoteOffTests.swift
// Echoel — 2026-09-24 (overnight P8m): `allocateRenderResources` clears the AUv3's MIDI note
// tracker before it re-arms the free-running drone. Blocking bundle.
//
// THE DEFECT (measured before the repair). The render block keeps the sounding MIDI note in
// `renderNoteState.current` and releases the voice only on a note-off for THAT note (last-note
// priority). Nothing outside the render block ever wrote the tracker. Sequence: the host holds
// note 60 → `current = 60`; the host changes rate → `deallocateRenderResources` cuts the voice,
// `allocateRenderResources` re-arms the drone, `current` is still 60; the key is released → the
// note-off matches and silences the drone, which was never that note. Found by tonight's
// read-only audit agent (WA3 device-model audit, its finding 3); path re-read hop by hop.
//
// THE REPAIR. `renderNoteState.current = -1` in `allocateRenderResources`, before `noteOn()`.
// Apple guarantees no render is in flight between allocate and the first callback.
//
// WHAT KIND OF GREEN (§1): SOURCE-TEXT SCANS (comment-stripped). The extension cannot be
// instantiated here. HOST: a key held across a sample-rate change is unmeasured on any real host.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `bdf6abee0`: claim 1 is a
// REGRESSION — one finding (allocate never writes the tracker there). Claim 2 is a COUNTERWEIGHT
// (the render block still releases only the tracked note, and the tracker still starts at -1) —
// green on both. The file names no `Sources/` symbol, so it compiles on both.

import Foundation
import XCTest

final class TheReallocatedDroneIgnoresAStaleNoteOffTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    // MARK: - claim 1

    func testAllocateForgetsTheLastNoteBeforeTheDroneStarts() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let allocate = try XCTUnwrap(Self.body(startingWith: "public override func allocateRenderResources() throws {",
                                               in: code),
                                     "`allocateRenderResources` not found — re-anchor this guard (#456)")
        let reset = try XCTUnwrap(allocate.range(of: "renderNoteState.current = -1"), """
            `allocateRenderResources` no longer clears the MIDI note tracker. A key held across a \
            re-allocate stays "current", and its note-off silences the fresh drone.
            """)
        let drone = try XCTUnwrap(allocate.range(of: "synth.noteOn()"),
                                  "the drone start is not found — re-anchor this guard (#456)")
        XCTAssertLessThan(reset.lowerBound, drone.lowerBound,
                          "the tracker is cleared after the drone starts, not before")
    }

    // MARK: - claim 2 (COUNTERWEIGHT)

    func testTheRenderBlockStillReleasesOnlyTheTrackedNote() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        XCTAssertTrue(code.contains("nonisolated(unsafe) var current: Int32 = -1"),
                      "the tracker no longer starts at -1 — the reset value above would mean something else")
        let render = try XCTUnwrap(Self.body(startingWith: "public override var internalRenderBlock", in: code),
                                   "the render block is not found — re-anchor this guard (#456)")
        XCTAssertTrue(render.contains("if Int32(midi.data.1) == noteState.current {"), """
            The render block no longer gates note-off on the tracked note. If last-note priority \
            changed shape, this guard's premise changed with it.
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
