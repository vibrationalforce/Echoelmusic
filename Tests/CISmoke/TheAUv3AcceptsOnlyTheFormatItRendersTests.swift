// TheAUv3AcceptsOnlyTheFormatItRendersTests.swift
// Echoel — 2026-09-24 (overnight P8l): the AUv3 refuses a bus format its render block cannot
// write — anything but non-interleaved Float32. Blocking bundle.
//
// THE DEFECT (measured before the repair). The mix loop binds each output buffer as `Float` and
// writes `count` samples per buffer, treating a single-buffer list as mono. No override of
// `shouldChange(to:for:)` existed, so a host could set an interleaved stereo bus (one buffer of
// 2 × frames: half filled, read as mono) or an integer format (float bit patterns in an Int16
// buffer). Found by tonight's read-only audit agent (its finding 5); whether any host actually
// sets such a format is unmeasured.
//
// THE REPAIR. `shouldChange(to:for:)` returns false unless the format is `.pcmFormatFloat32`,
// non-interleaved, with at least one channel; otherwise it defers to `super`.
//
// WHAT KIND OF GREEN (§1): claim 1 is a SOURCE-TEXT SCAN (the extension cannot be instantiated).
// Claim 2 is END-TO-END BEHAVIOUR of `AVAudioFormat` itself — the default the AU declares in `init`
// (`standardFormatWithSampleRate:channels:`) passes the same predicate — so the AU cannot refuse
// its own default bus. HOST: unmeasured.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `7356a4dbf`: claim 1 is a
// REGRESSION — one finding (no override there). Claim 2 is a COUNTERWEIGHT, green on both trees;
// it uses only AVFoundation.
//
// ⭐ 2026-09-25 (overnight P8t): claim 1 also pins the CHANNEL ceiling — no wider than
// `RenderScratch.ownedChannels`, the memory the block owns for a host that passes null `mData`.
// Found by tonight's read-only audio-thread review (its finding 1). Grading against parent
// `84e64044d`: that one assertion is a REGRESSION — one finding;
// the rest of the file is unchanged. Claim 2 now also checks the default bus fits under the
// ceiling, read from the declaration (a COUNTERWEIGHT: the AU must not refuse its own stereo default).
// Claim 2 therefore no longer uses only AVFoundation — it also reads the AU source (a SCAN half).

import AVFoundation
import Foundation
import XCTest

final class TheAUv3AcceptsOnlyTheFormatItRendersTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    // MARK: - claim 1 (SOURCE-TEXT SCAN)

    func testTheUnitRefusesAFormatTheRenderBlockCannotWrite() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let hook = try XCTUnwrap(Self.body(
            startingWith: "public override func shouldChange(to format: AVAudioFormat, for bus: AUAudioUnitBus) -> Bool {",
            in: code), """
            The AUv3 no longer vets a host's bus format. The render block writes non-interleaved \
            Float32 only; any other format reaches it unrefused.
            """)
        XCTAssertTrue(hook.contains("format.commonFormat == .pcmFormatFloat32"), "the sample format is no longer checked")
        XCTAssertTrue(hook.contains("!format.isInterleaved"), "an interleaved bus is no longer refused")
        XCTAssertTrue(hook.contains("format.channelCount <= AVAudioChannelCount(RenderScratch.ownedChannels)"), """
            A bus wider than the eight channels of memory the AU owns is no longer refused. A host \
            passing null `mData` would get null pointers back past channel 7, with `noErr`.
            """)
        XCTAssertTrue(hook.contains("super.shouldChange(to: format, for: bus)"),
                      "an acceptable format no longer defers to the base class")
        let render = try XCTUnwrap(Self.body(startingWith: "public override var internalRenderBlock", in: code),
                                   "the render block is not found — re-anchor this guard (#456)")
        XCTAssertTrue(render.contains("assumingMemoryBound(to: Float.self)"), """
            The render block no longer writes Float buffers. If it now serves another format, \
            widen the refusal above in the same commit.
            """)
    }

    // MARK: - claim 2 (COUNTERWEIGHT, behaviour)

    func testTheDefaultBusPassesTheRefusal() throws {
        // The ceiling is READ from the declaration, not restated here (#416): the constant is
        // private to the extension, so this bundle cannot name it.
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let marker = "static let ownedChannels = "
        let decl = try XCTUnwrap(code.range(of: marker), "`ownedChannels` not found — re-anchor this guard (#456)")
        let ceiling = try XCTUnwrap(UInt32(code[decl.upperBound...].prefix(while: { $0.isNumber })),
                                    "`ownedChannels` is no longer an integer literal — re-anchor this guard")
        for rate in [44_100.0, 48_000.0, 96_000.0] {
            let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2))
            XCTAssertEqual(format.commonFormat, .pcmFormatFloat32, "the standard format is no longer Float32 at \(rate)")
            XCTAssertFalse(format.isInterleaved, "the standard format is interleaved at \(rate)")
            XCTAssertLessThanOrEqual(format.channelCount, ceiling, "the default bus is wider than the owned-memory ceiling")
        }
    }

    // MARK: - helpers

    private static func body(startingWith anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor) else { return nil }
        var depth = 0
        var out = ""
        for ch in code[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { out.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return out }
            }
        }
        return nil
    }

    private func text(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — source-text claim cannot run (#454)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
