// AFadedPartPlaysItsRampsTests.swift
// Echoel — an audio part's fades are PLAYED: the lane sink bakes the two ramps into the audio it
// schedules (audio editor W4b, founder 2026-10-08: "Die klassische DAW Audio Editing View fehlt
// mir noch.").
//
// WHY: W4a gave a part fade lengths that nothing read. The device sink streams a part straight
// from its file (`scheduleSegment`), and `AVAudioPlayerNode` has no gain automation, so a fade is
// played the way the dead `AudioClipPlayer` meant to: the frames inside a fade are read, multiplied
// by the ramp and scheduled as short buffers; the frames between still stream from the file, all
// back to back on one node. Export records the live mix, so what plays is what is written.
//
// THE CLAIMS, AND WHICH KIND EACH IS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END — `AudioRegionPlayback.fadePlan` is the part's fades in MEDIA time: its file
//    start, its length × the stretch rate, the fade lengths scaled the same way; no fade or a
//    tempo that cannot map gives nil (the plain path).
// 2. END-TO-END — `PartFadePlan.pieces` cuts the scheduled frames at the fade edges: contiguous,
//    in order, together exactly the input, on every entry point (start, mid-fade, middle, inside
//    the fade-out, a file that ends early); degenerate input gives nothing.
// 3. END-TO-END — the ramps start silent, end silent, and meet the middle without a step: no
//    frame-to-frame jump anywhere in the part exceeds one ramp step.
// 4. END-TO-END — the real coordinator hands each part ITS plan right before `play`, a part
//    without fades gets nil, and a Beats part's pre-render gets the very same plan.
// 5. SOURCE-TEXT SCAN — the sink takes the plan once per `play` before any exit, the Beats cache
//    is keyed by the fades and the render bakes them, the faded path reads a FRESH handle and
//    starts the node only after the first piece is scheduled, a short read falls back to the
//    file, and the plain path is still there for every part without fades.
// 6. END-TO-END — `PartFadePlan.bake` multiplies a stretched rendering frame by frame by the
//    ramp at the file moment each output frame stands for, and touches nothing at unity.
//
// GRADING (§0/§3, no Swift toolchain in a web session): the file names `PartFadePlan`,
// `fadePlan`, `setFades` and `bake`, which W4b and W4b2 create, so it does NOT COMPILE against the parent
// — no assertion has a verdict there (one absence, #486). Claims 1–3 transcribed in Python against
// the work tree's arithmetic, claim 6 too; claim 4 re-derived by hand from `AudioLanePlayer`'s
// prime and start; claim 5 is a forward guard. That a fade SOUNDS smooth, starts on time and leaves no click at the piece
// joins is a DEVICE PROBE and open.

import XCTest
import Foundation
@testable import Echoelmusic

@MainActor
final class AFadedPartPlaysItsRampsTests: XCTestCase {

    private static let sink = "Sources/Echoelmusic/Sequencer/TimelineAudioSink.swift"
    private static let lanes = "Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift"
    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — the plan is the part's fades in media time

