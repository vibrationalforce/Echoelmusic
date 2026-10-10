// TheGrainInsertPlaysOnItsAudioTrackTests.swift
// Echoel — GMMW GA-10c: a track's grain insert is PLAYED. The lane coordinator asks the sink to
// render each part's grain at prime time (`GrainBake`, off the main actor) and hands the sink the
// part's grain right before every `play`; the sink schedules the ready rendering at the part's
// onset on the plain node, and plays the part exactly as before everywhere else.
//
// THE CLAIMS, AND WHICH KIND EACH IS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END — `AudioLanePlayer.grainToPlay` is the track's `soundingGrain` for an unstretched,
//    unpitched part, and nil without an enabled grain insert, at mix 0, for a stretched part and
//    for a pitched one (the rendering plays on the plain node, which can do neither).
// 2. END-TO-END — the real coordinator, driven with a spy sink: a grain track's part is rendered
//    at prime with its whole window and fades, and handed its grain right before `play`; a track
//    without one is told nil before every `play` and nothing is rendered (Off is untouched).
// 3. SOURCE-TEXT SCAN — the sink takes the grain once per `play` before any exit, plays a
//    rendering only for rate 1, no transpose and the exact key prime rendered, renders on a
//    detached task through `GrainBake`, sweeps the buffer before caching it, and clears the cache
//    with the lane.
//
// GRADING (§0/§3): the file names `grainToPlay`, `prepareGrain` and `setGrain`, which this commit
// creates, so it does NOT COMPILE against the parent — no assertion has a verdict there (one
// absence, #486); every claim is a FORWARD guard. Counterweights: claim 1's three nil cases,
// claim 2's grainless track. Claims 1–2 re-derived by hand from `prime`/`start`; claim 3 by `grep`.
// What the grain SOUNDS like, that it starts on time and what the render costs on a phone are a
// DEVICE PROBE and open — and no writer places a grain insert yet (GA-10d), so no song changes.

import XCTest
import Foundation
@testable import Echoelmusic

@MainActor
final class TheGrainInsertPlaysOnItsAudioTrackTests: XCTestCase {

    private static let sinkPath = "Sources/Echoelmusic/Sequencer/TimelineAudioSink.swift"
    private static let bar = TimelineTime.ticksPerBar

    private static func grain(position: Float = 0.3) -> GrainSettings {
        var s = GrainSettings()
        s.position = position
        s.seed = 11
        return s
    }

    private static func grainLane(_ settings: GrainSettings?) -> TimelineLane {
        TimelineLane(name: "Audio 1", kind: .audio,
                     deviceChain: settings.map { DeviceChain(inserts: [.grain($0)]) })
    }

    // MARK: 1 — one answer for which grain a part sounds

    func testAPartSoundsItsTracksGrainOnlyUnstretchedAndUnpitched() {
        let lane = Self.grainLane(Self.grain())
        let part = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 4 * Self.bar)
        let doc = TimelineDocument(lanes: [lane], regions: [part])
        XCTAssertEqual(AudioLanePlayer.grainToPlay(for: part, in: doc, nativeBPM: 0, bpm: 120),
                       Self.grain().sanitized, "an unstretched, unpitched part sounds its track's grain")

        let plain = Self.grainLane(nil)
        let plainPart = TimelineRegion(laneID: plain.id, clipID: UUID(), startTick: 0, lengthTicks: Self.bar)
        XCTAssertNil(AudioLanePlayer.grainToPlay(for: plainPart, in: TimelineDocument(lanes: [plain], regions: [plainPart]),
                                                 nativeBPM: 0, bpm: 120), "no insert, no grain")

        var off = DeviceInsert.grain(Self.grain())
        off.isEnabled = false
        let offLane = TimelineLane(name: "Audio 2", kind: .audio, deviceChain: DeviceChain(inserts: [off]))
        let offPart = TimelineRegion(laneID: offLane.id, clipID: UUID(), startTick: 0, lengthTicks: Self.bar)
        XCTAssertNil(AudioLanePlayer.grainToPlay(for: offPart, in: TimelineDocument(lanes: [offLane], regions: [offPart]),
                                                 nativeBPM: 0, bpm: 120), "a disabled insert is silent")

