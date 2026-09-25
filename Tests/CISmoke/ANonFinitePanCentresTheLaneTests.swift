// ANonFinitePanCentresTheLaneTests.swift
// Echoel — overnight P8 (2026-09-25). Blocking bundle.
//
// ⭐ THE DEFECT. A lane's pan is decided in TWO layers, and the first version of this slice
// (890837252) fixed only the second one — the review of it caught that (overnight P8b).
//   · THE BOUNDARY — where `TimelineLane.pan` is read: `MultiRollFanout.pan(forSlot:)` (every
//     melodic rack voice), `AudioLanePlayer.clampedPan` (every audio lane), the store's writer
//     `TimelineStore.setLanePan`, and `TimelineDocument.rollSlotPan` (the `rollSlotGain` mirror
//     for pan; no production reader today). All four clamped with a bare `max(-1, min(1, p))`,
//     and `min(1, NaN)` is 1 (every comparison with NaN is false), so a NaN lane played — or was
//     stored — HARD RIGHT.
//     ⛔ The first version of this header said "three" and "every site", and missed
//     `rollSlotPan` — found by the review of f2bef146d. A list of readers is a claim about the
//     WHOLE tree: `git grep -n "\.pan\b" -- Sources` and read EVERY hit before trusting it.
//   · THE SINKS — `PolySynthVoice.setPan` and `TimelineAudioSink.setPan` had the same bare clamp,
//     while `BioReactiveSynthVoice.setPan` already mapped non-finite to centre. One decision,
//     two rules (#416). On the live path the sinks only ever receive the boundary's output, so
//     fixing the sinks ALONE delivered nothing: a NaN arrived there already as 1.0.
// Every site now maps non-finite to 0 before the clamp.
//
// ⚠️ LATENT, NOT LIVE — measured, not assumed. `TimelineLane.pan` arrives from a decoded
// document (`JSONDecoder` throws on NaN), and `TimelineStore.setLanePan` has no production
// caller (`TheTimelineStoresLiveSurfaceTests`). This closes the boundary for the next producer.
//
// ⚠️ HONEST GRADING (transcribed in Python against both trees; no toolchain, §0).
//   · claim 1 — END-TO-END BEHAVIOUR on `PolySynthVoice` (reads the public `sourceNode.pan`,
//     the same read `BodyVibeBioRackTests` makes on the bio voice). REGRESSION against the tree
//     before 890837252: NaN and +inf land at 1 and -inf at -1.
//   · claim 2 — COUNTERWEIGHT, same voice: finite values land, out-of-range values clamp.
//     Green on every tree.
//   · claim 3 — SOURCE-TEXT SCAN on `TimelineAudioSink.setPan` (its `pan` is `private`, and the
//     sink needs an engine to own nodes). REGRESSION against the tree before 890837252.
//   · claim 4 — END-TO-END BEHAVIOUR on the pure `MultiRollFanout.pan(forSlot:)` over a real
//     `TimelineDocument`. REGRESSION on the parent of this commit (NaN and +inf read 1, -inf
//     reads -1); its finite rows are counterweights, green on both trees.
//   · claim 5 — SOURCE-TEXT SCAN on `AudioLanePlayer.clampedPan` (private) and
//     `TimelineStore.setLanePan` (`@MainActor`, persists to disk). REGRESSION on the parent of
//     this commit. One finding across claims 4 and 5: one rule missing at three sites (#486).
//   · claim 6 — END-TO-END BEHAVIOUR on the pure `TimelineDocument.rollSlotPan`. REGRESSION on
//     the tree before its repair (NaN and +inf read 1, -inf reads -1); the finite rows are
//     counterweights. Same finding as claims 4 and 5 — its fourth site.
//   · Not executed (no toolchain); what `Build for Testing` proves is compilation only. Whether
//     an unattached `AVAudioSourceNode` reports the pan it was given is the premise of claims 1
//     and 2 — its only precedent is in the non-blocking suite (#208) — and claim 2 fails loudly
//     if it does not.

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

    /// claim 4 — the melodic boundary: a non-finite LANE pan resolves to centre for its slot.
    func testTheRackSlotPanCentresANonFiniteLane() {
        let roll = TimelineLane(name: "MIDI 1", kind: .midi)
        let poisoned: [Float] = [.nan, .infinity, -.infinity]
        var lanes: [TimelineLane] = [roll]
        for (i, p) in poisoned.enumerated() {
            lanes.append(TimelineLane(name: "MIDI \(i + 2)", kind: .midi, pan: p))
        }
        lanes.append(TimelineLane(name: "MIDI 5", kind: .midi, pan: 0.5))
        lanes.append(TimelineLane(name: "MIDI 6", kind: .midi, pan: 3))
        let doc = TimelineDocument(lanes: lanes, regions: [])
        for (slot, p) in poisoned.enumerated() {
            XCTAssertEqual(MultiRollFanout.pan(forSlot: slot, in: doc, rollLane: roll.id), 0, """
                `MultiRollFanout.pan(forSlot:)` did not centre a lane whose pan is \(p). This is \
                the boundary every melodic voice's pan comes through: a bare \
                `Swift.max(-1, Swift.min(1, p))` resolves NaN to 1 before any sink sees it.
                """)
        }
        // Counterweights: a finite pan lands, an out-of-range one clamps.
        XCTAssertEqual(MultiRollFanout.pan(forSlot: 3, in: doc, rollLane: roll.id), 0.5)
        XCTAssertEqual(MultiRollFanout.pan(forSlot: 4, in: doc, rollLane: roll.id), 1)
    }

    /// claim 5 — the audio-lane boundary and the store's writer take the same rule.
    func testTheAudioLaneBoundaryAndTheStoreCentreANonFinitePan() throws {
        let player = try source("Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift")
        let store = try source("Sources/Echoelmusic/Core/TimelineStore.swift")
        let sites: [(label: String, code: String, head: String, tail: String, needle: String)] = [
            ("AudioLanePlayer.clampedPan", player,
             "private func clampedPan(in doc: TimelineDocument, laneID: UUID) -> Float {",
             "private func sink(for laneID: UUID)", "p.isFinite ? p : 0"),
            ("TimelineStore.setLanePan", store,
             "public func setLanePan(id: UUID, _ pan: Float) {",
             "persist()", "pan.isFinite ? pan : 0"),
        ]
        for (label, code, head, tail, needle) in sites {
            guard let h = code.range(of: head),
                  let t = code.range(of: tail, range: h.upperBound..<code.endIndex) else {
                XCTFail("`\(label)` or the member after it moved — re-anchor (#454).")
                continue
            }
            XCTAssertTrue(code[h.upperBound..<t.lowerBound].contains(needle), """
                `\(label)` clamps a lane pan without a finite check. `min(1, NaN)` is 1, so a NaN \
                lane plays (or is stored) hard right. Map non-finite to 0 before the clamp, as \
                `MultiRollFanout.pan(forSlot:)` and both sinks do (#416).
                """)
        }
    }

    /// claim 6 — the roll slot's own pan mirror takes the same rule.
    func testTheRollSlotPanCentresANonFiniteLane() {
        for poison: Float in [.nan, .infinity, -.infinity] {
            let doc = TimelineDocument(lanes: [TimelineLane(name: "MIDI 1", kind: .midi, pan: poison)],
                                       regions: [])
            XCTAssertEqual(doc.rollSlotPan, 0, """
                `rollSlotPan` for a lane whose pan is \(poison) is not centre. It is the \
                `rollSlotGain` mirror for pan, and a bare `max(-1, min(1, pan))` reads NaN as \
                hard right — the rule `MultiRollFanout.pan(forSlot:)` already refuses (#416).
                """)
        }
        // Counterweights: a finite pan lands, an out-of-range one clamps.
        let half = TimelineDocument(lanes: [TimelineLane(name: "MIDI 1", kind: .midi, pan: -0.5)],
                                    regions: [])
        XCTAssertEqual(half.rollSlotPan, -0.5)
        let wide = TimelineDocument(lanes: [TimelineLane(name: "MIDI 1", kind: .midi, pan: 3)],
                                    regions: [])
        XCTAssertEqual(wide.rollSlotPan, 1)
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
