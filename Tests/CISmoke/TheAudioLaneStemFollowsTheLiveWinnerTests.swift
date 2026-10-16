// TheAudioLaneStemFollowsTheLiveWinnerTests.swift
// LS-ST2 (2026-10-16, ADR-008 K1): an audio lane's stem is rendered OFFLINE from its files and
// the document, so the plan of WHICH file stretch sounds WHEN must be the live player's answer,
// not a second one. `AudioLaneStemPlan` asks `TimelineScheduling` for the winner at the grid
// ticks where it can change, starts each segment where `AudioLanePlayer.apply` would `.load`
// it, and ends it at the region's exact end or the next winner's tick.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–6 and 8–10 are END-TO-END over the public pure `AudioLaneStemPlan` and `TimelineScheduling`.
//     Claim 5 is the cross-check: a grid walk through `laneEvent` — the call the live player
//     makes per step — loads exactly the segments the plan lists, in order.
//   · Claim 7 is a SOURCE-TEXT SCAN that the plan asks the owners and walks no regions itself.
//   · NOT CLAIMED: that a rendered stem is sample-aligned with the live mix (that is G-D, a
//     DEVICE PROBE), and nothing about gain, mute, fades, grain or launch overrides — the plan
//     is placement only and says so in its header.
//
// EXPECTED VALUES derived by hand from the algebra (#442): at 120 BPM a quarter is 0.5 s, a bar
// (1 920 ticks) is 2 s, a grid step is 120 ticks; all expected seconds are exact binary values.
//
// HONEST GRADING against the parent (§3): `AudioLaneStemPlan` does not exist there — the file
// does not COMPILE on the parent, so no assertion has a verdict there; claims 1–7 are FORWARD
// guards (one absence, #486); claims 8–10 (LS-ST3a, the frame mapping) likewise. Claim 7's last two needles are COUNTERWEIGHTS (green on both trees:
// the live player still resolves with the timeline capabilities). Mutants: overlap decided by
// start order instead of `activeRegion` (2, 3, 5) · a segment cut at the next region's START
// instead of its own end (2) · the sub-step region listed (4) · `stretchRate` dropped from the
// resume position (6) · destination frames from rounded LENGTHS instead of ticks (8) · the
// file-end clamp dropped (9) · a warped segment copied plainly (10).

import Foundation
import XCTest
// `@testable` IS LOAD-BEARING: `TimelineLane`/`TimelineDocument` initialisers are reached
// through the app module, and the scan reads `AudioLanePlayer`.
@testable import Echoelmusic

