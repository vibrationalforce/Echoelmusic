// TheCutoutIsAMatteNotAGuessTests.swift
// Echoel — #1265 (K7 of `scratchpads/PLAN_KAMERA_EINGANG_2026-09-11.md`). Blocking bundle.
//
// WHAT THIS GUARDS. The prompt's step 7 — "Segmentierung/Freistellung, wenn verfügbar" — and
// its two side clauses: where the device cannot segment the option is DISABLED, never
// simulated; and the thermal ladder is VISIBLE to the performer. Six things must hold:
// (1) BEHAVIOUR — the slot carries a matte wish per consumer (`wantsMatte()`), stores the
//     matte with its frame and drops both on clear;
// (2) SOURCE-TEXT — the publisher asks ARKit (`supportsFrameSemantics(.personSegmentation)`),
//     follows the renderer's wish AND the thermal gate at its drain with a plain `run(config)`
//     (no reset options: tracking continues), and stores `frame.segmentationBuffer` with the
//     frame — no second session, no CPU mask;
// (3) SOURCE-TEXT — the renderer binds a THIRD slot (texture(2), 1×1 white placeholder) and the
//     shader samples the matte ONLY behind `camMatte`, scaling the layer's opacity per pixel;
//     `camMatte` sits at the tail of BOTH uniform twins;
// (4) SOURCE-TEXT — the field's row disables the toggle on `supportsSegmentation`, and says so;
// (5) SOURCE-TEXT — both mounts pass `cameraCutout:` from the shared key (#431, three surfaces);
// (6) SOURCE-TEXT — `thermalRelief` is written by the publisher on change and read by BOTH the
//     numbers row and the camera row (the ladder is a state the performer sees).
// None of it proves the matte's edge or its alignment on a device — NEEDS-FOUNDER-VERIFY at
// the renderer's camera block.
//
// ⚠️ HONEST GRADING (#433/#464), transcribed in Python against the parent (3578ce0) and this
// tree. Claim 1 cannot compile against the parent (no `matte:` label, no `wantsMatte`) — per
// §3 ONE finding; claims 2–6 are RED on the parent (no `frameSemantics`, no texture(2), no
// cut-out toggle, no `thermalRelief`). Counterweight inside claim 3: the K5 gate
// `if (u.camPresent > 0.5 && u.camOpacity > 0.001) {` must survive — green on both trees.

import Foundation
import XCTest
@testable import Echoelmusic
#if canImport(CoreVideo)
import CoreVideo
#endif

final class TheCutoutIsAMatteNotAGuessTests: XCTestCase {

    private static let publisher = "Sources/Echoelmusic/Bio/FaceExpressionBioPublisher.swift"
    private static let renderer = "Sources/Echoelmusic/Views/MetalBioView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let window = "Sources/Echoelmusic/Studio/FloatingVisualWindow.swift"
    private static let stage = "Sources/Echoelmusic/Studio/ExternalDisplayScene.swift"
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

    #if canImport(CoreVideo)
    // MARK: - claim 1 (BEHAVIOUR) — the slot carries the wish and the matte

