// TheAudioFeaturePathHasNoProducerTests.swift
// Echoel — #1325. `Core/AudioFeatureChannel` + `Core/AudioFeatureExtractor` lost their producer
// with the microphone (#1302, founder 2026-09-12) and three headers went on describing them as
// live — including the one in the RENDER path, which named a tick that no longer exists.
//
// ⭐ WHY THIS IS A REGISTER ENTRY AND NOT A DELETION. The renderer still READS the channel once
// per frame, and that read is the mounting point a restored audio input plugs into. Deleting it
// would move the expensive half of any future restoration into `MetalBioView.draw(in:)` — the
// body governed by the 10.76.41/50 churn law. Same ruling as the audio lanes (#527) and the
// modulation matrix (#541): producerless is not dead, and the honest label is the one that
// stops a later session from "tidying up" a working mounting point.
//
// ⚠️ THIS GUARD FORBIDS NOTHING (#364). Wiring a producer back is legal and expected; claim 1
// is a NOTICE, and its message names the three prose homes that travel in that same commit.
// It is the shape `TheAudioLanesHaveNoProducerTests` and `TheTempoDestinationHasNoRouteTests`
// already use in this bundle.
//
// ⚠️ ONE TRAP THE NEEDLE HAD TO AVOID (#408). `AudioFeatureChannel.swift` declares
// `public func publish(` itself, and `EngineBus` has an unrelated `publish` — so the count is
// taken over `Sources/` MINUS the channel's own file, on the RECEIVER form
// `AudioFeatureChannel.shared.publish(`, which can only be the producer.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **11 assertions across four claims**
// (claim 1 = 3, claim 2 = 3, claim 3 = 3, claim 4 = 2), all transcribed in Python and driven
// against BOTH trees. On the parent (`e2f7d48`) **3 are red and they are ONE finding** (#486):
// the three retractions this commit writes did not exist. Claims 1 and 2 are COUNTERWEIGHTS
// (#343) — green on both trees, and they are what makes claim 3 mean anything: without them a
// tree that deleted the channel outright, or wired one back, would still read the prose as
// correct. Claim 4 is END-TO-END (§1): `AudioFeatureFrame.silent(at:)` is a public Foundation
// value type, and it pins the EXACT zero the #1244 render skip depends on — the one property
// here that a restored producer must not break.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheAudioFeaturePathHasNoProducerTests: XCTestCase {

    private static let channel = "Sources/Echoelmusic/Core/AudioFeatureChannel.swift"
    private static let extractor = "Sources/Echoelmusic/Core/AudioFeatureExtractor.swift"
    private static let renderer = "Sources/Echoelmusic/Views/MetalBioView.swift"

    /// Claim 1 — NOTICE, not a ban: nothing publishes into the channel, and nothing calls the
    /// extractor. Red the day a producer returns, which is the day the prose moves with it.
    func testNothingPublishesIntoTheChannel() throws {
        let others = try Self.sourcesExcept([Self.channel])
        XCTAssertFalse(others.isEmpty,
                       "ANCHOR MISSING: read no Swift source outside the channel's own file "
                       + "— a missing anchor is a finding, not a pass (#454).")
        XCTAssertFalse(
            others.contains("AudioFeatureChannel.shared.publish("),
            "something publishes audio features again. This guard forbids that (#364) — it "
            + "reports it. Move the three retractions in the SAME commit: the ⛔ #1325 blocks "
            + "in AudioFeatureChannel.swift and MetalBioView.swift, and the `Core/"
            + "AudioFeatureChannel` entry in CLAUDE.md's unwired-cores register.")
        XCTAssertFalse(
            try Self.sourcesExcept([Self.extractor, Self.channel]).contains("AudioFeatureExtractor"),
            "`AudioFeatureExtractor` has a caller again — same repair as above, plus its own "
            + "⛔ #1325 header block.")
    }

    /// Claim 2 — counterweight: the renderer still MOUNTS the read. Claim 1 would stay green
    /// forever on a tree that deleted the channel, which is the outcome this entry exists to
    /// prevent.
    func testTheRendererStillMountsTheRead() throws {
        let code = SourceText.codeOnly(try text(Self.renderer))
        XCTAssertTrue(code.contains("AudioFeatureChannel.shared.snapshot(now: nowGov)"),
                      "the renderer no longer reads the channel — the mounting point for a "
                      + "restored audio input is gone, so restoring one now costs a change "
                      + "inside `draw(in:)` (the 10.76.41/50 churn law).")
        XCTAssertTrue(code.contains("musicLevel = max(musicLevel, input.frame.level)"),
                      "the level no longer joins `musicLevel` by max — a sum would double-count "
                      + "room and music the day an input returns.")
        XCTAssertTrue(code.contains("audioHueBias = input.frame.isSilent ? 0 :"),
                      "the hue bias no longer gates on `isSilent`; with no producer that is the "
                      + "line keeping the tint at exactly 0.")
    }

    /// Claim 3 — the three prose homes carry the retraction. This is the assertion that was red
    /// before the commit, and the reason the entry is findable at all.
    func testTheThreeProseHomesSayItIsProducerless() throws {
        XCTAssertTrue(try text(Self.channel).contains("NO PRODUCER SINCE #1302"),
                      "AudioFeatureChannel.swift no longer says it has no producer — its first "
                      + "line claims it 'carries input features to the picture'.")
        XCTAssertTrue(try text(Self.extractor).contains("NO CALLER SINCE #1302"),
                      "AudioFeatureExtractor.swift no longer records that nothing calls it.")
        XCTAssertTrue(try text(Self.renderer).contains("AND THE GUARD TICK WAS DELETED WITH THE MICROPHONE"),
                      "the render path's comment no longer retracts 'The features arrive at the "
                      + "guard tick (~15 Hz)' — the tick went with #1302, and this is the "
                      + "comment a session reads while deciding what the picture reacts to.")
    }

    /// Claim 4 — END-TO-END: silence is the EXACT zero. The #1244 skip compares the uniform
    /// block byte-for-byte, so a feature that trembled at 1e-5 would keep the device drawing
    /// sixty full frames a second for nothing. A restored producer must not break this.
    func testSilenceIsExactlyZero() throws {
        let silent = AudioFeatureFrame.silent(at: 12.5)
        XCTAssertEqual(silent.level, 0)
        XCTAssertTrue(silent.isSilent,
                      "`AudioFeatureFrame.silent(at:)` does not report itself silent — the "
                      + "renderer's `isSilent ? 0 :` hue gate would then apply a tint from a "
                      + "frame that measured nothing.")
    }

    // MARK: - helpers

    private static func sourcesExcept(_ excluded: [String]) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: sources.path) else { return "" }
        var joined = ""
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            let full = "Sources/" + relative
            if excluded.contains(full) { continue }
            if let body = try? String(contentsOf: sources.appendingPathComponent(relative),
                                      encoding: .utf8) {
                joined += SourceText.codeOnly(body) + "\n"
            }
        }
        return joined
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
