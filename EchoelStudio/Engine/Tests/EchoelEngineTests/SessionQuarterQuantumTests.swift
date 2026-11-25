import EchoelCore
import XCTest
@testable import EchoelEngine

/// The Session page's "1/4" launch quantum (`SessionView.choices`: `MusicalTime.ticksPerQuarter`):
/// a clip launched or stopped while the song plays waits for the next quarter-note line, not for
/// the bar. 120 BPM at 48 kHz: a quarter is 24 000 samples, a bar 96 000.
final class SessionQuarterQuantumTests: XCTestCase {
    private let rate = 48_000.0
    private let bar = MusicalTime.ticksPerBar(.common)
    private let quarter = MusicalTime.ticksPerQuarter

    /// One instrument track whose session clip is one bar with a short note on its first tick; nothing
    /// is placed in the arrangement, so every sound comes from the launched clip.
    private func song() throws -> (project: Project, clip: ClipID) {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "T", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "L", length: bar).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 240)]).apply(to: &project)
        return (project, clip)
    }

    private func engine(for project: Project) -> EngineCore {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project,
                                    slots: slots.slots, sampleRate: rate, generation: 1))
        return core
    }

    /// Renders `frames` in blocks of 256 and returns the left channel.
    private func render(_ core: EngineCore, frames: Int) -> [Float] {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let count = Swift.min(256, frames - start)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    core.render(frameCount: count, left: lp + start, right: rp + start)
                }
            }
            start += count
        }
        return left
    }

    private func firstSound(_ samples: [Float]) -> Int? {
        samples.firstIndex { Swift.abs($0) > 1e-6 }
    }

    private func reports(_ core: EngineCore) -> [LaunchReport] {
        Array(sequence(state: core.launchReports) { $0.pop() })
    }

    func testAClipLaunchedOnTheQuarterQuantumStartsOnTheNextQuarterNotTheNextBar() throws {
        let s = try song()
        let core = engine(for: s.project)
        core.setLaunchQuantum(quarter)
        core.play()
        _ = render(core, frames: 30_000)                 // past beat 2's line (24 000), before beat 3's (48 000)

        core.launch(slot: 0, .launch(s.clip))
        let wait = render(core, frames: 30_000)          // samples 30 000 ..< 60 000
        let start = try XCTUnwrap(firstSound(wait), "the clip starts within the next quarter")
        XCTAssertTrue((18_000...18_002).contains(start), "on beat 3 at sample 48 000, not on bar 2 at 96 000: \(start + 30_000)")

        let launched = reports(core)
        XCTAssertEqual(launched.map(\.state), [.queued, .playing])
        XCTAssertEqual(launched.first?.tick, 2 * quarter, "queued for the tick of beat 3")
    }

    func testAStopOnTheQuarterQuantumEndsTheClipOnTheNextQuarter() throws {
        let s = try song()
        let core = engine(for: s.project)
        core.setLaunchQuantum(quarter)
        core.play()
        _ = render(core, frames: 256)
        core.launch(slot: 0, .launch(s.clip))
        _ = render(core, frames: 60_000 - 256)           // the clip started at 24 000
        XCTAssertEqual(reports(core).map(\.state), [.queued, .playing])

        core.launch(slot: 0, .stop)
        _ = render(core, frames: 71_936 - 60_000)
        XCTAssertEqual(reports(core).map(\.state), [], "the stop waits for beat 4's line at 72 000")
        _ = render(core, frames: 512)
        XCTAssertEqual(reports(core).map(\.state), [.stopped], "and takes effect on it, not on bar 2 at 96 000")
        // Launched at 24 000, the one-bar clip would begin again at 120 000.
        XCTAssertNil(firstSound(render(core, frames: 72_000)), "no second pass after the stop")
    }
}
