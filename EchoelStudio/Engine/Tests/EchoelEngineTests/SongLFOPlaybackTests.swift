import EchoelCore
import EchoelDSP
import Foundation
import XCTest
@testable import EchoelEngine

/// `lfo.1`, the sine over each bar read from the song position, played by the same `EngineCore` the
/// app plays: it moves a mixer value and an instrument value, and an export holds exactly what
/// plays live at any block size — it never reads a wall clock or a sensor.
final class SongLFOPlaybackTests: XCTestCase {
    private let rate = 48_000.0
    private let bar = MusicalTime.ticksPerBar(.common)

    /// One synth track holding a note for two bars, at 120 BPM (one bar is 96 000 frames).
    private func song(routes: (TrackID) -> [ModulationRoute]) throws -> Project {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: 2 * bar).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 48, start: 0, length: 2 * bar - 10)]).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        for route in routes(track) { try Command.setModRoute(route).apply(to: &project) }
        return project
    }

    private func routes(_ track: TrackID) -> [ModulationRoute] {
        [ModulationRoute(source: .lfo1, target: .masterPan, depth: 1, polarity: .bipolar),
         ModulationRoute(source: .lfo1, target: ParameterAddress(.track(track), SynthParameter.cutoff.key), depth: 0.5)]
    }

    /// Played live, as the app plays: with live inputs present (no body measured), in blocks.
    private func live(_ project: Project, frames: Int, block: Int) -> (left: [Float], right: [Float]) {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                    sampleRate: rate, generation: 1, modulation: ModulationInputs()))
        core.play()
        var left = [Float](repeating: 0, count: frames), right = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let n = Swift.min(block, frames - start)
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

    private func export(_ project: Project, frames: Int) -> OfflineRender.Result {
        OfflineRender.render(project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0, frameCount: frames)
    }

    private func rms(_ samples: ArraySlice<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples { sum += sample * sample }
        return (sum / Float(samples.count)).squareRoot()
    }

    func testTheLFOSwingsThePanWithTheBar() throws {
        let out = export(try song(routes: routes), frames: 96_000)
        // A quarter of the way in the pan is hard right, three quarters in hard left.
        let quarter = 24_000, threeQuarters = 72_000, window = 2_400
        let rightAtQuarter = rms(out.right[(quarter - window)..<(quarter + window)])
        let leftAtQuarter = rms(out.left[(quarter - window)..<(quarter + window)])
        let rightLater = rms(out.right[(threeQuarters - window)..<(threeQuarters + window)])
        let leftLater = rms(out.left[(threeQuarters - window)..<(threeQuarters + window)])
        XCTAssertGreaterThan(rightAtQuarter, 0.01, "the note sounds")
        XCTAssertGreaterThan(rightAtQuarter, 4 * leftAtQuarter, "right a quarter of the way in")
        XCTAssertGreaterThan(leftLater, 4 * rightLater, "left three quarters in")
    }

    func testAnExportWithTheLFODiffersFromOneWithout() throws {
        let moving = export(try song(routes: routes), frames: 96_000)
        let still = export(try song { _ in [] }, frames: 96_000)
        XCTAssertNotEqual(moving.left, still.left)
        XCTAssertEqual(export(try song(routes: routes), frames: 96_000).left, moving.left, "and two exports agree")
    }

    /// Live is the export, at device buffers on the 64-frame gain grid and off it alike. A moving
    /// mixer value is evaluated every 64 frames of the song and ramped between; the grid used to
    /// start at each buffer, and the master's balance has a corner at centre, so a buffer whose
    /// grid missed the corner drew a different line across it: 8.6e-5 at 470 frames (CI
    /// 2026-11-05), while 100 frames hit the corner at the half bar and stayed below 1e-5.
    func testLiveIsTheExportAtEveryBlockSize() throws {
        let project = try song(routes: routes)
        let frames = 2 * 96_000
        let exported = export(project, frames: frames)
        XCTAssertGreaterThan(exported.peak, 0.01, "the note sounds")
        for (block, bound) in [(64, Float(1e-5)), (256, 1e-5), (4_096, 1e-5), (100, 1e-5), (470, 1e-5), (333, 1e-5)] {
            let played = live(project, frames: frames, block: block)
            XCTAssertEqual(played.left.count, exported.left.count)
            var largest: Float = 0
            for i in 0..<Swift.min(played.left.count, exported.left.count) {
                largest = Swift.max(largest, abs(played.left[i] - exported.left[i]), abs(played.right[i] - exported.right[i]))
            }
            XCTAssertLessThan(largest, bound, "block \(block): live is the export")
        }
    }
}
