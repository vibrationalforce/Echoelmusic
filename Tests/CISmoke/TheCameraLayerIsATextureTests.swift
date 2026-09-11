//
//  TheCameraLayerIsATextureTests.swift
//  Echoelmusic — CISmoke
//
//  K5 (#1262) — the front camera's image is a TEXTURE LAYER in the Metal field, fed by the ONE
//  ARSession that already tracks the face, and never part of a recorded take.
//
//  WHAT THIS PINS.
//  1. ONE OWNER of the front camera (prompt rule 1): `ARSession(` is constructed in exactly one
//     production file, and `AVCaptureSession(` in exactly one — the rear-lens rPPG capture.
//     No `AVCaptureMultiCamSession` anywhere in `Sources/`.
//  2. THE SHADER SAMPLES ONLY BEHIND `camPresent`, and both texture slots are ALWAYS bound
//     (two `setFragmentTexture` calls with placeholder fallbacks) — Metal's validation never
//     meets an empty declared slot, and an absent camera costs no sample.
//  3. A RECORDED TAKE NEVER CONTAINS THE CAMERA: the `wantsCapture` branch snaps `camOpacity`
//     to 0 and drops the texture pair — the camera-usage sentence ("No images are stored")
//     stays true with the recorder running.
//  4. THE #1244 SKIP SEES A NEW FRAME: the record after the drawable guard writes
//     `lastEncodedCameraSequence`, so identical uniforms cannot hide a changed camera image.
//  5. BOTH MOUNTS PASS THE TRIO from the shared keys (`cameraOpacity:` at the two `MetalBioView(`
//     sites; the three `visualCamera*` keys bound in both surfaces) — the three-surface rule.
//  6. THE SLOT, by behaviour: nothing is stored while nobody wants a frame; a registered
//     consumer gets the buffer with ITS transform and a moving sequence; `clear()` drops it.
//     (`CameraFrame` needs CoreVideo; the claim is compiled where it is available.)
//  7. `Package.swift` still declares no dependency — the layer is AVFoundation/ARKit/CoreVideo/
//     Metal only, as the prompt requires.
//  8. THE DOOR (K5b, #1263): one `Camera layer` row, blend as a Picker, mirror as a Toggle,
//     mounted once in `visualPanel` behind `isSupported` and the Metal-field condition.
//
//  ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`87d09bc`) and this tree: claims
//  2, 3, 4 and 5 RED on the parent, GREEN here (claim 8 RED on `5bbec8d`, GREEN with K5b);
//  claims 1 and 7 GREEN on both (counterweights,
//  they fail the day a second session or a dependency appears); claim 6 is behavioural on a
//  pure lock-protected class and was NOT run here (no toolchain). Whether the image stands the
//  right way up, mirrored, and fills the field is a device question (NEEDS-FOUNDER-VERIFY at
//  the renderer's camera block) — no gate here can see it.
//

import Foundation
import XCTest
#if canImport(CoreVideo)
import CoreVideo
#endif
@testable import Echoelmusic

final class TheCameraLayerIsATextureTests: XCTestCase {

    private static let renderer = "Sources/Echoelmusic/Views/MetalBioView.swift"
    private static let publisher = "Sources/Echoelmusic/Bio/FaceExpressionBioPublisher.swift"
    private static let window = "Sources/Echoelmusic/Studio/FloatingVisualWindow.swift"
    private static let stage = "Sources/Echoelmusic/Studio/ExternalDisplayScene.swift"

    /// Claim 1 — one owner per lens: one `ARSession(`, one `AVCaptureSession(`, no multi-cam.
    func testTheFrontCameraHasOneOwner() throws {
        let files = try swiftSources()
        let arOwners = files.filter { codeOnly($0.text).contains("ARSession(") }.map(\.path)
        XCTAssertEqual(arOwners, [Self.publisher], """
            `ARSession(` is constructed in \(arOwners) — the front camera must have exactly ONE \
            owner, the face publisher, whose session also feeds `CameraFrameSlot` (K5).
            """)
        let avOwners = files.filter { codeOnly($0.text).contains("AVCaptureSession(") }.map(\.path)
        XCTAssertEqual(avOwners, ["Sources/Echoelmusic/Video/CameraCapture.swift"], """
            `AVCaptureSession(` is constructed in \(avOwners) — only the rear-lens rPPG capture \
            may own a capture session; the camera LAYER reads `ARFrame.capturedImage`, never a \
            second session on the front lens (prompt rule 1).
            """)
        let multi = files.filter { codeOnly($0.text).contains("AVCaptureMultiCamSession") }.map(\.path)
        XCTAssertTrue(multi.isEmpty, "AVCaptureMultiCamSession appears in \(multi) — forbidden by the camera-input prompt")
    }

