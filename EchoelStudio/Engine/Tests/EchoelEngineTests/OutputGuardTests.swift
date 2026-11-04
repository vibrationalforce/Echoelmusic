import EchoelCore
import EchoelDSP
@testable import EchoelKernels
import XCTest
@testable import EchoelEngine

/// The live output's guard (AUD, 2026-11-01). Measured: the Four Tracks starter with its own
/// presets, every fader at 0 dB, a full bar of chords, bass, lead and drums played hard, peaked at
/// +2.6 dBFS with 95 samples over full scale in eight seconds — samples the device's converter
/// cuts flat, heard as crackle and grit. The earlier app always ended in a brick-wall limiter and
/// a −1 dB trim; Studio ended in nothing.
final class OutputGuardTests: XCTestCase {
    private let rate = 48_000.0

    /// The Four Tracks starter with a dense bar on every track, played hard.
    private func denseSong() throws -> Project {
        var project = try StarterProject.fourTracks.project()
        // Measured at unity on the master, as the header says; a new song starts lower
        // (`StarterProject.masterVolumeDB`), which this guard must not lean on.
        try Command.setVolume(.master, db: 0).apply(to: &project)
        let quarter = MusicalTime.ticksPerQuarter, bar = MusicalTime.ticksPerBar(.common)
        let tracks = project.tracks.filter { $0.kind == .instrument }.map(\.id)
        var parts: [[Note]] = [[], [], [], []]
        for b in 0..<4 {
            let at = Tick(b) * bar
            for pitch in [60, 64, 67, 71] { parts[0].append(Note(pitch: pitch, velocity: 110, start: at, length: bar)) }
            for k in 0..<4 { parts[1].append(Note(pitch: 36, velocity: 120, start: at + Tick(k) * quarter, length: quarter / 2)) }
            for k in 0..<8 {
                parts[2].append(Note(pitch: 72 + (k % 4) * 2, velocity: 110, start: at + Tick(k) * quarter / 2, length: quarter / 2))
                parts[3].append(Note(pitch: 42, velocity: 100, start: at + Tick(k) * quarter / 2, length: quarter / 4))
            }
            for k in 0..<4 { parts[3].append(Note(pitch: k % 2 == 0 ? 36 : 38, velocity: 120, start: at + Tick(k) * quarter, length: quarter / 4)) }
        }
        for (track, notes) in zip(tracks, parts) {
            let clip = ClipID()
            try Command.createClip(track: track, id: clip, name: "C", length: 4 * bar).apply(to: &project)
            try Command.addNotes(clip, notes).apply(to: &project)
            try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        }
        return project
    }

    private func render(_ project: Project, guarded: Bool, seconds: Double = 8) -> (left: [Float], right: [Float]) {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        core.setOutputGuard(guarded)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                    sampleRate: rate, generation: 1))
        core.play()
        let frames = Int(seconds * rate)
        var left = [Float](repeating: 0, count: frames), right = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let n = Swift.min(256, frames - start)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    core.render(frameCount: n, left: lp + start, right: rp + start)
                }
            }
            start += n
        }
        return (left, right)
    }

    private func peak(_ out: (left: [Float], right: [Float])) -> Float {
        Swift.max(out.left.map { Swift.abs($0) }.max() ?? 0, out.right.map { Swift.abs($0) }.max() ?? 0)
    }

    func testTheGuardedOutputNeverPassesItsCeiling() throws {
        let song = try denseSong()
        let open = render(song, guarded: false)
        XCTAssertGreaterThan(peak(open), 1, "the song itself goes over full scale")
        let guarded = render(song, guarded: true)
        let ceiling = Float(Foundation.pow(10, EngineCore.outputCeilingDB / 20))
        XCTAssertLessThanOrEqual(peak(guarded), ceiling * 1.0001)
        XCTAssertEqual(ClickDetector().clicks(in: guarded.left), [], "the guard turns down without a click")
    }

    /// Below the ceiling the guard is not there: the same samples, bit for bit.
    func testBelowItsCeilingTheGuardChangesNothing() throws {
        var song = try denseSong()
        for track in song.tracks { try Command.setVolume(.track(track.id), db: -12).apply(to: &song) }
        let open = render(song, guarded: false, seconds: 2)
        XCTAssertLessThan(peak(open), 0.8)
        let guarded = render(song, guarded: true, seconds: 2)
        XCTAssertEqual(open.left, guarded.left)
        XCTAssertEqual(open.right, guarded.right)
    }

    /// An engine nobody asked to guard — an export's, a bake's — plays the mix as it is: the file
    /// is measured and warned about (CUT), never limited behind the musician's back.
    func testAnEngineIsUnguardedUntilAsked() throws {
        let core = EngineCore(sampleRate: rate)
        XCTAssertFalse(core.guardsOutput)
    }
}
