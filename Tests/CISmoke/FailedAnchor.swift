// FailedAnchor.swift
// Echoel — #1240's repair as ONE helper (W-RED, 2026-11-01). A missed ANCHOR is a red, not a
// skip: under `xcodebuild test-without-building` a skip does not fail the job, so a guard whose
// anchor moved went quietly green. `TheAnchorMissSkipsDoNotGrowTests` ratchets the skips and
// says "use XCTFail (and `throw` your own Error if the caller needs to stop)"; 158 files each
// declare a private error for that. This is the same two lines, shared, so a migrated site is a
// one-token change — `throw XCTSkip(` → `throw failedAnchor(` — and keeps its message.
//
// KIND (§1): test infrastructure, no claim of its own. A TREE that is missing still SKIPS
// (`fileExists` in the window); only an anchor miss comes here.

import XCTest

/// The error a test throws after `failedAnchor` has recorded its failure; it only stops the test.
struct FailedAnchor: Error, CustomStringConvertible {
    let description: String
}

/// Records an `XCTFail` at the caller's line and returns the error to `throw`, so the test stops
/// where the anchor was missed — red for its named reason, never a skip.
func failedAnchor(_ message: String, file: StaticString = #filePath, line: UInt = #line) -> FailedAnchor {
    XCTFail(message, file: file, line: line)
    return FailedAnchor(description: message)
}
