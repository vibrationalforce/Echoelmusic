import EchoelCore
import XCTest
@testable import EchoelEngine

final class MeterBankTests: XCTestCase {
    private let rate = 48_000.0
    private let bar = MusicalTime.ticksPerBar(.common)

    private func project(notes: [[Note]]) throws -> (Project, [TrackID]) {
        var project = Project(tempo: 120)
        var ids: [TrackID] = []
        for (n, list) in notes.enumerated() {
            let track = TrackID(), clip = ClipID()
            try Command.addTrack(id: track, name: "T\(n)", kind: .instrument, index: nil).apply(to: &project)
            try Command.createClip(track: track, id: clip, name: "C", length: bar).apply(to: &project)
            if !list.isEmpty { try Command.addNotes(clip, list).apply(to: &project) }
            try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
            ids.append(track)
        }
        return (project, ids)
    }

    /// Publishes `project`, plays, and returns the engine with each track's meter reading.
    private func playing(_ project: Project) -> (EngineCore, [TrackID: Int]) {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        let snapshot = EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                      sampleRate: rate, generation: 1)
        core.publish(snapshot)
        core.play()
        return (core, core.meterIndices(for: snapshot))
    }

    @discardableResult
    private func render(_ core: EngineCore, frames: Int) -> (left: [Float], right: [Float]) {
        var left = [Float](repeating: 0, count: frames), right = [Float](repeating: 0, count: frames)
        var done = 0
        while done < frames {
            let n = Swift.min(256, frames - done)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    core.render(frameCount: n, left: lp + done, right: rp + done)
                }
            }
            done += n
        }
        return (left, right)
    }

    func testAPlayingTrackLightsItsMeterAndTheMasterWhileASilentOneStaysDark() throws {
        let (song, tracks) = try project(notes: [[Note(pitch: 60, start: 0, length: 960)], []])
        let (core, meters) = playing(song)
        render(core, frames: 4_800)
        let playing = core.meters.level(try XCTUnwrap(meters[tracks[0]]))
        XCTAssertGreaterThan(playing.left, 0.01)
        XCTAssertGreaterThan(playing.right, 0.01)
        XCTAssertEqual(core.meters.level(try XCTUnwrap(meters[tracks[1]])), .silent)
        XCTAssertGreaterThan(core.meters.level(core.masterMeter).left, 0.01)
    }

    func testTheMasterReadsWhatLeavesTheEngine() throws {
        let (song, _) = try project(notes: [[Note(pitch: 60, start: 0, length: 960)]])
        let (core, _) = playing(song)
        let out = render(core, frames: 4_800)
        let master = core.meters.level(core.masterMeter)
        let loudest = out.left.map(Swift.abs).max() ?? 0
        let lastBlock = out.left.suffix(256).map(Swift.abs).max() ?? 0
        XCTAssertLessThanOrEqual(master.left, loudest + 1e-6, "never above what was played")
        XCTAssertGreaterThanOrEqual(master.left, lastBlock - 1e-6, "never below the block just played")
    }

    func testTheMeterIsAfterTheFader() throws {
        let made = try project(notes: [[Note(pitch: 60, start: 0, length: 960)], [Note(pitch: 60, start: 0, length: 960)]])
        var song = made.0
        let tracks = made.1
        try Command.setVolume(.track(tracks[1]), db: -6).apply(to: &song)
        let (core, meters) = playing(song)
        render(core, frames: 4_800)
        let full = core.meters.level(try XCTUnwrap(meters[tracks[0]])).left
        let quieter = core.meters.level(try XCTUnwrap(meters[tracks[1]])).left
        XCTAssertEqual(quieter / full, Float(pow(10, -6.0 / 20)), accuracy: 0.03)
    }

    func testAReadingFallsTwentyDecibelsASecondOnceTheSoundStops() throws {
        let (song, tracks) = try project(notes: [[Note(pitch: 60, start: 0, length: 240)]])
        let (core, meters) = playing(song)
        render(core, frames: 4_800)
        let index = try XCTUnwrap(meters[tracks[0]])
        core.pause()
        render(core, frames: 96_000)   // the release rings out
        let before = core.meters.level(index).left
        XCTAssertGreaterThan(before, 0, "still falling, not cut")
        render(core, frames: 48_000)
        let after = core.meters.level(index).left
        XCTAssertEqual(after / before, 0.1, accuracy: 0.02)
    }

    func testTheFallFactorIsTwentyDecibelsPerSecond() {
        XCTAssertEqual(MeterBank.fall(frames: 48_000, sampleRate: 48_000), 0.1, accuracy: 1e-5)
        XCTAssertEqual(MeterBank.fall(frames: 0, sampleRate: 48_000), 1)
        XCTAssertEqual(MeterBank.fall(frames: 256, sampleRate: 0), 1)
    }

    func testAReadingIgnoresNonFiniteSamplesAndUnknownIndices() {
        let bank = MeterBank(count: 2)
        bank.record(0, left: .nan, right: -.infinity, fall: 1)
        XCTAssertEqual(bank.level(0), .silent)
        bank.record(1, left: -0.5, right: 0.25, fall: 1)
        XCTAssertEqual(bank.level(1), MeterBank.Level(left: 0.5, right: 0.25))
        bank.record(9, left: 1, right: 1, fall: 1)
        XCTAssertEqual(bank.level(9), .silent)
        XCTAssertEqual(bank.level(-1), .silent)
    }
}