    /// Claim 2 — the fragment declares both slots, samples only behind `camPresent`, and the
    /// encoder always binds both (placeholders when no frame).
    func testTheShaderSamplesOnlyBehindCamPresentAndBothSlotsAreAlwaysBound() throws {
        let src = try text(Self.renderer)
        XCTAssertTrue(src.contains("texture2d<float> camY [[texture(0)]]")
                      && src.contains("texture2d<float> camCbCr [[texture(1)]]"),
                      "the fragment no longer declares the two camera planes at texture(0)/texture(1) (K5)")
        XCTAssertTrue(src.contains("if (u.camPresent > 0.5 && u.camOpacity > 0.001) {"),
                      "the camera sample is not gated on `camPresent` — with a placeholder bound that is a black layer, not a missing one (K5)")
        XCTAssertEqual(occurrences("encoder.setFragmentTexture(", in: src), 2,
                       "expected exactly two `setFragmentTexture(` calls (Y and CbCr), always executed on the encode path (K5)")
        XCTAssertTrue(src.contains("?? placeholderY, index: 0)") && src.contains("?? placeholderCbCr, index: 1)"),
                      "a camera slot can be left unbound — the placeholder fallback is gone (K5)")
    }

    /// Claim 3 — the recorder never gets the camera.
    func testARecordedTakeNeverContainsTheCamera() throws {
        let src = try text(Self.renderer)
        guard let branch = src.range(of: "        if wantsCapture {\n            // The snap, see above.") else {
            return XCTFail("the `if wantsCapture {` camera branch is gone from draw(in:) — re-anchor (K5)")
        }
        let body = String(src[branch.upperBound...].prefix(400))
        XCTAssertTrue(body.contains("cameraTexturesCurrent = nil") && body.contains("uniforms.camOpacity = 0"),
                      "a take in flight no longer drops the camera pair and snaps the opacity to 0 — the mp4 would carry the face (K5)")
    }

    /// Claim 4 — the encoded record carries the camera sequence.
    func testTheSkipRecordCarriesTheCameraSequence() throws {
        let src = try text(Self.renderer)
        guard let record = src.range(of: "        lastEncodedUniforms = uniforms\n        hasEncodedOnce = true\n") else {
            return XCTFail("the encoded-uniforms record is gone — re-anchor (#1244/K5)")
        }
        let after = String(src[record.upperBound...].prefix(120))
        XCTAssertTrue(after.contains("lastEncodedCameraSequence = cameraSequenceThisFrame"),
                      "the record does not store the camera sequence — a new camera frame with settled uniforms would be skipped (K5)")
    }

    /// Claim 5 — both mounts pass the trio from the shared keys.
    func testBothMountsPassTheCameraTrioFromTheSharedKeys() throws {
        for path in [Self.window, Self.stage] {
            let src = try text(path)
            XCTAssertTrue(src.contains("StudioDefaultKeys.visualCameraOpacity.key")
                          && src.contains("StudioDefaultKeys.visualCameraMirror.key")
                          && src.contains("StudioDefaultKeys.visualCameraBlend.key"),
                          "\(path) no longer binds the three `visual.camera.*` keys — that surface renders the struct fallback (K5)")
            XCTAssertTrue(src.contains("cameraOpacity: Float("),
                          "\(path) does not pass `cameraOpacity:` to `MetalBioView(` — the layer is unreachable there (#431, K5)")
        }
    }