final class TheAudioLaneStemFollowsTheLiveWinnerTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let bpm: Double = 120

    private static func plan(_ regions: [TimelineRegion], lane: TimelineLane,
                             nativeBPM: @escaping (UUID) -> Double = { _ in 0 }) -> [AudioLaneStemSegment] {
        AudioLaneStemPlan.segments(in: TimelineDocument(lanes: [lane], regions: regions),
                                   laneID: lane.id, bpm: bpm, nativeBPM: nativeBPM)
    }

    // MARK: 1 — one part is one segment from its media offset

    func testOnePartIsOneSegment() {
        let lane = TimelineLane(name: "Audio", kind: .audio)
        let part = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0,
                                  lengthTicks: 4 * Self.bar, contentOffsetSeconds: 1.5)
        let segments = Self.plan([part], lane: lane)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.regionID, part.id)
        XCTAssertEqual(segments.first?.startTick, 0)
        XCTAssertEqual(segments.first?.songStartSeconds ?? -1, 0, accuracy: 1e-12)
        XCTAssertEqual(segments.first?.songLengthSeconds ?? -1, 8, accuracy: 1e-12)
        XCTAssertEqual(segments.first?.mediaFromSeconds ?? -1, 1.5, accuracy: 1e-12)
        XCTAssertEqual(segments.first?.rate, 1)
    }

    // MARK: 2 — a part laid on top takes the lane, the one beneath resumes where it would be

    func testAPartOnTopCutsAndTheOneBeneathResumes() {
        let lane = TimelineLane(name: "Audio", kind: .audio)
        let under = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0,
                                   lengthTicks: 4 * Self.bar, contentOffsetSeconds: 1.5)
        let top = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: Self.bar,
                                 lengthTicks: Self.bar)
        let segments = Self.plan([under, top], lane: lane)
        XCTAssertEqual(segments.map(\.regionID), [under.id, top.id, under.id])
        XCTAssertEqual(segments.map(\.startTick), [0, Self.bar, 2 * Self.bar])
        XCTAssertEqual(segments.map(\.songLengthSeconds), [2, 2, 4])
        XCTAssertEqual(segments.map(\.mediaFromSeconds), [1.5, 0, 5.5],
                       "the resumed part starts at its media position at that tick, not at its offset")

        // A part that ends in a gap ends at its OWN end, not at the next part's start.
        let first = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: Self.bar)
        let later = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 3 * Self.bar, lengthTicks: Self.bar)
        XCTAssertEqual(Self.plan([first, later], lane: lane).map(\.songLengthSeconds), [2, 2])
    }

    // MARK: 3 — an equal start goes to the part placed later, entirely

    func testAnEqualStartGoesToThePartPlacedLater() {
        let lane = TimelineLane(name: "Audio", kind: .audio)
        let older = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 2 * Self.bar)
        let newer = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 2 * Self.bar)
        XCTAssertEqual(Self.plan([older, newer], lane: lane).map(\.regionID), [newer.id])
    }

    // MARK: 4 — a part no grid tick lands in is not in the stem, and a bad tempo plans nothing

    func testAnUnschedulablePartAndABadTempoPlanNothing() {
        let lane = TimelineLane(name: "Audio", kind: .audio)
        let sliver = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 121, lengthTicks: 1)
        XCTAssertFalse(TimelineScheduling.isSampleable(sliver), "premise: the live player never loads it")
        XCTAssertTrue(Self.plan([sliver], lane: lane).isEmpty)

        let part = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: Self.bar)
        let doc = TimelineDocument(lanes: [lane], regions: [part])
        for bad in [0.0, -120, .nan, .infinity] {
            XCTAssertTrue(AudioLaneStemPlan.segments(in: doc, laneID: lane.id, bpm: bad).isEmpty, "bpm \(bad)")
        }
    }

    // MARK: 5 — the plan loads exactly what a grid walk through `laneEvent` loads

    func testThePlanMatchesTheLivePlayersGridWalk() {
        let lane = TimelineLane(name: "Audio", kind: .audio)
        let regions: [TimelineRegion] = [
            TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 3 * Self.bar),
            TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 500, lengthTicks: Self.bar),
            TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 2_000, lengthTicks: 30),
            TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 4_000, lengthTicks: 2 * Self.bar),
            TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 4_500, lengthTicks: 600),
        ]
        let doc = TimelineDocument(lanes: [lane], regions: regions)
        let step = TimelineTime.ticksPerTransportStep
        var loads: [(tick: Int, id: UUID)] = []
        var previous = -1
        var tick = 0
        while tick <= doc.endTick + step {
            if case .load(let region) = TimelineScheduling.laneEvent(in: doc, laneID: lane.id,
                                                                     fromTick: previous, toTick: tick) {
                loads.append((tick, region.id))
            }
            previous = tick
            tick += step
        }
        let segments = AudioLaneStemPlan.segments(in: doc, laneID: lane.id, bpm: Self.bpm)
        XCTAssertGreaterThanOrEqual(loads.count, 4, "premise: the layout exercises cuts and resumes")
        XCTAssertEqual(segments.map(\.startTick), loads.map(\.tick))
        XCTAssertEqual(segments.map(\.regionID), loads.map(\.id))
    }

    // MARK: 6 — a warped part resumes at its media position at the warp rate

    func testAWarpedPartResumesAtTheWarpRate() {
        let lane = TimelineLane(name: "Audio", kind: .audio)
        let clip = UUID()
        let under = TimelineRegion(laneID: lane.id, clipID: clip, startTick: 0,
                                   lengthTicks: 4 * Self.bar, contentOffsetSeconds: 1.5, warpEnabled: true)
        let top = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: Self.bar, lengthTicks: Self.bar)
        let segments = Self.plan([under, top], lane: lane, nativeBPM: { $0 == clip ? 60 : 0 })
        let rate = TempoMatch.stretchRate(nativeBPM: 60, masterBPM: Self.bpm)
        XCTAssertEqual(rate, 2, "premise: a 60 BPM clip in a 120 BPM song plays twice as fast")
        XCTAssertEqual(segments.map(\.rate), [rate, 1, rate])
        XCTAssertEqual(segments.last?.mediaFromSeconds ?? -1, 1.5 + 4 * rate, accuracy: 1e-12,
                       "song seconds 4 consume media seconds 4 × rate")
    }

    // MARK: 8 — touching segments share their frame: no gap, no overlap

    func testTouchingSegmentsShareTheirFrame() {
        let lane = TimelineLane(name: "Audio", kind: .audio)
        let under = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0,
                                   lengthTicks: 4 * Self.bar, contentOffsetSeconds: 1.5)
        let top = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: Self.bar, lengthTicks: Self.bar)
        let frames = Self.plan([under, top], lane: lane).compactMap {
            AudioLaneStemPlan.frames(for: $0, bpm: Self.bpm, sampleRate: 48_000, fileFrames: 480_000)
        }
        XCTAssertEqual(frames.map(\.destinationStart), [0, 96_000, 192_000])
        XCTAssertEqual(frames.map(\.count), [96_000, 96_000, 192_000])
        XCTAssertEqual(frames.map(\.sourceStart), [72_000, 0, 264_000])

        // An odd tempo and rate, where two separately rounded lengths would drift by a sample.
        let regions: [TimelineRegion] = [
            TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 3 * Self.bar),
            TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 500, lengthTicks: Self.bar),
            TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 4_000, lengthTicks: 2 * Self.bar),
            TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 4_500, lengthTicks: 600),
        ]
        let doc = TimelineDocument(lanes: [lane], regions: regions)
        let segments = AudioLaneStemPlan.segments(in: doc, laneID: lane.id, bpm: 127)
        let odd = segments.compactMap {
            AudioLaneStemPlan.frames(for: $0, bpm: 127, sampleRate: 44_100, fileFrames: 10_000_000)
        }
        XCTAssertEqual(odd.count, segments.count)
        var touching = 0
        for i in 1..<segments.count where segments[i - 1].endTick == segments[i].startTick {
            XCTAssertEqual(odd[i - 1].destinationStart + odd[i - 1].count, odd[i].destinationStart,
                           "segment \(i) does not start on the frame its neighbour ends on")
            touching += 1
        }
        XCTAssertGreaterThanOrEqual(touching, 3, "premise: the layout has cuts that touch")
    }

    // MARK: 9 — a file that ends early leaves silence; a position past it copies nothing

    func testAShortFileLeavesTheRestSilent() {
        let lane = TimelineLane(name: "Audio", kind: .audio)
        let part = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0,
                                  lengthTicks: 4 * Self.bar, contentOffsetSeconds: 1.5)
        guard let segment = Self.plan([part], lane: lane).first else { return XCTFail("premise: one segment") }
        let short = AudioLaneStemPlan.frames(for: segment, bpm: Self.bpm, sampleRate: 48_000, fileFrames: 144_000)
        XCTAssertEqual(short, AudioLaneStemFrames(destinationStart: 0, sourceStart: 72_000, count: 72_000))
        XCTAssertNil(AudioLaneStemPlan.frames(for: segment, bpm: Self.bpm, sampleRate: 48_000, fileFrames: 72_000),
                     "a media position at the file's end copies nothing")
        XCTAssertNil(AudioLaneStemPlan.frames(for: segment, bpm: 0, sampleRate: 48_000, fileFrames: 144_000))
        XCTAssertNil(AudioLaneStemPlan.frames(for: segment, bpm: Self.bpm, sampleRate: .nan, fileFrames: 144_000))
    }

    // MARK: 10 — a warped segment is not copied at the wrong speed

    func testAWarpedSegmentIsNotCopiedAtTheWrongSpeed() {
        let lane = TimelineLane(name: "Audio", kind: .audio)
        let clip = UUID()
        let part = TimelineRegion(laneID: lane.id, clipID: clip, startTick: 0,
                                  lengthTicks: Self.bar, warpEnabled: true)
        let segments = Self.plan([part], lane: lane, nativeBPM: { $0 == clip ? 60 : 0 })
        XCTAssertEqual(segments.first?.rate, 2, "premise: the segment is warped")
        XCTAssertNil(segments.first.flatMap {
            AudioLaneStemPlan.frames(for: $0, bpm: Self.bpm, sampleRate: 48_000, fileFrames: 480_000)
        }, "a plain copy of a warped segment would not match the song")
    }

    // MARK: 7 — the plan asks the owners; the live player still resolves the same way

    func testThePlanAsksTheOwners() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        func code(_ path: String) throws -> String {
            SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
        }
        let plan = try code("Sources/Echoelmusic/Sequencer/AudioLaneStemPlan.swift")
        for owner in ["TimelineScheduling.candidateSampleTicks(in: document, laneID: laneID)",
                      "TimelineScheduling.activeRegion(in: document, laneID: laneID, at: tick)",
                      "AudioRegionPlayback.filePositionSeconds(",
                      "capabilities: StretchMode.timelineCapabilities"] {
            XCTAssertTrue(plan.contains(owner), "the plan asks `\(owner)` instead of deciding it again")
        }
        XCTAssertFalse(plan.contains(".regions"),
                       "the plan never walks the regions — which part sounds is defined once (#1440)")

        let live = try code("Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift")
        XCTAssertTrue(live.contains("capabilities: StretchMode.timelineCapabilities"),
                      "COUNTERWEIGHT: the live player resolves the stretch the same way")
        XCTAssertTrue(live.contains("TimelineScheduling.laneEvent(in: doc, laneID: laneID,"),
                      "COUNTERWEIGHT: the live player still decides by `laneEvent`, the walk claim 5 replays")
    }
}
