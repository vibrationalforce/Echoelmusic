// TheFingerHintSaysWhereTheFingerGoesTests.swift
// Echoel — Kandidat A (c), founder 2026-10-15 after the deep audit: the pulse needed knowledge only
// a guide card held. `PulseFingerHint` says the whole sentence on the instrument while the camera
// reads and the pulse is not yet locked.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (`PulseFingerHint.sentence`, pure): recovery first, then a denied
//      camera (unless another source delivers), then a LATCHED remedy, otherwise the one steady
//      instruction (`.coverLens`); nothing when locked or when the camera is not reading.
//   2. SOURCE-TEXT SCAN: the leaf is mounted in `startControlRow` right after `AudioDegradedRow()`,
//      and it is a top-level struct in its own file — the host never reads the 10 Hz publisher
//      (freeze law 10.76.41/50).
//
// ⚠️ HONEST GRADING (#433): `PulseFingerHint` is created by this commit — one absence (#486), every
// claim FORWARD; transcribed by reading the five-line function.
// ⚠️ THE LIMIT: whether the sentence helps a first-time player find the lens is a DEVICE PROBE
// (NEEDS-FOUNDER-VERIFY: fresh install, Play, camera source — the line under the first row says
// to cover the rear camera, and disappears once the pulse locks).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheFingerHintSaysWhereTheFingerGoesTests: XCTestCase {

    private func line(live: Bool = true, flowing: Bool = true, recovery: String? = nil,
                      denied: Bool = false, other: Bool = false, cue: PulseCue = .finding,
                      latched: Bool = false) -> String? {
        PulseFingerHint.sentence(cameraLive: live, framesFlowing: flowing, recoveryHint: recovery,
                                 permissionDenied: denied, otherSourceLive: other, cue: cue,
                                 cueIsLatched: latched)
    }

    // MARK: 1 — the precedence

    func testThePrecedenceIsThePills() {
        XCTAssertEqual(line(flowing: false, recovery: "Camera paused"), "Camera paused",
                       "a camera iOS is holding gets the recovery sentence — no finger can fix it")
        XCTAssertEqual(line(live: false, denied: true), PulseCue.cameraDenied.fullHint)
        XCTAssertNil(line(live: false, denied: true, other: true),
                     "a strap already delivering: a denied camera is not the player's problem")
        XCTAssertEqual(line(cue: .holdStill), PulseCue.coverLens.fullHint,
                       "an unlatched live cue gives the ONE steady instruction, never a flickering sentence")
        XCTAssertEqual(line(cue: .stalled(hasRhythmlessSignal: false), latched: true),
                       PulseCue.stalled(hasRhythmlessSignal: false).fullHint, "a latched remedy is said in full")
        XCTAssertNil(line(cue: .locked), "the hint retires once the pulse is measured")
        XCTAssertNil(line(live: false), "nothing while the camera is not reading")
    }

    // MARK: 2 — the mount

    func testTheLeafIsMountedUnderTheFirstLine() throws {
        let studio = try code("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        guard let degraded = studio.range(of: "AudioDegradedRow()"),
              let hint = studio.range(of: "PulseFingerHint()", range: degraded.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: the hint after AudioDegradedRow()")
        }
        XCTAssertTrue(studio[degraded.upperBound..<hint.lowerBound].allSatisfy(\.isWhitespace),
                      "directly under the first line, beside the other status leaf — nothing between them")
        XCTAssertFalse(studio.contains("struct PulseFingerHint"), "the leaf lives in its own file, not in the host")
        let leaf = try code("Sources/Echoelmusic/Studio/PulseFingerHint.swift")
        XCTAssertTrue(leaf.contains("@Environment(CameraRPPGBioPublisher.self) private var cameraRPPG"),
                      "the leaf reads the publisher in its own body")
        XCTAssertTrue(leaf.contains("cueIsLatched: cameraRPPG.cueWarrantsFullHintOnScreen"),
                      "the latch is the pill's own rule (#569), not a second one")
    }

    // MARK: helpers

    private func code(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relativePath) not on disk — this run has no source tree")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
