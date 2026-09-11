// TheBodyChannelsRideTheFaceSessionTests.swift
// Echoel — #1264 (K6a of `scratchpads/PLAN_KAMERA_EINGANG_2026-09-11.md`). Blocking bundle.
//
// WHAT THIS GUARDS. The prompt's body half — hand heights, hands apart, shoulder tilt,
// presence — arrives as five more channels on the SAME front-camera session (Vision on
// `ARFrame.capturedImage`, own queue, drop policy, thermal gate), never as a second camera
// owner. Five things must hold:
// (1) BEHAVIOUR — `BodyPoseMath.bag(from:)`: a joint that was not seen writes NO key (the
//     bank then eases that channel to rest — loss as a state), presence is the ONE key
//     always written, distance is scaled by `handDistanceFullScale`, tilt is a signed angle,
//     and a non-finite joint writes nothing;
// (2) BEHAVIOUR — the five `FaceGestureChannel` body cases are `isBody`, read their neutral
//     from an empty bag (0, and 0.5 for the CENTRED tilt), and the bank moves them like any
//     face channel and releases them to rest;
// (3) BEHAVIOUR — the five `ModSource` body channels produce, gate on `.faceCam` provenance,
//     are [0..1], sit in `gestureChannels` after the twelve face ones, and go out under
//     `/echoelmusic/gesture/<name>` on a face frame with the frame's value;
// (4) SOURCE-TEXT — one owner: the analyzer constructs no capture session, the face
//     publisher hands it the ARKit frame (`analyze(frame.capturedImage)`), reads the body slot
//     with an AGE (`read(maxAge:`), skips the body in the neutral hold (`where !ch.isBody`),
//     and the analyzer carries the drop flag, the stride and the thermal gate;
// (5) SOURCE-TEXT — the numbers row shows the body line (`"Hand L"`, `bodyPresence`).
// (6) K6c (#1266) — BEHAVIOUR + SOURCE-TEXT: the Vision orientation follows the INTERFACE
//     orientation through one pure table (`BodyPoseMath.visionOrientationRaw`), portrait =
//     `.right` (6) as K6a hard-wired, and the publisher pushes it to the analyzer on change.
// None of it proves chirality, scale or sign on a device — those are the four asks at
// `BodyPoseAnalyzer`'s header (NEEDS-FOUNDER-VERIFY #1264).
//
// ⚠️ HONEST GRADING (#433/#464), transcribed in Python against the parent (e26c116) and this
// tree. Claims 1–3 cannot compile against the parent (no `BodyPoseMath`, no body cases) — per
// §3 ONE finding; claims 4–5 are RED on the parent (no analyzer file, no `read(maxAge:`, no
// `"Hand L"`). No counterweight is possible here beyond claim 3's pulse-frame half.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheBodyChannelsRideTheFaceSessionTests: XCTestCase {

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

    private func frame(_ source: BioSource, handL: Float = 0.7, tilt: Float = 0.5) -> BioSampleFrame {
        BioSampleFrame(timestamp: 1, heartRateBPM: source == .faceCam ? 0 : 70,
                       hrvNormalized: 0, breathRate: 0, breathPhase: 0, coherence: 0,
                       motionEnergy: 0, source: source, handHeightL: handL, shoulderTilt: tilt)
    }

    // MARK: - claim 1 (BEHAVIOUR) — a missing joint writes no key; presence always does

    func testAMissingJointWritesNoKeyAndPresenceAlwaysDoes() {
        let empty = BodyPoseMath.bag(from: BodyPoseSample())
        XCTAssertEqual(empty, [BodyPoseMath.bodyPresenceKey: 0], "nothing seen: only presence, and it is 0")
        let oneHand = BodyPoseMath.bag(from: BodyPoseSample(leftWrist: SIMD2(0.3, 0.8), bodyConfidence: 0.9))
        XCTAssertEqual(oneHand[BodyPoseMath.handHeightLKey], 0.8, "a wrist's y IS its height (Vision: origin bottom-left, y up)")
        XCTAssertNil(oneHand[BodyPoseMath.handHeightRKey], "the unseen hand writes no key — the bank eases it to rest")
        XCTAssertNil(oneHand[BodyPoseMath.handDistanceKey], "distance needs BOTH wrists")
        XCTAssertNil(oneHand[BodyPoseMath.shoulderTiltKey], "tilt needs BOTH shoulders")
        XCTAssertEqual(oneHand[BodyPoseMath.bodyPresenceKey], 1)
        let both = BodyPoseMath.bag(from: BodyPoseSample(leftWrist: SIMD2(0.1, 0.5), rightWrist: SIMD2(0.5, 0.5),
                                                          leftShoulder: SIMD2(0.3, 0.6), rightShoulder: SIMD2(0.7, 0.6),
                                                          bodyConfidence: 0.5))
        XCTAssertEqual(both[BodyPoseMath.handDistanceKey] ?? -1, 0.4 / BodyPoseMath.handDistanceFullScale, accuracy: 1e-5)
        XCTAssertEqual(both[BodyPoseMath.shoulderTiltKey] ?? -1, 0, accuracy: 1e-6, "level shoulders: tilt 0 rad")
        let lean = BodyPoseMath.bag(from: BodyPoseSample(leftShoulder: SIMD2(0.3, 0.5), rightShoulder: SIMD2(0.7, 0.9)))
        XCTAssertGreaterThan(lean[BodyPoseMath.shoulderTiltKey] ?? 0, 0, "right shoulder higher: positive angle (signed, the bank centres it)")
        let wide = BodyPoseMath.bag(from: BodyPoseSample(leftWrist: SIMD2(0, 0), rightWrist: SIMD2(1, 1)))
        XCTAssertEqual(wide[BodyPoseMath.handDistanceKey], 1, "clamped at 1 beyond full scale")
        let nan = BodyPoseMath.bag(from: BodyPoseSample(leftWrist: SIMD2(0.2, .nan), bodyConfidence: .nan))
        XCTAssertNil(nan[BodyPoseMath.handHeightLKey], "a non-finite joint writes nothing")
        XCTAssertEqual(nan[BodyPoseMath.bodyPresenceKey], 0, "a non-finite confidence is no body")
        XCTAssertEqual(BodyPoseMath.bag(from: BodyPoseSample(bodyConfidence: BodyPoseMath.presenceConfidence))[BodyPoseMath.bodyPresenceKey], 1)
    }

    // MARK: - claim 2 (BEHAVIOUR) — the body cases in the bank

    func testTheBodyCasesAreUncalibratedAndRestAtTheirNeutral() {
        let body: [FaceGestureChannel] = [.handHeightL, .handHeightR, .handDistance, .shoulderTilt, .bodyPresence]
        XCTAssertEqual(FaceGestureChannel.allCases.filter(\.isBody), body, "exactly the five, appended at the END of the case list (persisted baselines index by order)")
        XCTAssertEqual(Array(FaceGestureChannel.allCases.suffix(5)), body)
        for ch in body {
            XCTAssertEqual(ch.rawValue(from: [:]), ch.neutral, "`\(ch)` reads its neutral from an empty bag")
        }
        XCTAssertTrue(FaceGestureChannel.shoulderTilt.isCentered, "tilt is centred: 0.5 = level")
        XCTAssertEqual(FaceGestureChannel.shoulderTilt.rawValue(from: [BodyPoseMath.shoulderTiltKey: FaceGestureChannel.shoulderTiltFullScaleRadians]), 1, accuracy: 1e-6)
        XCTAssertEqual(FaceGestureChannel.shoulderTilt.rawValue(from: [BodyPoseMath.shoulderTiltKey: -FaceGestureChannel.shoulderTiltFullScaleRadians]), 0, accuracy: 1e-6)
        XCTAssertEqual(FaceGestureChannel.handHeightL.rawValue(from: [BodyPoseMath.handHeightLKey: 0.9]), 0.9)
        XCTAssertFalse(FaceGestureChannel.headYaw.isBody)
        // Calibration never touches the body: a baseline under a body key is ignored.
        var c = FaceCalibration.identity
        c.gestureBaselines = [FaceGestureChannel.handHeightL.rawValue: 0.5]
        let raw = FaceGestureChannel.allCases.map { $0 == .handHeightL ? Float(0.9) : $0.neutral }
        let out = c.applyGestures(raw)
        XCTAssertEqual(out[FaceGestureChannel.allCases.firstIndex(of: .handHeightL)!], 0.9, accuracy: 1e-6,
                       "a body key in a persisted calibration must not re-centre an ABSOLUTE channel (`isBody`)")
        // The bank: a raised hand rises, a lost body eases every body channel to rest.
        var bank = FaceGestureBank(deadzone: 0.06)
        for _ in 0..<50 { bank = bank.updated(raw: FaceGestureChannel.allCases.map { $0 == .handHeightL ? 0.9 : $0.neutral }, dt: 0.1) }
        XCTAssertGreaterThan(bank[.handHeightL], 0.8)
        XCTAssertEqual(bank[.shoulderTilt], 0.5, "level shoulders stay at rest")
        for _ in 0..<50 { bank = bank.updated(raw: FaceGestureChannel.allCases.map(\.neutral), dt: 0.1) }
        XCTAssertLessThan(bank[.handHeightL], 0.05, "a missing hand key eases the channel to rest through the ordinary update")
        for _ in 0..<50 { bank = bank.released(dt: 0.1) }
        XCTAssertTrue(bank.isSettled)
    }

    // MARK: - claim 3 (BEHAVIOUR) — five ModSources, provenance-gated, on the wire

    func testTheFiveBodySourcesProduceAndRideTheGestureNamespace() {
        XCTAssertEqual(ModSource.bodyChannels.count, 5)
        XCTAssertEqual(ModSource.gestureChannels, ModSource.faceChannels + ModSource.bodyChannels)
        XCTAssertEqual(Set(ModSource.gestureChannels).count, 17, "twelve face + five body, none twice")
        for source in ModSource.bodyChannels {
            XCTAssertTrue(source.hasProducer, "`\(source)` has a producer since #1264")
            XCTAssertTrue(source.isMeasured(in: frame(.faceCam)))
            XCTAssertFalse(source.isMeasured(in: frame(.cameraPPG)), "provenance is the gate — a pulse frame carries no body")
            XCTAssertEqual(source.range, 0...1)
            XCTAssertFalse(ModSource.faceChannels.contains(source), "the face presets route face channels only (#1261)")
            let lower = source.displayName.lowercased()
            XCTAssertFalse(lower.contains("emotion") || lower.contains("posture") || lower.contains("mood"), "movement, never an inferred state")
        }
        XCTAssertEqual(ModSource.handHeightL.rawValue(from: frame(.faceCam, handL: 0.7)), 0.7, accuracy: 1e-6)
        XCTAssertEqual(ModSource.shoulderTilt.rawValue(from: frame(.faceCam, tilt: 0.25)), 0.25, accuracy: 1e-6)
        let face = OSCSender.bioMessages(for: frame(.faceCam, handL: 0.7))
        XCTAssertEqual(face.first(where: { $0.address == "/echoelmusic/gesture/handHeightL" })?.floats, [0.7])
        XCTAssertEqual(face.first(where: { $0.address == "/echoelmusic/gesture/bodyPresence" })?.floats, [0])
        let pulse = OSCSender.bioMessages(for: frame(.cameraPPG, handL: 0.7))
        XCTAssertFalse(pulse.contains { $0.address.hasPrefix("/echoelmusic/gesture/") }, "COUNTERWEIGHT — a pulse frame never carries a gesture address")
    }

    // MARK: - claim 4 (SOURCE-TEXT) — one owner, aged slot, uncalibrated body, drop + thermal

    func testTheAnalyzerRidesTheFaceSessionWithDropAndThermalGate() throws {
        let analyzer = SourceText.codeOnly(try file(Self.analyzer))
        for forbidden in ["AVCaptureSession(", "ARSession(", "AVCaptureMultiCamSession"] {
            XCTAssertFalse(analyzer.contains(forbidden), """
                `BodyPoseAnalyzer` constructs `\(forbidden)`. The body reads the FACE session's \
                frames (prompt rule 1: ONE front-camera owner per mode) — a second capture \
                session steals the lens from ARKit and both go dark.
                """)
        }
        for needle in ["thermalState", "busy", "frameStride", "orientation: orientation", "VNDetectHumanHandPoseRequest", "VNDetectHumanBodyPoseRequest"] {
            XCTAssertTrue(analyzer.contains(needle), """
                `BodyPoseAnalyzer` lost `\(needle)`. The pass must keep its drop flag, its \
                stride, its thermal gate at `.serious`, the portrait orientation and both \
                Vision requests — the prompt's rule 1c and its thermal clause.
                """)
        }
        let pub = SourceText.codeOnly(try file(Self.publisher))
        for needle in ["analyze(frame.capturedImage)", "read(maxAge:", "where !ch.isBody", "bodyStaleSeconds", "handHeightL: gestures[.handHeightL]", "bodyPresence: gestures[.bodyPresence]"] {
            XCTAssertTrue(pub.contains(needle), """
                `FaceExpressionBioPublisher` lost `\(needle)`. The body must be fed from the \
                ARKit frame delegate, read from its slot with an AGE (a thermal stop eases the \
                channels to rest instead of freezing a pose), skipped in the neutral hold, and \
                reach the `.faceCam` frame through the bank.
                """)
        }
    }

    // MARK: - claim 6 (BEHAVIOUR + SOURCE-TEXT) — the orientation follows the interface

    func testTheVisionOrientationFollowsTheInterface() throws {
        XCTAssertEqual(BodyPoseMath.visionOrientationRaw(forInterfaceOrientationRaw: 1), 6, "portrait reads the sensor buffer `.right` — K6a's constant, now the table's default")
        XCTAssertEqual(BodyPoseMath.visionOrientationRaw(forInterfaceOrientationRaw: 0), 6, "unknown is portrait, the instrument's posture")
        XCTAssertEqual(BodyPoseMath.visionOrientationRaw(forInterfaceOrientationRaw: 2), 8, "upside-down portrait reads `.left`")
        XCTAssertEqual(BodyPoseMath.visionOrientationRaw(forInterfaceOrientationRaw: 3), 3, "landscape left reads `.down`")
        XCTAssertEqual(BodyPoseMath.visionOrientationRaw(forInterfaceOrientationRaw: 4), 1, "landscape right reads `.up`")
        XCTAssertEqual(Set([0, 1, 2, 3, 4].map(BodyPoseMath.visionOrientationRaw(forInterfaceOrientationRaw:))), [1, 3, 6, 8], "four distinct readings — no two postures share one")
        let analyzer = SourceText.codeOnly(try file(Self.analyzer))
        XCTAssertTrue(analyzer.contains("func setInterfaceOrientation(raw: Int)") && analyzer.contains("CGImagePropertyOrientation(rawValue: orientationRaw) ?? .right"),
                      "the analyzer no longer takes the interface orientation, or falls back to something other than portrait (K6c)")
        let pub = SourceText.codeOnly(try file(Self.publisher))
        XCTAssertTrue(pub.contains("bodyAnalyzer?.setInterfaceOrientation(raw: raw)") && pub.contains("guard raw != pushedOrientationRaw else { return }"),
                      "the publisher does not push the interface orientation on change (K6c)")
    }

    // MARK: - claim 5 (SOURCE-TEXT) — the numbers row shows the body line

    func testTheNumbersRowShowsTheBodyLine() throws {
        let row = SourceText.codeOnly(try file(Self.row))
        for needle in ["\"Hand L\"", "\"Hand R\"", "\"Apart\"", "\"Tilt\"", "face.bodyPresence"] {
            XCTAssertTrue(row.contains(needle), """
                `FaceChannelsRow` lost `\(needle)`. The body channels are numbers in the same \
                leaf as the face ones (science-first, and the freeze law keeps the 10 Hz read \
                out of the menu host).
                """)
        }
    }
}
