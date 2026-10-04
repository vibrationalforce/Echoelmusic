// TheLiveStateIsTheRecordingRedTests.swift
// Echoel — Restructure F6b (2026-10-04, `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md` §2C/§3).
//
// WHAT WAS WRONG. `BroadcastView` filled its "Go Live" button with `EchoelTheme.danger` while
// live. `EchoelTheme` keeps `recording` and `danger` as two names for one value ON PURPOSE —
// an error-red retune must not repaint a live/recording indicator — and the broadcast button
// was the one live indicator that borrowed the error red. Its label also carried a ternary
// whose two branches were the same black (`onPrimary` is `Color.black`).
//
// THE REPAIR. Live is the recording red (the take's record button, `RecordTakeControls`, is
// the reference); the label is `onPrimary` without a condition. The "engine not installed"
// warning in the same file stays `danger` — that one IS an error.
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3). SOURCE-TEXT SCAN over comment-stripped
// `Sources/`, transcribed in Python against the parent `360e6be0d` and the worktree:
//   · claim 1 — RED on the parent, a REGRESSION: the live fill names `danger`.
//   · claim 2 — RED on the parent, a REGRESSION: one live/recording ternary picks `danger`.
//   · claim 3 — COUNTERWEIGHT, green on both: the two tokens are still declared apart, the
//     reference still uses `recording`, and the error line still uses `danger`.
// The view is doorless (no engine linked); this guard does not prove anything renders.

import Foundation
import XCTest

final class TheLiveStateIsTheRecordingRedTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/"

    /// `<live or recording flag> ? EchoelTheme.danger` — a capture state painted as an error.
    private static let captureStateAsError =
        #"\b(isLive|recording|isRecording|wavRecording)\s*\?\s*EchoelTheme\.danger\b"#

    /// 1 — the broadcast button wears the recording red while live, with a plain label.
    func testTheBroadcastGoesLiveInTheRecordingRed() throws {
        let code = try read(Self.studio + "BroadcastView.swift")
        XCTAssertTrue(code.contains(".fill(broadcast.isLive ? EchoelTheme.recording : EchoelTheme.text))"),
                      "BroadcastView's live fill no longer names `EchoelTheme.recording`.")
        XCTAssertFalse(code.contains("isLive ? EchoelTheme.danger"), """
            BroadcastView paints "live" with the error red. Live is `EchoelTheme.recording` — the \
            two tokens share a value today and are kept apart on purpose.
            """)
        XCTAssertFalse(code.contains("isLive ? EchoelTheme.onPrimary : .black"),
                       "The live label is back to a ternary whose two branches are the same black.")
    }

    /// 2 — across `Sources/`, no live or recording flag selects the error red.
    func testNoCaptureStateIsPaintedAsAnError() throws {
        let regex = try NSRegularExpression(pattern: Self.captureStateAsError)
        var holders: [String] = []
        for (path, code) in try swiftSources() {
            let n = regex.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code))
            if n > 0 { holders.append("\(path) (\(n))") }
        }
        XCTAssertTrue(holders.isEmpty, """
            A live/recording state picks `EchoelTheme.danger` in \(holders). A capture state is \
            `EchoelTheme.recording`; `danger` is for errors.
            """)
    }

    /// 3 — COUNTERWEIGHT: the distinction claims 1–2 rely on still exists.
    func testTheTwoRedsStayTwoNames() throws {
        let theme = try read(Self.studio + "EchoelTheme.swift")
        XCTAssertTrue(theme.contains("static let recording = Color("),
                      "`EchoelTheme.recording` is no longer declared as its own token.")
        XCTAssertTrue(theme.contains("static let danger  = Color("),
                      "`EchoelTheme.danger` is no longer declared as its own token.")
        XCTAssertTrue(try read(Self.studio + "RecordTakeControls.swift")
                        .contains(".fill(recording ? EchoelTheme.recording : EchoelTheme.fill))"),
                      "The reference (the take's record button) no longer fills with `recording`.")
        XCTAssertTrue(try read(Self.studio + "BroadcastView.swift")
                        .contains(".foregroundStyle(EchoelTheme.danger)"),
                      "BroadcastView's engine warning lost `danger` — an error stays the error red.")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func root() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }

    private func read(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: root().appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// Every `.swift` file under `Sources/`, comment-stripped. An empty walk FAILS — it would
    /// pass claim 2 vacuously.
    private func swiftSources() throws -> [(String, String)] {
        let sources = root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            XCTFail("ANCHOR MISSING: cannot walk Sources/ (#454)")
            throw AnchorMissing(name: "Sources/")
        }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            guard let cut = url.path.range(of: "/Sources/", options: .backwards) else { continue }
            out.append(("Sources/" + String(url.path[cut.upperBound...]), SourceText.codeOnly(text)))
        }
        guard out.count > 100 else {
            XCTFail("the Sources/ walk found only \(out.count) Swift files — the scan cannot be trusted")
            throw AnchorMissing(name: "Sources/ walk")
        }
        return out
    }
}
