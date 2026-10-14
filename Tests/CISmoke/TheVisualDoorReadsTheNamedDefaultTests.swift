//
//  TheVisualDoorReadsTheNamedDefaultTests.swift
//  Night clarity pass 2026-10-14 (lead finding 5 of the read-only shell audit): `WorkspaceView`
//  read the visual window's visibility through a HAND-TYPED key and default —
//  `@AppStorage("visual.floating.visible") … = true` — while `StudioDefaultKeys.floatingVisualVisible`
//  names the same key and value. Two spellings of one default is the H15/#502 shape: a change to
//  one (a renamed key, a new default) leaves the other reading a different truth, and nothing
//  goes red.
//
//  WHAT THIS PINS (SOURCE-TEXT SCAN, comments stripped): the literal key occurs in `Sources/` code
//  only inside `StudioDefaultKeys.swift`, and the head reads the named default. It forbids no new
//  reader (#364) — a new one reads the named form too.
//
//  GRADING (#433/#464): red on the parent (the literal stood in `WorkspaceView.swift`), green on
//  the worktree. Transcribed, not run.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest

final class TheVisualDoorReadsTheNamedDefaultTests: XCTestCase {

    func testTheVisualWindowKeyIsSpelledOnce() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let sources = root.appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw XCTSkip("Sources/ not on disk — this run has no source tree")
        }
        var spelledIn: [String] = []
        var scanned = 0
        for case let url as URL in walker where url.pathExtension == "swift" {
            scanned += 1
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if code.contains("\"visual.floating.visible\"") { spelledIn.append(url.lastPathComponent) }
        }
        XCTAssertGreaterThan(scanned, 100, "a scan that saw almost nothing is not a pass")
        XCTAssertEqual(spelledIn, ["StudioDefaultKeys.swift"],
                       "the visual window's key is spelled once, in StudioDefaultKeys — every reader uses the named default")

        let workspace = SourceText.codeOnly(try String(
            contentsOf: sources.appendingPathComponent("Studio/WorkspaceView.swift"), encoding: .utf8))
        XCTAssertTrue(workspace.contains(
            "@AppStorage(StudioDefaultKeys.floatingVisualVisible.key) private var floatingVisualVisible = StudioDefaultKeys.floatingVisualVisible.value"),
                      "the head reads the named key AND the named default value")
    }
}
