// ANonFiniteLaneLevelIsSilentTests.swift
// Echoel — overnight P8b (2026-09-25). Blocking bundle.
//
// ⭐ THE DEFECT. `TimelineDocument.effectiveGain(for:)` is the ONE gain rule for a lane: every
// melodic rack slot (`MultiRollFanout.gain(forSlot:)`) and every audio lane (`AudioLanePlayer`,
// three sites) multiplies by it. It clamped with `max(0, min(2, lane.level))`, and `min(2, NaN)`
// is 2 (every comparison with NaN is false), so a NaN level played at DOUBLE gain, +6 dB — the
// loud direction. The gain SINKS (`PolySynthVoice.setGain`, `TimelineAudioSink.setGain`) already
// map a non-finite gain to silence, and they never saw the NaN: the boundary had turned it into
// 2.0 first. This is the pan lesson of f2bef146d (`ANonFinitePanCentresTheLaneTests`), found by
// walking the sibling field up to where it is decided.
// Non-finite now means silent at the boundary, and the two members that say they MIRROR the
// gain rule — `rollSlotSilenceReason` and `unsilenceRollSlot()` — take the same reading, so a
// lane the gain rule silences is never reported audible and the one-tap repair can lift it.
// The store's writer `TimelineStore.setLaneLevel` would STORE 2.0 for NaN; it now stores 0.
//
// ⚠️ LATENT, NOT LIVE — measured, not assumed. `TimelineLane.level` arrives from a decoded
// document (`JSONDecoder` throws on NaN), and `setLaneLevel` has no production caller
// (`TheTimelineStoresLiveSurfaceTests`). This closes the boundary for the next producer.
//
// ⚠️ HONEST GRADING (transcribed in Python against both trees; no toolchain, §0).
//   · claims 1–3 are END-TO-END BEHAVIOUR on the pure `TimelineDocument` value type, and
//     REGRESSIONS on the parent: NaN and +inf gain read 2, the NaN silence reason reads nil,
//     and `unsilenceRollSlot()` leaves NaN in place. One finding — one rule missing at the
//     boundary and its two stated mirrors (#486). The -inf rows are counterweights (0 on both).
//   · claim 4 is a COUNTERWEIGHT: every finite level, mute and foreign solo behaves exactly as
//     before, on both trees.
//   · claim 5 is a SOURCE-TEXT SCAN on `TimelineStore.setLaneLevel` (`@MainActor`, persists to
//     disk). REGRESSION on the parent.
//   · Not executed (no toolchain); what `Build for Testing` proves is compilation only.

import XCTest
@testable import Echoelmusic

final class ANonFiniteLaneLevelIsSilentTests: XCTestCase {

    /// A document whose first non-bio MIDI lane (the roll slot) has `level`.
    private func doc(level: Float, muted: Bool = false, otherSoloed: Bool = false)
        -> (TimelineDocument, UUID) {
        let lane = TimelineLane(name: "MIDI 1", kind: .midi, level: level, isMuted: muted)
        let other = TimelineLane(name: "MIDI 2", kind: .midi, isSoloed: otherSoloed)
        return (TimelineDocument(lanes: [lane, other], regions: []), lane.id)
    }

    /// claim 1 — the gain rule silences a non-finite level instead of doubling it.
    func testANonFiniteLevelPlaysSilentNotDouble() {
        let poisoned: [Float] = [.nan, .infinity, -.infinity]
        for level in poisoned {
            let (d, id) = doc(level: level)
            XCTAssertEqual(d.effectiveGain(for: id), 0, """
                `effectiveGain` for a lane whose level is \(level) is not 0. The bare \
                `max(0, min(2, level))` resolves NaN (and +inf) to 2 — double gain — upstream of \
                gain sinks that would have silenced it. Refuse non-finite before the clamp.
                """)
        }
    }

    /// claim 2 — the silence explanation agrees with the gain rule it mirrors.
    func testTheSilenceReasonNamesANonFiniteLevel() {
        let (d, _) = doc(level: .nan)
        XCTAssertEqual(d.rollSlotSilenceReason, .levelZero, """
            A NaN roll-slot level is silent under `effectiveGain`, but `rollSlotSilenceReason` \
            reports it audible (`NaN <= 0.001` is false). The reason must mirror the gain rule.
            """)
    }

    /// claim 3 — the one-tap repair lifts a non-finite level back to unity.
    func testUnsilenceLiftsANonFiniteLevel() {
        let made = doc(level: .nan)
        var d = made.0
        let id = made.1
        d.unsilenceRollSlot()
        XCTAssertEqual(d.effectiveGain(for: id), 1, """
            `unsilenceRollSlot()` left a NaN level in place, so the "make it audible" action \
            could not repair the silence it was offered for.
            """)
    }

    /// claim 4 — COUNTERWEIGHT: finite levels, mute and solo behave exactly as before.
    func testEveryFiniteLevelBehavesAsBefore() {
        let (half, halfID) = doc(level: 0.5)
        XCTAssertEqual(half.effectiveGain(for: halfID), 0.5)
        XCTAssertNil(half.rollSlotSilenceReason)
        let (loud, loudID) = doc(level: 3)
        XCTAssertEqual(loud.effectiveGain(for: loudID), 2)
        let (neg, negID) = doc(level: -1)
        XCTAssertEqual(neg.effectiveGain(for: negID), 0)
        XCTAssertEqual(neg.rollSlotSilenceReason, .levelZero)
        let (muted, mutedID) = doc(level: 1, muted: true)
        XCTAssertEqual(muted.effectiveGain(for: mutedID), 0)
        XCTAssertEqual(muted.rollSlotSilenceReason, .muted)
        let (soloed, soloedID) = doc(level: 1, otherSoloed: true)
        XCTAssertEqual(soloed.effectiveGain(for: soloedID), 0)
        XCTAssertEqual(soloed.rollSlotSilenceReason, .otherSoloed)
        let silent = doc(level: 0)
        var zero = silent.0
        let zeroID = silent.1
        zero.unsilenceRollSlot()
        XCTAssertEqual(zero.effectiveGain(for: zeroID), 1)
    }

    /// claim 5 — the store's writer stores silence, not double gain (source-text).
    func testTheStoreWriterRefusesANonFiniteLevel() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent("Sources/Echoelmusic/Core/TimelineStore.swift")
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("source tree not present at \(path.path)")
        }
        let code = SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
        guard let head = code.range(of: "public func setLaneLevel(id: UUID, _ level: Float) {"),
              let tail = code.range(of: "persist()", range: head.upperBound..<code.endIndex) else {
            XCTFail("`TimelineStore.setLaneLevel` or its `persist()` moved — re-anchor (#454).")
            return
        }
        XCTAssertTrue(code[head.upperBound..<tail.lowerBound].contains("level.isFinite"), """
            `TimelineStore.setLaneLevel` clamps without a finite check. `min(2, NaN)` is 2, so a \
            NaN level would be STORED as double gain. Refuse non-finite, as `effectiveGain` does.
            """)
    }
}
