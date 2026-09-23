// TheWarpSwitchIsHonestTests.swift
// Echoel — #C1 (founder 2026-09-23: "WARP / NATIVE BPM: Approved.")
//
// WHAT KIND OF GUARD THIS IS (§1). Claims 1–7 are END-TO-END BEHAVIOUR over shipped, public
// value types: `AudioWarp`'s pure decisions driven with hand-built `TimelineDocument`/`Clip`
// values, and claim 5 checks them against the ENGINE's own rate (`StretchPlan.resolve`) and
// the ENGINE's own tick→seconds map. No store is constructed — the real `TimelineStore` and
// `ClipStore` persist into the shared App Group. Claims 8–9 are SOURCE-TEXT SCANS of the one
// write path and the surface. Whether a warped loop SOUNDS in time is a DEVICE question,
// registered as NEEDS-FOUNDER-VERIFY (23)–(27) in `Studio/WorkstationView.swift`.
//
// HONEST GRADING (§3). `AudioWarp` and `TimelineStore.setRegionWarp` are created by this
// commit, so the file does not compile against the parent and NO assertion has a verdict
// there; every behavioural claim is a FORWARD guard. It was graded by TRANSCRIPTION: the
// span arithmetic re-driven in Python (ticks rounded like `TimelineTime.ticks`, bars ceiled
// like `coveringBars`, rate clamped like `TempoMatch.rateRange`), giving 9600 unwarped at
// 120, 7680 warped at 90/120/140, and 9600 under the 40→200 clamp. The scans were driven
// against the worktree (all present) and the parent (every positive needle absent — one
// absence, #486).
//
// COUNTERWEIGHTS (#343): claim 1's premise that an unwarped part plays at rate 1, and claim
// 9's pin that the facts stay ONE combined element while the switch stays outside it.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheWarpSwitchIsHonestTests: XCTestCase {

    // A 4-bar loop at 100 BPM lasts exactly 9.6 s. Placed unwarped at 120 it covers 4.8 bars,
    // i.e. FIVE whole bars — the import's own `unwarpedRegion` span.
    private static let native = 100.0
    private static let seconds = 9.6
    private static let song = 120.0
    private static let bar = TimelineTime.ticksPerBar

    private struct Fixture {
        var document: TimelineDocument
        var clips: [Clip]
        let laneID: UUID
    }

    private func fixture(nativeBPM: Double = native,
                         duration: Double? = seconds,
                         offset: Double = 0,
                         warped: [Bool] = [false],
                         laneKind: ClipKind = .audio) -> Fixture {
        let lane = TimelineLane(name: "Audio 1", kind: laneKind)
        var clips: [Clip] = []
        var regions: [TimelineRegion] = []
        for (index, isWarped) in warped.enumerated() {
            let clip = Clip(name: "loop \(index)", kind: .audio, mediaRef: "/tmp/loop\(index).wav",
                            nativeDurationSeconds: duration, nativeBPM: nativeBPM)
            clips.append(clip)
            let start = index * 8 * Self.bar
            regions.append(TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: start,
                                          lengthTicks: 5 * Self.bar,
                                          contentOffsetSeconds: offset,
                                          warpEnabled: isWarped))
        }
        return Fixture(document: TimelineDocument(lanes: [lane], regions: regions),
                       clips: clips, laneID: lane.id)
    }

    /// 1. No known native tempo → no switch; a known one → the switch reads the parts.
    func testTheSwitchExistsOnlyWhereAPartCanWarp() {
        let unknown = fixture(nativeBPM: 0)
        XCTAssertEqual(AudioWarp.state(laneID: unknown.laneID, in: unknown.document,
                                       clips: unknown.clips), .unavailable,
                       "a clip whose tempo stayed unclear has nothing to warp TO — show no switch")
        let midiLane = fixture(laneKind: .midi)
        XCTAssertEqual(AudioWarp.state(laneID: midiLane.laneID, in: midiLane.document,
                                       clips: midiLane.clips), .unavailable,
                       "only an AUDIO track carries a warp switch")
        let off = fixture()
        XCTAssertEqual(AudioWarp.state(laneID: off.laneID, in: off.document, clips: off.clips), .off)
        let on = fixture(warped: [true, true])
        XCTAssertEqual(AudioWarp.state(laneID: on.laneID, in: on.document, clips: on.clips), .on)
        let mixed = fixture(warped: [true, false])
        XCTAssertEqual(AudioWarp.state(laneID: mixed.laneID, in: mixed.document,
                                       clips: mixed.clips), .mixed)
        // Premise (counterweight): an unwarped part plays at recorded speed, so "off" is honest.
        let plan = StretchPlan.resolve(mode: .clean, warpEnabled: false, nativeBPM: Self.native,
                                       projectBPM: Self.song,
                                       capabilities: StretchMode.timelineCapabilities)
        XCTAssertEqual(plan.rate, 1.0)
    }

    /// 2. On: the whole-file part is warped AND resized to the bars its file covers at the
    /// engine's rate — 4 bars, not the 5 it was placed with. Off: back to the import's span.
    func testWarpingResizesAWholeFilePartToItsOwnBars() throws {
        let f = fixture()
        let on = AudioWarp.changes(warp: true, laneID: f.laneID, in: f.document,
                                   clips: f.clips, bpm: Self.song)
        let change = try XCTUnwrap(on.first)
        XCTAssertEqual(on.count, 1)
        XCTAssertTrue(change.warpEnabled)
        XCTAssertEqual(change.lengthTicks, 4 * Self.bar,
                       "a 9.6 s loop at 100 BPM is four bars; left at five, its last bar is silent")

        var warped = f.document
        warped.regions[0].warpEnabled = true
        warped.regions[0].lengthTicks = change.lengthTicks
        let off = AudioWarp.changes(warp: false, laneID: f.laneID, in: warped,
                                    clips: f.clips, bpm: Self.song)
        XCTAssertEqual(off.first?.warpEnabled, false)
        XCTAssertEqual(off.first?.lengthTicks,
                       AudioClipFactory.coveringBars(forDurationSeconds: Self.seconds,
                                                     bpm: Self.song) * Self.bar,
                       "off returns the part to exactly what the import placed (#416)")
    }

    /// 3. A warped loop spans the same bars at ANY song tempo inside the engine's range — the
    /// property that lets it survive a flow tempo that follows the body.
    func testAWarpedLoopSpansItsBarsAtAnyTempo() {
        let f = fixture()
        for bpm in [90.0, 120.0, 140.0] {
            let length = AudioWarp.changes(warp: true, laneID: f.laneID, in: f.document,
                                           clips: f.clips, bpm: bpm).first?.lengthTicks
            XCTAssertEqual(length, 4 * Self.bar, "at \(bpm) BPM")
        }
    }

    /// 4. A trimmed part (content offset > 0) is an AUTHORED window: its length is kept and
    /// only its rate changes. Missing duration or a broken tempo also keeps the length.
    func testAnAuthoredWindowKeepsItsLength() {
        let trimmed = fixture(offset: 1.0)
        XCTAssertEqual(AudioWarp.changes(warp: true, laneID: trimmed.laneID, in: trimmed.document,
                                         clips: trimmed.clips, bpm: Self.song).first?.lengthTicks,
                       5 * Self.bar)
        let noDuration = fixture(duration: nil)
        XCTAssertEqual(AudioWarp.changes(warp: true, laneID: noDuration.laneID,
                                         in: noDuration.document, clips: noDuration.clips,
                                         bpm: Self.song).first?.lengthTicks, 5 * Self.bar)
        let f = fixture()
        for bad in [Double.nan, 0, -1, .infinity] {
            let change = AudioWarp.changes(warp: true, laneID: f.laneID, in: f.document,
                                           clips: f.clips, bpm: bad).first
            XCTAssertEqual(change?.warpEnabled, true, "the flag still follows the switch")
            XCTAssertEqual(change?.lengthTicks, 5 * Self.bar, "no span from a bpm of \(bad)")
        }
    }

    /// 5. The span AGREES WITH THE ENGINE: over the part's length, at the rate `AudioLanePlayer`
    /// will ask for, the media consumed covers the whole file and overshoots by less than one
    /// bar — including where `TempoMatch` clamps the rate (native 40 → song 200 wants 5×,
    /// plays 4×), which is the case a "bars at the native tempo" shortcut gets wrong.
    func testTheSpanCoversTheFileAtTheRateTheEnginePlays() throws {
        let cases: [(native: Double, duration: Double, song: Double, bars: Int)] = [
            (100, 9.6, 120, 4), (100, 9.6, 90, 4), (40, 24, 200, 5),
        ]
        for c in cases {
            let f = fixture(nativeBPM: c.native, duration: c.duration)
            let change = try XCTUnwrap(AudioWarp.changes(warp: true, laneID: f.laneID,
                                                         in: f.document, clips: f.clips,
                                                         bpm: c.song).first)
            XCTAssertEqual(change.lengthTicks, c.bars * Self.bar, "native \(c.native) → \(c.song)")
            let rate = StretchPlan.resolve(mode: .clean, warpEnabled: true, nativeBPM: c.native,
                                           projectBPM: c.song,
                                           capabilities: StretchMode.timelineCapabilities).rate
            let consumed = TimelineTime.seconds(fromTicks: change.lengthTicks, bpm: c.song) * rate
            let barOfMedia = TimelineTime.seconds(fromTicks: Self.bar, bpm: c.song) * rate
            XCTAssertGreaterThanOrEqual(consumed + 1e-9, c.duration, "the part ends before its file")
            XCTAssertLessThan(consumed - c.duration, barOfMedia, "the part overshoots by a bar or more")
        }
    }

    /// 6. No change → no write. Mixed → on touches only the unwarped part. (No undo spam.)
    func testASwitchThatWouldChangeNothingWritesNothing() {
        let f = fixture()
        XCTAssertEqual(f.document.regions[0].lengthTicks,
                       AudioClipFactory.coveringBars(forDurationSeconds: Self.seconds,
                                                     bpm: Self.song) * Self.bar,
                       "premise: the fixture part sits at exactly its import span")
        XCTAssertTrue(AudioWarp.changes(warp: false, laneID: f.laneID, in: f.document,
                                        clips: f.clips, bpm: Self.song).isEmpty,
                      "an off part at its import span has nothing to turn off")

        let mixed = fixture(warped: [true, false])
        var aligned = mixed.document
        aligned.regions[0].lengthTicks = 4 * Self.bar
        let changes = AudioWarp.changes(warp: true, laneID: mixed.laneID, in: aligned,
                                        clips: mixed.clips, bpm: Self.song)
        XCTAssertEqual(changes.map(\.regionID), [aligned.regions[1].id])
    }

    /// 7. Parts on OTHER tracks are never touched.
    func testTheSwitchStaysOnItsOwnTrack() {
        let f = fixture()
        let other = TimelineLane(name: "Audio 2", kind: .audio)
        var doc = f.document
        doc.lanes.append(other)
        doc.regions.append(TimelineRegion(laneID: other.id, clipID: f.clips[0].id,
                                          startTick: 0, lengthTicks: 5 * Self.bar))
        let changes = AudioWarp.changes(warp: true, laneID: f.laneID, in: doc,
                                        clips: f.clips, bpm: Self.song)
        XCTAssertEqual(changes.map(\.regionID), [doc.regions[0].id])
    }

    /// 8. SOURCE-TEXT SCAN — one write path. The store's setter has exactly one production
    /// caller, `AudioWarp`, and `AudioWarp` never reaches the session tempo or the algorithm.
    func testTheStoreIsWrittenOnlyThroughTheDecision() throws {
        let store = try code("Sources/Echoelmusic/Core/TimelineStore.swift")
        XCTAssertTrue(store.contains("public func setRegionWarp(_ changes: [AudioWarp.Change])"))
        XCTAssertTrue(store.contains("snapshotForUndo()"), "the switch must be undoable")

        let warp = try code("Sources/Echoelmusic/Sequencer/AudioWarp.swift")
        XCTAssertTrue(warp.contains("timeline.setRegionWarp(plan)"))
        XCTAssertTrue(warp.contains("StretchPlan.resolve("),
                      "the span must ask the engine's rate, not re-derive it (#416)")
        for forbidden in ["setTempo", "SessionContext", "stretchMode =", "nativeBPM ="] {
            XCTAssertFalse(warp.contains(forbidden), "AudioWarp must not write \(forbidden)")
        }

        var callers: [String] = []
        let root = try repoRoot().appendingPathComponent("Sources")
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  !url.path.hasSuffix("Core/TimelineStore.swift"),
                  let text = try? String(contentsOf: url, encoding: .utf8),
                  SourceText.codeOnly(text).contains("setRegionWarp(") else { continue }
            callers.append(url.lastPathComponent)
        }
        XCTAssertEqual(callers, ["AudioWarp.swift"],
                       "`setRegionWarp` must be reached only through `AudioWarp` — found \(callers)")
    }

    /// 9. SOURCE-TEXT SCAN — the surface. The view calls the switch once, hands the stores over,
    /// is unavailable while playing, and keeps the switch OUTSIDE the combined facts (#621).
    func testTheSurfaceHandsTheStoresOverAndKeepsTheSwitchItsOwnElement() throws {
        let view = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(view.components(separatedBy: "AudioWarp.setWarp(").count - 1, 1)
        XCTAssertTrue(view.contains("timeline: timeline"))
        XCTAssertTrue(view.contains(".disabled(playing)"))
        XCTAssertTrue(view.contains(".accessibilityValue(on ?"),
                      "a switch must speak its state, not only its name")

        guard let factsStart = view.range(of: "private func laneFacts("),
              let factsEnd = view.range(of: "private func warpSwitch(",
                                        range: factsStart.upperBound..<view.endIndex) else {
            XCTFail("ANCHOR MISSING: laneFacts / warpSwitch")
            return
        }
        let facts = view[factsStart.upperBound..<factsEnd.lowerBound]
        XCTAssertTrue(facts.contains(".accessibilityElement(children: .combine)"),
                      "the lane's facts stay ONE spoken sentence (#1436)")
        XCTAssertFalse(facts.contains("warpSwitch("),
                       "the switch must sit OUTSIDE the combined element, or VoiceOver loses it (#621)")
        guard let rowStart = view.range(of: "private func laneRow("),
              let rowEnd = view.range(of: "private func laneFacts(",
                                      range: rowStart.upperBound..<view.endIndex) else {
            XCTFail("ANCHOR MISSING: laneRow")
            return
        }
        XCTAssertTrue(view[rowStart.upperBound..<rowEnd.lowerBound].contains("warpSwitch(laneID: row.id)"))
    }

    // MARK: - Source helpers

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func code(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        // #1240: only a missing TREE may skip; an unreadable file that exists is a red.
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — this guard inspects source text (#454)")
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        return SourceText.codeOnly(text)
    }
}
