// ThePictureLaneRidesTheSongClockTests.swift
// Echoel — One World V2 (founder 2026-10-15: "Video Spur fehlt"). The VV-8 executor: while the
// transport runs, the picture lane shows the part the plan names, at the song position, and a
// drifting player is corrected on the transport's own step — no clock of its own.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR: `prime` shows the part `VideoLanePlan.shot` names, a prime into a gap
//      lets the picture go ONCE (a dark lane is not cleared again), and the sink is made lazily —
//      a document with no picture creates nothing.
//   2. END-TO-END BEHAVIOUR: one step inside the same part asks the plan's `resync` — a drift of
//      0.1 s is a nudge at the ±3 % ceiling, 0.5 s is a seek to the song position, a drift inside
//      one frame is `.hold` (handed on, so the sink can return a nudged rate to 1), and a sink that cannot say where it is (loading, seeking) is never
//      corrected. Written from the algebra (#442): at 120 BPM one bar is 2 s.
//   3. END-TO-END BEHAVIOUR: ONE PICTURE, ONE LANE — a second picture lane's part is never shown,
//      by prime or by step; stepping out of the shown lane's part clears it.
//   4. END-TO-END BEHAVIOUR: both stop paths hold the frame (`pause`), and a stop before anything
//      was shown makes no sink.
//   5. SOURCE-TEXT SCAN: every place `TimelineRegionPlayer` primes, steps or stops the audio lanes
//      does the same for the picture lane — the song clock is one clock (#416). And the executor
//      stays Foundation-only with no clock, timer or observer of its own.
//
// ⚠️ HONEST GRADING (#433), transcribed in Python against both trees. This file names
// `VideoLanePlayer` and `VideoLaneSink`, which this same commit creates, so it does NOT compile
// against the parent and no assertion has a verdict there. Claims 1–4 are FORWARD by construction.
// Claim 5's twin counts would be red on the parent by content (four audio primes, zero picture
// primes) — one absence, reported three times (#486). Mutants, each red on the claim it targets:
// `clear` without the `current != nil` guard (claim 1), `correct` without the observed-seconds
// guard (claim 2), `.keep` handled for every lane (claim 3), `stopAll` dropping `pause` (claim 4),
// one `videoLanes?.prime` removed (claim 5). Stripper `SourceText.codeOnly`: PROPHYLAKTISCH for
// claim 5 (0 of 6 verdicts flip — the twin lines carry trailing comments, never commented-out
// calls).
//
// ⚠️ THE LIMIT. A spy stands in for the device half. Whether an `AVPlayer` slaved to these calls
// stays on the beat, and whether the nudges read as invisible, is a DEVICE PROBE.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ThePictureLaneRidesTheSongClockTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let step = TimelineTime.ticksPerTransportStep
    private static let playerPath = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let executorPath = "Sources/Echoelmusic/Sequencer/VideoLanePlayer.swift"

    @MainActor
    private final class SpySink: VideoLaneSink {
        /// How many times the executor asked for a sink.
        var made = 0
        var shown: [VideoLanePlan.Shot] = []
        var corrections: [VideoLanePlan.Resync] = []
        var pauses = 0
        var clears = 0
        var observedSeconds: Double?
        var itemSeconds: Double?
        func show(_ shot: VideoLanePlan.Shot) { shown.append(shot) }
        func correct(_ resync: VideoLanePlan.Resync) { corrections.append(resync) }
        func pause() { pauses += 1 }
        func clear() { clears += 1 }
    }

    /// Lane A (shown): one part, bars 0–2. Lane B (never shown): one part, bars 2–3.
    private struct Fixture {
        let laneA = TimelineLane(name: "Picture A", kind: .video)
        let laneB = TimelineLane(name: "Picture B", kind: .video)
        let clipA = Clip(name: "a", kind: .video, mediaRef: "a.mov", nativeDurationSeconds: 100)
        let clipB = Clip(name: "b", kind: .video, mediaRef: "b.mov", nativeDurationSeconds: 100)
        var document: TimelineDocument {
            TimelineDocument(lanes: [laneA, laneB], regions: [
                TimelineRegion(laneID: laneA.id, clipID: clipA.id, startTick: 0, lengthTicks: 2 * TimelineTime.ticksPerBar),
                TimelineRegion(laneID: laneB.id, clipID: clipB.id, startTick: 2 * TimelineTime.ticksPerBar,
                               lengthTicks: TimelineTime.ticksPerBar),
            ])
        }
    }

    private func executor(_ fixture: Fixture, _ spy: SpySink) -> VideoLanePlayer {
        let clips = [fixture.clipA.id: fixture.clipA, fixture.clipB.id: fixture.clipB]
        return VideoLanePlayer(makeSink: { spy.made += 1; return spy },
                               resolveURL: { clips[$0] == nil ? nil : URL(fileURLWithPath: "/media/\($0).mov") },
                               clip: { clips[$0] })
    }

    // MARK: 1 — prime shows, a gap lets go once, the sink is lazy

    func testAPrimeShowsThePartAndAGapLetsGoOnce() throws {
        let fixture = Fixture()
        let spy = SpySink()
        let player = executor(fixture, spy)
        player.prime(in: TimelineDocument(lanes: [], regions: []), atTick: 0, bpm: 120)
        XCTAssertEqual(spy.made, 0, "a document with no picture lane makes no sink")

        player.prime(in: fixture.document, atTick: Self.bar, bpm: 120)
        XCTAssertEqual(spy.made, 1)
        let shot = try XCTUnwrap(spy.shown.last)
        XCTAssertEqual(shot.laneID, fixture.laneA.id)
        XCTAssertEqual(shot.mediaSeconds, 2, "one bar into the part at 120 BPM is 2 s of file")

        player.prime(in: fixture.document, atTick: 2 * Self.bar + Self.step, bpm: 120)
        XCTAssertEqual(spy.clears, 1, "the shown lane is in a gap: the picture goes")
        player.prime(in: fixture.document, atTick: 2 * Self.bar + 2 * Self.step, bpm: 120)
        XCTAssertEqual(spy.clears, 1, "a dark lane is not cleared again")
        XCTAssertEqual(spy.made, 1, "one sink for the whole run")
    }

    // MARK: 2 — the step corrects through the plan's resync

    func testAStepInsideThePartCorrectsTowardTheSongPosition() {
        let fixture = Fixture()
        let spy = SpySink()
        let player = executor(fixture, spy)
        let doc = fixture.document
        player.prime(in: doc, atTick: 0, bpm: 120)
        let from = Self.bar - Self.step, to = Self.bar   // expected file position at `to`: 2 s

        spy.observedSeconds = nil
        player.apply(in: doc, fromTick: from, toTick: to, bpm: 120)
        XCTAssertEqual(spy.corrections, [], "a sink loading or seeking is never corrected")

        spy.observedSeconds = 2 + VideoLanePlan.deadbandSeconds / 2
        player.apply(in: doc, fromTick: from, toTick: to, bpm: 120)
        XCTAssertEqual(spy.corrections, [.hold], "drift inside one frame is held — handed on, so a nudged rate returns to 1")

        spy.observedSeconds = 2.1
        player.apply(in: doc, fromTick: from, toTick: to, bpm: 120)
        XCTAssertEqual(spy.corrections.last, .nudge(rate: Float(1 - VideoLanePlan.maxSlew)),
                       "0.1 s ahead: (0.1 − 1/30) × 0.5 > 0.03, so the nudge sits on the ceiling, slowing")

        spy.observedSeconds = 2.5
        player.apply(in: doc, fromTick: from, toTick: to, bpm: 120)
        XCTAssertEqual(spy.corrections.last, .seek(toSeconds: 2), "beyond 0.25 s the picture is sought to the song position")
        XCTAssertEqual(spy.corrections.count, 3)
        XCTAssertEqual(spy.shown.count, 1, "staying in the part is never a new shot")
    }

    // MARK: 3 — one picture, one lane

    func testASecondPictureLaneIsNeverShown() {
        let fixture = Fixture()
        let spy = SpySink()
        let player = executor(fixture, spy)
        let doc = fixture.document
        player.prime(in: doc, atTick: 0, bpm: 120)
        player.apply(in: doc, fromTick: 2 * Self.bar - Self.step, toTick: 2 * Self.bar, bpm: 120)
        XCTAssertEqual(spy.clears, 1, "stepping out of the shown lane's part clears it")
        player.prime(in: doc, atTick: 2 * Self.bar + Self.step, bpm: 120)
        spy.observedSeconds = 50
        player.apply(in: doc, fromTick: 2 * Self.bar + Self.step, toTick: 2 * Self.bar + 2 * Self.step, bpm: 120)
        XCTAssertEqual(spy.shown.map(\.laneID), [fixture.laneA.id],
                       "lane B plays a part the whole time — it is never shown (v1: one footage layer)")
        XCTAssertEqual(spy.corrections, [], "lane B's `.keep` is not lane A's correction")
    }

    // MARK: 4 — stop holds the frame

    func testStopHoldsTheFrameAndMakesNothing() {
        let fixture = Fixture()
        let spy = SpySink()
        let idle = executor(fixture, spy)
        idle.stopAll()
        XCTAssertEqual(spy.made, 0, "a stop before anything was shown makes no sink")

        let player = executor(fixture, spy)
        player.prime(in: fixture.document, atTick: 0, bpm: 120)
        player.stopAll()
        XCTAssertEqual(spy.pauses, 1)
        XCTAssertEqual(spy.clears, 0, "a stop holds the frame — it does not let the picture go")
    }

    // MARK: 5 — one clock: every audio-lane drive has its picture twin

    func testEveryAudioLaneDriveHasItsPictureTwin() throws {
        let code = try source(Self.playerPath)
        for (audio, picture) in [("audioLanes?.prime(in:", "videoLanes?.prime(in:"),
                                 ("audioLanes?.apply(in:", "videoLanes?.apply(in:"),
                                 ("audioLanes?.stopAll()", "videoLanes?.stopAll()")] {
            let a = occurrences(of: audio, in: code), p = occurrences(of: picture, in: code)
            XCTAssertGreaterThan(a, 0, "anchor `\(audio)` matched nothing — moved? (#454)")
            XCTAssertEqual(p, a, """
                `\(audio)` runs \(a)× and `\(picture)` \(p)× — the picture lane rides the SAME clock \
                as the audio lanes: prime, step and stop it everywhere they are (#416).
                """)
        }
        let executor = try source(Self.executorPath)
        let imports = executor.components(separatedBy: "\n").filter { $0.hasPrefix("import ") }
        XCTAssertEqual(imports, ["import Foundation"], "the executor is Foundation-only — the device half is the injected sink")
        for banned in ["Task {", "Task.detached", "DispatchQueue", "Timer", "addPeriodicTimeObserver", "AVPlayer"] {
            XCTAssertFalse(executor.contains(banned), "the executor has no clock of its own: `\(banned)`")
        }
    }

    // MARK: helpers

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func repoRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("source tree not present above \(#filePath)")
    }

    private func source(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("`\(relativePath)` is gone — renamed or moved? Point this guard at its new home.")
            return ""
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
