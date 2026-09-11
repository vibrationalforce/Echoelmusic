// TheGestureChannelsReachTheWireTests.swift
// Echoel — #1260 (K4a of `scratchpads/PLAN_KAMERA_EINGANG_2026-09-11.md`). Blocking bundle.
//
// WHAT THIS GUARDS. The face take grew from three channels to twelve (brow down, blink,
// squint, pucker, cheeks, head turn/nod/tilt/distance), and each of them must be
// (1) a `ModSource` with a producer, measured by PROVENANCE (`.faceCam`), so the two
//     route pickers offer exactly the channels a face take carries;
// (2) on the wire under `/echoelmusic/gesture/<ModSource>` — on a face frame only, never
//     leaking into a `/bio/*` integrator's batch from a pulse source;
// (3) normalised honestly: head angles CENTRED at 0.5, gated on their distance from rest,
//     a calibration persisted before #1260 still decoding (a missing key is identity).
// Claims 1–4 are BEHAVIOUR on the shipped types; claim 5 is a SOURCE-TEXT scan of the law
// file's OSC list and the publisher's head-pose keys. None of it proves a head turn reads
// as a turn on a device — that sign convention is the device ask at
// `FaceGestureChannel.yawFullScaleRadians`.
//
// ⚠️ HONEST GRADING (#433/#464), transcribed in Python against the parent (d2fe686) and
// this tree. Claims 1–4 cannot compile against the parent (no `faceChannels`, no
// `FaceGestureChannel`, no `gestureAddress`) — per §3 ONE finding; claim 5 is RED on the
// parent (no gesture line in `CLAUDE.md`, no `head.yaw` key). The pulse-frame half of
// claim 2 is a COUNTERWEIGHT: green on both trees.
//
// K6a (#1264) — the body's five channels (hand heights, hands apart, shoulder tilt, presence)
// ride the same face session, so the WIRE set is `ModSource.gestureChannels` (face + body,
// 17) and the producing total is 5 + 12 + 5; `FaceGestureChannel` has 14 cases and the
// shoulder tilt joins the centred three. `faceChannels` itself stays 12 — the face presets
// (#1261) are written against it. The body's own claims: `TheBodyChannelsRideTheFaceSessionTests`.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheGestureChannelsReachTheWireTests: XCTestCase {

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

    private func frame(_ source: BioSource, smile: Float = 0.4, yaw: Float = 0.8) -> BioSampleFrame {
        BioSampleFrame(timestamp: 1, heartRateBPM: source == .faceCam ? 0 : 70,
                       hrvNormalized: 0, breathRate: 0, breathPhase: 0, coherence: 0,
                       motionEnergy: 0, source: source, faceSmile: smile, headYaw: yaw)
    }

    // MARK: - claim 1 (BEHAVIOUR) — twelve channels, all producing, measured by provenance

    func testTwelveFaceChannelsProduceAndGateOnProvenance() {
        XCTAssertEqual(ModSource.faceChannels.count, 12)
        XCTAssertEqual(Set(ModSource.faceChannels).count, 12, "no channel listed twice")
        for source in ModSource.faceChannels {
            XCTAssertTrue(source.hasProducer, "`\(source)` has a producer since #1257/#1260 — a hidden producing channel is the #215 lie inverted")
            XCTAssertTrue(source.isMeasured(in: frame(.faceCam)), "`\(source)` is measured on a `.faceCam` frame")
            XCTAssertFalse(source.isMeasured(in: frame(.cameraPPG)), "`\(source)` must NOT read as measured on a pulse frame — provenance is the gate")
            XCTAssertEqual(source.range, 0...1, "every face channel is a [0..1] control value")
            XCTAssertFalse(source.displayName.isEmpty)
            XCTAssertFalse(source.displayName.lowercased().contains("emotion"), "movement, never a feeling")
        }
        XCTAssertEqual(ModSource.headYaw.rawValue(from: frame(.faceCam, yaw: 0.8)), 0.8, accuracy: 1e-6)
        XCTAssertEqual(ModSource.allCases.filter(\.hasProducer).count, 5 + 12 + 5,
                       "the pickers offer the five pulse/breath channels plus the twelve face and five body channels (#1264) — motion stays out (#215)")
    }

    // MARK: - claim 2 (BEHAVIOUR) — on the wire, face frames only

    func testTheGestureAddressesRideOnlyOnAFaceFrame() {
        let face = OSCSender.bioMessages(for: frame(.faceCam))
        XCTAssertEqual(face.first?.address, "/echoelmusic/bio/synthetic", "provenance first, as on every non-empty batch (#639)")
        XCTAssertEqual(face.first?.floats, [0], "a face is a real body")
        let gesture = face.filter { $0.address.hasPrefix("/echoelmusic/gesture/") }
        XCTAssertEqual(gesture.count, 17, "all twelve face and five body channels go out on a face frame (#1264)")
        XCTAssertEqual(Set(gesture.map(\.address)), Set(ModSource.gestureChannels.map(OSCSender.gestureAddress)))
        XCTAssertEqual(gesture.first(where: { $0.address == "/echoelmusic/gesture/faceSmile" })?.floats, [0.4])
        XCTAssertEqual(gesture.first(where: { $0.address == "/echoelmusic/gesture/headYaw" })?.floats, [0.8])
        XCTAssertFalse(face.contains { $0.address == "/echoelmusic/bio/heart/bpm" }, "a face frame carries no pulse, so no BPM goes out")
        // COUNTERWEIGHT — a pulse frame never carries a gesture address.
        let pulse = OSCSender.bioMessages(for: frame(.cameraPPG))
        XCTAssertFalse(pulse.contains { $0.address.hasPrefix("/echoelmusic/gesture/") },
                       "a `/bio/*` integrator on a pulse take must never see a gesture channel it did not ask for")
        XCTAssertEqual(OSCSender.gestureAddress(.headDistance), "/echoelmusic/gesture/headDistance")
    }

    // MARK: - claim 3 (BEHAVIOUR) — head angles are centred, distance is a window

    func testHeadPoseIsCentredAndDistanceIsAWindow() {
        XCTAssertEqual(FaceGestureChannel.headYaw.rawValue(from: [:]), 0.5, "no pose in the bag reads as rest")
        XCTAssertEqual(FaceGestureChannel.headYaw.rawValue(from: [FaceGestureChannel.headYawKey: 0]), 0.5)
        XCTAssertEqual(FaceGestureChannel.headYaw.rawValue(from: [FaceGestureChannel.headYawKey: FaceGestureChannel.yawFullScaleRadians]), 1, accuracy: 1e-6)
        XCTAssertEqual(FaceGestureChannel.headYaw.rawValue(from: [FaceGestureChannel.headYawKey: -FaceGestureChannel.yawFullScaleRadians]), 0, accuracy: 1e-6)
        XCTAssertEqual(FaceGestureChannel.headYaw.rawValue(from: [FaceGestureChannel.headYawKey: .nan]), 0.5, "NaN reads as rest")
        XCTAssertEqual(FaceGestureChannel.headDistance.rawValue(from: [FaceGestureChannel.headDistanceKey: FaceGestureChannel.nearMetres]), 0)
        XCTAssertEqual(FaceGestureChannel.headDistance.rawValue(from: [FaceGestureChannel.headDistanceKey: FaceGestureChannel.farMetres]), 1)
        XCTAssertEqual(FaceGestureChannel.eyeBlink.rawValue(from: ["eyeBlinkLeft": 1, "eyeBlinkRight": 0]), 0.5, "both eyes averaged")
        XCTAssertEqual(FaceGestureChannel.allCases.count, 14, "nine face gestures + five body channels (#1264)")
        XCTAssertEqual(FaceGestureChannel.allCases.filter(\.isCentered).map(\.rawValue), ["headYaw", "headPitch", "headRoll", "shoulderTilt"])
        // The bank: a tiny off-centre wobble stays at rest (0.5); a real turn moves; loss returns to 0.5.
        var bank = FaceGestureBank(deadzone: 0.06)
        for _ in 0..<50 { bank = bank.updated(raw: FaceGestureChannel.allCases.map { $0 == .headYaw ? 0.52 : $0.neutral }, dt: 0.1) }
        XCTAssertEqual(bank[.headYaw], 0.5, "a 0.02 wobble around rest is under the centred deadzone")
        for _ in 0..<50 { bank = bank.updated(raw: FaceGestureChannel.allCases.map { $0 == .headYaw ? 0.1 : $0.neutral }, dt: 0.1) }
        XCTAssertLessThan(bank[.headYaw], 0.2, "a turn to one side reads below rest")
        for _ in 0..<50 { bank = bank.released(dt: 0.1) }
        XCTAssertTrue(bank.isSettled, "loss eases every channel back to its rest value")
        XCTAssertEqual(bank[.headYaw], 0.5, accuracy: 0.005)
    }

    // MARK: - claim 4 (BEHAVIOUR) — calibration re-centres, and a pre-#1260 record still loads

    func testTheCalibrationRecentresAndDecodesOldRecords() throws {
        var c = FaceCalibration.identity
        c.gestureBaselines = [FaceGestureChannel.headYaw.rawValue: 0.6, FaceGestureChannel.browDown.rawValue: 0.2]
        let raw = FaceGestureChannel.allCases.map { ch -> Float in
            switch ch { case .headYaw: return 0.6; case .browDown: return 0.2; default: return ch.neutral }
        }
        let out = c.applyGestures(raw)
        XCTAssertEqual(out[FaceGestureChannel.allCases.firstIndex(of: .headYaw)!], 0.5, accuracy: 1e-6, "the calibrated neutral head pose reads exactly 0.5")
        XCTAssertEqual(out[FaceGestureChannel.allCases.firstIndex(of: .browDown)!], 0, accuracy: 1e-6, "the calibrated resting brow reads 0")
        XCTAssertFalse(c.isIdentity)
        let old = Data("{\"smileBaseline\":0.1,\"browBaseline\":0,\"jawBaseline\":0}".utf8)
        let decoded = try JSONDecoder().decode(FaceCalibration.self, from: old)
        XCTAssertEqual(decoded.smileBaseline, 0.1, accuracy: 1e-6)
        XCTAssertTrue(decoded.gestureBaselines.isEmpty, "a record persisted before #1260 loads with identity gesture baselines")
        let round = try JSONDecoder().decode(FaceCalibration.self, from: try JSONEncoder().encode(c))
        XCTAssertEqual(round, c)
    }

    // MARK: - claim 5 (SOURCE-TEXT) — the law file lists the namespace; the publisher writes the pose keys

    func testTheLawFileAndThePublisherNameTheChannels() throws {
        let law = try file("CLAUDE.md")
        XCTAssertTrue(law.contains("/echoelmusic/gesture/"), """
            `CLAUDE.md`'s OSC address set does not list `/echoelmusic/gesture/…`. That list is \
            the one an integrator (and the website) is written from; an address on the wire \
            that the register does not know is #1260's own #416.
            """)
        let pub = SourceText.codeOnly(try file(Self.publisher))
        for needle in ["FaceGestureChannel.headYawKey", "FaceGestureChannel.headDistanceKey", "simd_inverse(camera)", "gestures[.headYaw]"] {
            XCTAssertTrue(pub.contains(needle), """
                `FaceExpressionBioPublisher` lost `\(needle)`. The head pose must be derived \
                RELATIVE TO THE CAMERA (world anchor × inverse camera transform) and reach the \
                frame through the bank — otherwise holding the phone off-axis reads as a turn.
                """)
        }
    }
}
