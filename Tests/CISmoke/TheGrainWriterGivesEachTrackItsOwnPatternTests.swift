// TheGrainWriterGivesEachTrackItsOwnPatternTests.swift
// Echoel — GMMW GA-10d1: the ONE writer of a track's grain insert, and the edit path that asks for
// the new rendering while the song plays.
//
// THE CLAIMS, AND WHICH KIND EACH IS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END — `GrainSettings.trackSeed` is never 0 (0 means "none chosen"), stable for a
//    track, and different between two tracks.
// 2. END-TO-END over a REAL `TimelineStore` — `setLaneGrain` places a grain on an AUDIO track
//    with the track's own seed when none is chosen, keeps the track's seed on a later edit, keeps
//    an explicitly chosen seed, writes nothing when nothing changes, removes only the grain (an
//    unknown insert stays), and refuses a MIDI track, the bio track and an unknown lane.
// 3. END-TO-END — the real coordinator with a spy sink: `prepareGrains` asks a primed lane for
//    the rendering its part now needs, and starts, stops or plays NOTHING; a lane that was never
//    primed is not asked (it renders at its own prime).
// 4. SOURCE-TEXT SCAN — the mixer merge asks for the renderings only on a real change; the sink
//    queues a request made while another renders (one entry per part window), starts the next
//    when a rendering lands, and drops the queue with the lane.
//
// GRADING (§0/§3): the file names `setLaneGrain`, `trackSeed` and `prepareGrains`, which this
// commit creates, so it does NOT COMPILE against the parent — no assertion has a verdict there
// (one absence, #486); every claim is a FORWARD guard. Counterweights: claim 1's "two tracks
// differ", claim 2's refusals and the kept unknown insert, claim 3's unprimed lane and its "no
// play". Claims 1–3 re-derived by hand from the shipped code; claim 4 by `grep`.
// What a grain edit SOUNDS like mid-song, and how soon the new rendering is heard, is a DEVICE
// PROBE and open: until it lands, the part's onset plays dry (the documented first-pass rule).

import XCTest
import Foundation
@testable import Echoelmusic

@MainActor
final class TheGrainWriterGivesEachTrackItsOwnPatternTests: XCTestCase {

    private static let sinkPath = "Sources/Echoelmusic/Sequencer/TimelineAudioSink.swift"
    private static let playerPath = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let bar = TimelineTime.ticksPerBar
    private static let unknownInsert = DeviceInsert(typeID: "com.example.future.fx", typeVersion: 2,
                                                    isEnabled: true, stateBlob: Data([1, 2, 3]))

    private static func grain(position: Float = 0.3, seed: UInt64 = 0) -> GrainSettings {
        var s = GrainSettings()
        s.position = position
        s.seed = seed
        return s
    }

    // MARK: 1 — a track's own pattern

    func testATracksSeedIsItsOwnAndNeverNone() {
        let a = UUID()
        let b = UUID()
        XCTAssertNotEqual(GrainSettings.trackSeed(a), 0, "0 means 'none chosen' to the writer")
        XCTAssertEqual(GrainSettings.trackSeed(a), GrainSettings.trackSeed(a), "stable for the track")
        XCTAssertNotEqual(GrainSettings.trackSeed(a), GrainSettings.trackSeed(b),
                          "COUNTERWEIGHT: two tracks do not share one pattern by default")
        let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        XCTAssertEqual(GrainSettings.trackSeed(zero), 1, "an id that folds to 0 still gets a seed")
    }

    // MARK: 2 — the one writer, on a real store

    func testTheStoreWritesTheGrainWithTheTracksSeedAndRefusesOtherTracks() {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }

        let audio = TimelineLane(name: "Audio 1", kind: .audio,
                                 deviceChain: DeviceChain(inserts: [Self.unknownInsert]))
        let other = TimelineLane(name: "Audio 2", kind: .audio)
        let midi = TimelineLane(name: "Keys", kind: .midi)
        let bio = TimelineLane(name: "Body", kind: .audio, isBio: true)
        timeline.replaceDocument(TimelineDocument(lanes: [audio, other, midi, bio], regions: []))
        func chain(_ id: UUID) -> DeviceChain? {
            timeline.document.lanes.first(where: { $0.id == id })?.deviceChain
        }

        timeline.setLaneGrain(audio.id, settings: Self.grain())
        XCTAssertEqual(chain(audio.id)?.soundingGrain?.seed, GrainSettings.trackSeed(audio.id),
                       "a first grain without a chosen seed takes the track's own")
        XCTAssertEqual(chain(audio.id)?.inserts.first, Self.unknownInsert, "an unknown insert stays in place")

        timeline.setLaneGrain(audio.id, settings: Self.grain(position: 0.7))
        XCTAssertEqual(chain(audio.id)?.soundingGrain?.position, 0.7)
        XCTAssertEqual(chain(audio.id)?.soundingGrain?.seed, GrainSettings.trackSeed(audio.id),
                       "a later edit keeps the track's pattern")
        let written = timeline.document
        timeline.setLaneGrain(audio.id, settings: Self.grain(position: 0.7))
        XCTAssertEqual(timeline.document, written, "the same settings write nothing")

        timeline.setLaneGrain(other.id, settings: Self.grain(seed: 42))
        XCTAssertEqual(chain(other.id)?.soundingGrain?.seed, 42, "an explicitly chosen seed is kept")
        timeline.setLaneGrain(other.id, settings: Self.grain(position: 0.1))
        XCTAssertEqual(chain(other.id)?.soundingGrain?.seed, 42, "and survives a later edit")
        XCTAssertNotEqual(chain(audio.id)?.soundingGrain?.seed, chain(other.id)?.soundingGrain?.seed)

