import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelEngine

/// Headphone Spatial monitoring (Recovery 5): the engine places each track at its pan's place for
/// headphones, live and in the Spatial Headphone Mix alike, and the stereo export stays as it was.
final class HeadphoneSpatialTests: XCTestCase {
    private let rate = 48_000.0
    private let bar = MusicalTime.ticksPerBar(.common)

    /// One synth track playing a chord for two bars, panned `pan`.
    private func song(pan: Double, panLane: [AutomationPoint]? = nil) throws -> Project {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "S", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: 2 * bar).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 2 * bar - 240),
                                    Note(pitch: 67, start: 480, length: bar)]).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        try Command.setPan(.track(track), pan: pan).apply(to: &project)
        if let panLane { try Command.setAutomation(.pan(track), points: panLane).apply(to: &project) }
        return project
    }

    private func live(_ project: Project, frames: Int, block: Int, spatial: Bool,
                      switchAt: Int? = nil) -> (left: [Float], right: [Float]) {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        core.setHeadphoneSpatial(spatial)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                    sampleRate: rate, generation: 1))
        core.play()
        var left = [Float](repeating: 0, count: frames), right = left
        let l = UnsafeMutablePointer<Float>.allocate(capacity: block)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: block)
        defer { l.deallocate(); r.deallocate() }
        var done = 0
        while done < frames {
            if let switchAt, done >= switchAt { core.setHeadphoneSpatial(!spatial) }
            let count = Swift.min(block, frames - done)
            core.render(frameCount: count, left: l, right: r)
            for i in 0..<count {
                left[done + i] = l[i]
                right[done + i] = r[i]
            }
            done += count
        }
        return (left, right)
    }

    private func rms(_ x: ArraySlice<Float>) -> Double {
        let sum = x.reduce(0.0) { (total: Double, value: Float) -> Double in total + Double(value) * Double(value) }
        return (sum / Double(Swift.max(x.count, 1))).squareRoot()
    }

    private func export(_ project: Project, spatial: Bool, frames: Int) -> OfflineRender.Result {
        OfflineRender.render(project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0, frameCount: frames,
                             headphoneSpatial: spatial)
    }

    func testTheSpatialHeadphoneMixIsWhatTheMonitorPlaysAtEveryBlockSize() throws {
        let project = try song(pan: 0.7)
        let frames = 96_000
        let mix = export(project, spatial: true, frames: frames)
        XCTAssertGreaterThan(rms(mix.left[...]), 0.001, "the mix sounds")
        for block in [64, 256, 4_096] {
            let out = live(project, frames: frames, block: block, spatial: true)
            XCTAssertEqual(out.left, mix.left, "block \(block)")
            XCTAssertEqual(out.right, mix.right, "block \(block)")
        }
    }

    func testWithTheSwitchOffTheExportIsTheStereoMix() throws {
        let project = try song(pan: 1)
        let frames = 48_000
        let plain = OfflineRender.render(project, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0, frameCount: frames)
        let off = export(project, spatial: false, frames: frames)
        XCTAssertEqual(off.left, plain.left)
        XCTAssertEqual(off.right, plain.right)
        // Hard right in the stereo mix: nothing on the left but the pan law's rounding.
        XCTAssertLessThan(rms(plain.left[...]), rms(plain.right[...]) * 1e-5)
        XCTAssertEqual(live(project, frames: frames, block: 256, spatial: false).right, plain.right)
        // Placed for headphones, the left ear hears it too — later and darker, but it hears it.
        let spatial = export(project, spatial: true, frames: frames)
        XCTAssertGreaterThan(rms(spatial.left[...]), 0.001)
        XCTAssertGreaterThan(rms(spatial.right[...]), rms(spatial.left[...]))
    }

    func testACentredTrackIsTheSameInBothEars() throws {
        let out = export(try song(pan: 0), spatial: true, frames: 48_000)
        XCTAssertEqual(out.left, out.right)
        XCTAssertGreaterThan(rms(out.left[...]), 0.001)
    }

    /// The switch flipped mid-song crossfades: no sample jumps further than the music itself does.
    func testSwitchingTheMonitorDoesNotClick() throws {
        let project = try song(pan: -0.9)
        let frames = 48_000
        let plain = live(project, frames: frames, block: 256, spatial: false)
        let worstMusic = zip(plain.left, plain.left.dropFirst()).map { Swift.abs($1 - $0) }.max() ?? 0
        for start in [false, true] {
            let out = live(project, frames: frames, block: 256, spatial: start, switchAt: 24_064)
            for ear in [out.left, out.right] {
                let jumps = zip(ear[23_000..<26_000], ear[23_001..<26_001]).map { Swift.abs($1 - $0) }
                XCTAssertLessThan(jumps.max() ?? 0, worstMusic * 1.5 + 0.005, "turning it \(start ? "off" : "on")")
            }
        }
    }

    /// A pan ride moves the object: it glides, never steps.
    func testAPanRideMovesTheObjectWithoutAStep() throws {
        let project = try song(pan: 0, panLane: [AutomationPoint(tick: 0, value: -1), AutomationPoint(tick: bar / 2, value: 1),
                                                 AutomationPoint(tick: bar, value: -1)])
        let out = export(project, spatial: true, frames: 96_000)
        // The steepest the music itself moves in either ear, held at either side.
        var worstMusic: Float = 0
        for side in [-1.0, 1] {
            let held = export(try song(pan: side), spatial: true, frames: 96_000)
            for ear in [held.left, held.right] {
                worstMusic = Swift.max(worstMusic, zip(ear, ear.dropFirst()).map { Swift.abs($1 - $0) }.max() ?? 0)
            }
        }
        for ear in [out.left, out.right] {
            XCTAssertTrue(ear.allSatisfy(\.isFinite))
            let jumps = zip(ear, ear.dropFirst()).map { Swift.abs($1 - $0) }
            XCTAssertLessThan(jumps.max() ?? 0, worstMusic * 1.2 + 0.005)
        }
        // Early in the first half the object is on the left, early in the second half on the right.
        XCTAssertGreaterThan(rms(out.left[2_000..<6_000]), rms(out.right[2_000..<6_000]))
        XCTAssertGreaterThan(rms(out.right[25_000..<29_000]), rms(out.left[25_000..<29_000]))
    }

    func testTheGainsPanIsTheStripsPan() {
        for pan in [-1.0, -0.4, 0, 0.3, 1] {
            let gains = EngineSnapshot.gains(track: MixerStrip(volumeDB: -6, pan: pan), master: MixerStrip())
            XCTAssertEqual(EngineCore.pan(of: gains), pan, accuracy: 1e-6)
            XCTAssertEqual(EngineCore.centre(gains), EngineSnapshot.linear(-6) * Float(0.5.squareRoot()), accuracy: 1e-6)
        }
        XCTAssertEqual(EngineCore.pan(of: (.nan, .infinity)), 0)
        XCTAssertEqual(EngineCore.centre((.nan, 1)), 0)
    }
}
