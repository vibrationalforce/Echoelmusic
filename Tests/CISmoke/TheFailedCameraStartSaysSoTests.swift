// TheFailedCameraStartSaysSoTests.swift
// Echoel — audit 2026-10-03, slice MP-1 ("ein Kamera-Start, der scheitert, sagt es").
//
// WHAT IT GUARDS. `CameraCapture.start()` throws `.noCamera` when there is no rear camera and
// `.configurationFailed` when the session refuses its input or output. `CameraRPPGBioPublisher`
// caught both, logged a warning and set `isRunning = false` — and nothing else. Only the
// ACCESS case had a voice (`permissionDenied` → `PulseCue.cameraDenied`). Every other failure
// left the strip silent, so a player kept placing a finger on a lens that was never opened.
// Now the publisher sets `cameraUnavailable` on the same failed-start edge (exclusive with
// `permissionDenied`), clears it on the same success edge, and `BioStripView.statusBanner`
// names it — gated like the denied branch, so a strap or Apple Health reading silences it.
//
// §1 LIMIT: all four claims are SOURCE-TEXT SCANS (the publisher's start path is async and
// device-bound; the strip is a `private` member of a `View`). Whether an iPhone whose camera is
// held by another app actually shows the line is a DEVICE PROBE — open, not covered here.
//
// §3 HONEST GRADING against the parent (d0945a031): this file names no new Swift symbol (every
// needle is text), so it compiles there. Claims 1, 2 and 3 are REGRESSIONS on the parent for
// their named reason — the flag, the banner branch and the catalog key are absent (three
// absences of ONE missing feature, #486). Claim 4 is a COUNTERWEIGHT, green on both trees: the
// failure paths the flag reports still exist. Stripper `SourceText.codeOnly`: PROPHYLAKTISCH
// (0 of 4 verdicts flip — no comment quotes an anchor; the catalog is read raw, it is JSON).

import Foundation
import XCTest

final class TheFailedCameraStartSaysSoTests: XCTestCase {

    private static let publisher = "Sources/Echoelmusic/Bio/CameraRPPGBioPublisher.swift"
    private static let strip = "Sources/Echoelmusic/Studio/BioStripView.swift"
    private static let capture = "Sources/Echoelmusic/Video/CameraCapture.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    private static let line = "The rear camera didn't start — pick another pulse source"

    // MARK: - Claim 1 — the flag is set on the failed-start edge and cleared on the success edge

    func testThePublisherRemembersAFailedStart() throws {
        let code = try source(Self.publisher)
        XCTAssertEqual(occurrences(of: "public private(set) var cameraUnavailable = false", in: code), 1,
                       "the flag is published, read-only outside the publisher")
        guard let denied = code.range(of: "permissionDenied = (status == .denied || status == .restricted)"),
              let assign = code.range(of: "cameraUnavailable = !permissionDenied") else {
            return XCTFail("ANCHOR MISSING: the failed-start branch no longer derives both flags")
        }
        XCTAssertTrue(denied.upperBound <= assign.lowerBound
                      && code.distance(from: denied.upperBound, to: assign.lowerBound) < 80,
                      "the flag is set right after the access check, so the two stay exclusive")
        XCTAssertEqual(occurrences(of: "cameraUnavailable = !permissionDenied", in: code), 1)
        guard let clearedDenied = code.range(of: "permissionDenied = false\n        cameraUnavailable = false") else {
            return XCTFail("a successful start must clear the flag beside `permissionDenied = false`, or the line outlives the fix")
        }
        XCTAssertEqual(occurrences(of: "\n        cameraUnavailable = false\n", in: code), 1, "one clearing site, the success edge")
        XCTAssertLessThan(assign.lowerBound, clearedDenied.lowerBound, "catch branch first, success path after it")
    }

    // MARK: - Claim 2 — the strip names it, between the denied branch and the running branches

    func testTheStripSaysTheCameraDidNotStart() throws {
        let body = try functionBody("private var statusBanner: some View {", in: try source(Self.strip))
        guard let denied = body.range(of: "} else if cameraRPPG.permissionDenied, reading == nil {"),
              let failed = body.range(of: "} else if cameraRPPG.cameraUnavailable, reading == nil {"),
              let running = body.range(of: "} else if cameraRPPG.isRunning {") else {
            return XCTFail("ANCHOR MISSING in `statusBanner`: the denied, the failed-start or the running branch")
        }
        XCTAssertTrue(denied.upperBound <= failed.lowerBound && failed.upperBound <= running.lowerBound,
                      "a failed start is a non-running state: it sits with the denied branch, before the running ones")
        XCTAssertTrue(body.contains("banner(String(localized: \"\(Self.line)\"),"),
                      "the branch renders the catalogued line")
    }

    // MARK: - Claim 3 — the line is in the catalog (read raw: the catalog is JSON, not Swift)

    func testTheLineIsCatalogued() throws {
        let url = try repoRoot().appendingPathComponent(Self.catalog)
        let data = try Data(contentsOf: url)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = root?["strings"] as? [String: Any] ?? [:]
        XCTAssertGreaterThan(strings.count, 400, "ANCHOR MISSING: the string catalog read as nearly empty (#454)")
        XCTAssertNotNil(strings[Self.line], "the banner's key has no catalog entry")
        XCTAssertLessThanOrEqual(Self.line.count, 76, "no longer than the strip's longest original sentence")
    }

    // MARK: - Claim 4 — COUNTERWEIGHT: the failures the flag reports still exist

    func testTheCaptureStillThrowsTheFailuresTheFlagReports() throws {
        let code = try source(Self.capture)
        XCTAssertTrue(code.contains("throw CameraCaptureError.noCamera"), "no rear camera is a thrown failure")
        XCTAssertTrue(code.contains("CameraCaptureError.configurationFailed"), "a refused session is a thrown failure")
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func functionBody(_ head: String, in code: String) throws -> String {
        guard let start = code.range(of: head) else {
            throw AnchorMissing(reason: "`\(head)` is gone")
        }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(code[start.lowerBound...index]) } }
            index = code.index(after: index)
        }
        throw AnchorMissing(reason: "unbalanced braces after `\(head)`")
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