        timeline.setLaneGrain(audio.id, settings: nil)
        XCTAssertNil(chain(audio.id)?.soundingGrain, "nil removes the grain")
        XCTAssertEqual(chain(audio.id)?.inserts, [Self.unknownInsert], "COUNTERWEIGHT: only the grain")

        timeline.setLaneGrain(midi.id, settings: Self.grain())
        XCTAssertNil(chain(midi.id), "a MIDI track plays no grain, so the writer places none")
        timeline.setLaneGrain(bio.id, settings: Self.grain())
        XCTAssertNil(chain(bio.id), "nor on the body track")
        let before = timeline.document
        timeline.setLaneGrain(UUID(), settings: Self.grain())
        XCTAssertEqual(timeline.document, before, "an unknown lane is a no-op, not a crash")
    }

    // MARK: 3 — the edit path asks for the rendering, and plays nothing

    private enum Event: Equatable {
        case render(from: Double, length: Double, GrainSettings)
        case grain(GrainSettings?)
        case play(from: Double)
        case stop
    }

    @MainActor
    private final class Spy: AudioRegionSink {
        var events: [Event] = []
        func play(url: URL, fromSeconds: Double, lengthSeconds: Double, gain: Float,
                  stretch: StretchPlan) { events.append(.play(from: fromSeconds)) }
        func stop() { events.append(.stop) }
        func prepareGrain(url: URL, fromSeconds: Double, lengthSeconds: Double,
                          settings: GrainSettings, fades: PartFadePlan?) {
            events.append(.render(from: fromSeconds, length: lengthSeconds, settings))
        }
        func setGrain(_ settings: GrainSettings?) { events.append(.grain(settings)) }
    }

    func testAGrainEditAsksAPrimedLaneForItsRenderingAndPlaysNothing() {
        var spies: [Spy] = []
        let clip = UUID()
        let player = AudioLanePlayer(makeSink: { let s = Spy(); spies.append(s); return s },
                                     resolveURL: { _ in URL(fileURLWithPath: "/tmp/loop.wav") })
        let lane = TimelineLane(name: "Audio 1", kind: .audio)
        let part = TimelineRegion(laneID: lane.id, clipID: clip, startTick: 0, lengthTicks: 2 * Self.bar)
        player.prime(in: TimelineDocument(lanes: [lane], regions: [part]), atTick: 0, bpm: 120)
        XCTAssertEqual(spies.count, 1, "the premise: prime made the lane's sink")
        spies.forEach { $0.events.removeAll() }

        var edited = lane
        edited.deviceChain = DeviceChain(inserts: [.grain(Self.grain(seed: 5))])
        let unprimed = TimelineLane(name: "Audio 2", kind: .audio,
                                    deviceChain: DeviceChain(inserts: [.grain(Self.grain(seed: 6))]))
        let unprimedPart = TimelineRegion(laneID: unprimed.id, clipID: clip, startTick: 0, lengthTicks: Self.bar)
        player.prepareGrains(in: TimelineDocument(lanes: [edited, unprimed], regions: [part, unprimedPart]), bpm: 120)

        let length = TimelineTime.seconds(fromTicks: 2 * Self.bar, bpm: 120)
        XCTAssertEqual(spies.first?.events, [.render(from: 0, length: length, Self.grain(seed: 5).sanitized)],
                       "the primed lane is asked for the new rendering — no stop, no hand-over, no play")
        XCTAssertEqual(spies.count, 1,
                       "COUNTERWEIGHT: a lane that was never primed gets no sink here; its own prime renders it")
    }

    // MARK: 4 — the merge asks, the sink keeps every request

    func testTheMergeAsksAndTheSinkQueuesWhatItCannotStartYet() throws {
        let player = try source(Self.playerPath)
        let refresh = try XCTUnwrap(Self.body(after: "private func refreshMixer()", in: player),
                                    "ANCHOR MISSING: `refreshMixer`")
        assertOrder(in: refresh, ["guard doc.mergeMixer(from: fresh) else { return }",
                                  "audioLanes?.prepareGrains(in: doc, bpm: pattern?.tempo ?? Self.fallbackTempo)"],
                    why: "a grain edit is a mixer value; the renderings are asked for only on a real change")

        let sink = try source(Self.sinkPath)
        let prepare = try XCTUnwrap(Self.body(after: "func prepareGrain(url: URL, fromSeconds: Double, lengthSeconds: Double,",
                                              in: sink), "ANCHOR MISSING: `TimelineAudioSink.prepareGrain`")
        assertOrder(in: prepare, ["guard grainInFlight.isEmpty else {",
                                  "grainQueued.count < Self.grainQueueCap",
                                  "grainQueued[window] = GrainRequest(",
                                  "Task.detached(priority: .userInitiated)"],
                    why: "a request made while another renders waits, one per part window, capped")
        let store = try XCTUnwrap(Self.body(after: "private func storeGrain(key: GrainKey, channels: [[Float]])", in: sink),
                                  "ANCHOR MISSING: `storeGrain`")
        assertOrder(in: store, ["grainInFlight.remove(key)", "defer { startNextQueuedGrain() }"],
                    why: "whatever a rendering's outcome, the next waiting request starts")
        let next = try XCTUnwrap(Self.body(after: "private func startNextQueuedGrain()", in: sink),
                                 "ANCHOR MISSING: `startNextQueuedGrain`")
        assertOrder(in: next, ["while grainInFlight.isEmpty", "grainQueued[window] = nil", "prepareGrain(url: request.url"],
                    why: "a waiting request leaves the queue before it is started, so it cannot loop")
        let detach = try XCTUnwrap(Self.body(after: "func detach()", in: sink), "ANCHOR MISSING: `detach`")
        XCTAssertTrue(detach.contains("grainQueued.removeAll()"), "a removed lane must drop its waiting requests")
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