        let warped = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: Self.bar,
                                    warpEnabled: true)
        XCTAssertNil(AudioLanePlayer.grainToPlay(for: warped, in: TimelineDocument(lanes: [lane], regions: [warped]),
                                                 nativeBPM: 100, bpm: 120),
                     "COUNTERWEIGHT: a stretched part plays as before — the rendering is made at rate 1")

        var dry = Self.grain()
        dry.mix = 0
        let dryLane = Self.grainLane(dry)
        let dryPart = TimelineRegion(laneID: dryLane.id, clipID: UUID(), startTick: 0, lengthTicks: Self.bar)
        XCTAssertNil(AudioLanePlayer.grainToPlay(for: dryPart, in: TimelineDocument(lanes: [dryLane], regions: [dryPart]),
                                                 nativeBPM: 0, bpm: 120),
                     "mix 0 plays the file itself, bit for bit — a rendering would be its mono sum")

        var pitched = part
        pitched.transposeSemitones = 3
        XCTAssertNil(AudioLanePlayer.grainToPlay(for: pitched, in: TimelineDocument(lanes: [lane], regions: [pitched]),
                                                 nativeBPM: 0, bpm: 120),
                     "COUNTERWEIGHT: a pitched part plays through the pitch chain, unbaked")
    }

    // MARK: 2 — the coordinator renders at prime and hands the grain over before play

    private enum Event: Equatable {
        case render(from: Double, length: Double, GrainSettings, PartFadePlan?)
        case grain(GrainSettings?)
        case play(from: Double)
    }

    @MainActor
    private final class Spy: AudioRegionSink {
        var events: [Event] = []
        func play(url: URL, fromSeconds: Double, lengthSeconds: Double, gain: Float,
                  stretch: StretchPlan) { events.append(.play(from: fromSeconds)) }
        func stop() {}
        func prepareGrain(url: URL, fromSeconds: Double, lengthSeconds: Double,
                          settings: GrainSettings, fades: PartFadePlan?) {
            events.append(.render(from: fromSeconds, length: lengthSeconds, settings, fades))
        }
        func setGrain(_ settings: GrainSettings?) { events.append(.grain(settings)) }
    }

    private func primed(_ region: TimelineRegion, lane: TimelineLane) -> [Event] {
        let spy = Spy()
        let player = AudioLanePlayer(makeSink: { spy },
                                     resolveURL: { $0 == region.clipID ? URL(fileURLWithPath: "/tmp/loop.wav") : nil })
        player.prime(in: TimelineDocument(lanes: [lane], regions: [region]), atTick: 0, bpm: 120)
        return spy.events
    }

    func testTheCoordinatorRendersAtPrimeAndHandsTheGrainOverBeforePlay() {
        let lane = Self.grainLane(Self.grain())
        let part = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 4 * Self.bar,
                                  contentOffsetSeconds: 1, fadeInTicks: Self.bar)
        let length = TimelineTime.seconds(fromTicks: 4 * Self.bar, bpm: 120)
        let fades = AudioRegionPlayback.fadePlan(for: part, bpm: 120, stretchRate: 1)
        XCTAssertNotNil(fades, "the premise: the part has a fade, so the rendering must carry it")
        XCTAssertEqual(primed(part, lane: lane),
                       [.render(from: 1, length: length, Self.grain().sanitized, fades),
                        .grain(Self.grain().sanitized), .play(from: 1)],
                       "rendered at prime with the whole window and fades, handed over right before play")

        let plain = Self.grainLane(nil)
        let plainPart = TimelineRegion(laneID: plain.id, clipID: UUID(), startTick: 0, lengthTicks: Self.bar)
        XCTAssertEqual(primed(plainPart, lane: plain), [.grain(nil), .play(from: 0)],
                       "COUNTERWEIGHT: a track without a grain renders nothing and is told so before play")
    }

    // MARK: 3 — the sink: once per play, only the exact rendering, off the main actor

    func testTheSinkPlaysOnlyTheExactRenderingAndKeepsEveryOtherPath() throws {
        let sink = try source(Self.sinkPath)
        let play = try XCTUnwrap(Self.body(after: "func play(url: URL, fromSeconds: Double, lengthSeconds: Double, gain: Float,",
                                           in: sink), "ANCHOR MISSING: `TimelineAudioSink.play`")
        assertOrder(in: play, ["let grain = pendingGrain", "pendingGrain = nil", "guard lengthSeconds > 0"],
                    why: "the grain is taken before the first exit, so it can never reach a later part")
        assertOrder(in: play, ["if let grain, stretch.rate == 1.0, transposeSemitones == 0,",
                               "grainBuffers[GrainKey(url: url, fromSeconds: fromSeconds,",
                               "lengthSeconds: lengthSeconds, settings: grain, fades: fades)]",
                               "plainNode.engine?.isRunning == true",
                               "plainNode.scheduleBuffer(buffer, at: nil)",
                               "node.scheduleSegment(file, startingFrame: startFrame, frameCount: frames, at: nil)"],
                    why: "only the exact rendering plays, unstretched and unpitched, and the plain path stays")
        let prepare = try XCTUnwrap(Self.body(after: "func prepareGrain(url: URL, fromSeconds: Double, lengthSeconds: Double,",
                                              in: sink), "ANCHOR MISSING: `TimelineAudioSink.prepareGrain`")
        assertOrder(in: prepare, ["guard grainInFlight.isEmpty else { return }",
                                  "format.channelCount == 1 || format.channelCount == 2",
                                  "Task.detached(priority: .userInitiated)",
                                  "Self.renderGrain(url: url, fromSeconds: fromSeconds,",
                                  "fades?.bake(into: &channels, fromSeconds: fromSeconds,",
                                  "storeGrain(key: key, channels: channels)"],
                    why: "one render per lane, only for a layout the node takes, made off the main actor, fades baked in, then stored")
        let render = try XCTUnwrap(Self.body(after: "private nonisolated static func renderGrain(", in: sink),
                                   "ANCHOR MISSING: `renderGrain`")
        assertOrder(in: render, ["AVAudioFile(forReading: url)",
                                 "partFrames <= grainMaxPartFrames",
                                 "GrainBake.render(source: mono, sampleRate: sr,"],
                    why: "a FRESH handle, a capped part, then the bake — a longer part plays dry")
        let store = try XCTUnwrap(Self.body(after: "private func storeGrain(key: GrainKey, channels: [[Float]])", in: sink),
                                  "ANCHOR MISSING: `storeGrain`")
        assertOrder(in: store, ["AudioOutputGuard.sweepNonFinite(out)", "grainBuffers[key] = out"],
                    why: "a non-finite sample is swept while the buffer is still local, never after a node holds it")
        let detach = try XCTUnwrap(Self.body(after: "func detach()", in: sink), "ANCHOR MISSING: `detach`")
        XCTAssertTrue(detach.contains("grainBuffers.removeAll()") && detach.contains("grainInFlight.removeAll()")
                      && detach.contains("grainFailed.removeAll()"),
                      "a removed lane must drop its renderings")
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
