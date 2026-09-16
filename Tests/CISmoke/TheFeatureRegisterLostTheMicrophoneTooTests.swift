// TheFeatureRegisterLostTheMicrophoneTooTests.swift
// Echoel — #1340. `docs/dev/FEATURE_MATRIX.md` is the document CLAUDE.md names as the feature
// register: the page a session opens to decide what is live before it plans anything. Four days
// after #1302 deleted the microphone, it still carried FOUR present-tense claims about the
// capability that went with it — and one of them was marked **Live**.
//
// ⭐ THE SHARPEST ONE SAT ONE LINE BELOW ITS OWN TOMBSTONE. Line 182 already read
// "⛔ `MicrophoneManager.swift` stood here and was deleted with the audio input — #1302"; line 183
// then said the live feature set includes "**mic FFT (1024-pt)**". Measured, not remembered: the
// only two `installTap`s under `Audio/` sit on `meterNode` and on `masterMixer`, and the ring they
// fill is documented in `AudioEngine` as "for the immersive FFT visual". The FFT is real; the
// DIRECTION was wrong, and direction is the whole claim. This is the CLAUDE.md-H1 shape (a
// retraction that fixed the paragraph it was thinking about and left the neighbouring line), and
// the #456 shape (a repair must travel to EVERY home), in one place.
//
// ⚠️ WHAT THIS GUARD DOES **NOT** DO, deliberately. It does not scan the register for the names of
// deleted types — this repo strikes a claim by QUOTING it inside a ⛔ block, so a negative text scan
// would go red on the very retraction that fixes the defect (#491). What it pins instead is the
// pair that CAN be checked without that trap: the measurable fact the register now asserts (those
// files are gone), and the code half that must stay (the stored patch still sounds, the taps are
// still on the output).
//
// ⚠️ AND IT FORBIDS NOTHING (#364). If a microphone is built again, claim 3 goes red and its
// message names the register lines that must move in the SAME commit — which is the failure this
// slice is about, not the microphone.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **14 assertions across three claims**
// (claim 1 = 1 anchor + 4 pins, claim 2 = 1 walk-size anchor + 6 in the loop, claim 3 = 2),
// transcribed in Python and driven against BOTH trees. On the parent (`f1203d9`) **4 are red and
// they are ONE finding** (#486): all four are claim 1's pins, and all four name prose THIS commit
// writes into the register — one repair reported four times, not four repairs. The other **10 are
// COUNTERWEIGHTS** (#343), green on both trees, and they are why the file exists: without them
// claim 1 stays green on a tree that
// "cleaned up" `voiceProfileTaps` along with the capture chain, or that wired a microphone tap back
// in while the register kept saying OUTPUT.
// ⛔ THE FIRST DRAFT OF THIS PARAGRAPH SAID **11 assertions (4 + 6 + 1)** and the transcription
// counted 14. Both anchors were missing from the split — exactly the #1334 defect this bundle
// closed nine slices ago, in a file whose own subject is a description that does not match what
// it describes. A header is a claim; it gets counted, not estimated.
// SOURCE-TEXT + FILE-EXISTENCE SCAN (§1). Nothing here plays audio; that the stored patch still
// SOUNDS is a device probe (#95/#527) and is not claimed.

import Foundation
import XCTest

final class TheFeatureRegisterLostTheMicrophoneTooTests: XCTestCase {

    private static let register = "docs/dev/FEATURE_MATRIX.md"

