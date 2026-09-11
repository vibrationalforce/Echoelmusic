// TheTrackingRateIsAChoiceNotAConstantTests.swift
// Echoel — #1267 (K7b of `scratchpads/PLAN_KAMERA_EINGANG_2026-09-11.md`). Blocking bundle.
//
// WHAT THIS GUARDS. The prompt's load clause: "Tracking-Rate konfigurierbar (60/30/15 Hz),
// Standard 30 Hz" and "Kameratextur in reduzierter Auflösung". Four things must hold:
// (1) BEHAVIOUR — the pure core: default 30, the pick takes the wanted rate at the FEWEST
//     pixels and returns nil when no format has it (no invented rate), the offered list is
//     what ARKit has (distinct, highest first), the body stride keeps ~15 passes/s;
// (2) SOURCE-TEXT — the publisher applies the pick to `config.videoFormat` at start and
//     re-runs the same configuration on a change (no reset options), and hands the running
//     rate to the body analyzer;
// (3) SOURCE-TEXT — the analyzer's stride is set from the rate, not a literal;
// (4) SOURCE-TEXT — the numbers row offers the rate as a segmented `Picker` (a named choice)
//     bound to the shared key, only when the device offers more than one.
// None of it proves that 30 Hz sounds like 60 on a device — that is the founder's ear
// (prompt: "wenn 60 nichts hörbar verbessert").
//
// ⚠️ HONEST GRADING (#433/#464), transcribed in Python against the parent (7c8c0e8) and this
// tree. Claim 1 cannot compile against the parent (no `FaceTrackingRate`) — per §3 ONE
// finding; claims 2–4 are RED on the parent (no `videoFormat`, a literal stride, no picker).
// Counterweight in claim 2: the K7 segmentation toggle still uses `arSession.run(config)`.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTrackingRateIsAChoiceNotAConstantTests: XCTestCase {

    private static let publisher = "Sources/Echoelmusic/Bio/FaceExpressionBioPublisher.swift"
    private static let analyzer = "Sources/Echoelmusic/Bio/BodyPoseAnalyzer.swift"
    private static let row = "Sources/Echoelmusic/Studio/FaceChannelsRow.swift"

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

    // MARK: - claim 1 (BEHAVIOUR) — the pure core

    func testTheCorePicksTheWantedRateAtTheFewestPixelsAndInventsNothing() {
        XCTAssertEqual(FaceTrackingRate.defaultHz, 30, "the shipped default is 30 Hz (prompt)")
        XCTAssertEqual(StudioDefaultKeys.faceTrackingHz.value, FaceTrackingRate.defaultHz, "the key's default IS the core's default — one number")
        let formats: [(hz: Int, pixels: Int)] = [(60, 1920 * 1080), (30, 1920 * 1080), (60, 1280 * 720), (30, 1280 * 720)]
        XCTAssertEqual(FaceTrackingRate.pick(from: formats, wantHz: 30), 3, "30 Hz at 720p — the fewest pixels for the wanted rate")
        XCTAssertEqual(FaceTrackingRate.pick(from: formats, wantHz: 60), 2)
        XCTAssertNil(FaceTrackingRate.pick(from: formats, wantHz: 15), "a rate no format has is NOT picked — ARKit's default stays, nothing is invented")
        XCTAssertNil(FaceTrackingRate.pick(from: [], wantHz: 30))
        XCTAssertEqual(FaceTrackingRate.offered(from: [60, 30, 60, 30, 0, -1]), [60, 30], "distinct, highest first, nothing non-positive")
        XCTAssertEqual(FaceTrackingRate.offered(from: []), [])
        XCTAssertEqual(FaceTrackingRate.stride(forCaptureHz: 60), 4, "60 → every 4th frame ≈ 15 passes/s (the K6a stride)")
        XCTAssertEqual(FaceTrackingRate.stride(forCaptureHz: 30), 2)
        XCTAssertEqual(FaceTrackingRate.stride(forCaptureHz: 15), 1)
        XCTAssertEqual(FaceTrackingRate.stride(forCaptureHz: 0), 1, "a degenerate rate never yields a zero stride (modulo by zero)")
    }

    // MARK: - claim 2 (SOURCE-TEXT) — the publisher applies and re-applies the pick

    func testThePublisherAppliesThePickAndFollowsAChange() throws {
        let pub = SourceText.codeOnly(try file(Self.publisher))
        for needle in ["if let format = Self.videoFormat(forHz: appliedTrackingHz) { config.videoFormat = format }",
                       "body.setCaptureHz(config.videoFormat.framesPerSecond)",
                       "FaceTrackingRate.pick(from: shapes, wantHz: hz)",
                       "availableTrackingRates.contains(hz) ? hz : StudioDefaultKeys.faceTrackingHz.value",
                       "guard want != appliedTrackingHz, let format = Self.videoFormat(forHz: want) else { return }",
                       "bodyAnalyzer?.setCaptureHz(format.framesPerSecond)",
                       "syncTrackingRate()"] {
            XCTAssertTrue(pub.contains(needle), """
                `FaceExpressionBioPublisher` lost `\(needle)`. The tracking rate must be applied \
                through the pure pick at start, re-applied from the drain on a change, guarded \
                against a rate ARKit does not offer, and handed to the body analyzer (K7b).
                """)
        }
        XCTAssertEqual(pub.components(separatedBy: "arSession.run(config)\n").count - 1, 2,
                       "two plain `run(config)` sites — the K7 semantics toggle and the K7b rate change; neither resets tracking")
    }

    // MARK: - claim 3 (SOURCE-TEXT) — the stride is derived

    func testTheAnalyzerStrideIsDerivedFromTheRate() throws {
        let analyzer = SourceText.codeOnly(try file(Self.analyzer))
        XCTAssertTrue(analyzer.contains("private var frameStride = FaceTrackingRate.stride(forCaptureHz: 60)"), "the stride is a literal again (K7b)")
        XCTAssertTrue(analyzer.contains("func setCaptureHz(_ hz: Int)") && analyzer.contains("frameCounter % frameStride == 0"),
                      "the analyzer no longer takes the capture rate, or does not use the derived stride (K7b)")
        XCTAssertFalse(analyzer.contains("static let frameStride = 4"), "the K6a literal stride is back (K7b)")
    }

    // MARK: - claim 4 (SOURCE-TEXT) — a named choice in the numbers row

    func testTheRowOffersTheRateAsANamedChoice() throws {
        let row = SourceText.codeOnly(try file(Self.row))
        XCTAssertTrue(row.contains("@AppStorage(StudioDefaultKeys.faceTrackingHz.key)"), "the row does not bind the shared rate key (K7b)")
        XCTAssertTrue(row.contains("Picker(\"Tracking rate\", selection: $trackingHz)") && row.contains(".pickerStyle(.segmented)"),
                      "the rate is not a segmented `Picker` — it is a named choice among the device's formats, never a number field (K7b)")
        XCTAssertTrue(row.contains("if FaceExpressionBioPublisher.availableTrackingRates.count > 1 {"),
                      "the picker must hide where ARKit offers one rate — a one-entry choice is a lie (K7b)")
        XCTAssertFalse(row.contains("EchoelValueField(label: \"Tracking"), "a rate as a number field would offer 47 Hz — not a device format (K7b)")
    }
}