    func testThePlanIsThePartsFadesInMediaTime() {
        let part = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: 4 * Self.bar,
                                  contentOffsetSeconds: 2, fadeInTicks: Self.bar / 2, fadeOutTicks: Self.bar)
        let rates: [Double] = [1, 1.5, 0.5]
        for rate in rates {
            guard let plan = AudioRegionPlayback.fadePlan(for: part, bpm: 120, stretchRate: rate) else {
                XCTFail("rate \(rate): a part with fades got no plan")
                continue
            }
            XCTAssertEqual(plan.partStart, 2, "the part starts where its file offset says")
            XCTAssertEqual(plan.duration, TimelineTime.seconds(fromTicks: 4 * Self.bar, bpm: 120) * rate,
                           accuracy: 1e-9, "rate \(rate): the part runs its length × the rate in the file")
            XCTAssertEqual(plan.fadeIn, TimelineTime.seconds(fromTicks: Self.bar / 2, bpm: 120) * rate,
                           accuracy: 1e-9, "rate \(rate): the fade-in scales with the rate, so it lasts its ticks in song time")
            XCTAssertEqual(plan.fadeOut, TimelineTime.seconds(fromTicks: Self.bar, bpm: 120) * rate,
                           accuracy: 1e-9, "rate \(rate): the fade-out scales the same way")
        }
        let plain = TimelineRegion(laneID: UUID(), clipID: UUID(), startTick: 0, lengthTicks: 4 * Self.bar)
        XCTAssertNil(AudioRegionPlayback.fadePlan(for: plain, bpm: 120, stretchRate: 1),
                     "a part without fades takes the plain path")
        let badTempi: [Double] = [0, -120, .nan, .infinity]
        for bpm in badTempi {
            XCTAssertNil(AudioRegionPlayback.fadePlan(for: part, bpm: bpm, stretchRate: 1), "bpm \(bpm) cannot map")
        }
        XCTAssertEqual(AudioRegionPlayback.fadePlan(for: part, bpm: 120, stretchRate: .nan)?.duration ?? 0,
                       TimelineTime.seconds(fromTicks: 4 * Self.bar, bpm: 120), accuracy: 1e-9,
                       "a degenerate rate plays as unwarped, as everywhere else in the media mapping")