    /// Claim 1 — the register records the retraction rather than quietly swapping the sentence.
    /// Positive pins only: a negative scan here would hit the ⛔ blocks themselves (#491).
    func testTheRegisterRecordsTheMicrophoneRetraction() throws {
        let text = try Self.text(Self.register)
        XCTAssertFalse(text.isEmpty, "ANCHOR MISSING: could not read \(Self.register) (#454).")
        XCTAssertTrue(
            text.contains("a 1024-pt FFT window on the **master OUTPUT**"),
            "the register no longer says which DIRECTION its FFT window faces. It said \"mic FFT\" "
            + "for four days after #1302 removed every microphone, one line below its own "
            + "`MicrophoneManager` tombstone.")
        XCTAssertTrue(
            text.contains("ITS CAPTURE HALF IS DELETED"),
            "the #1302 retraction on the \"Live (voice timbre)\" row is gone. That row named three "
            + "deleted types and was marked **Live** — the single most expensive line on the page.")
        XCTAssertTrue(
            text.contains("`SynthPatch.voiceProfileTaps` (~64 floats, max-normalized) plus its label"),
            "the register no longer states that the PATCH half SURVIVES. Without that sentence the "
            + "retraction reads as \"voice timbre is gone\", and the next cleanup deletes a field "
            + "that a stored patch still applies (#95/#527) — the retraction would then cause the "
            + "damage it was written to prevent.")
        XCTAssertTrue(
            text.contains("TWO OF THOSE CORES NO LONGER EXIST"),
            "the marker inside the dated 2026-06-18 history block is gone. History is kept as "
            + "written, but that line is PRESCRIPTIVE — \"built but NOT yet wired\" is an "
            + "invitation to wire a flagship vocoder that no longer exists.")
    }

    /// Claim 2 — the measurable fact the register now asserts: every type it struck is gone as a
    /// FILE. Counterweight direction: if one comes back, the register's ⛔ blocks become the lie.
    func testTheStruckTypesHaveNoFiles() throws {
        let sources = try Self.repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: sources.path) else {
            return XCTFail("ANCHOR MISSING: cannot walk Sources/ (#454).")
        }
        var names = Set<String>()
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            names.insert((rel as NSString).lastPathComponent)
        }
        XCTAssertGreaterThan(names.count, 200,
                             "ANCHOR MISSING: only \(names.count) Swift files walked; the tree "
                             + "holds well over three hundred. A walk that finds nothing would "
                             + "make every assertion below vacuously green (#926).")
        for gone in ["VocoderCore", "FeedbackGuard", "VoiceCaptureController",
                     "VoiceCaptureEngine", "VoiceAnalyzer", "MultiTrackRecorder"] {
            XCTAssertFalse(
                names.contains("\(gone).swift"),
                "`\(gone).swift` is back under `Sources/`. That is legal (#364) — the founder may "
                + "ask for an audio input again. It is NOT legal to leave `docs/dev/FEATURE_MATRIX.md` "
                + "saying it was deleted: the ⛔ block on that row, and the Live/Roadmap lines around "
                + "it, move in the SAME commit. A register that is wrong in the OPTIMISTIC direction "
                + "gets planned from; that is why this pair is pinned together.")
        }
    }

    /// Claim 3 — counterweight in CODE, two halves. The patch-side spectrum must still exist (or
    /// claim 1's survival sentence is describing a field nobody kept), and the FFT tap must still
    /// face the OUTPUT (or the register's corrected word is wrong again).
    func testThePatchHalfSurvivesAndTheTapStillFacesTheOutput() throws {
        let patch = SourceText.codeOnly(
            try Self.text("Sources/Echoelmusic/DSP/SynthPatch.swift"))
        XCTAssertTrue(
            patch.contains("public var voiceProfileTaps: [Float]?"),
            "`SynthPatch.voiceProfileTaps` is gone. #1302 removed the microphone, not the stored "
            + "spectrum: a patch written by an older build carries these taps and `EchoelDDSP` "
            + "still blends them. Deleting the field silently changes how such a patch SOUNDS — "
            + "the #527 shape, where \"obviously absent\" becomes \"quietly different\".")
        let engine = SourceText.codeOnly(
            try Self.text("Sources/Echoelmusic/Audio/AudioEngine.swift"))
        XCTAssertFalse(
            engine.contains("inputNode.installTap"),
            "an INPUT tap is back in `AudioEngine`. Legal (#364), and it makes the register's "
            + "corrected wording — \"a 1024-pt FFT window on the **master OUTPUT**\" — false in the "
            + "same word it was just repaired in. Move that line in the SAME commit, and re-check "
            + "`docs/_headers` (`microphone=()`) and the `NSMicrophoneUsageDescription` question "
            + "that is founder-gated in CLAUDE.md.")
    }

    private static func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func text(_ relativePath: String) throws -> String {
        try String(contentsOf: try repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}
