import EchoelCore
import EchoelDSP
@testable import EchoelKernels
import XCTest
@testable import EchoelEngine

/// The bass presets of EchoelTools A3 and the slide and accent under them (A2), through the engine
/// the app plays: overlapping notes glide, the line does not click, and the export is what plays.
final class BassLineTests: XCTestCase {
    private let rate = 48_000.0
    private let quarter = MusicalTime.ticksPerQuarter
    private let bar = MusicalTime.ticksPerBar(.common)

    /// A line of overlapping notes — each struck before the last lets go — some of them hard.
    private func line(_ preset: String) throws -> Project {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Bass", kind: .instrument, index: nil).apply(to: &project)
        try Command.loadInstrumentPreset(track, name: preset).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: 2 * bar).apply(to: &project)
        let pitches = [36, 43, 41, 48, 36, 39, 34, 36]
        let notes = pitches.enumerated().map { (index: Int, pitch: Int) -> Note in
            Note(pitch: pitch, velocity: index % 3 == 0 ? 120 : 80, start: Tick(index) * quarter,
                 length: quarter + quarter / 4)
        }
        try Command.addNotes(clip, notes).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        return project
    }

    private func live(_ project: Project, frames: Int, block: Int) -> [Float] {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                    sampleRate: rate, generation: 1))
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
        return left
    }

    func testTheBassPresetsExistAndTheGlideHasSlideAndAccent() throws {
        let glide = try XCTUnwrap(InstrumentPreset.named("808 Glide"))
        XCTAssertGreaterThan(glide.values[SynthParameter.slide.key.rawValue] ?? 0, 0)
        XCTAssertGreaterThan(glide.values[SynthParameter.accent.key.rawValue] ?? 0, 0)
        XCTAssertNotNil(InstrumentPreset.named("Reese Bass"))
    }

    func testABassLinePlaysTheSameLiveAndInTheExport() throws {
        for preset in ["808 Glide", "Reese Bass"] {
            let project = try line(preset)
            let export = OfflineRender.render(project, sampleRate: rate, tailSeconds: 0.5, ringOutSeconds: 0)
            let played = live(project, frames: export.frameCount, block: 333)
            for i in 0..<export.frameCount where abs(export.left[i] - played[i]) > 1e-6 {
                return XCTFail("\(preset): sample \(i) differs: \(export.left[i]) vs \(played[i])")
            }
        }
    }

    func testABassLineDoesNotClick() throws {
        for preset in ["808 Glide", "Reese Bass"] {
            let out = live(try line(preset), frames: 96_000, block: 256)
            XCTAssertGreaterThan(out.map { abs($0) }.max() ?? 0, 0.02, preset)
            let clicks = ClickDetector().clicks(in: out)
            XCTAssertEqual(clicks, [], "\(preset): " + clicks.prefix(4).map(\.description).joined(separator: "; "))
        }
    }
}
