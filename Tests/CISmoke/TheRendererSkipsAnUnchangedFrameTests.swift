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
// as Apple advises. (2) THE SKIP: gated on `hasEncodedOnce`, on the footage sequence (VV-5a) and
// on byte equality with `lastEncodedUniforms`; the record is updated right after. ⛔ It carried a
// capture term, `!wantsCapture`, because a video take needed a rendered texture on every frame,
// identical or not. Video capture is gone (#1304, founder 2026-09-12), so no capture term gates
// it — and anything that reads the rendered texture again has to put that term back, or it
// silently receives nothing while the picture is still.
// (3) COUNTERWEIGHT, by text: `isPaused = false` and
// `preferredFramesPerSecond = 60` are exactly as before — this is a skip, not a pause.
// (4) THE HELPER, by behaviour: `bytesEqual` is true for identical structs, false for a
// one-field difference, and true for an identical NaN (the reason it is bytes, not `==`).
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`c3227d0`) and this tree: claims 1
// and 2 RED on the parent, GREEN here; claim 3 GREEN on both; claim 4 is behavioural on a pure
// static helper and was NOT run here (no toolchain). Whether the last frame stays on the layer
// with no flicker is a device question (NEEDS-FOUNDER-VERIFY at the skip).
// ⛔ #1301: claim 2's needle CARRIED a camera-sequence term from K5 (#1262) until the camera
// layer went with the face source. ⭐ VV-5a (GMMW) re-widened the skip by the FOOTAGE sequence —
// the same kind of term K5a/#1262 introduced and #1301 removed — because the encoder binds two
// textures again. The LAW is the reason this note stays: the skip's gates must cover EVERY input
// the encoder binds. Bind a texture, a buffer, anything the uniforms do not describe, and this
// needle has to grow a term in the SAME commit, or the renderer holds a stale frame over changed
// input and no test notices. Claims 5 and 6 pin the footage half of that law.
//
// ⚠️ GRADING OF THE VV-5a EDIT (§3), transcribed (§0) against the parent (`500491409`) and this
// tree: ZERO regressions. Claim 2's widened needle and its footage record, and claims 5, 6 and 7
// whole, name symbols this commit creates (`footageSequenceThisFrame`, `bindFootage`,
// `refreshFootage`, `FootageHold` …) — FORWARD guards, i.e. ONE anchor absence on the parent
// reported N times (#486), never regressions. ⛔ The first draft of this paragraph booked claim 2
// as a regression; the review caught it — red there only because the new symbols do not exist,
// which is the flattering direction §3 names. Claims 1 and 3 — counterweights, green on both.
// Claim 4 is behaviour on an UNCHANGED helper and was not transcribed (no toolchain); this edit
// does not touch it. KIND (§1): claims 1–3 and 5–7 are SOURCE-TEXT SCANS; claim 4 is behaviour.
// Whether a bound pair ever renders is a DEVICE PROBE, and in VV-5a nothing produces one
// (`footageSource` has no writer yet — VV-5b).

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

    /// Claim 2 — the skip and its gates. Renamed with VV-5a (#374): the old name named a capture
    /// term that has been gone since #1304.
    func testTheSkipIsGatedOnTheFootageSequenceAndByteEquality() throws {
        let src = try text("Sources/Echoelmusic/Views/MetalBioView.swift")
        // ⛔ #1301 narrowed the skip to `hasEncodedOnce` plus byte equality; VV-5a re-widened it by
        // the footage sequence, because the encoder binds two footage textures again.
        let skipLine = "if hasEncodedOnce, footageSequenceThisFrame == lastEncodedFootageSequence, Self.bytesEqual(uniforms, lastEncodedUniforms) {"
        XCTAssertTrue(src.contains(skipLine),
                      "the unchanged-frame skip lost a gate: it must never skip the first frame, and it must not skip a new footage frame whose uniforms happen to be settled (#1244, VV-5a)")
        guard let skip = src.range(of: skipLine) else { return }
        let after = String(src[skip.upperBound...].prefix(1200))
        XCTAssertTrue(after.contains("lastEncodedUniforms = uniforms") && after.contains("hasEncodedOnce = true"),
                      "the encoded-uniforms record is not updated after the skip decision (#1244)")
        XCTAssertTrue(after.contains("lastEncodedFootageSequence = footageSequenceThisFrame"),
                      "the encoded footage sequence is not recorded after the skip decision — a new footage frame with settled uniforms would be skipped (VV-5a)")
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

    /// Claim 5 — every draw with the shared pipeline binds BOTH footage slots, and the one
    /// footage call sits after the time line and before the skip that compares its result.
    func testEveryDrawWithThePipelineBindsBothFootageSlots() throws {
        let code = SourceText.codeOnly(try text("Sources/Echoelmusic/Views/MetalBioView.swift"))
        let pipelines = code.components(separatedBy: "encoder.setRenderPipelineState(pipeline)").count - 1
        let binds = code.components(separatedBy: "bindFootage(on: encoder)").count - 1
        XCTAssertGreaterThan(pipelines, 0, "no draw sets the pipeline any more — re-anchor this claim (VV-5a)")
        XCTAssertEqual(pipelines, binds, """
            \(pipelines) encodes set the pipeline and \(binds) bind the footage slots. The fragment \
            declares texture(0)/(1); a draw that leaves them unbound reads undefined memory on \
            the GPU — no crash, no build error. Every pipeline draw calls `bindFootage(on:)` (VV-5a).
            """)
        guard let binder = body(of: "private func bindFootage(", in: code) else {
            return XCTFail("`bindFootage(on:)` is gone — the two footage slots have no single binder (VV-5a)")
        }
        XCTAssertEqual(code.components(separatedBy: "encoder.setFragmentTexture(").count - 1, 2,
                       "expected exactly two fragment-texture binds in MetalBioView, both in `bindFootage` (VV-5a)")
        XCTAssertEqual(binder.components(separatedBy: "encoder.setFragmentTexture(").count - 1, 2,
                       "a fragment texture is bound outside `bindFootage` — one binder, or the placeholder fallback can be skipped (VV-5a)")
        XCTAssertTrue(binder.contains("?? placeholderY, index: 0)") && binder.contains("?? placeholderCbCr, index: 1)"),
                      "`bindFootage` no longer falls back to the 1x1 placeholders — an unpaired draw leaves a declared slot unbound (VV-5a)")
        let call = "let footageSequenceThisFrame = refreshFootage()"
        XCTAssertEqual(code.components(separatedBy: call).count - 1, 1, "expected exactly one footage refresh per draw (VV-5a)")
        guard let time = code.range(of: "uniforms.time = reduceMotion ? 0 : Float(nowT - startTime)"),
              let refresh = code.range(of: call),
              let skip = code.range(of: "if hasEncodedOnce, footageSequenceThisFrame == lastEncodedFootageSequence,") else {
            return XCTFail("the time line, the footage refresh or the skip is gone from draw(in:) — re-anchor (VV-5a)")
        }
        XCTAssertTrue(time.upperBound < refresh.lowerBound && refresh.upperBound < skip.lowerBound,
                      "the footage refresh no longer sits between the time line and the skip — the skip would compare a sequence the uniforms do not describe (VV-5a)")
    }

    /// Claim 6 — with no source the footage path touches nothing: its FIRST statement is the
    /// guard on the tier and the source, and that guard's exit returns sequence 0.
    func testWithNoSourceTheFootagePathTouchesNothing() throws {
        let code = SourceText.codeOnly(try text("Sources/Echoelmusic/Views/MetalBioView.swift"))
        guard let refresh = body(of: "private func refreshFootage(", in: code) else {
            return XCTFail("`refreshFootage()` is gone — re-anchor (VV-5a)")
        }
        let opening = refresh.dropFirst().drop { $0.isWhitespace }
        XCTAssertTrue(opening.hasPrefix("guard !footageTierBlocked, let source = footageSource,"), """
            `refreshFootage()` no longer opens with the tier-and-source guard. With no source it \
            must return before writing a uniform, or the #1244 skip stops deciding as it did \
            before VV-5a.
            """)
        // Brace-MATCHED, not "up to the next `}`": the else block opens with an `if … { … }` of
        // its own, and a first-`}` slice would end inside it and never see the return.
        guard let exit = body(of: "else", in: refresh) else {
            return XCTFail("the guard in `refreshFootage()` has no else block — re-anchor (VV-5a)")
        }
        XCTAssertTrue(exit.contains("return 0"),
                      "the no-source exit of `refreshFootage()` no longer returns sequence 0 — the skip would compare against a stale sequence (VV-5a)")
        XCTAssertEqual(code.components(separatedBy: "footageTierBlocked = (q?.tier ?? .balanced) <= .low").count - 1, 1,
                       "the footage layer no longer stands down at the `.low` tier — two full-drawable plane samples per pixel on a hot or low device (VV-5a)")
    }

    /// Claim 7 — a bound pair outlives the GPU's read, and the stream never stretches it. Both
    /// came from the VV-5a review: a pair dropped after a counted number of ticks can be recycled
    /// by the source's pool while a buffer still samples it (`waitUntilScheduled` is not
    /// "completed"), and the screen's viewport->image affine drawn at the stream's aspect distorts.
    func testTheFootagePairOutlivesTheGPUReadAndTheStreamCarriesNoStretch() throws {
        let code = SourceText.codeOnly(try text("Sources/Echoelmusic/Views/MetalBioView.swift"))
        let hold = "buffer.addCompletedHandler { @Sendable _ in withExtendedLifetime(hold) {} }"
        XCTAssertEqual(code.components(separatedBy: hold).count - 1, 1, """
            The bound footage pair no longer rides into the command buffer's completion handler. \
            A `CVMetalTexture` released before the GPU finishes lets the source recycle the pixel \
            buffer under the read — a torn or wrong frame, no crash, no log (VV-5a review).
            """)
        guard let holdAt = code.range(of: hold), let commitAt = code.range(of: "buffer.commit()") else {
            return XCTFail("the footage hold or the commit is gone from draw(in:) — re-anchor (VV-5a)")
        }
        XCTAssertTrue(holdAt.upperBound < commitAt.lowerBound,
                      "the footage hold is registered after `buffer.commit()` — Metal ignores a handler added to a committed buffer (VV-5a)")
        guard let broadcast = body(of: "private func encodeBroadcastFrame(", in: code) else {
            return XCTFail("`encodeBroadcastFrame` is gone — re-anchor (VV-5a)")
        }
        guard let aspect = broadcast.range(of: "u.aspect = Float(spec.width) / Float(spec.height)"),
              let off = broadcast.range(of: "u.footPresent = 0"),
              let upload = broadcast.range(of: "encoder.setFragmentBytes(&u,") else {
            return XCTFail("""
                The stream encode no longer turns the footage layer off. The footage affine was \
                fitted to the VIEW's aspect; drawn at the stream's it stretches the picture. If \
                VV-5b derived a stream-aspect affine, replace this assertion in the same commit.
                """)
        }
        XCTAssertTrue(aspect.upperBound < off.lowerBound && off.upperBound < upload.lowerBound,
                      "the stream's footage switch-off sits outside the copy it must change — after the upload it does nothing (VV-5a)")
    }

    /// The brace-matched body of the member whose declaration starts with `anchor`, from its
    /// first `{` through the matching `}`. nil when the anchor is missing — never "", so an
    /// absence cannot read green (#926).
    private func body(of anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor),
              let open = code.range(of: "{", range: start.upperBound ..< code.endIndex) else { return nil }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let ch = code[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.lowerBound ... index]) }
            }
            index = code.index(after: index)
        }
        return nil
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
