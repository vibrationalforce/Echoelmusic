// ANonFinitePanCentresTheLaneTests.swift
// Echoel — overnight P8 (2026-09-25). Blocking bundle.
//
// ⭐ THE DEFECT. The live lane-pan path ends at three sinks: `BioReactiveSynthVoice.setPan`
// maps a non-finite pan to centre (`pan.isFinite ? pan : 0`); `PolySynthVoice.setPan` and
// `TimelineAudioSink.setPan` clamped with a bare `max(-1, min(1, pan))`. `min(1, NaN)` is 1,
// because every comparison with NaN is false, so a NaN pan landed HARD RIGHT, and the sink
// also stored it for every later region start. One boundary, two rules (#416), and in both
// files the gain setter right beside it already guarded `isFinite`.
//
// ⚠️ LATENT, NOT LIVE — measured, not assumed. The pan arrives from `TimelineLane.pan` in a
// decoded document (`JSONDecoder` throws on NaN), and `TimelineStore.setLanePan` has no
// production caller (`TheTimelineStoresLiveSurfaceTests`). This closes the boundary for the
// next producer.
//
// ⚠️ HONEST GRADING (transcribed in Python against both trees; no toolchain, §0).
//   · claim 1 — END-TO-END BEHAVIOUR on `PolySynthVoice` (reads the public `sourceNode.pan`,
//     the same read `BodyVibeBioRackTests` makes on the bio voice). REGRESSION: on the parent,
//     NaN and +inf land at 1 and -inf at -1.
//   · claim 2 — COUNTERWEIGHT, same voice: finite values land, out-of-range values clamp.
//     Green on both trees.
//   · claim 3 — SOURCE-TEXT SCAN on `TimelineAudioSink.setPan` (its `pan` is `private`, and the
//     sink needs an engine to own nodes). REGRESSION: the parent's body has no `isFinite`.
//   · Not executed (no toolchain); what `Build for Testing` proves is compilation only. Whether
//     an unattached `AVAudioSourceNode` reports the pan it was given is the premise of claims 1
//     and 2; claim 2 fails loudly if it does not.

import XCTest
@testable import Echoelmusic

@MainActor
final class ANonFinitePanCentresTheLaneTests: XCTestCase {

    /// claim 1 — a non-finite pan centres the poly voice instead of sending it hard right.
    func testTheMelodicVoiceCentresANonFinitePan() {
        let voice = PolySynthVoice(maxVoices: 1)
        for poison: Float in [.nan, .infinity, -.infinity] {
            voice.setPan(0.5)
            voice.setPan(poison)
            XCTAssertEqual(voice.sourceNode.pan, 0, accuracy: 0.0001, """
                `PolySynthVoice.setPan(\(poison))` did not centre the voice. A bare \
                `max(-1, min(1, pan))` sends NaN to HARD RIGHT (`min(1, NaN)` is 1). Map \
                non-finite to 0 first, as `BioReactiveSynthVoice.setPan` does (#416).
                """)
        }
    }

    /// claim 2 — COUNTERWEIGHT: finite values still land and still clamp to −1…1.
    func testTheMelodicVoiceStillPansAndClamps() {
        let voice = PolySynthVoice(maxVoices: 1)
        voice.setPan(0.5)
        XCTAssertEqual(voice.sourceNode.pan, 0.5, accuracy: 0.0001)
        voice.setPan(5)
        XCTAssertEqual(voice.sourceNode.pan, 1, accuracy: 0.0001)
        voice.setPan(-5)
        XCTAssertEqual(voice.sourceNode.pan, -1, accuracy: 0.0001)
    }

    /// claim 3 — the audio-lane sink takes the same rule (source-text; its `pan` is private).
    func testTheAudioLaneSinkCentresANonFinitePan() throws {
        let code = try source("Sources/Echoelmusic/Sequencer/TimelineAudioSink.swift")
        guard let head = code.range(of: "func setPan(_ pan: Float) {"),
              let end = code.range(of: "func detach()", range: head.upperBound..<code.endIndex) else {
            XCTFail("`TimelineAudioSink.setPan` or the `detach()` after it moved — re-anchor (#454).")
            return
        }
        let body = code[head.upperBound..<end.lowerBound]
        XCTAssertTrue(body.contains("pan.isFinite ? pan : 0"), """
            `TimelineAudioSink.setPan` clamps without a finite check. `min(1, NaN)` is 1, so a \
            NaN pan lands hard right and is stored for every later region start. Its own \
            `setGain` one member up maps non-finite to silent; pan maps it to centre (#416).
            """)
    }

    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let path = root.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("source tree not present at \(path.path)")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
