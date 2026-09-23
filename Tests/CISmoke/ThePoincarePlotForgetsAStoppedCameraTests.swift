// ThePoincarePlotForgetsAStoppedCameraTests.swift
// Echoel — S4b (founder 2026-09-23, "all tasks"): before the Poincaré plot gets a door (S4c), it
// must stop drawing a camera that is no longer measuring.
//
// THE DEFECT. `CameraAnalyzer.rawIntervalsMs` — the plot's only input — survived both window
// resets (lock loss and `resetPulseState`), while every other beat array was emptied beside it.
// So a stopped camera, a lifted finger or a new take kept showing the PREVIOUS take's cloud,
// under a readout that said "Waiting for beats" forever.
//
// WHAT KIND OF GUARD THIS IS (§1): all five claims are SOURCE-TEXT SCANS — `CameraAnalyzer` sits
// behind `#if canImport(AVFoundation)` with `private` clear sites, and the view is a `View`. That
// the cloud actually clears and redraws per beat is a DEVICE PROBE and stays open.
//
// HONEST GRADING (§3), transcribed against the parent tree: claims 1, 3 and 4 are REGRESSIONS
// (no clear existed; `body` read neither value; `readout()` never asked `isRunning`); claim 2 is
// FORWARD (it rides on the clears claim 1 introduces — vacuous-red on the parent, #486); claim 5
// is a COUNTERWEIGHT, green on both.

import Foundation
import XCTest

final class ThePoincarePlotForgetsAStoppedCameraTests: XCTestCase {

    private static let analyzer = "Sources/Echoelmusic/Video/CameraAnalyzer.swift"
    private static let view = "Sources/Echoelmusic/Studio/AnalysisPoincareView.swift"

    /// 1. Wherever the beats die, the raw window dies with them (±3 lines, the same window
    /// `RMSSDReadsOnlyAdjacentBeatsTests` uses for `rrSegments` — trailing comments only).
    func testTheRawWindowDiesWhereverTheBeatsDie() throws {
        let lines = SourceText.codeOnly(try rawText(Self.analyzer))
            .split(separator: "\n", omittingEmptySubsequences: false)
        let clears = lines.indices.filter { lines[$0].contains("rrIntervals.removeAll()") }
        XCTAssertGreaterThanOrEqual(clears.count, 2, "expected the lock-loss clear and `resetPulseState`")
        for i in clears {
            let near = lines[max(0, i - 3)...min(lines.count - 1, i + 3)]
            XCTAssertTrue(near.contains { $0.contains("rawIntervalsMs.removeAll()") }, """
                `rrIntervals` is emptied at line \(i + 1) but `rawIntervalsMs` is not — the \
                Poincaré plot would keep drawing a take that has ended (S4b).
                """)
        }
    }

    /// 2. The clear is conditional: the lock-loss block runs every frame while confidence is
    /// low, and an unconditional write to an observed array invalidates the plot ~15×/s.
    func testTheRawWindowIsClearedOnlyWhenItHoldsSomething() throws {
        let lines = SourceText.codeOnly(try rawText(Self.analyzer))
            .split(separator: "\n", omittingEmptySubsequences: false)
        let sites = lines.filter { $0.contains("rawIntervalsMs.removeAll()") }
        XCTAssertGreaterThanOrEqual(sites.count, 2)
        for line in sites {
            XCTAssertTrue(line.contains("if !rawIntervalsMs.isEmpty {"),
                          "an unguarded clear: \(line.trimmingCharacters(in: .whitespaces))")
        }
    }

    /// 3. The plot reads the beats in `body` (a Canvas-closure read may not register the view
    /// as an observer) and gates them on the camera running.
    func testThePlotReadsTheBeatsInItsBody() throws {
        let code = SourceText.codeOnly(try rawText(Self.view))
        let body = try slice(code, from: "struct AnalysisPoincareView", to: "private func draw(")
        guard let start = body.range(of: "var body: some View {") else {
            return XCTFail("`AnalysisPoincareView.body` moved — re-anchor this claim")
        }
        let inBody = String(body[start.upperBound...])
        XCTAssertTrue(inBody.contains("cameraRPPG.isRunning ? cameraRPPG.rrWindowMs : []"))
        XCTAssertTrue(inBody.contains("draw(ctx, size, rr: rr)"), "the Canvas must draw the value `body` read")
    }

    /// 4. The readout asks whether the camera runs BEFORE it reads any beat.
    func testTheReadoutAsksWhetherTheCameraRunsFirst() throws {
        let code = SourceText.codeOnly(try rawText(Self.view))
        let readout = try slice(code, from: "private func readout() -> String {", to: "\n    }\n}")
        let running = try XCTUnwrap(readout.range(of: "guard cameraRPPG.isRunning else"))
        let beats = try XCTUnwrap(readout.range(of: "cameraRPPG.rrWindowMs"))
        XCTAssertLessThan(running.lowerBound, beats.lowerBound)
        XCTAssertTrue(readout.contains("Camera pulse is off."))
    }

    /// 5. COUNTERWEIGHT — the lock flag never gates the plot: it can flip at the analyzer rate
    /// (~3.75 Hz), which would blink the cloud faster than the 3 Hz flash ceiling.
    func testTheLockFlagDoesNotGateThePlot() throws {
        let code = SourceText.codeOnly(try rawText(Self.view))
        XCTAssertFalse(code.contains("cameraRPPG.isLocked"))
    }

    // MARK: - Helpers

    /// A missed anchor ends the claim as a FAILURE (the XCTFail above), never a skip (#1240).
    private struct AnchorMissing: Error {}

    /// Text from the start of `from` up to (not including) the first `to` after it.
    private func slice(_ text: String, from: String, to: String) throws -> String {
        guard let start = text.range(of: from),
              let end = text.range(of: to, range: start.upperBound..<text.endIndex) else {
            XCTFail("anchor `\(from)` … `\(to)` not found — re-anchor this guard (#1240)")
            throw AnchorMissing()
        }
        return String(text[start.lowerBound..<end.lowerBound])
    }

    private func rawText(_ relativePath: String) throws -> String {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(relativePath) is not present — this guard inspects source text (#454)")
        }
        return try String(contentsOf: path, encoding: .utf8)
    }
}
