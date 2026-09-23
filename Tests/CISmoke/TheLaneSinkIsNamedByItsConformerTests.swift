// SOURCE-TEXT SCAN plus a tree walk (§1). It proves which TYPE the docs name and that the
// dead one still has no code reference; it does not play a lane — that is a DEVICE PROBE.
//
// ── WHAT #1381 FOUND ────────────────────────────────────────────────────────────────
// `AudioClipPlayer` has ZERO callers and ZERO tests (#1230 measured the half correctly,
// #1376 and #1379 corrected four comments that claimed it renders). EIGHT further files
// still signposted it as the LIVE executor, and five of those were outright false:
//   · `AudioLanePlayer` header — "the thin AVFoundation adapter (an AudioClipPlayer per
//     lane) … land in a following cycle", eight lines above that same header's own
//     "WIRED since v191". A claim and its refutation in one block (#425).
//   · its `AudioRegionSink` doc and its `makeSink` doc — both named `AudioClipPlayer` as
//     the implementation. It conforms to nothing.
//   · `AudioEngine.attachPlayerNode(_:format:)` — "Used by AudioClipPlayer". Wrong twice:
//     that type has no callers, and it never used THIS overload (it takes `through:`).
//   · `AudioClipRegion` header — "the forthcoming AudioClipPlayer … consumes this". Not
//     forthcoming; the file exists and is dead.
// Measured instead: the only `AudioRegionSink` conformer in `Sources/` is
// `TimelineAudioSink`, injected at `EchoelmusicApp` as `makeSink`.
//
// ── WHY THE CLAIMS ARE POSITIVE, NOT ABSENCES (#491) ───────────────────────────────
// The repaired files QUOTE the sentences they retract, so a naive
// `XCTAssertFalse(contains("AudioClipPlayer"))` would strike the retraction itself — the
// trap #1379 walked into one slice ago. Claims 1 and 2 therefore pin what the docs must
// SAY; claim 4 is the only absence claim and it reads COMMENT-STRIPPED text, where a
// retraction cannot live by construction.
//
// ── GRADING AGAINST THE PARENT (§3) ────────────────────────────────────────────────
// Transcribed in Python against `git show HEAD:<path>` and the worktree (§0).
//   · REGRESSIONS: claims 1 and 2 (neither doc named the conformer on the parent).
//   · COUNTERWEIGHTS, green on BOTH trees: 3, 4, 5.
//   · ANCHOR ABSENCE: none.
//
// ⛔ CLAIM 5's FIRST DRAFT WAS RED ON BOTH TREES and produced no delta, which is the exact
// blind spot §3 names. It asked for four foreign consumers of `AudioClipRegion` on the
// strength of a `git grep -l` that counts COMMENTS: measured comment-stripped, three files
// outside its own name it in code, and two of those three are themselves dead
// (`AudioClipPlayer`, `WarpedClipPlan` — the latter found as a new orphan by this very
// measurement). `AudioRegionPlayback` takes a `TimelineRegion`. So the model is held by ONE
// live member, `nativeBPMRange`, and the claim now pins that. The #867 defect, committed
// inside the register block that states #867 as a law.
//
// ⚠️ #364 — wiring `AudioClipPlayer` up, or replacing `TimelineAudioSink`, is ordinary
// work; it reds claims 3 and 4 BY DESIGN, and their messages name the prose that must move
// in the same commit (#456).

import Foundation
import XCTest

final class TheLaneSinkIsNamedByItsConformerTests: XCTestCase {

    private static let lanePlayer = "Echoelmusic/Sequencer/AudioLanePlayer.swift"
    private static let engine = "Echoelmusic/Audio/AudioEngine.swift"
    private static let app = "Echoelmusic/EchoelmusicApp.swift"
    private static let sink = "Echoelmusic/Sequencer/TimelineAudioSink.swift"

    /// 1 — the coordinator names its real sink, in all three places it describes one.
    /// REGRESSION.
    func testTheCoordinatorNamesTheConformer() throws {
        let text = try Self.rawText(Self.lanePlayer)
        let hits = text.components(separatedBy: "TimelineAudioSink").count - 1
        XCTAssertGreaterThanOrEqual(hits, 3, """
            `AudioLanePlayer` names `TimelineAudioSink` only \(hits) time(s); three of its docs \
            describe the device sink (the file header, the `AudioRegionSink` protocol doc, and \
            the `makeSink` property doc) and each named `AudioClipPlayer` before #1381 — a type \
            that conforms to nothing and has zero callers. This is the file a reader opens to \
            learn what actually plays a lane.
            """)
    }

