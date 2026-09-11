// TheFaceChannelsAreCalibratedTests.swift
// Echoel — #1258 (K2 of `scratchpads/PLAN_KAMERA_EINGANG_2026-09-11.md`). Blocking bundle.
//
// WHAT THIS GUARDS. Raw ARKit blendShape values are not musically usable: a resting face
// reads a person- and light-dependent offset, and a still face flickers by hundredths. K2
// puts three stages in front of the EMA — a NEUTRAL-hold calibration (`FaceCalibration`,
// per-channel baseline, span floored), a DEADZONE WITH HYSTERESIS (`FaceExpressionMapping
// .gate`), and the numbers row that shows the result (`FaceChannelsRow`, a LEAF under the
// source chooser). Claims 1–3 are BEHAVIOUR on the pure core (the strong kind, §1); 4–6 are
// SOURCE-TEXT scans: they prove where the row sits and who reads the publisher, never that
// a face produces a quiet number — that is the device ask in the publisher's header.
//
// ⚠️ HONEST GRADING (#433/#464), transcribed in Python against the parent (0f5212f) and
// this tree. Claims 1–3 cannot compile against the parent (no `FaceCalibration`, no
// `deadzone:` label) — per §3 ONE finding. Claims 4–6 are RED on the parent for their named
// reason (no leaf file, no mount, no `calibrate(` / `smile =` in the publisher). One
// COUNTERWEIGHT inside claim 6: the publisher still writes `breathPhase: 0` — green on both
// trees, pinned because two sibling guards read that literal from this very file.
//
// ⚠️ #364 — nothing here forbids re-tuning `defaultDeadzone` or the span floor; the
// numbers are named constants and the claims test the SHAPE (identity, monotone, gated),
// not the value.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheFaceChannelsAreCalibratedTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let leaf = "Sources/Echoelmusic/Studio/FaceChannelsRow.swift"
    private static let publisher = "Sources/Echoelmusic/Bio/FaceExpressionBioPublisher.swift"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func file(_ relative: String) throws -> String {
        guard let text = try? String(
            contentsOf: try repoRoot().appendingPathComponent(relative), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) — a missing anchor is a finding, not a pass.")
            return ""
        }
        return text
    }

    private func slice(_ text: String, from: String, to: String) -> String {
        guard let a = text.range(of: from), let b = text.range(of: to, range: a.upperBound..<text.endIndex)
        else { return "" }
        return String(text[a.upperBound..<b.lowerBound])
    }

    // MARK: - claim 1 (BEHAVIOUR) — identity is raw, a baseline subtracts, the span floors

    func testTheCalibrationMapsNeutralToZeroAndFullToOne() {
        let id = FaceCalibration.identity
        XCTAssertTrue(id.isIdentity)
        XCTAssertEqual(id.apply(smile: 0.37, browRaise: 0.5, jawOpen: 1).smile, 0.37, accuracy: 1e-6,
                       "the un-calibrated state must map raw to raw — otherwise a fresh install already differs from the tracker")
        let c = FaceCalibration(smileBaseline: 0.3, browBaseline: 0, jawBaseline: 0.9)
        XCTAssertFalse(c.isIdentity)
        let out = c.apply(smile: 0.3, browRaise: 0, jawOpen: 0.9)
        XCTAssertEqual(out.smile, 0, accuracy: 1e-6, "the neutral hold IS zero after calibration")
        XCTAssertEqual(out.jawOpen, 0, accuracy: 1e-6)
        XCTAssertEqual(c.apply(smile: 1, browRaise: 1, jawOpen: 1).smile, 1, accuracy: 1e-6,
                       "a full ARKit excursion still reaches 1 (span = 1 − baseline)")
        XCTAssertEqual(c.apply(smile: 0.65, browRaise: 0, jawOpen: 0).smile, 0.5, accuracy: 1e-6,
                       "halfway between neutral and full reads 0.5")
        // Span floor: baseline 0.9 would leave a span of 0.1; the floor (0.2) keeps a
        // tracker fault from turning a hundredth of movement into a full-scale jump.
        XCTAssertEqual(c.apply(smile: 0, browRaise: 0, jawOpen: 1).jawOpen, 0.5, accuracy: 1e-6,
                       "span is floored at `FaceCalibration.minimumSpan` (0.2): (1 − 0.9) / 0.2 = 0.5")
        XCTAssertEqual(c.apply(smile: .nan, browRaise: 0, jawOpen: 0).smile, 0,
                       "NaN at the boundary reads as no expression, never propagates")
        XCTAssertEqual(c.apply(smile: 0.1, browRaise: 0, jawOpen: 0).smile, 0,
                       "below the baseline clamps to 0, never negative")
    }

    // MARK: - claim 2 (BEHAVIOUR) — the neutral hold is a mean; an empty hold writes nothing

    func testTheNeutralHoldBecomesTheBaseline() {
        let c = FaceCalibration.fromNeutral(smile: [0.2, 0.4], browRaise: [], jawOpen: [0.1, .nan, 0.3])
        XCTAssertEqual(c.smileBaseline, 0.3, accuracy: 1e-6)
        XCTAssertEqual(c.browBaseline, 0, "a channel with no samples keeps identity")
        XCTAssertEqual(c.jawBaseline, 0.2, accuracy: 1e-6, "non-finite samples are dropped, not averaged")
        XCTAssertTrue(FaceCalibration.fromNeutral(smile: [], browRaise: [], jawOpen: []).isIdentity,
                      "a hold that produced no frames cannot write a calibration from nothing")
        // Codable round trip — the publisher persists exactly this.
        if let data = try? JSONEncoder().encode(c),
           let back = try? JSONDecoder().decode(FaceCalibration.self, from: data) {
            XCTAssertEqual(back, c)
        } else {
            XCTFail("FaceCalibration must round-trip through JSON — that is how it survives a relaunch")
        }
    }

    // MARK: - claim 3 (BEHAVIOUR) — the deadzone gates flicker and does not chatter

    func testTheDeadzoneHoldsAStillFaceAtZero() {
        var m = FaceExpressionMapping(deadzone: 0.06)
        for _ in 0..<100 { m = m.updated(rawSmile: 0.05, rawBrowRaise: 0.059, rawJawOpen: 0.02, dt: 0.1) }
        XCTAssertEqual(m.smile, 0, "tracker flicker under the deadzone must read exactly 0")
        XCTAssertEqual(m.browRaise, 0)
        XCTAssertEqual(m.jawOpen, 0)
        // A deliberate movement passes and rises monotonically toward 1.
        for _ in 0..<100 { m = m.updated(rawSmile: 1, rawBrowRaise: 0.2, rawJawOpen: 0, dt: 0.1) }
        XCTAssertEqual(m.smile, 1, accuracy: 1e-3)
        XCTAssertGreaterThan(m.browRaise, 0.1)
        // Hysteresis: once active, a value between the exit (0.03) and the entry (0.06)
        // stays active; only under the exit does the channel drop back to 0.
        var h = FaceExpressionMapping(deadzone: 0.06)
        for _ in 0..<50 { h = h.updated(rawSmile: 0.2, rawBrowRaise: 0, rawJawOpen: 0, dt: 0.1) }
        let active = h.updated(rawSmile: 0.045, rawBrowRaise: 0, rawJawOpen: 0, dt: 10)
        XCTAssertGreaterThan(active.smile, 0, "0.045 sits between exit and entry: an ACTIVE channel keeps reading it")
        let released = active.updated(rawSmile: 0.02, rawBrowRaise: 0, rawJawOpen: 0, dt: 10)
        XCTAssertEqual(released.smile, 0, accuracy: 1e-4, "under the exit the channel releases")
        let stillOff = released.updated(rawSmile: 0.045, rawBrowRaise: 0, rawJawOpen: 0, dt: 10)
        XCTAssertEqual(stillOff.smile, 0, "0.045 from an INACTIVE channel does not re-enter — that is the hysteresis")
        // Deadzone 0 is the pure EMA the 2026-07 tests pin — unchanged behaviour.
        var plain = FaceExpressionMapping()
        for _ in 0..<100 { plain = plain.updated(rawSmile: 0.05, rawBrowRaise: 0, rawJawOpen: 0, dt: 0.1) }
        XCTAssertEqual(plain.smile, 0.05, accuracy: 1e-3, "deadzone 0 passes the raw value through (the pre-#1258 contract)")
        XCTAssertEqual(FaceExpressionMapping.defaultDeadzone, 0.06)
    }

    // MARK: - claim 4 (SOURCE-TEXT) — the numbers row sits under the chooser, as a leaf

    func testTheNumbersRowIsALeafUnderTheChooser() throws {
        let studio = try file(Self.studio)
        for anchor in ["\n            bioSourceRow\n", "\n            FaceChannelsRow()\n", "AlwaysOnBioPanelStrip()"] {
            XCTAssertEqual(studio.components(separatedBy: anchor).count - 1, 1,
                           "bioPanel anchor `\(anchor.trimmingCharacters(in: .whitespacesAndNewlines))` not unique — re-anchor (#408).")
        }
        if let chooser = studio.range(of: "\n            bioSourceRow\n"),
           let row = studio.range(of: "\n            FaceChannelsRow()\n"),
           let strip = studio.range(of: "AlwaysOnBioPanelStrip()") {
            XCTAssertTrue(chooser.upperBound <= row.lowerBound && row.upperBound <= strip.lowerBound, """
                `FaceChannelsRow()` is mounted outside the window chooser → row → always-on \
                strip. The numbers belong directly under the control that picks the face; \
                move the row and this scan together.
                """)
        }
        // The freeze law: the HOST reads nothing of the 10 Hz publisher in `bioPanel`.
        let panel = slice(studio, from: "private var bioPanel: some View {", to: "\n    }\n")
        XCTAssertFalse(panel.isEmpty, "bioPanel slice empty — re-anchor (#454).")
        XCTAssertFalse(SourceText.codeOnly(panel).contains("faceExpression."), """
            `bioPanel` reads `faceExpression.` directly. That publisher writes three values at \
            10 Hz; a read in the menu host's body rebuilds the whole host and tears down any \
            open Picker (10.76.41/50). The read belongs in `FaceChannelsRow`, the leaf.
            """)
    }

    // MARK: - claim 5 (SOURCE-TEXT) — the leaf reads the publisher itself and shows numbers

    func testTheLeafReadsThePublisherItself() throws {
        let leaf = SourceText.codeOnly(try file(Self.leaf))
        XCTAssertTrue(leaf.contains("@Environment(FaceExpressionBioPublisher.self)"),
                      "the leaf must own the publisher read — a value passed down from the host is the host reading it")
        XCTAssertTrue(leaf.contains("EchoelDecimalText.string("),
                      "numbers first: the channels render through the one decimal formatter, not a gauge")
        XCTAssertTrue(leaf.contains("face.calibrate()"),
                      "the calibration door is in the row — a calibration nobody can start is a constant")
        XCTAssertFalse(leaf.lowercased().contains("emotion") || leaf.lowercased().contains("mood"),
                       "the row names movement, never a feeling (EU AI Act framing)")
    }

    // MARK: - claim 6 (SOURCE-TEXT) — the publisher calibrates, gates, persists, and still says 0 breath

    func testThePublisherCalibratesAndPersists() throws {
        let pub = SourceText.codeOnly(try file(Self.publisher))
        for needle in ["public func calibrate(", "FaceCalibration.defaultsKey", "calibration.apply(",
                       "FaceExpressionMapping.defaultDeadzone", "smile = mapping.smile"] {
            XCTAssertTrue(pub.contains(needle), """
                `FaceExpressionBioPublisher` lost `\(needle)`. The chain is raw → calibration → \
                deadzone/EMA → observable channel → bus; remove a stage and either the numbers \
                row or the routes read something the other does not.
                """)
        }
        XCTAssertTrue(pub.contains("breathPhase: 0"),
                      "COUNTERWEIGHT: the face frame still carries no breath — two sibling guards read this literal here")
    }
}
