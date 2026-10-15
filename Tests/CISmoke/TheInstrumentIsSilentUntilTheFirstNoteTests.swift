// TheInstrumentIsSilentUntilTheFirstNoteTests.swift
// Echoel — founder 2026-10-15 („Echoel-Plugin still bis zur ersten Note – ja"). In AUM the AUv3
// sounded a drone the moment it was loaded (FOUNDER_DEVICE_SESSION §2b finding 2). A professional
// instrument is silent until it is played.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (`EchoelDDSP`, shipped): the allocate sequence — admitted start, then
//      an immediate release, nothing rendered between — renders silence (below −80 dBFS — anti-denormal and filter state may leave a residue that is not a sound); a note afterwards
//      sounds. So "silent until the first note" holds for the voice.
//   2. SOURCE-TEXT SCAN (the extension cannot be instantiated here): `allocateRenderResources`
//      releases the voice right after its start; the render block scales the texture bed by the
//      voice's envelope (a per-sample ramp), so the bed is silent with the voice.
//   3. COUNTERWEIGHT: the tracker is still cleared before the start (P8m) and the start is still
//      the argument-less admitted one (P8h).
//
// ⚠️ HONEST GRADING (#433): claim 1 drives shipped types and is green on both trees for the voice
// alone — the regression on the parent is claim 2 (no release after the start, no bed scaling):
// one finding. Claim 3 is a counterweight. Transcribed, no local toolchain (§0).
// ⚠️ THE LIMIT: silence in a real host is a DEVICE PROBE (NEEDS-FOUNDER-VERIFY: AUM → add Echoel
// → no sound until a key is played; a note sounds; after release the texture fades with it).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheInstrumentIsSilentUntilTheFirstNoteTests: XCTestCase {

    private static let audioUnit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    func testTheReleasedStartIsSilentAndANoteSounds() {
        let synth = EchoelDDSP(sampleRate: 48000)
        synth.amplitude = 0.6
        synth.noteOn()
        synth.noteOff()
        var block = [Float](repeating: 0, count: 512)
        var loaded: Float = 0
        for _ in 0..<20 {
            synth.render(buffer: &block, frameCount: 512)
            loaded = Swift.max(loaded, block.map { abs($0) }.max() ?? 0)
        }
        XCTAssertLessThan(loaded, 1e-4, "the loaded instrument makes a sound before any note (above -80 dBFS)")
        synth.noteOn()
        var played: Float = 0
        for _ in 0..<20 {
            synth.render(buffer: &block, frameCount: 512)
            played = Swift.max(played, block.map { abs($0) }.max() ?? 0)
        }
        XCTAssertGreaterThan(played, 0, "a note after the silent start is not heard — claim 1 would be vacuous")
    }

    func testTheAllocateReleasesTheStartAndTheBedFollowsTheVoice() throws {
        let code = SourceText.codeOnly(try text(Self.audioUnit))
        let allocate = try XCTUnwrap(body(startingWith: "public override func allocateRenderResources()", in: code),
                                     "allocateRenderResources not found — re-anchor (#456)")
        let reset = try XCTUnwrap(allocate.range(of: "renderNoteState.current = -1"), "the tracker reset moved")
        let start = try XCTUnwrap(allocate.range(of: "synth.noteOn()"), "the admitted start moved")
        let release = try XCTUnwrap(allocate.range(of: "synth.noteOff()"), "the voice is no longer released at load")
        XCTAssertLessThan(reset.lowerBound, start.lowerBound, "P8m: the tracker is cleared before the start")
        XCTAssertLessThan(start.lowerBound, release.lowerBound, "the release follows the start")
        let render = try XCTUnwrap(body(startingWith: "public override var internalRenderBlock", in: code),
                                   "render block not found — re-anchor (#456)")
        XCTAssertTrue(render.contains("let textureTo = synthRef.envelopeLevel.isFinite ? synthRef.envelopeLevel : 0"),
                      "the texture bed no longer reads the voice's envelope")
        XCTAssertTrue(render.contains("data[i] = (synthSample + texBuf[i] * bed) * gain"),
                      "the texture bed is no longer scaled by the voice — it would drone on its own")
    }

    // MARK: helpers

    private func text(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relativePath) not on disk — this run has no source tree")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The brace-matched body that starts at `anchor` (§2, #408).
    private func body(startingWith anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor),
              let open = code[start.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < code.endIndex {
            if code[index] == "{" { depth += 1 } else if code[index] == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        return nil
    }
}
