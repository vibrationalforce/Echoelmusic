// ThePictureFollowsTheSongClockTests.swift
// Echoel — GMMW VV-7 (founder 2026-10-04, E12: "Erst Video-Spur abspielen"). A picture lane shows
// what the song clock says it shows: the part the scheduler picks, at the file position the song
// position demands, and a drifting player is pulled back without a jump at the deadband edge.
//
// WHAT THIS GUARDS. `VideoLanePlan` is the pure plan a picture-lane player (VV-8, not built yet)
// will execute. It owns none of the three decisions it combines — precedence is
// `TimelineScheduling.activeRegion` (#1440), the file position is
// `AudioRegionPlayback.filePositionSeconds` (#416), the file is the injected resolver's (#1439) —
// and this file pins that it ASKS rather than re-derives. The one rule it does own is the resync
// ramp ported from the deleted `VideoResyncPolicy`: the rate correction starts at zero at the
// deadband edge (the 2026-07-16 judder fix).
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR: on a lane with overlapping parts (a long part, two shorter ones on
//      one start, placed in order) the plan shows exactly the part `activeRegion` returns at
//      EVERY grid tick, and a part whose shadow lifts comes back at its own song position, not
//      from its start. SOURCE-TEXT SCAN: the plan never walks the regions itself.
//   2. END-TO-END BEHAVIOUR: the file position is the part's offset plus the song seconds since it
//      began; the remaining run is the song seconds to its end. Written from the algebra (#442):
//      at 120 BPM one beat is 0.5 s. SOURCE-TEXT SCAN: it asks `filePositionSeconds` with an
//      explicit rate of 1.
//   3. END-TO-END BEHAVIOUR: a part with nothing to show goes dark — file not found, a non-video
//      clip, a lane that is not a picture lane (MIDI, or the bio lane), a tempo that cannot map.
//      A stepped-into part whose file is missing is `.clear`, never the previous part's picture.
//   4. END-TO-END BEHAVIOUR: a file shorter than its part holds its last frame; a clip of unknown
//      length never claims to in the plan (the player's measured length decides, claim 6).
//   5. END-TO-END BEHAVIOUR: one command per picture lane per step, in lane order — entering a part
//      is `.show` at the step's position, staying is `.keep`, leaving into a gap is `.clear`.
//   6. END-TO-END BEHAVIOUR of the resync: hold inside one frame, a nudge that leaves rate 1
//      continuously at the edge and slows a picture that is ahead / speeds one that is behind,
//      the ±3 % ceiling, a seek beyond 0.25 s or on a non-finite report, and a still last frame
//      that is held or sought but never nudged. Drift is anchored at an expected position of
//      exactly 0, so every boundary is exact (#442). A clip of unknown length past the end of the
//      item the player measured holds that item's last frame instead of being sought past it.
//   7. COUNTERWEIGHT (#1438, forward): `.video` may join `ClipKind.timelineEngineKinds` only
//      together with an executor — some file other than the plan that calls it. Vacuously true
//      today; its job is to go red on a commit that moves the label ahead of the engine. Two limits
//      it does not hide: any CODE mention counts as a caller, and it is one-directional — an
//      executor landing without the label passes (the #1438 under-claim), which #364 accepts.
//   8. SOURCE-TEXT SCAN of the prose: the doc comments over `videoLaneEvents` and `videoLaneIDs`
//      name their consumer instead of announcing the model's retirement — and, while no executor
//      exists, say that VV-8 is still to come. Once one exists that sentence is history and the
//      check stands down rather than pinning it.
//
// ⚠️ HONEST GRADING (#433), transcribed in Python against the parent and the worktree. This file
// names `VideoLanePlan`, which this same commit creates, so it does NOT compile against the
// parent's `Sources/` and no assertion has a verdict there. Claims 1–6 are FORWARD by
// construction; claim 7 is a forward counterweight, vacuous until `.video` is added — on the
// parent its census would select nothing, the same single absence as the rest (#486); claim 8
// would be red on the parent by content — both comments said the model retires and neither
// named a consumer. Mutants, each red on the claim it targets: precedence by the earliest
// start, the first of two on one start, a part re-entered from its own start, the default
// stretch rate dropped for 1.25, no resolver check, no kind check, no lane check, the held
// frame on the file's last second, the ramp from the deadband value instead of zero, the sign
// flipped, no ceiling, a held frame nudged, the player's item length ignored, `.video` in the
// engine set. Stripper `SourceText.codeOnly`: TRAGEND for claim 7 (under the `.video` mutant the
// RAW census counts `TimelineScheduling.swift`'s doc comments, which name the plan, as a caller
// and stays green — 1 verdict flips); PROPHYLAKTISCH for claim 1's `.regions` scan (the prose says
// "regions", never `.regions`); claim 8 reads the RAW text on purpose, because what it pins IS prose.
//
// ⚠️ THE LIMIT. Nothing here plays a picture. Whether a real player slaved to these commands
// stays on the beat, whether a 1/30-s deadband reads as locked on a 60 Hz display, and whether
// the ±3 % nudge is invisible are DEVICE PROBES that belong to VV-8.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePictureFollowsTheSongClockTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let beat = TimelineTime.ticksPerQuarter
    private static let step = TimelineTime.ticksPerTransportStep
    private static let planPath = "Sources/Echoelmusic/Sequencer/VideoLanePlan.swift"
    private static let schedulingPath = "Sources/Echoelmusic/Sequencer/TimelineScheduling.swift"

    private struct Library {
        var clips: [UUID: Clip] = [:]
        var files: [UUID: URL] = [:]
        mutating func add(_ clip: Clip, resolvable: Bool = true) {
            clips[clip.id] = clip
            if resolvable { files[clip.id] = URL(fileURLWithPath: "/media/\(clip.name).mov") }
        }
        func shot(_ doc: TimelineDocument, _ lane: UUID, _ tick: Int, bpm: Double = 120) -> VideoLanePlan.Shot? {
            VideoLanePlan.shot(in: doc, laneID: lane, at: tick, bpm: bpm,
                               clip: { clips[$0] }, resolveURL: { files[$0] })
        }
        func commands(_ doc: TimelineDocument, from: Int, to: Int) -> [VideoLanePlan.Command] {
            VideoLanePlan.commands(in: doc, fromTick: from, toTick: to, bpm: 120,
                                   clip: { clips[$0] }, resolveURL: { files[$0] })
        }
    }

    private static func video(_ name: String, seconds: Double? = 100) -> Clip {
        Clip(name: name, kind: .video, mediaRef: "\(name).mov", nativeDurationSeconds: seconds)
    }

    // MARK: 1 — precedence is the scheduler's

    func testTheOverlappingPartIsTheSchedulersChoice() throws {
        let lane = TimelineLane(name: "Picture", kind: .video)
        var library = Library()
        let long = Self.video("long"), first = Self.video("first"), placedLater = Self.video("later")
        [long, first, placedLater].forEach { library.add($0) }
        let longPart = TimelineRegion(laneID: lane.id, clipID: long.id, startTick: 0, lengthTicks: 4 * Self.bar)
        let firstPart = TimelineRegion(laneID: lane.id, clipID: first.id, startTick: Self.bar, lengthTicks: Self.bar)
        let laterPart = TimelineRegion(laneID: lane.id, clipID: placedLater.id, startTick: Self.bar, lengthTicks: Self.bar)
        let doc = TimelineDocument(lanes: [lane], regions: [longPart, firstPart, laterPart])

        var checked = 0
        for tick in stride(from: 0, through: 5 * Self.bar, by: Self.step) {
            let scheduler = TimelineScheduling.activeRegion(in: doc, laneID: lane.id, at: tick)
            XCTAssertEqual(library.shot(doc, lane.id, tick)?.regionID, scheduler?.id,
                           "tick \(tick): the plan shows exactly the part `activeRegion` picks (#1440)")
            checked += 1
        }
        XCTAssertEqual(checked, 81, "premise: five bars of sixteenth steps, both ends included")

        XCTAssertEqual(library.shot(doc, lane.id, Self.bar)?.regionID, laterPart.id,
                       "two parts on one start: the one placed later wins")
        let back = try XCTUnwrap(library.shot(doc, lane.id, 2 * Self.bar), "the long part returns after the shadow lifts")
        XCTAssertEqual(back.regionID, longPart.id)
        XCTAssertEqual(back.mediaSeconds, 4, "…at its own song position (two bars = 4 s), not from its start")
        XCTAssertNil(library.shot(doc, lane.id, 4 * Self.bar), "the gap after the last part shows nothing")

        let entering = library.commands(doc, from: 2 * Self.bar - Self.step, to: 2 * Self.bar)
        guard case .show(let resumed)? = entering.first else {
            return XCTFail("stepping out of the shadow is a new shot: \(entering)")
        }
        XCTAssertEqual(resumed.regionID, longPart.id)
        XCTAssertEqual(resumed.mediaSeconds, 4, "the step path and the prime path agree")

        let code = try source(Self.planPath)
        XCTAssertFalse(code.contains(".regions"),
                       "the plan never walks the document's regions — precedence is defined once, in `activeRegion` (#1440)")
        XCTAssertEqual(occurrences(of: "TimelineScheduling.activeRegion(", in: code), 1)
        XCTAssertEqual(occurrences(of: "TimelineScheduling.videoLaneEvents(", in: code), 1)
        XCTAssertEqual(occurrences(of: "shot(of: region,", in: code), 2,
                       "both entry points build their shot in the one private function")
    }

    // MARK: 2 — the file position is the song position

    func testTheFilePositionIsTheSongPosition() throws {
        let lane = TimelineLane(name: "Picture", kind: .video)
        var library = Library()
        let clip = Self.video("clip")
        library.add(clip)
        let part = TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 2 * Self.bar,
                                  lengthTicks: 2 * Self.bar, contentOffsetSeconds: 1.5)
        let doc = TimelineDocument(lanes: [lane], regions: [part])

        let atStart = try XCTUnwrap(library.shot(doc, lane.id, 2 * Self.bar))
        XCTAssertEqual(atStart.mediaSeconds, 1.5, "the part begins at its file offset")
        XCTAssertEqual(atStart.remainingSeconds, 4, "two bars at 120 BPM run 4 s")
        let oneBeatIn = try XCTUnwrap(library.shot(doc, lane.id, 2 * Self.bar + Self.beat))
        XCTAssertEqual(oneBeatIn.mediaSeconds, 2, "one beat later the file is half a second further")
        XCTAssertEqual(oneBeatIn.remainingSeconds, 3.5, "and the part runs seven more beats")
        XCTAssertEqual(oneBeatIn.url, URL(fileURLWithPath: "/media/clip.mov"), "the shot carries the resolved file")
        XCTAssertFalse(oneBeatIn.holdsLastFrame)

        let slower = try XCTUnwrap(library.shot(doc, lane.id, 2 * Self.bar + Self.beat, bpm: 60))
        XCTAssertEqual(slower.mediaSeconds, 2.5, "at 60 BPM the same beat is a whole second of film")

        let code = try source(Self.planPath)
        XCTAssertEqual(occurrences(of: "AudioRegionPlayback.filePositionSeconds(", in: code), 1,
                       "the file position has one definition (#416)")
        XCTAssertTrue(code.contains("stretchRate: 1)") || code.contains("stretchRate: 1.0)"),
                      "the picture runs at rate 1, written at the call — a default appears in no diff (#431)")
    }

    // MARK: 3 — nothing to show is dark

    func testAPartWithNothingToShowGoesDark() throws {
        let picture = TimelineLane(name: "Picture", kind: .video)
        let midi = TimelineLane(name: "MIDI", kind: .midi)
        let body = TimelineLane(name: "Body", kind: .video, isBio: true)
        var library = Library()
        let shown = Self.video("shown"), missing = Self.video("missing")
        let sound = Clip(name: "sound", kind: .audio, mediaRef: "sound.wav", nativeDurationSeconds: 100)
        library.add(shown)
        library.add(missing, resolvable: false)
        library.add(sound)
        let doc = TimelineDocument(lanes: [picture, midi, body], regions: [
            TimelineRegion(laneID: picture.id, clipID: shown.id, startTick: 0, lengthTicks: Self.bar),
            TimelineRegion(laneID: picture.id, clipID: missing.id, startTick: Self.bar, lengthTicks: Self.bar),
            TimelineRegion(laneID: picture.id, clipID: sound.id, startTick: 2 * Self.bar, lengthTicks: Self.bar),
            TimelineRegion(laneID: midi.id, clipID: shown.id, startTick: 0, lengthTicks: Self.bar),
            TimelineRegion(laneID: body.id, clipID: shown.id, startTick: 0, lengthTicks: Self.bar),
        ])

        XCTAssertNotNil(library.shot(doc, picture.id, 0), "premise: a resolvable video part shows")
        XCTAssertNil(library.shot(doc, picture.id, Self.bar), "a file the resolver cannot find shows nothing (#1439)")
        XCTAssertNil(library.shot(doc, picture.id, 2 * Self.bar), "an audio clip on a picture lane shows nothing")
        XCTAssertNil(library.shot(doc, midi.id, 0), "a MIDI lane is not a picture lane, whatever its part holds")
        XCTAssertNil(library.shot(doc, body.id, 0), "the bio lane is not a picture lane")
        XCTAssertNil(library.shot(doc, picture.id, 0, bpm: 0), "a tempo that cannot map shows nothing")
        XCTAssertNil(library.shot(doc, picture.id, 0, bpm: .nan))

        let intoMissing = library.commands(doc, from: Self.bar - Self.step, to: Self.bar)
        XCTAssertEqual(intoMissing, [.clear(laneID: picture.id)],
                       "stepping into a part with no file darkens the lane — the previous part's picture never stays up")
    }

    // MARK: 4 — a short file holds its last frame

    func testAShortFileHoldsItsLastFrame() throws {
        let lane = TimelineLane(name: "Picture", kind: .video)
        var library = Library()
        let short = Self.video("short", seconds: 3), unknown = Self.video("unknown", seconds: nil)
        library.add(short)
        library.add(unknown)
        let doc = TimelineDocument(lanes: [lane], regions: [
            TimelineRegion(laneID: lane.id, clipID: short.id, startTick: 0, lengthTicks: 2 * Self.bar,
                           contentOffsetSeconds: 1.5),
            TimelineRegion(laneID: lane.id, clipID: unknown.id, startTick: 2 * Self.bar, lengthTicks: 2 * Self.bar,
                           contentOffsetSeconds: 1.5),
        ])

        let running = try XCTUnwrap(library.shot(doc, lane.id, 2 * Self.beat))
        XCTAssertEqual(running.mediaSeconds, 2.5, "one second in, a 3-s file still runs")
        XCTAssertFalse(running.holdsLastFrame)
        let held = try XCTUnwrap(library.shot(doc, lane.id, 3 * Self.beat))
        XCTAssertTrue(held.holdsLastFrame, "at 1.5 s in, the file's 3 s are used up")
        XCTAssertEqual(held.mediaSeconds, 3 - VideoLanePlan.lastFrameMarginSeconds, accuracy: 1e-12,
                       "the held frame sits just inside the file's end")
        XCTAssertEqual(held.remainingSeconds, 2.5, "the part itself still runs to its end")

        let open = try XCTUnwrap(library.shot(doc, lane.id, 2 * Self.bar + 3 * Self.beat))
        XCTAssertFalse(open.holdsLastFrame, "an unknown length never claims the file ran out")
        XCTAssertEqual(open.mediaSeconds, 3)
    }

    // MARK: 5 — one command per picture lane per step

    func testEveryStepIsOneCommandPerPictureLane() throws {
        let a = TimelineLane(name: "A", kind: .video)
        let midi = TimelineLane(name: "MIDI", kind: .midi)
        let b = TimelineLane(name: "B", kind: .video)
        let body = TimelineLane(name: "Body", kind: .video, isBio: true)
        var library = Library()
        let one = Self.video("one"), two = Self.video("two")
        library.add(one)
        library.add(two)
        let doc = TimelineDocument(lanes: [a, midi, b, body], regions: [
            TimelineRegion(laneID: a.id, clipID: one.id, startTick: Self.bar, lengthTicks: Self.bar,
                           contentOffsetSeconds: 1),
            TimelineRegion(laneID: b.id, clipID: two.id, startTick: 0, lengthTicks: Self.bar),
        ])

        let entering = library.commands(doc, from: Self.bar - Self.step, to: Self.bar)
        XCTAssertEqual(entering.count, 2, "one command per picture lane — not the MIDI lane, not the bio lane")
        guard case .show(let shot)? = entering.first else { return XCTFail("lane A enters its part: \(entering)") }
        XCTAssertEqual(shot.laneID, a.id, "lanes in document order")
        XCTAssertEqual(shot.mediaSeconds, 1, "entering at the part's start shows its offset")
        XCTAssertEqual(entering.last, .clear(laneID: b.id), "lane B left its part into a gap")

        XCTAssertEqual(library.commands(doc, from: Self.bar, to: Self.bar + Self.step),
                       [.keep(laneID: a.id), .keep(laneID: b.id)], "staying is not a reload")
        XCTAssertEqual(library.commands(doc, from: 2 * Self.bar - Self.step, to: 2 * Self.bar),
                       [.clear(laneID: a.id), .keep(laneID: b.id)])
    }

    // MARK: 6 — the resync ramp

    func testTheRampStartsAtZeroAtTheDeadbandEdge() throws {
        let lane = TimelineLane(name: "Picture", kind: .video)
        var library = Library()
        let clip = Self.video("clip"), short = Self.video("short", seconds: 1)
        library.add(clip)
        library.add(short)
        let doc = TimelineDocument(lanes: [lane], regions: [
            TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 0, lengthTicks: Self.bar),
            TimelineRegion(laneID: lane.id, clipID: short.id, startTick: Self.bar, lengthTicks: Self.bar),
        ])
        let zero = try XCTUnwrap(library.shot(doc, lane.id, 0))
        XCTAssertEqual(zero.mediaSeconds, 0, "premise: drift is measured from exactly 0 (#442)")
        func resync(_ observed: Double) -> VideoLanePlan.Resync {
            VideoLanePlan.resync(zero, observedSeconds: observed, itemSeconds: 100)
        }
        func rate(_ observed: Double) -> Double? {
            if case .nudge(let r) = resync(observed) { return Double(r) }
            return nil
        }
        let edge = VideoLanePlan.deadbandSeconds
        let gain = VideoLanePlan.slewPerSecondOfDrift

        XCTAssertEqual(resync(0), .hold)
        XCTAssertEqual(resync(edge), .hold, "one frame of drift is held")
        XCTAssertEqual(resync(-edge), .hold)
        for excess in [1e-3, 1e-4, 1e-6] {
            let ahead = try XCTUnwrap(rate(edge + excess), "just past the edge is a nudge")
            let behind = try XCTUnwrap(rate(-(edge + excess)))
            XCTAssertLessThan(ahead, 1, "a picture AHEAD of the song slows down")
            XCTAssertGreaterThan(behind, 1, "a picture BEHIND the song speeds up")
            XCTAssertEqual(1 - ahead, excess * gain, accuracy: 1e-7,
                           "the correction is the drift BEYOND the edge — it starts at zero there (the 2026-07-16 judder fix)")
            XCTAssertEqual(behind - 1, excess * gain, accuracy: 1e-7)
        }
        XCTAssertEqual(rate(0.2), Double(Float(1 - VideoLanePlan.maxSlew)), "the slew stops at 3 %")
        XCTAssertEqual(rate(-0.2), Double(Float(1 + VideoLanePlan.maxSlew)))
        XCTAssertNotNil(rate(VideoLanePlan.seekBeyondSeconds), "0.25 s itself is still slewed")
        XCTAssertEqual(resync(0.26), .seek(toSeconds: 0), "beyond 0.25 s the player jumps")
        XCTAssertEqual(resync(-0.26), .seek(toSeconds: 0))
        XCTAssertEqual(resync(.nan), .seek(toSeconds: 0), "a player that cannot say where it is is re-anchored")
        XCTAssertEqual(resync(.infinity), .seek(toSeconds: 0))

        let still = try XCTUnwrap(library.shot(doc, lane.id, Self.bar + 3 * Self.beat))
        XCTAssertTrue(still.holdsLastFrame, "premise: a 1-s file is used up 1.5 s into its part")
        XCTAssertEqual(VideoLanePlan.resync(still, observedSeconds: still.mediaSeconds + 0.01, itemSeconds: nil), .hold)
        XCTAssertEqual(VideoLanePlan.resync(still, observedSeconds: still.mediaSeconds - 0.1, itemSeconds: nil),
                       .seek(toSeconds: still.mediaSeconds), "a still frame that is wrong is sought, never nudged")
    }

    func testAnUnmeasuredClipHoldsTheEndThePlayerMeasured() throws {
        let lane = TimelineLane(name: "Picture", kind: .video)
        var library = Library()
        let unknown = Self.video("unknown", seconds: nil)
        library.add(unknown)
        let doc = TimelineDocument(lanes: [lane], regions: [
            TimelineRegion(laneID: lane.id, clipID: unknown.id, startTick: 0, lengthTicks: 4 * Self.bar),
        ])
        let late = try XCTUnwrap(library.shot(doc, lane.id, 10 * Self.beat))
        XCTAssertEqual(late.mediaSeconds, 5, "premise: ten beats in, the plan asks for 5 s of the file")
        XCTAssertFalse(late.holdsLastFrame, "premise: a clip of unknown length never holds in the plan")
        let end = 3 - VideoLanePlan.lastFrameMarginSeconds

        XCTAssertEqual(VideoLanePlan.resync(late, observedSeconds: 3, itemSeconds: 3), .hold,
                       "a player stopped at the end of a 3-s item is where the song wants it — no seek past the end")
        XCTAssertEqual(VideoLanePlan.resync(late, observedSeconds: 1, itemSeconds: 3), .seek(toSeconds: end),
                       "a player short of that end is sought to the item's last frame, not to 5 s")
        XCTAssertEqual(VideoLanePlan.resync(late, observedSeconds: 3 - 0.05, itemSeconds: 3), .seek(toSeconds: end),
                       "the held end is a still frame: sought, never nudged")
        XCTAssertEqual(VideoLanePlan.resync(late, observedSeconds: 3, itemSeconds: nil), .seek(toSeconds: 5),
                       "counterweight: until the player knows its length, the plan's position stands")
        XCTAssertEqual(VideoLanePlan.resync(late, observedSeconds: 5, itemSeconds: 100), .hold,
                       "counterweight: an item longer than the position changes nothing")
    }

    // MARK: 7 — the label waits for the engine

    func testTheVideoLabelWaitsForItsExecutor() throws {
        let callers = try filesCalling("VideoLanePlan").filter { $0 != Self.planPath }
        if ClipKind.timelineEngineKinds.contains(.video) {
            XCTAssertFalse(callers.isEmpty, """
                `.video` is in `timelineEngineKinds`, but no file outside the plan calls `VideoLanePlan` — the \
                label moved ahead of the engine (#1438). Land the executor (VV-8) with it.
                """)
        }
        XCTAssertTrue(ClipKind.midi.isPlayable && ClipKind.audio.isPlayable,
                      "premise: the set is read through `isPlayable`, and the two engines that exist are in it")
    }

    // MARK: 8 — the prose names the consumer

    func testTheSchedulingCommentsNameTheirConsumer() throws {
        let raw = try rawSource(Self.schedulingPath)
        let events = try docComment(above: "public static func videoLaneEvents(", in: raw)
        XCTAssertTrue(events.contains("VideoLanePlan.commands"),
                      "the scheduler's video events name the plan that consumes them")
        let executors = try filesCalling("VideoLanePlan").filter { $0 != Self.planPath }
        if executors.isEmpty {
            XCTAssertTrue(events.contains("VV-8"), "…and, while no executor exists, say that it is still to come")
        }
        let ids = try docComment(above: "var videoLaneIDs: [UUID]", in: raw)
        XCTAssertTrue(ids.contains("VideoLanePlan.shot"), "the picture-lane set names the plan that refuses other lanes")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let reason: String }

    /// The contiguous `///` lines directly above the first occurrence of `head`.
    private func docComment(above head: String, in raw: String) throws -> String {
        guard let range = raw.range(of: head) else {
            XCTFail("ANCHOR MISSING: `\(head)` (#408)")
            throw AnchorMissing(reason: head)
        }
        let before = raw[..<range.lowerBound].components(separatedBy: "\n").dropLast()
        let block = before.reversed().prefix { $0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }
        XCTAssertFalse(block.isEmpty, "no doc comment above `\(head)`")
        return block.reversed().joined(separator: "\n")
    }

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

    private func rawSource(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            // The tree is here (`repoRoot` found it), so a missing file is a move, not a missing
            // checkout — a skip would turn half of claims 1, 2 and 8 into silence (#454).
            XCTFail("`\(relativePath)` is gone — renamed or moved? Point this guard at its new home.")
            throw AnchorMissing(reason: relativePath)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func source(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try rawSource(relativePath))
    }

    /// Every Swift file under `Sources/` whose CODE (comments stripped) contains `needle`, as
    /// repo-relative paths, sorted.
    private func filesCalling(_ needle: String) throws -> [String] {
        let sources = try repoRoot().appendingPathComponent("Sources")
        guard FileManager.default.fileExists(atPath: sources.path),
              let walker = FileManager.default.enumerator(atPath: sources.path) else {
            throw XCTSkip("cannot enumerate Sources/ — refusing to report a green it did not earn")
        }
        var hits: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            let text = try String(contentsOf: sources.appendingPathComponent(relative), encoding: .utf8)
            if SourceText.codeOnly(text).contains(needle) {
                hits.append("Sources/" + relative)
            }
        }
        XCTAssertFalse(hits.isEmpty, "the scan selected nothing — a census of nothing is a finding (#454)")
        return hits.sorted()
    }
}