        XCTAssertNil(PartFadePlan(partStart: 0, duration: 4, fadeIn: 0, fadeOut: 0), "no fade, no plan")
        XCTAssertNil(PartFadePlan(partStart: .nan, duration: 4, fadeIn: 1, fadeOut: 0), "no file position, no plan")
        XCTAssertNil(PartFadePlan(partStart: 0, duration: 0, fadeIn: 1, fadeOut: 0), "no length, no plan")
        let overlong = PartFadePlan(partStart: 0, duration: 2, fadeIn: 3, fadeOut: 3)
        XCTAssertEqual(overlong?.fadeIn, 2, "the plan stores the lengths as they play — the one rule")
        XCTAssertEqual(overlong?.fadeOut, 0)
    }

    // MARK: 2 — the cut covers the scheduled frames exactly once, in order

    private static let rate: Double = 48_000
    /// File start 2 s, 8 s long, a 1 s fade-in and a 2 s fade-out: edges at frames 96 000,
    /// 144 000, 384 000 and 480 000.
    private static let plan = PartFadePlan(partStart: 2, duration: 8, fadeIn: 1, fadeOut: 2)

    func testTheCutHasTheRightPiecesOnEveryEntry() throws {
        let plan = try XCTUnwrap(Self.plan)
        expect(plan, 96_000, 384_000, [96_000..<144_000, 144_000..<384_000, 384_000..<480_000],
               "from the part's start: fade-in, middle, fade-out")
        expect(plan, 120_000, 360_000, [120_000..<144_000, 144_000..<384_000, 384_000..<480_000],
               "entered inside the fade-in: the rest of the ramp first")
        expect(plan, 200_000, 280_000, [nil, 200_000..<384_000, 384_000..<480_000],
               "entered after the fade-in: no head")
        expect(plan, 400_000, 80_000, [nil, nil, 400_000..<480_000], "entered inside the fade-out")
        expect(plan, 96_000, 200_000, [96_000..<144_000, 144_000..<296_000, nil],
               "a file that ends before the fade-out never plays one")

        let inOnly = try XCTUnwrap(PartFadePlan(partStart: 0, duration: 4, fadeIn: 1, fadeOut: 0))
        expect(inOnly, 0, 192_000, [0..<48_000, 48_000..<192_000, nil], "no fade-out, no tail")
        let outOnly = try XCTUnwrap(PartFadePlan(partStart: 0, duration: 4, fadeIn: 0, fadeOut: 1))
        expect(outOnly, 0, 192_000, [nil, 0..<144_000, 144_000..<192_000], "no fade-in, no head")
        let filled = try XCTUnwrap(PartFadePlan(partStart: 0, duration: 2, fadeIn: 1, fadeOut: 1))
        expect(filled, 0, 96_000, [0..<48_000, nil, 48_000..<96_000], "fades that fill the part leave no middle")

        expect(plan, 96_000, 0, [nil, nil, nil], "no frames, no pieces")
        expect(plan, -1, 10, [nil, nil, nil], "a negative frame is refused")
        expect(plan, Int64.max - 5, 10, [nil, nil, nil], "an end past Int64 is refused, never wrapped")
        let badRates: [Double] = [0, -48_000, .nan, .infinity]
        for sampleRate in badRates {
            let p = plan.pieces(startFrame: 96_000, frameCount: 384_000, sampleRate: sampleRate)
            XCTAssertTrue(p.head == nil && p.middle == nil && p.tail == nil, "sample rate \(sampleRate) gives nothing")
        }
    }

    /// One cut checked against `want` = [head, middle, tail]. A typed parameter, so the range
    /// literals at the call sites get their type from here rather than from inference.
    private func expect(_ plan: PartFadePlan, _ start: Int64, _ count: Int64, _ want: [Range<Int64>?],
                        _ why: String, line: UInt = #line) {
        let p = plan.pieces(startFrame: start, frameCount: count, sampleRate: Self.rate)
        let got: [Range<Int64>?] = [p.head, p.middle, p.tail]
        XCTAssertEqual(got, want, why, line: line)
    }

    func testThePiecesAreContiguousAndCoverExactlyTheInput() throws {
        let plan = try XCTUnwrap(Self.plan)
        let starts: [Int64] = [96_000, 100_003, 143_999, 144_000, 250_001, 383_999, 384_000, 479_999]
        let counts: [Int64] = [1, 7, 47_999, 48_000, 380_000]
        for start in starts { for count in counts {
            let p = plan.pieces(startFrame: start, frameCount: count, sampleRate: Self.rate)
            let pieces = [p.head, p.middle, p.tail].compactMap { $0 }
            guard let first = pieces.first, let last = pieces.last else {
                XCTFail("(\(start), \(count)): frames to play, but no piece")
                continue
            }
            XCTAssertEqual(first.lowerBound, start, "(\(start), \(count)): the first piece starts at the first frame")
            XCTAssertEqual(last.upperBound, start + count, "(\(start), \(count)): the last piece ends at the last frame")
            for (left, right) in zip(pieces, pieces.dropFirst()) {
                XCTAssertEqual(left.upperBound, right.lowerBound, "(\(start), \(count)): a gap or an overlap at \(left)")
            }
            XCTAssertTrue(pieces.allSatisfy { !$0.isEmpty }, "(\(start), \(count)): an empty piece was returned")
        } }
    }

    // MARK: 3 — the ramps start and end silent and meet the middle without a step

    func testTheRampsMeetTheMiddleWithoutAStep() throws {
        let plan = try XCTUnwrap(Self.plan)
        func level(_ frame: Int64) -> Double { plan.gain(atMediaSeconds: Double(frame) / Self.rate) }
        XCTAssertEqual(level(96_000), 0, accuracy: 1e-12, "the fade-in starts silent")
        XCTAssertEqual(level(144_000), 1, accuracy: 1e-12, "the middle plays at unity")
        XCTAssertEqual(level(384_000), 1, accuracy: 1e-12, "the fade-out starts from unity")
        XCTAssertLessThan(level(479_999), 1e-4, "the fade-out ends silent")
        let longestStep = Swift.max(1 / (plan.fadeIn * Self.rate), 1 / (plan.fadeOut * Self.rate))
        var worst = 0.0
        var previous = level(96_000)
        for frame in Int64(96_001)..<480_000 {
            let current = level(frame)
            worst = Swift.max(worst, abs(current - previous))
            previous = current
        }
        XCTAssertLessThanOrEqual(worst, longestStep + 1e-9, """
            a frame-to-frame jump of \(worst) inside the part — larger than one ramp step \
            (\(longestStep)). The head, middle and tail pieces would meet with a click.
            """)
    }

    // MARK: 4 — the coordinator hands each part its own plan right before it plays

    private enum Event: Equatable {
        case beats(PartFadePlan?)
        case fades(PartFadePlan?)
        case play(from: Double)
    }

    @MainActor
    private final class Spy: AudioRegionSink {
        var events: [Event] = []
        func play(url: URL, fromSeconds: Double, lengthSeconds: Double, gain: Float,
                  stretch: StretchPlan) { events.append(.play(from: fromSeconds)) }
        func stop() {}
        func setFades(_ plan: PartFadePlan?) { events.append(.fades(plan)) }
        func prepareBeats(url: URL, fromSeconds: Double, lengthSeconds: Double, rate: Double,
                          fades: PartFadePlan?) { events.append(.beats(fades)) }
    }

    private func primed(_ region: TimelineRegion, lane: TimelineLane, atTick tick: Int) -> [Event] {
        let spy = Spy()
        let player = AudioLanePlayer(makeSink: { spy },
                                     resolveURL: { $0 == region.clipID ? URL(fileURLWithPath: "/tmp/loop.wav") : nil },
                                     resolveNativeBPM: { _ in 100 })
        player.prime(in: TimelineDocument(lanes: [lane], regions: [region]), atTick: tick, bpm: 120)
        return spy.events
    }

    func testTheCoordinatorHandsEachPartItsPlanBeforePlay() {
        let lane = TimelineLane(name: "Audio 1", kind: .audio)
        for warped in [false, true] {
            let part = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 4 * Self.bar,
                                      contentOffsetSeconds: 1, warpEnabled: warped,
                                      fadeInTicks: Self.bar, fadeOutTicks: Self.bar)
            let rate = StretchPlan.resolve(mode: part.stretchMode, warpEnabled: warped, nativeBPM: 100,
                                           projectBPM: 120, capabilities: StretchMode.timelineCapabilities).rate
            let expected = AudioRegionPlayback.fadePlan(for: part, bpm: 120, stretchRate: rate)
            XCTAssertNotNil(expected, "warped \(warped): the part has fades — the premise of this claim")
            XCTAssertEqual(primed(part, lane: lane, atTick: 0), [.fades(expected), .play(from: 1)],
                           "warped \(warped): the plan arrives right before the part plays")
            let midway = primed(part, lane: lane, atTick: Self.bar)
            XCTAssertEqual(midway.first, .fades(expected),
                           "warped \(warped): entered mid-part, the plan still describes the WHOLE part")
            XCTAssertEqual(midway.count, 2, "warped \(warped): one plan, one play")
        }
        let plain = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 4 * Self.bar)
        XCTAssertEqual(primed(plain, lane: lane, atTick: 0), [.fades(nil), .play(from: 0)],
                       "a part without fades is told so — no plan can linger from the part before")

        // W4b2: a Beats part's pre-render is handed the SAME plan `start` hands the sink, so the
        // rendering prime asks for is the one play looks up.
        let beats = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 4 * Self.bar,
                                   warpEnabled: true, stretchMode: .beats,
                                   fadeInTicks: Self.bar, fadeOutTicks: Self.bar)
        let rate = StretchPlan.resolve(mode: .beats, warpEnabled: true, nativeBPM: 100, projectBPM: 120,
                                       capabilities: StretchMode.timelineCapabilities).rate
        XCTAssertNotEqual(rate, 1, "the premise: a warped Beats part at 100 → 120 bpm is pre-rendered")
        let plan = AudioRegionPlayback.fadePlan(for: beats, bpm: 120, stretchRate: rate)
        XCTAssertNotNil(plan)
        XCTAssertEqual(primed(beats, lane: lane, atTick: 0), [.beats(plan), .fades(plan), .play(from: 0)],
                       "the render and the play must carry one plan — two would miss the cache forever")
    }

    // MARK: 5 — the sink: once per play, Beats skipped, fresh handle, play after the first piece

    func testTheSinkPlaysTheRampsAndKeepsThePlainPath() throws {
        let sink = try source(Self.sink)
        let play = try XCTUnwrap(Self.body(after: "func play(url: URL, fromSeconds: Double, lengthSeconds: Double, gain: Float,", in: sink),
                                 "ANCHOR MISSING: `TimelineAudioSink.play`")
        assertOrder(in: play, ["let fades = pendingFades", "pendingFades = nil", "guard lengthSeconds > 0"],
                        why: "the plan is taken before the first exit, so it can never reach a later part")
        let beats = try XCTUnwrap(play.range(of: "stretch.mode == .beats"), "ANCHOR MISSING: the Beats shortcut")
        let open = try XCTUnwrap(play.range(of: "{", range: beats.upperBound..<play.endIndex))
        XCTAssertTrue(play[beats.lowerBound..<open.lowerBound].contains("fades: fades)]"),
                      "the Beats lookup must be keyed by the part's fades — or a faded part plays an unfaded rendering")
        let prepare = try XCTUnwrap(Self.body(after: "func prepareBeats(url: URL, fromSeconds: Double, lengthSeconds: Double, rate: Double,", in: sink),
                                    "ANCHOR MISSING: `TimelineAudioSink.prepareBeats`")
        assertOrder(in: prepare, ["BeatsKey(url: url, rate: rate, fromSeconds: fromSeconds, fades: fades)",
                                  "WSOLAStretcher().stretchMultichannel(",
                                  "fades.bake(into: &rendered, fromSeconds: fromSeconds,",
                                  "mediaSecondsPerFrame: rate / sampleRate)",
                                  "storeBeats(key: key,"],
                    why: "the render is keyed by the fades and bakes them into its output before it is stored")
        let key = try XCTUnwrap(Self.body(after: "private struct BeatsKey: Hashable", in: sink), "ANCHOR MISSING: `BeatsKey`")
        XCTAssertTrue(key.contains("let fadeInMilli: Int") && key.contains("let fadeOutMilli: Int"),
                      "a fade edit must resolve a different cache entry")
        assertOrder(in: play, ["guard node.engine?.isRunning == true else { return }", "stop()",
                               "playFaded(fades, url: url, file: file, on: node,",
                                   "node.scheduleSegment(file, startingFrame: startFrame, frameCount: frames, at: nil)",
                                   "setGain(gain)", "node.play()"],
                        why: "silence first, the faded path next, and the plain path — byte for byte — for every other part")

        let faded = try XCTUnwrap(Self.body(after: "private func playFaded(", in: sink), "ANCHOR MISSING: `playFaded`")
        XCTAssertTrue(faded.contains("AVAudioFile(forReading: url)"),
                      "the ramps must be read from a FRESH handle — the node streams the shared one on its own thread")
        XCTAssertTrue(faded.contains("baked(piece.frames, from: reader,"), "the baked pieces read the fresh handle")
        let firstSchedule = try XCTUnwrap(faded.range(of: "node.schedule"), "ANCHOR MISSING: the first schedule")
        let lastRefusal = try XCTUnwrap(faded.range(of: "return false", options: .backwards))
        XCTAssertLessThan(lastRefusal.lowerBound, firstSchedule.lowerBound,
                          "a refusal after something was scheduled would play the part twice")
        XCTAssertEqual(faded.components(separatedBy: "node.play()").count - 1, 1, "the node is started once")
        assertOrder(in: faded, ["node.scheduleBuffer(buffer, at: nil)", "if index == 0 {", "node.play()"],
                        why: "the node starts only after the first piece is scheduled")
        XCTAssertTrue(faded.contains("Self.firstFadedChunkSeconds"), "a long first ramp is cut so the part starts on time")

        let baked = try XCTUnwrap(Self.body(after: "private func baked(", in: sink), "ANCHOR MISSING: `baked`")
        XCTAssertTrue(baked.contains("buffer.frameLength == count"), "a short read must fall back to the file, keeping the timing exact")
        XCTAssertTrue(baked.contains("plan.gain(atMediaSeconds:"), "the ramp is the one rule, asked per frame")

        let lanes = try source(Self.lanes)
        let start = try XCTUnwrap(Self.body(after: "private func start(_ region: TimelineRegion,", in: lanes),
                                  "ANCHOR MISSING: `AudioLanePlayer.start`")
        assertOrder(in: start, ["lane.setFades(AudioRegionPlayback.fadePlan(for: region, bpm: bpm, stretchRate: plan.rate))",
                                    "lane.play(url: url,"],
                        why: "every part is told its fades — or nil — right before it plays")
    }

    // MARK: 6 — the Beats rendering is multiplied by the ramp at the moment each frame stands for

    func testTheBakeMultipliesEachFrameByItsRamp() throws {
        // A 1 s part at file second 2, fades of 0.25 s each, rendered at rate 2 and 16 frames per
        // second: output frame i stands for the file's moment 2 + i × 2 / 16.
        let plan = try XCTUnwrap(PartFadePlan(partStart: 2, duration: 1, fadeIn: 0.25, fadeOut: 0.25))
        let step = 2.0 / 16.0
        var channels: [[Float]] = [Array(repeating: 1, count: 10), Array(repeating: 2, count: 5)]
        plan.bake(into: &channels, fromSeconds: 2, mediaSecondsPerFrame: step)
        for (index, channel) in channels.enumerated() {
            for (frame, value) in channel.enumerated() {
                let unbaked: Float = index == 0 ? 1 : 2
                let want = unbaked * Float(plan.gain(atMediaSeconds: 2 + Double(frame) * step))
                XCTAssertEqual(value, want, accuracy: 1e-6, "channel \(index), frame \(frame)")
            }
        }
        XCTAssertEqual(channels[0][0], 0, "the rendering starts silent")
        XCTAssertEqual(channels[0][1], 0.5, accuracy: 1e-6, "halfway up the fade-in")
        XCTAssertEqual(channels[0][4], 1, "unity in the middle — untouched")
        XCTAssertEqual(channels[0][7], 0.5, accuracy: 1e-6, "halfway down the fade-out")
        XCTAssertEqual(channels[0][8], 0, "silent at the part's end")
        XCTAssertEqual(channels[1].count, 5, "a shorter channel keeps its length")
        XCTAssertEqual(channels[1][1], 1, accuracy: 1e-6, "every channel gets the same ramp")

        var untouched: [[Float]] = [[0.5, 0.5, 0.5]]
        let degenerate: [Double] = [0, -1, .nan, .infinity]
        for bad in degenerate {
            plan.bake(into: &untouched, fromSeconds: 2, mediaSecondsPerFrame: bad)
            XCTAssertEqual(untouched, [[0.5, 0.5, 0.5]], "step \(bad) must change nothing")
        }
        plan.bake(into: &untouched, fromSeconds: .nan, mediaSecondsPerFrame: step)
        XCTAssertEqual(untouched, [[0.5, 0.5, 0.5]], "a non-finite start must change nothing")
    }

    // MARK: helpers

    private func assertOrder(in text: String, _ needles: [String], why: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        var cursor = text.startIndex
        for needle in needles {
            guard let hit = text.range(of: needle, range: cursor..<text.endIndex) else {
                XCTFail("`\(needle)` missing or out of order — \(why)", file: file, line: line)
                return
            }
            cursor = hit.upperBound
        }
    }

    /// The brace-matched body of the first declaration starting with `signature`, or nil.
    private static func body(after signature: String, in code: String) -> String? {
        guard let start = code.range(of: signature),
              let open = code[start.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < code.endIndex {
            switch code[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(code[code.index(after: open)..<index]) }
            default: break
            }
            index = code.index(after: index)
        }
        return nil
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let text = try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
        return SourceText.codeOnly(text)
    }
}
