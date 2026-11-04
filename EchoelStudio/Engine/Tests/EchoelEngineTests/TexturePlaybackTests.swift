import EchoelCore
import EchoelDSP
@testable import EchoelKernels
import XCTest
@testable import EchoelEngine

/// The texture engine (A10) through the engine the app plays: the song's rule, density, rate and
/// seed reach the voice, the export is what plays live for every block size, an automated rate and
/// a route on the density move it, and a synth at level 0 is silent.
final class TexturePlaybackTests: XCTestCase {
    private let rate = 48_000.0
    private let bar = MusicalTime.ticksPerBar(.common)
    private let quarter = MusicalTime.ticksPerQuarter

    private func song(level: Double = 0.35, automated: Bool = true) throws -> (Project, TrackID) {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Cells", kind: .instrument, index: nil).apply(to: &project)
        try Command.loadInstrumentPreset(track, name: "Cell Texture").apply(to: &project)
        for (parameter, value) in [(SynthParameter.textureRule, 2.0), (.textureSeed, 4_711), (.level, level)] {
            try Command.setInstrumentParameter(track, key: parameter.key.rawValue, value: value).apply(to: &project)
        }
        try Command.createClip(track: track, id: clip, name: "C", length: 2 * bar).apply(to: &project)
        var notes: [Note] = []
        for k in 0..<4 { notes.append(Note(pitch: 45 + 7 * k, velocity: 100, start: Tick(k) * quarter, length: quarter)) }
        for pitch in [45, 52, 57, 64] { notes.append(Note(pitch: pitch, velocity: 90, start: 4 * quarter, length: 4 * quarter)) }
        try Command.addNotes(clip, notes).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        if automated {
            let evolve = ParameterAddress(.track(track), SynthParameter.textureRate.key)
            try Command.setAutomation(evolve, points: [AutomationPoint(tick: 0, value: 2),
                                                       AutomationPoint(tick: 2 * bar, value: 30)]).apply(to: &project)
        }
        return (project, track)
    }

    private func live(_ project: Project, frames: Int, block: Int, inputs: ModulationInputs? = nil) -> [Float] {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                    sampleRate: rate, generation: 1, modulation: inputs))
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

    func testTheSongsTextureReachesTheVoice() throws {
        let (project, track) = try song()
        let settings = try XCTUnwrap(project.track(track)?.instrument)
        let patch = SynthPatch(settings)
        XCTAssertEqual(patch.engine, .texture)
        XCTAssertEqual(patch.textureRule, 2)
        XCTAssertEqual(patch.textureSeed, 4_711)
        XCTAssertEqual(patch.textureDensity, 0.8, accuracy: 1e-6)
        // Not a number never reaches a voice as a trap: it plays the default.
        var broken = patch
        PatchField.textureRule.apply(.nan, to: &broken)
        PatchField.textureSeed.apply(.infinity, to: &broken)
        XCTAssertEqual(broken.textureRule, 0)
        XCTAssertEqual(broken.textureSeed, 0)
    }

    /// The export is what plays live, whatever block size the device asks for.
    func testTheExportIsWhatPlaysLiveInEveryBlockSize() throws {
        let (project, _) = try song()
        let export = OfflineRender.render(project, sampleRate: rate, tailSeconds: 0.5, ringOutSeconds: 0)
        XCTAssertGreaterThan(export.frameCount, 96_000)
        XCTAssertGreaterThan(export.left.map { Swift.abs($0) }.max() ?? 0, 0.02, "the texture sounds")
        XCTAssertTrue(export.left.allSatisfy(\.isFinite))
        for block in [64, 256, 4_096] {
            let played = live(project, frames: export.frameCount, block: block)
            for i in 0..<export.frameCount {
                guard export.left[i] == played[i] else {
                    return XCTFail("block \(block), sample \(i) differs: \(export.left[i]) vs \(played[i])")
                }
            }
        }
    }

    /// The automated rate moves the row without a click.
    func testAnAutomatedRateDoesNotClick() throws {
        let (project, _) = try song()
        let out = live(project, frames: 96_000, block: 256)
        let clicks = ClickDetector().clicks(in: out)
        XCTAssertEqual(clicks, [], clicks.prefix(4).map(\.description).joined(separator: "; "))
    }

    /// A route on the density moves the sound live, and without a measured source nothing moves.
    func testARouteOnTheDensityMovesTheTexture() throws {
        var (project, track) = try song(automated: false)
        let density = ParameterAddress(.track(track), SynthParameter.textureDensity.key)
        try Command.setModRoute(ModulationRoute(source: .coherence, target: density, depth: -1)).apply(to: &project)
        let inputs = ModulationInputs()
        let still = live(project, frames: 48_000, block: 256, inputs: inputs)
        XCTAssertEqual(still, live(project, frames: 48_000, block: 256), "an absent source moves nothing")
        inputs.set(.coherence, 1)
        let thinned = live(project, frames: 48_000, block: 256, inputs: inputs)
        XCTAssertNotEqual(thinned, still, "full coherence closes the harmonics")
        XCTAssertTrue(thinned.allSatisfy(\.isFinite))
    }

    func testLevelZeroIsSilence() throws {
        let (project, _) = try song(level: 0)
        XCTAssertTrue(live(project, frames: 48_000, block: 256).allSatisfy { $0 == 0 })
        let export = OfflineRender.render(project, sampleRate: rate, tailSeconds: 0.5, ringOutSeconds: 0)
        XCTAssertTrue(export.left.allSatisfy { $0 == 0 })
    }
}
