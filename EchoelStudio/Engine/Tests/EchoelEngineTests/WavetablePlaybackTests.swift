import EchoelCore
import EchoelDSP
@testable import EchoelKernels
import XCTest
@testable import EchoelEngine

/// The synth fed with the musician's own sample, through the engine the app plays: the table cut
/// from the song's file, its Position swept by automation without a click, and the export the
/// same as what plays live.
final class WavetablePlaybackTests: XCTestCase {
    private let rate = 48_000.0
    private let bar = MusicalTime.ticksPerBar(.common)
    private let quarter = MusicalTime.ticksPerQuarter

    private struct Song {
        var project: Project
        var track: TrackID
        var samples: [MediaID: SampleBuffer]
    }

    /// A second of a 165 Hz tone that brightens from a sine to a buzz: the file the table is cut from.
    private func voice() -> [Float] {
        (0..<48_000).map { (i: Int) -> Float in
            let t = Double(i) / 48_000, bright = Double(i) / 48_000
            var x = sin(2 * Double.pi * 165 * t)
            for h in 2...9 { x += bright * sin(2 * Double.pi * 165 * Double(h) * t) / Double(h) }
            return Float(0.4 * x)
        }
    }

    /// A synth on the wavetable engine cut from `voice()`, playing a phrase, its Position automated
    /// from the first cycle to the last over two bars.
    private func song(sweep: Bool = true) throws -> Song {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Table", kind: .instrument, index: nil).apply(to: &project)
        let file = MediaFile(name: "Voice", path: "Media/voice.wav", frameCount: 48_000, sampleRate: rate)
        try Command.addMedia(file).apply(to: &project)
        try Command.setInstrumentWavetable(track, WavetableSource(media: file.id, frames: WavetableSource.frames(for: file)))
            .apply(to: &project)
        for (parameter, value) in [(SynthParameter.engine, Double(WavetableSource.engineIndex)), (.cutoff, 12_000),
                                   (.character, 0)] {
            try Command.setInstrumentParameter(track, key: parameter.key.rawValue, value: value).apply(to: &project)
        }
        try Command.createClip(track: track, id: clip, name: "C", length: 2 * bar).apply(to: &project)
        var notes: [Note] = []
        for k in 0..<6 { notes.append(Note(pitch: 48 + 5 * k, velocity: 100, start: Tick(k) * quarter, length: quarter)) }
        for pitch in [48, 55, 60, 64] { notes.append(Note(pitch: pitch, velocity: 90, start: 6 * quarter, length: 2 * quarter)) }
        try Command.addNotes(clip, notes).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        if sweep {
            let position = ParameterAddress(.track(track), SynthParameter.character.key)
            try Command.setAutomation(position, points: [AutomationPoint(tick: 0, value: 0),
                                                         AutomationPoint(tick: 2 * bar, value: 1)]).apply(to: &project)
        }
        let buffer = try XCTUnwrap(SampleBuffer(samples: voice(), sampleRate: rate))
        return Song(project: project, track: track, samples: [file.id: buffer])
    }

    private func live(_ s: Song, frames: Int, block: Int = 256, tables: [WavetableSource: WavetableBank]) -> [Float] {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: s.project)
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: s.project), project: s.project, slots: slots.slots,
                                    sampleRate: rate, generation: 1, samples: s.samples, wavetables: tables))
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

    func testTheSongsFileIsCutIntoTheTableItPlays() throws {
        let s = try song(sweep: false)
        let tables = Wavetables.prepare(s.project, samples: s.samples)
        XCTAssertEqual(tables.count, 1)
        let table = try XCTUnwrap(tables.values.first)
        XCTAssertEqual(table.frameCount, 23)
        let cut = live(s, frames: 24_000, tables: tables)
        let factory = live(s, frames: 24_000, tables: [:])
        XCTAssertTrue(cut.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(cut.map { abs($0) }.max() ?? 0, 0.02)
        XCTAssertNotEqual(cut, factory, "the sample's cycles, not the factory shapes")
        XCTAssertGreaterThan(factory.map { abs($0) }.max() ?? 0, 0.02, "a table not built yet plays the factory shapes")
    }

    func testTheExportIsWhatPlaysLive() throws {
        let s = try song()
        let export = OfflineRender.render(s.project, sampleRate: rate, tailSeconds: 0.5, ringOutSeconds: 0, samples: s.samples)
        let played = live(s, frames: export.frameCount, block: 333, tables: Wavetables.prepare(s.project, samples: s.samples))
        XCTAssertGreaterThan(export.frameCount, 96_000)
        for i in 0..<export.frameCount {
            guard abs(export.left[i] - played[i]) <= 1e-6 else {
                return XCTFail("sample \(i) differs: \(export.left[i]) vs \(played[i])")
            }
        }
    }

    func testSweepingThePositionDoesNotClick() throws {
        let s = try song()
        let out = live(s, frames: 96_000, tables: Wavetables.prepare(s.project, samples: s.samples))
        let clicks = ClickDetector().clicks(in: out)
        XCTAssertEqual(clicks, [], clicks.prefix(4).map(\.description).joined(separator: "; "))
    }
}