    #if canImport(CoreVideo)
    /// Claim 6 — the slot: no wish, no frame; a wish, the frame with its transform; clear drops.
    func testTheSlotStoresOnlyWhileWantedAndClearDrops() throws {
        let slot = CameraFrameSlot()
        let key = UUID()
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 4, 4, kCVPixelFormatType_32BGRA, nil, &pb)
        let buffer = try XCTUnwrap(pb)
        slot.store(buffer, transforms: [key: .identity])
        XCTAssertNil(slot.latest(for: key), "a frame was stored while nobody wanted one — a Face source with the layer at 0 would retain buffers (K5)")
        slot.setWanted(true, for: key, viewport: CameraViewport(size: CGSize(width: 390, height: 844), orientationRaw: 1))
        XCTAssertEqual(slot.wantedViewports()[key]?.orientationRaw, 1)
        let before = slot.currentSequence
        let transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1, ty: 0)
        slot.store(buffer, transforms: [key: transform])
        let frame = try XCTUnwrap(slot.latest(for: key), "a wanted consumer got no frame (K5)")
        XCTAssertEqual(frame.viewportToImage, transform, "the consumer got a transform computed for another key (K5)")
        XCTAssertGreaterThan(frame.sequence, before, "the sequence did not advance on a store — the renderer could never see a new frame (K5)")
        slot.clear()
        XCTAssertNil(slot.latest(for: key), "clear() left a frame behind — a stopped session would keep its last image on the field (K5)")
        XCTAssertGreaterThan(slot.currentSequence, frame.sequence, "clear() did not advance the sequence — a renderer holding the old one would not notice the loss (K5)")
    }
    #endif

    /// Claim 8 (K5b, #1263) — the door: one `Camera layer` number row, a NAMED blend choice as a
    /// Picker (never a number field), the mirror switch, mounted ONCE in `visualPanel` behind
    /// `isSupported`, binding the same three keys the mounts read.
    func testTheFieldPanelHasTheCameraLayerDoor() throws {
        let src = try text("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        XCTAssertEqual(occurrences("label: \"Camera layer\"", in: src), 1,
                       "expected exactly one `Camera layer` row in EchoelStudioView (K5b)")
        XCTAssertTrue(src.contains("Picker(\"Blend\", selection: $visualCameraBlend)"),
                      "the blend is no longer a Picker — it is a named choice (Screen · Multiply · Cross), never a number field (K5b)")
        XCTAssertTrue(src.contains("Toggle(isOn: $visualCameraMirror)"), "the mirror switch is gone (K5b)")
        XCTAssertTrue(src.contains("StudioDefaultKeys.visualCameraOpacity.key")
                      && src.contains("StudioDefaultKeys.visualCameraMirror.key")
                      && src.contains("StudioDefaultKeys.visualCameraBlend.key"),
                      "the panel no longer binds the three `visual.camera.*` keys the mounts read (K5b)")
        XCTAssertEqual(occurrences("                cameraLayerRow\n", in: src), 1,
                       "`cameraLayerRow` must be mounted exactly once (in `visualPanel`) (K5b)")
        XCTAssertTrue(src.contains("if FaceExpressionBioPublisher.isSupported, !donutIsThePicture {\n                cameraLayerRow"),
                      "the door is not gated on the device capability and the Metal field being the picture — a dead row on a phone without TrueDepth, or under the donuts (K5b)")
    }

    /// Claim 7 — still zero dependencies.
    func testThePackageStillDeclaresNoDependency() throws {
        let manifest = try text("Package.swift")
        XCTAssertTrue(manifest.contains("dependencies: []"),
                      "Package.swift declares a dependency — the camera layer must stay on Apple frameworks only (prompt rule)")
    }

    // MARK: - helpers

    private func occurrences(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    /// Comment-stripped source (line and block comments), so a doc that QUOTES a constructor
    /// cannot count as one.
    private func codeOnly(_ source: String) -> String {
        var out = ""
        var i = source.startIndex
        var inBlock = false
        while i < source.endIndex {
            let c = source[i]
            let next = source.index(after: i) < source.endIndex ? source[source.index(after: i)] : Character(" ")
            if inBlock {
                if c == "*", next == "/" { inBlock = false; i = source.index(i, offsetBy: 2); continue }
                i = source.index(after: i); continue
            }
            if c == "/", next == "*" { inBlock = true; i = source.index(i, offsetBy: 2); continue }
            if c == "/", next == "/" {
                while i < source.endIndex, source[i] != "\n" { i = source.index(after: i) }
                continue
            }
            out.append(c)
            i = source.index(after: i)
        }
        return out
    }

    private func root() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: root().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func swiftSources() throws -> [(path: String, text: String)] {
        let base = root().appendingPathComponent("Sources")
        guard let e = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
        var out: [(String, String)] = []
        for case let url as URL in e where url.pathExtension == "swift" {
            let rel = "Sources/" + url.path.dropFirst(base.path.count + 1)
            out.append((rel, try String(contentsOf: url, encoding: .utf8)))
        }
        return out.sorted { $0.0 < $1.0 }
    }
}