    func testTheSlotCarriesTheMatteWishAndTheMatte() throws {
        let slot = CameraFrameSlot()
        let key = UUID(), other = UUID()
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 4, 4, kCVPixelFormatType_32BGRA, nil, &pb)
        var mb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_OneComponent8, nil, &mb)
        let buffer = try XCTUnwrap(pb), matte = try XCTUnwrap(mb)
        XCTAssertFalse(slot.wantsMatte(), "nobody registered: no matte wish")
        let viewport = CameraViewport(size: CGSize(width: 390, height: 844), orientationRaw: 1)
        slot.setWanted(true, for: key, viewport: viewport)
        XCTAssertFalse(slot.wantsMatte(), "a plain wish (K5 signature) does not ask for the matte")
        slot.setWanted(true, for: other, viewport: viewport, matte: true)
        XCTAssertTrue(slot.wantsMatte(), "one consumer wanting the cut-out is enough for the producer to segment")
        slot.store(buffer, matte: matte, transforms: [key: .identity, other: .identity])
        XCTAssertNotNil(slot.latest(for: other)?.matte, "the matte rides with its frame")
        XCTAssertNotNil(slot.latest(for: key)?.matte, "the matte is per frame, not per consumer — the consumer decides whether to bind it")
        slot.store(buffer, transforms: [key: .identity, other: .identity])
        XCTAssertNil(slot.latest(for: other)?.matte, "a frame without a matte (segmentation off) carries nil — no stale matte over a new frame")
        slot.setWanted(false, for: other, viewport: viewport)
        XCTAssertFalse(slot.wantsMatte(), "the wish leaves with its consumer")
        slot.store(buffer, matte: matte, transforms: [key: .identity])
        slot.clear()
        XCTAssertNil(slot.latest(for: key), "clear drops the frame and the matte")
    }
    #endif

    // MARK: - claim 2 (SOURCE-TEXT) — the publisher asks ARKit, follows the wish and the heat

    func testThePublisherFollowsTheWishAndTheThermalLadder() throws {
        let pub = SourceText.codeOnly(try file(Self.publisher))
        for needle in ["supportsFrameSemantics(.personSegmentation)", "CameraFrameSlot.shared.wantsMatte()",
                       "config.frameSemantics = want ? [.personSegmentation] : []", "arSession.run(config)\n",
                       "matte: frame.segmentationBuffer", "thermalIsSerious", "if relief != thermalRelief { thermalRelief = relief }"] {
            XCTAssertTrue(pub.contains(needle), """
                `FaceExpressionBioPublisher` lost `\(needle)`. The matte must come from ARKit's own \
                segmentation on the SAME session (asked, never simulated), switched by a plain \
                `run(config)` so tracking continues, off at `.serious`, and the relief text must be \
                written on change so the performer sees the ladder.
                """)
        }
        XCTAssertFalse(pub.contains("arSession.run(config, options: [.resetTracking, .removeExistingAnchors])\n        segmentationOn"),
                       "the semantics toggle must not reset tracking — that flickers the face channels (K7)")
    }

    // MARK: - claim 3 (SOURCE-TEXT) — third slot, sampled only behind camMatte, twins in step

    func testTheRendererBindsTheMatteSlotAndSamplesItOnlyBehindTheFlag() throws {
        let src = try file(Self.renderer)
        XCTAssertTrue(src.contains("texture2d<float> camMatte [[texture(2)]]"), "the fragment does not declare the matte at texture(2) (K7)")
        XCTAssertTrue(src.contains("?? placeholderMatte, index: 2)"), "the matte slot can be left unbound — the 1×1 white fallback is gone (K7)")
        XCTAssertTrue(src.contains("float cut = (u.camMatte > 0.5) ? camMatte.sample(camS, iuv).r : 1.0;"),
                      "the matte is not sampled behind `camMatte` — with the placeholder bound that is fine, but a real matte under an off toggle would cut the room (K7)")
        XCTAssertTrue(src.contains("clamp(u.camOpacity, 0.0, 1.0) * cut);"), "the matte no longer scales the layer's opacity per pixel (K7)")
        // COUNTERWEIGHT — the K5 gate survives: no sample of anything without a frame.
        XCTAssertTrue(src.contains("if (u.camPresent > 0.5 && u.camOpacity > 0.001) {"), "the K5 `camPresent` gate is gone")
        XCTAssertTrue(src.contains("    var camMatte: Float = 0\n") && src.contains("float camTy;\n                      float camMatte; };"),
                      "`camMatte` must sit at the TAIL of both uniform twins (the raw-bytes law) (K7)")
        XCTAssertTrue(src.contains("kCVPixelFormatType_OneComponent8") && src.contains("cameraMatteCurrent = nil"),
                      "the matte view must check ARKit's one-component format and be dropped with its frame (K7)")
    }

    // MARK: - claim 4 (SOURCE-TEXT) — disabled, never simulated

    func testTheToggleIsDisabledWhereTheDeviceCannotSegment() throws {
        let studio = SourceText.codeOnly(try file(Self.studio))
        XCTAssertTrue(studio.contains("Toggle(isOn: $visualCameraCutout)"), "the cut-out toggle is gone from the camera row (K7)")
        XCTAssertTrue(studio.contains(".disabled(!FaceExpressionBioPublisher.supportsSegmentation)"),
                      "the toggle is not disabled on `supportsSegmentation` — the prompt says grey out, never simulate (K7)")
        XCTAssertTrue(studio.contains("\"Cut-out is not available on this device.\""), "the disabled state does not say why (K7)")
    }

    // MARK: - claim 5 (SOURCE-TEXT) — three surfaces, one key

    func testBothMountsPassTheCutoutFromTheSharedKey() throws {
        for path in [Self.window, Self.stage] {
            let src = try file(path)
            XCTAssertTrue(src.contains("StudioDefaultKeys.visualCameraCutout.key"), "\(path) does not bind `visual.camera.cutout` (K7)")
            XCTAssertTrue(src.contains("cameraCutout:"), "\(path) does not pass `cameraCutout:` to `MetalBioView(` (#431, K7)")
        }
        XCTAssertEqual(StudioDefaultKeys.visualCameraCutout.value, false, "the cut-out ships OFF")
    }

    // MARK: - claim 6 (SOURCE-TEXT) — the ladder is visible in both rows

    func testTheThermalReliefReachesBothRows() throws {
        let row = SourceText.codeOnly(try file(Self.row))
        let studio = SourceText.codeOnly(try file(Self.studio))
        XCTAssertTrue(row.contains("face.thermalRelief"), "`FaceChannelsRow` no longer shows the thermal relief (K7)")
        XCTAssertTrue(studio.contains("faceExpression.thermalRelief"), "the camera row no longer shows the thermal relief (K7)")
    }
}
