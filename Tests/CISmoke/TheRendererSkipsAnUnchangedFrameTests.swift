// TheRendererSkipsAnUnchangedFrameTests.swift
// Echoel — #1244 (visual audit 2026-09-10, V2). The Metal renderer skips the GPU pass when the
// frame's uniforms are byte-identical to the last encoded ones — without pausing anything.
//
// THE COST. Under Reduce Motion — the accessibility switch and the `.minimal` tier that thermal
// `.critical` / battery < 10 % forces — `time` is 0 and the phases are frozen, and once the
// bio/touch easings settle the renderer drew SIXTY identical full-size frames a second, on the
// device that could least afford it. The audit's first proposal (`isPaused = true`) was wrong
// in kind: the picture is not static under Reduce Motion, it still follows the body and the
// fingers, slowly; and the display link's cadence is pinned by a founder-verified flicker law.
//
// WHAT THIS PINS. (1) ORDER: the drawable is acquired AFTER `uniforms.time` is set — after every
// uniform is final — so the skip can sit in front of it, and the drawable is requested as late
// as Apple advises. (2) THE SKIP: gated on `hasEncodedOnce` and byte equality with
// `lastEncodedUniforms`; the record is updated right after. ⛔ It carried a third term,
// `!wantsCapture`, because a video take needed a rendered texture on every frame, identical or
// not. Video capture is gone (#1304, founder 2026-09-12), so the skip is unconditional — and
// anything that reads the rendered texture again has to put that term back, or it silently
// receives nothing while the picture is still. (3) COUNTERWEIGHT, by text: `isPaused = false` and
// `preferredFramesPerSecond = 60` are exactly as before — this is a skip, not a pause.
// (4) THE HELPER, by behaviour: `bytesEqual` is true for identical structs, false for a
// one-field difference, and true for an identical NaN (the reason it is bytes, not `==`).
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`c3227d0`) and this tree: claims 1
// and 2 RED on the parent, GREEN here; claim 3 GREEN on both; claim 4 is behavioural on a pure
// static helper and was NOT run here (no toolchain). Whether the last frame stays on the layer
// with no flicker is a device question (NEEDS-FOUNDER-VERIFY at the skip).
// ⛔ #1301: claim 2's needle CARRIED a camera-sequence term from K5 (#1262) until the camera
// layer went with the face source. The premise it was added for — "the shader reads nothing but
// uniforms" — holds again, so the term is back out. ⭐ The LAW is the reason this note stays:
// the skip's gates must cover EVERY input the encoder binds. Bind a texture, a buffer, anything
// the uniforms do not describe, and this needle has to grow a term in the SAME commit, or the
// renderer holds a stale frame over changed input and no test notices.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheRendererSkipsAnUnchangedFrameTests: XCTestCase {

    /// Claim 1 — the drawable is acquired after the last uniform is written.
    func testTheDrawableIsAcquiredAfterTheUniformsAreFinal() throws {
        let src = try text("Sources/Echoelmusic/Views/MetalBioView.swift")
        guard let time = src.range(of: "uniforms.time = reduceMotion ? 0 : Float(nowT - startTime)"),
              let guardAt = src.range(of: "guard let drawable = view.currentDrawable,") else {
            return XCTFail("the time assignment or the drawable guard is gone from draw(in:) — re-anchor (#1244)")
        }
        XCTAssertTrue(time.upperBound < guardAt.lowerBound,
                      "the drawable is acquired before the uniforms are final again — the skip cannot sit in front of it, and the drawable is requested earlier than Apple advises (#1244)")
        XCTAssertEqual(src.components(separatedBy: "guard let drawable = view.currentDrawable,").count - 1, 1,
                       "expected exactly one drawable guard in MetalBioView (#1244)")
    }

    /// Claim 2 — the skip and its three gates.
    func testTheSkipIsGatedOnCaptureAndByteEquality() throws {
        let src = try text("Sources/Echoelmusic/Views/MetalBioView.swift")
        // ⛔ #1301 narrowed the skip back to two gates plus byte equality: the camera-sequence
        // term left with the layer it existed for. See the header for what must re-widen it.
        XCTAssertTrue(src.contains("if hasEncodedOnce, Self.bytesEqual(uniforms, lastEncodedUniforms) {"),
                      "the unchanged-frame skip lost a gate: it must yield to a take/still and must never skip the first frame (#1244)")
        guard let skip = src.range(of: "if hasEncodedOnce, Self.bytesEqual(uniforms, lastEncodedUniforms) {") else { return }
        let after = String(src[skip.upperBound...].prefix(1200))
        XCTAssertTrue(after.contains("lastEncodedUniforms = uniforms") && after.contains("hasEncodedOnce = true"),
                      "the encoded-uniforms record is not updated after the skip decision (#1244)")
        // #1245 (review): the record is written AFTER the drawable guard — a nil drawable presents
        // nothing and must not count as encoded, or every settled tick afterwards skips against a
        // frame that never reached the layer.
        if let guardAt = after.range(of: "guard let drawable = view.currentDrawable,"),
           let record = after.range(of: "lastEncodedUniforms = uniforms") {
            XCTAssertTrue(guardAt.upperBound < record.lowerBound,
                          "the encoded record is written before the drawable guard again — a nil drawable would poison the skip (#1245)")
        } else {
            XCTFail("the drawable guard or the record is not within reach of the skip (#1245)")
        }
    }

    /// Claim 3 — counterweight: it is a skip, not a pause.
    func testTheDisplayLinkIsNotPausedOrRetimed() throws {
        let src = try text("Sources/Echoelmusic/Views/MetalBioView.swift")
        XCTAssertTrue(src.contains("view.isPaused = false") && src.contains("view.preferredFramesPerSecond = 60"),
                      "`makeUIView` no longer leaves the display link running at the pinned 60 — #1244 skips encodes precisely so the cadence never has to change (#1244)")
        XCTAssertFalse(src.contains("isPaused = true"), "someone pauses the MTKView — the picture under Reduce Motion still follows the body; pausing freezes it (#1244)")
    }

    /// Claim 4 — the byte comparison, on a stand-in struct of the same kind.
    func testBytesEqualIsByteEqualityIncludingNaN() {
        struct Probe { var a: Float = 0; var b: Float = 1; var c: Float = 2 }
        XCTAssertTrue(MetalBioRenderer.bytesEqual(Probe(), Probe()))
        XCTAssertFalse(MetalBioRenderer.bytesEqual(Probe(), Probe(a: 0, b: 1, c: 2.0000002)))
        let nan = Probe(a: .nan, b: 1, c: 2)
        XCTAssertTrue(MetalBioRenderer.bytesEqual(nan, nan), "an identical NaN must compare equal — that is why the skip compares bytes, not Floats (#1244)")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