    /// 2 — and the engine helper names its live caller. REGRESSION.
    func testTheAttachHelperNamesItsLiveCaller() throws {
        let text = try Self.rawText(Self.engine)
        guard let doc = text.range(of: "func attachPlayerNode(_ node: AVAudioPlayerNode, format:") else {
            return XCTFail("`attachPlayerNode(_:format:)` not found — re-anchor this scan (#454).")
        }
        let head = String(text[text.startIndex..<doc.lowerBound].suffix(1200))
        XCTAssertTrue(head.contains("TimelineAudioSink"), """
            The doc above `attachPlayerNode(_:format:)` does not name `TimelineAudioSink`. That \
            is its live caller (the plain, unwarped lane path). It said "Used by \
            AudioClipPlayer", which was wrong twice over — zero callers, and that type takes the \
            `through:` overload anyway. Whoever debugs lane playback reads this line first.
            """)
    }

    /// 3 — the fact that makes claims 1 and 2 true, in CODE. COUNTERWEIGHT.
    func testTheConformerIsTheInjectedSink() throws {
        let sinkCode = try Self.codeText(Self.sink)
        XCTAssertTrue(sinkCode.contains("TimelineAudioSink: AudioRegionSink"), """
            `TimelineAudioSink` no longer declares conformance to `AudioRegionSink`. Claims 1 \
            and 2 name it as THE sink; if the conformer changed, those docs and the register \
            entry in CLAUDE.md move in the same commit (#456).
            """)
        let appCode = try Self.codeText(Self.app)
        XCTAssertTrue(appCode.contains("makeSink:") && appCode.contains("TimelineAudioSink("), """
            `EchoelmusicApp` no longer injects a `TimelineAudioSink` as `makeSink`. The \
            protocol has exactly one conformer and exactly one injection site; both halves are \
            what make "the production sink is TimelineAudioSink" a fact rather than an intention.
            """)
    }

    /// 4 — the premise: the dead executor is still dead, measured on COMMENT-STRIPPED text so
    /// the retractions that quote it cannot satisfy the scan (#491). COUNTERWEIGHT.
    func testTheDeadExecutorHasNoCodeReference() throws {
        let (scanned, refs) = try Self.filesWhoseCodeNames("AudioClipPlayer")
        XCTAssertGreaterThan(scanned, 0, "empty corpus — the walk found no Swift file (#454).")
        let foreign = refs.filter { $0 != "AudioClipPlayer.swift" }
        XCTAssertTrue(foreign.isEmpty, """
            `AudioClipPlayer` is referenced in CODE by \(foreign.joined(separator: ", ")). If it \
            was wired up, that is ordinary work (#364) — but then the register entry in \
            CLAUDE.md, the three `(dead)` pointers in `TimelineAudioSink`, and the retractions \
            in `AudioEngine` / `AudioOutputGuard+PCMBuffer` / `AudioClipRegion` / \
            `AudioLanePlayer` / `StretchMode` are all stale and move in the same commit (#456).
            """)
    }

    /// 5 — and the MODEL is not an orphan, for the ONE narrow reason that actually holds.
    /// COUNTERWEIGHT.
    ///
    /// ⚠️ This claim's first draft asked for four foreign consumers and was RED ON BOTH TREES
    /// — the #867 defect, caught only because §3 says to drive every assertion in a new file
    /// rather than the diff. `git grep -l` had counted four PROSE mentions as consumers.
    func testTheClipRegionModelIsHeldByTheSharedRange() throws {
        let clip = try Self.codeText("Echoelmusic/Sequencer/Clip.swift")
        XCTAssertTrue(clip.contains("AudioClipRegion.nativeBPMRange"), """
            `Clip.swift` no longer reads `AudioClipRegion.nativeBPMRange`. That single member is \
            the ONLY live code use of the whole editor model — measured comment-stripped, the \
            other two files naming it in code are `AudioClipPlayer` and `WarpedClipPlan`, both \
            with zero external references (S1's `AudioTempoCorrection.bounds` forwards the SAME \
            member, which is a second reader of the range, not a second spelling of it). The tempting reading of #1381 is "the executor is \
            dead, delete its model too"; what forbids that is #416 — `Clip` cites this type as \
            the home of the shared clamp range, and a second spelling of a range is the defect \
            whether or not the two agree today. If the range moved, move this claim with it.
            """)
    }

    // MARK: - helpers

    private static func filesWhoseCodeNames(_ needle: String) throws -> (Int, [String]) {
        let root = try sourcesRoot()
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return (0, [])
        }
        var scanned = 0
        var hits: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            scanned += 1
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if code.contains(needle) { hits.append(url.lastPathComponent) }
        }
        return (scanned, hits)
    }

    private static func sourcesRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path),
                          "Sources/ not present in this checkout")
        return sources
    }

    private static func rawText(_ relative: String) throws -> String {
        let url = try sourcesRoot().appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            struct Missing: Error, CustomStringConvertible {
                let p: String
                var description: String { "Sources/\(p) is missing — re-anchor this scan (#454)." }
            }
            throw Missing(p: relative)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func codeText(_ relative: String) throws -> String {
        SourceText.codeOnly(try rawText(relative))
    }
}
