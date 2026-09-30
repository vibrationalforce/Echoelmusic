// TheHeadPlayOwnsTheSpaceKeyTests.swift
// Echoel — interface audit 2026-09-30, Zug 2 ("Ein Kopf, der spricht und hört"): the space bar
// belongs to the ONE Play/Stop in the project header, and to nothing else.
//
// WHAT IT GUARDS. `ProjectHeader.playStopButton` carries `.keyboardShortcut(.space, modifiers: [])`.
// A hardware keyboard (iPad, Mac, a stage laptop) then plays and stops the one transport with the
// key every DAW gives it. The law is the COUNT: exactly one bare-space shortcut in `Sources/`. A
// second one — on the Workstation's Play, on a Perform scene — would make the key ambiguous, which
// is the two-transports confusion `OneStartControlTests` and `TheProjectHeaderRunsOneTransportTests`
// exist to prevent. `.disabled(!available)` on the same button still governs the key.
//
// §1 LIMIT: every claim is a SOURCE-TEXT SCAN. It proves where the modifier sits, not that a key
// press reaches it — whether space in a focused text field types a space instead of starting
// playback is a DEVICE PROBE (NEEDS-FOUNDER-VERIFY on the modifier's comment).
//
// §3 HONEST GRADING, transcribed in Python against the parent (bca147417) and this tree: claim 1
// is the DECISION — the parent has ZERO `.keyboardShortcut(.space` (measured), so its "exactly
// one" is RED there for the named reason; claims 2 and 3 are red on the parent by the same
// absence (one absence, reported once, #486); claim 4 is a COUNTERWEIGHT, green on both trees.
// ZERO regressions claimed. Stripper `SourceText.codeOnly`: TRAGEND on claim 1 (the modifier's
// own comment quotes the needle once — raw count 2, stripped 1; 1 of 4 verdicts flips).

import Foundation
import XCTest

final class TheHeadPlayOwnsTheSpaceKeyTests: XCTestCase {

    private static let header = "Sources/Echoelmusic/Studio/ProjectHeader.swift"
    private static let needle = ".keyboardShortcut(.space"
    private static let buttonHead =
        "private func playStopButton(running: Bool, play: ProjectTransport.PlayAction) -> some View"

    // MARK: - Claim 1 — exactly ONE bare-space shortcut in all of Sources/

    func testExactlyOneSpaceShortcutExistsInSources() throws {
        let hits = try swiftFiles().compactMap { path -> String? in
            let code = try source(path)
            return code.contains(Self.needle) ? path : nil
        }
        XCTAssertEqual(hits, [Self.header],
                       "The space bar belongs to the header's ONE Play/Stop. Found in: \(hits)")
        let code = try source(Self.header)
        XCTAssertEqual(occurrences(of: Self.needle, in: code), 1,
                       "one shortcut in the one file — a second would make the key ambiguous")
    }

    // MARK: - Claim 2 — it sits on the play/stop button itself

    func testTheShortcutSitsOnThePlayStopButton() throws {
        let button = try body(of: Self.buttonHead, in: try source(Self.header))
        XCTAssertTrue(button.contains(Self.needle + ", modifiers: [])"),
                      "bare space, no modifiers — ⌘-space is the system's")
    }

    // MARK: - Claim 3 — ordering: `.disabled(!available)` precedes it, so the key obeys availability

    func testTheDisabledGateGovernsTheKey() throws {
        let button = try body(of: Self.buttonHead, in: try source(Self.header))
        guard let disabled = button.range(of: ".disabled(!available)"),
              let key = button.range(of: Self.needle) else {
            return XCTFail("ANCHOR MISSING: `.disabled(!available)` or the shortcut left the button")
        }
        XCTAssertLessThan(disabled.lowerBound, key.lowerBound,
                          "the availability gate is declared on the same button, before the key")
    }

    // MARK: - Claim 4 — COUNTERWEIGHT: the button is still the ONE transport (stop for everything)

    func testTheButtonStillStopsEverythingAndStartsTheSong() throws {
        let button = try body(of: Self.buttonHead, in: try source(Self.header))
        XCTAssertTrue(button.contains("stopAll()"), "running → Stop, for everything")
        XCTAssertTrue(button.contains("case .startSong, .startSongAndInstrument: startSong()"),
                      "stopped → the song starts; the key inherits exactly this")
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func body(of head: String, in code: String) throws -> String {
        guard let start = code.range(of: head),
              let open = code.range(of: "{", range: start.upperBound..<code.endIndex) else {
            throw AnchorMissing(reason: "`\(head)` is gone from \(Self.header) (#454)")
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(code[open.lowerBound...index]) } }
            index = code.index(after: index)
        }
        throw AnchorMissing(reason: "unbalanced braces after `\(head)`")
    }

    private func swiftFiles() throws -> [String] {
        let root = try repoRoot()
        let sources = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw AnchorMissing(reason: "cannot enumerate Sources/")
        }
        var out: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            out.append(String(url.path.dropFirst(root.path.count + 1)))
        }
        XCTAssertGreaterThan(out.count, 100, "the walk over Sources/ returned almost nothing — a scan that matches nothing is a finding, never a pass")
        return out.sorted()
    }

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }
}
