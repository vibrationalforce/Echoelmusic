// TheVoiceProfilerInstanceHalfHasNoProducerTests.swift
// Echoel — #1339. `VoiceTimbreProfiler` is never CONSTRUCTED in `Sources/`, so its instance
// half (`add`, `profile()`) is unreachable in the app: the F0/voicing producer it documented,
// `VoiceAnalyzer`, went with the audio input (#1302). Its STATIC half is live — `MetalBioView`
// calls `colorDescriptors(taps:)` on the taps a saved patch carries.
//
// ⭐ THE SPLIT IS THE WHOLE POINT, and it is the shape a tidy-up gets wrong. "No constructions"
// reads as "delete the file"; deleting it breaks the visual, because the LIVE entry point is a
// static the constructor never touches. Callerless is not dead (#527), and here only HALF is
// callerless. Until #1339 the file header described the dead half as the live one, so a reader
// checking it would have been reassured by a sentence about a producer that no longer exists.
//
// ⚠️ THIS IS NOT A DUPLICATE OF `TheVoiceProfileIsMeasuredNotRecordedTests` (#416). That guard
// drives the ALGORITHM end-to-end (median over voiced frames, Nyquist, non-finite poisoning)
// and constructs the profiler itself — which is exactly why "zero constructions" here is scoped
// to `Sources/`. Two different questions about one type: does the maths hold, and can the app
// reach it.
//
// ⚠️ THIS GUARD DOES NOT FORBID A RETURNING PRODUCER (#364). It goes red the day something
// constructs the profiler again, and its message is the instruction: the header's ⛔ #1339 block
// moves in the same commit. That is the event that went unnoticed in the other direction.
//
// ⚠️ ONE STALE SENTENCE IS KNOWINGLY LEFT ALONE, and it is named here rather than quietly
// fixed: `TheVoiceProfileIsMeasuredNotRecordedTests`'s own header still says the privacy
// property "lets v1 ship under the Info.plist promise". That plist key is orphaned (#1302,
// founder-gated, report-not-edit), so the sentence is about a string that really does still
// exist — stale in framing, not false in fact. Editing it would widen this slice past its
// finding; recording it is the #456 half that can be done honestly from here.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **7 assertions across three claims**
// (claim 1 = 2, claim 2 = 3, claim 3 = 2), transcribed in Python and driven against BOTH trees.
// On the parent (`c6d11b5`): **2 red, and they are FORWARD guards, not regressions** — claim 3
// names prose THIS commit writes. **The other 5 are COUNTERWEIGHTS** (#343), green on both
// trees. That is the honest shape: like #1336, the CODE was right the whole time and only its
// description lied, so there is nothing here a code assertion could have caught earlier. Claims
// 1 and 2 earn their place by what they catch NEXT — a returning producer, and a tidy-up
// deletion of a file whose live half is a static.
// LIMITS (§1): SOURCE-TEXT SCAN throughout. Whether the visual actually colours from a saved
// patch is a DEVICE PROBE and is NOT claimed here.

import Foundation
import XCTest

final class TheVoiceProfilerInstanceHalfHasNoProducerTests: XCTestCase {

    private static let profiler = "Sources/Echoelmusic/DSP/VoiceTimbreProfiler.swift"

    /// Claim 1 — nothing in `Sources/` constructs the profiler, so `add`/`profile()` cannot run.
    func testTheProfilerIsNeverConstructedInSources() throws {
        let code = try Self.allSourceCode()
        XCTAssertFalse(code.isEmpty, "ANCHOR MISSING: could not walk `Sources/` (#454).")
        XCTAssertEqual(
            Self.occurrences(of: "VoiceTimbreProfiler(", in: code), 0,
            "something constructs `VoiceTimbreProfiler` again. Good — but its file header says "
            + "in a ⛔ #1339 block that the instance half is unreachable and that only the "
            + "static `colorDescriptors` is live. Move that block in THIS commit, and say what "
            + "now supplies F0 and voicing: the producer the header used to name, "
            + "`VoiceAnalyzer`, was deleted with the audio input (#1302).")
    }

    /// Claim 2 — counterweight: the LIVE static half is still called, and the persisted taps it
    /// reads still exist. Without this, claim 1 stays green on a tree that deleted the file.
    func testTheStaticHalfIsStillTheVisualsSource() throws {
        let metal = SourceText.codeOnly(try Self.text("Sources/Echoelmusic/Views/MetalBioView.swift"))
        XCTAssertTrue(metal.contains("VoiceTimbreProfiler.colorDescriptors(taps:"),
                      "`MetalBioView` no longer calls `colorDescriptors`. That call is the ONLY "
                      + "reason `VoiceTimbreProfiler` may not be deleted as unused — the live "
                      + "entry point is a STATIC, which no construction-count can reveal.")
        let patch = SourceText.codeOnly(try Self.text("Sources/Echoelmusic/DSP/SynthPatch.swift"))
        XCTAssertTrue(patch.contains("public var voiceProfileTaps: [Float]?"),
                      "the persisted taps are gone from `SynthPatch`. They are what the static "
                      + "half reads: a patch saved by an older build carries them and applies "
                      + "them (#95/#527/#1293). The NAME says voice, the THING is the synth.")
        let code = SourceText.codeOnly(try Self.text(Self.profiler))
        XCTAssertTrue(code.contains("public static func colorDescriptors(taps: [Float])"),
                      "the static half is gone from the profiler itself.")
    }

    /// Claim 3 — FORWARD guards (§3): the header no longer names a deleted producer, and the
    /// retraction is recorded rather than the sentence quietly swapped. Read RAW — these are
    /// comments, and `codeOnly` would make both assertions vacuous (#926).
    func testTheHeaderNoLongerNamesADeletedProducer() throws {
        let raw = try Self.text(Self.profiler)
        XCTAssertTrue(raw.contains("**0 constructions**"),
                      "the header no longer states the measurement its keep/delete argument "
                      + "rests on. Without it the file reads as an orphan.")
        XCTAssertTrue(raw.contains("load-bearing through a DIFFERENT entry"),
                      "the sentence that stops the tidy-up deletion is gone. `git grep` for the "
                      + "constructor returns zero either way — only this line says why that is "
                      + "not permission to delete.")
    }

    // MARK: - Helpers

    private static func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var i = text.startIndex
        while let r = text.range(of: needle, range: i..<text.endIndex) {
            count += 1
            i = r.upperBound
        }
        return count
    }

    private static func allSourceCode() throws -> String {
        let sources = Self.root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: sources.path) else { return "" }
        var joined = ""
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            if let body = try? String(contentsOf: sources.appendingPathComponent(relative),
                                      encoding: .utf8) {
                joined += SourceText.codeOnly(body) + "\n"
            }
        }
        return joined
    }

    private static func root() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func text(_ relativePath: String) throws -> String {
        try String(contentsOf: root().appendingPathComponent(relativePath), encoding: .utf8)
    }
}
