// TheFaceLossFadesNotSnapsTests.swift
// Echoel — #1259 (K3 of `scratchpads/PLAN_KAMERA_EINGANG_2026-09-11.md`). Blocking bundle.
//
// WHAT THIS GUARDS. Two ways a routed face channel used to move for no reason of the face:
//  (1) LOSS — the face leaves the picture and the publisher simply stopped publishing, so
//      the consumers held the last value for a whole freshness window (6 s) and then
//      released it — a frozen parameter, then a step. The prompt's rule: hold, then fade
//      to neutral over ~300 ms; never snap, never freeze. `FaceExpressionMapping.released`
//      is that fade and the publisher runs it (`faceLostAt`, `lossFadeCapSeconds`).
//  (2) THE FOREIGN FRAME — `EngineBus.latestBio` is one slot (#1015): every 4–5 s the
//      wrist publisher writes a `.healthKit` frame that carries no face channel, so both
//      drivers saw "unmeasured" for ≤100 ms and began a release. `FXModulation
//      .channelBridgeSeconds` holds the last reading across such a frame, in the FX driver
//      and in the matrix engine alike.
// Claims 1–2 are BEHAVIOUR on the pure core; 3–4 are SOURCE-TEXT scans of the two drivers
// and the publisher (they prove the bridge is wired, not that a device stays smooth — the
// device ask is in the publisher's header).
//
// ⚠️ HONEST GRADING (#433/#464), transcribed in Python against the parent (ebc1f98) and
// this tree. Claims 1–2 cannot compile against the parent (no `released(`); claims 3–4 are
// RED on the parent for their named reason (no bridge constant, no `lastMeasured`, no
// `faceLostAt`). The bridge-shorter-than-freshness inequality inside claim 3 is a
// COUNTERWEIGHT on the constants, green wherever both exist.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheFaceLossFadesNotSnapsTests: XCTestCase {

    private static let publisher = "Sources/Echoelmusic/Bio/FaceExpressionBioPublisher.swift"
    private static let fxDriver = "Sources/Echoelmusic/Tools/FXBioModulator.swift"
    private static let engine = "Sources/Echoelmusic/Core/ModulationEngine.swift"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func code(_ relative: String) throws -> String {
        guard let text = try? String(
            contentsOf: try repoRoot().appendingPathComponent(relative), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) — a missing anchor is a finding, not a pass.")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    // MARK: - claim 1 (BEHAVIOUR) — the release eases to 0, ~95 % within 0.3 s, monotone

    func testTheReleaseFadesToZeroWithinTheLossWindow() {
        var m = FaceExpressionMapping(deadzone: 0.06)
        for _ in 0..<100 { m = m.updated(rawSmile: 1, rawBrowRaise: 0.6, rawJawOpen: 0.3, dt: 0.1) }
        XCTAssertEqual(m.smile, 1, accuracy: 1e-3)
        var previous = m.smile
        var t = 0.0
        while t < 0.3 {
            m = m.released(dt: 0.1)
            t += 0.1
            XCTAssertLessThan(m.smile, previous, "the release must be monotone — a bump is a click")
            previous = m.smile
        }
        XCTAssertLessThan(m.smile, 0.06, "≥ 94 % of a full smile gone within 0.3 s (τ = \(FaceExpressionMapping.lossTimeConstant))")
        XCTAssertGreaterThan(m.smile, 0, "and not snapped to 0 — that is the audible step")
        for _ in 0..<20 { m = m.released(dt: 0.1) }
        XCTAssertTrue(m.isSettled, "after the cap every channel is under the settle floor")
        XCTAssertEqual(FaceExpressionMapping.lossTimeConstant, 0.1, accuracy: 1e-9)
    }

    // MARK: - claim 2 (BEHAVIOUR) — the release resets the hysteresis

    func testTheReleaseResetsTheGate() {
        var m = FaceExpressionMapping(deadzone: 0.06)
        for _ in 0..<50 { m = m.updated(rawSmile: 0.3, rawBrowRaise: 0, rawJawOpen: 0, dt: 0.1) }
        let r = m.released(dt: 10)
        XCTAssertEqual(r.smile, 0, accuracy: 1e-6)
        let back = r.updated(rawSmile: 0.045, rawBrowRaise: 0, rawJawOpen: 0, dt: 10)
        XCTAssertEqual(back.smile, 0, """
            After a release a value under the entry (0.06) re-engaged the channel — the \
            hysteresis flag survived the loss. A returning face must start from the gate.
            """)
        XCTAssertEqual(FaceExpressionMapping(deadzone: 0.06).released(dt: 1), FaceExpressionMapping(deadzone: 0.06),
                       "releasing a neutral mapping is the identity")
    }

    // MARK: - claim 3 (SOURCE-TEXT) — both drivers bridge a foreign frame, shorter than any freshness window

    func testBothDriversBridgeAForeignFrame() throws {
        XCTAssertGreaterThan(FXModulation.channelBridgeSeconds, 0)
        for source in [BioSource.faceCam, .cameraPPG, .ble, .healthKit, .fallback] {
            XCTAssertLessThan(FXModulation.channelBridgeSeconds, source.freshnessWindow, """
                The bridge (\(FXModulation.channelBridgeSeconds) s) is not shorter than \
                `\(source)`'s freshness window — a source that truly stopped would be bridged \
                past the point the bus itself calls it stale. The bridge covers a FOREIGN frame \
                (≤ 100 ms at the face's 10 Hz, ≤ 1 s at the strap's), never a loss.
                """)
        }
        let fx = try code(Self.fxDriver)
        for needle in ["lastMeasured[source] = (v, uptime)", "FXModulation.channelBridgeSeconds", "signal = held.value"] {
            XCTAssertTrue(fx.contains(needle), """
                `FXBioModulator` lost `\(needle)`. Without the bridge every route on a channel \
                the wrist frame does not carry releases for 0.25 s every 4–5 s (#1015 × \
                `FXRouteFade`) — a periodic dip the player did not make.
                """)
        }
        let engine = try code(Self.engine)
        for needle in ["lastMeasuredAt[route.source] = frame.timestamp", "FXModulation.channelBridgeSeconds", "lastRouteValue[route.id] = value"] {
            XCTAssertTrue(engine.contains(needle), """
                `ModulationEngine` lost `\(needle)`. `ModulationMatrix.output(for:frame:)` does \
                NOT gate on `isMeasured` (documented at `range`), so a foreign frame reads the \
                channel as 0 for one tick — on the tempo route that is a 100 ms lurch toward \
                the floor every 4–5 s.
                """)
        }
    }

    // MARK: - claim 4 (SOURCE-TEXT) — the publisher fades on loss and then falls silent

    func testThePublisherFadesThenFallsSilent() throws {
        let pub = try code(Self.publisher)
        for needle in ["faceLostAt = now", "mapping.released(dt: dt)", "lossFadeCapSeconds", "isFaceTracked = false", "publishFrame(bus: bus, at: now)"] {
            XCTAssertTrue(pub.contains(needle), """
                `FaceExpressionBioPublisher` lost `\(needle)`. Loss is a STATE: fade the channels \
                to 0 over ~0.3 s while still publishing, then stop — a publisher that just stops \
                freezes every route for the freshness window and then steps.
                """)
        }
        XCTAssertEqual(pub.components(separatedBy: "bus.publish(bio: BioSampleFrame(").count - 1, 1,
                       "ONE frame shape (`publishFrame`) for tracked and fading takes — two literals drift (#416)")
        XCTAssertLessThan(FaceExpressionBioPublisher.lossFadeCapSeconds, BioSource.faceCam.freshnessWindow)
    }
}
