import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelEngine

/// The engine playing its built-in instruments through the kernels, against the DSP voices it
/// drove before (S-26 D2.2): one song with everything that reaches an instrument — clip bends,
/// the pedal and the mod wheel, cutoff and waveform automation, a bend sent while silent, drums,
/// a sampler and a sample swap, a launched and stopped clip, an instrument switch and back, a
/// slot handed to a new track, seek, stop and play, notes and all-off messages played live — is
/// played the same way into both and must come out the same, sample for sample, on both channels.
/// The old path and this test go together in the next commit.
final class InstrumentPathOracleTests: XCTestCase {
    private let rate = 48_000.0
    private let bar = MusicalTime.ticksPerBar(.common)

    /// The song in the states it is published in, in order.
    private struct Song {
        var versions: [Project] = []
        var samples: [MediaID: SampleBuffer] = [:]
        let synth = TrackID(), drums = TrackID(), sampler = TrackID(), late = TrackID()
        let loop = ClipID()
    }

    private func tone(hertz: Double, frames: Int) -> [Float] {
        (0..<frames).map { (index: Int) -> Float in
            let seconds = Double(index) / 48_000
            let fade = 1 - Double(index) / Double(frames)
            return Float(sin(2 * Double.pi * hertz * seconds) * fade)
        }
    }

    /// Gives `track` `samples` as its sample, under a new media file; returns the file's buffer.
    private func addMedia(_ samples: [Float], named name: String, to project: inout Project,
                          track: TrackID) throws -> (MediaID, SampleBuffer) {
        let media = MediaFile(name: name, path: "Media/\(name).wav", frameCount: samples.count, sampleRate: rate)
        try Command.addMedia(media).apply(to: &project)
        try Command.setInstrumentSample(track, media.id).apply(to: &project)
        return (media.id, try XCTUnwrap(SampleBuffer(samples: samples, sampleRate: rate, rootPitch: 60)))
    }

    private func clip(_ track: TrackID, _ id: ClipID, length: Tick, _ notes: [Note], controls: [ControlChange] = [],
                      at starts: [Tick], in project: inout Project) throws {
        try Command.createClip(track: track, id: id, name: "C", length: length).apply(to: &project)
        try Command.addNotes(id, notes).apply(to: &project)
        if !controls.isEmpty { try Command.setControls(id, controls).apply(to: &project) }
        for start in starts {
            try Command.placeClip(track: track, id: PlacementID(), clip: id, start: start).apply(to: &project)
        }
    }

    private func makeSong() throws -> Song {
        var song = Song()
        var project = Project(tempo: 120)
        try Command.addTrack(id: song.synth, name: "Synth", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: song.drums, name: "Drums", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: song.sampler, name: "Sampler", kind: .instrument, index: nil).apply(to: &project)
        try Command.setInstrumentDevice(song.drums, .drums).apply(to: &project)
        try Command.setInstrumentDevice(song.sampler, .sampler).apply(to: &project)
        try Command.setPan(.track(song.synth), pan: -0.3).apply(to: &project)
        try Command.setPan(.track(song.drums), pan: 0.4).apply(to: &project)

        // The synth: a bend before its first note, the mod wheel, the pedal, overlapping notes.
        let synthNotes = [Note(pitch: 48, velocity: 90, start: 960, length: 1_500),
                          Note(pitch: 55, velocity: 70, start: 1_300, length: 2_000),
                          Note(pitch: 62, velocity: 110, start: 3_000, length: 480),
                          Note(pitch: 48, velocity: 60, start: 4_200, length: 2_400),
                          Note(pitch: 67, velocity: 100, start: 6_000, length: 900)]
        let synthControls = [ControlChange(kind: .pitchBend, start: 0, value: 12_000),
                             ControlChange(kind: .controller(number: 1), start: 1_000, value: 90),
                             ControlChange(kind: .controller(number: 64), start: 1_200, value: 127),
                             ControlChange(kind: .pitchBend, start: 2_000, value: 4_000),
                             ControlChange(kind: .pitchBend, start: 2_500, value: 8_192),
                             ControlChange(kind: .controller(number: 64), start: 3_500, value: 0),
                             ControlChange(kind: .controller(number: 1), start: 5_000, value: 0)]
        try clip(song.synth, ClipID(), length: 2 * bar, synthNotes, controls: synthControls, at: [0, 2 * bar],
                 in: &project)
        // The clip the session launches; it is in the track, not on the timeline.
        try clip(song.synth, song.loop, length: bar,
                 [Note(pitch: 72, start: 0, length: 480), Note(pitch: 76, start: 960, length: 960)], at: [], in: &project)
        let values: [(SynthParameter, Double)] = [(.waveform, 2), (.cutoff, 1_500), (.resonance, 0.5),
                                                  (.release, 0.08), (.level, 0.6)]
        for (parameter, value) in values {
            try Command.setInstrumentParameter(song.synth, key: parameter.key.rawValue, value: value).apply(to: &project)
        }
        try Command.setAutomation(ParameterAddress(.track(song.synth), SynthParameter.cutoff.key), points: [
            AutomationPoint(tick: 0, value: 500), AutomationPoint(tick: bar, value: 6_000, curve: 0.5),
            AutomationPoint(tick: 3 * bar, value: 800),
        ]).apply(to: &project)
        try Command.setAutomation(ParameterAddress(.track(song.synth), SynthParameter.waveform.key), points: [
            AutomationPoint(tick: 0, value: 0), AutomationPoint(tick: bar, value: 3), AutomationPoint(tick: 6 * bar / 4, value: 1),
        ]).apply(to: &project)

        // The drums, with an open hat a closed one chokes.
        let hits: [(pitch: Int, start: Tick)] = [(36, 0), (42, 480), (38, 960), (42, 1_440), (36, 1_920), (46, 2_400),
                                                 (42, 2_640), (38, 2_880), (36, 3_840), (36, 5_760)]
        let drumNotes: [Note] = hits.map { (hit: (pitch: Int, start: Tick)) -> Note in
            Note(pitch: hit.pitch, velocity: 100, start: hit.start, length: 240)
        }
        try clip(song.drums, ClipID(), length: 2 * bar, drumNotes, at: [0, 2 * bar], in: &project)

        // The sampler, with controllers it must ignore and a re-trigger of a held pitch.
        let samplerNotes = [Note(pitch: 60, velocity: 100, start: 0, length: 960),
                            Note(pitch: 67, velocity: 80, start: 480, length: 960),
                            Note(pitch: 60, velocity: 120, start: 720, length: 480),
                            Note(pitch: 64, velocity: 90, start: 4_000, length: 3_000)]
        try clip(song.sampler, ClipID(), length: 2 * bar, samplerNotes,
                 controls: [ControlChange(kind: .pitchBend, start: 100, value: 16_383),
                            ControlChange(kind: .controller(number: 64), start: 300, value: 127)],
                 at: [0, 2 * bar], in: &project)
        let first = try addMedia(tone(hertz: 220, frames: 24_000), named: "low", to: &project, track: song.sampler)
        song.samples[first.0] = first.1
        song.versions.append(project)

        // A new sample, and a synth value changed while it plays under automation.
        let second = try addMedia(tone(hertz: 330, frames: 30_000), named: "high", to: &project, track: song.sampler)
        song.samples[second.0] = second.1
        try Command.setInstrumentParameter(song.synth, key: SynthParameter.release.key.rawValue, value: 0.3)
            .apply(to: &project)
        song.versions.append(project)
        let sounding = project

        // The synth track plays drums for a while, then the synth again.
        try Command.setInstrumentDevice(song.synth, .drums).apply(to: &project)
        song.versions.append(project)
        project = sounding
        song.versions.append(project)

        // The drums track goes; a new synth track takes its slot.
        try Command.removeTrack(song.drums).apply(to: &project)
        try Command.addTrack(id: song.late, name: "Late", kind: .instrument, index: nil).apply(to: &project)
        try clip(song.late, ClipID(), length: 4 * bar,
                 [Note(pitch: 50, start: 0, length: 4 * bar), Note(pitch: 57, start: bar, length: 2 * bar)],
                 at: [0], in: &project)
        song.versions.append(project)
        return song
    }

    /// Plays the whole script into a fresh engine on `path`, in blocks of `block`; both channels.
    private func play(_ song: Song, path: EngineCore.InstrumentPath, block: Int) throws -> [Float] {
        let core = EngineCore(sampleRate: rate, slotCapacity: Track.limit(for: .instrument), instruments: path)
        core.setClickEnabled(false)
        core.setLaunchQuantum(0)
        var assigner = SlotAssigner(capacity: core.slotCapacity)
        var generation: UInt64 = 0
        var out: [Float] = []

        func publish(_ index: Int) {
            let project = song.versions[index]
            assigner.update(for: project)
            generation += 1
            core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: assigner.slots,
                                        sampleRate: rate, generation: generation, samples: song.samples))
        }
        func render(_ frames: Int) {
            var left = [Float](repeating: 0, count: frames)
            var right = [Float](repeating: 0, count: frames)
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
            out += left
            out += right
        }
        func live(_ track: TrackID, _ status: UInt8, _ data1: UInt8, _ data2: UInt8) throws {
            core.playLive(slot: try XCTUnwrap(assigner.slots[track]), status: status, data1, data2)
        }

        publish(0)
        core.play()
        render(40_000)
        // Played live over the song: a note held with the pedal, a note-on at velocity 0 as its off,
        // the wheel, the mod wheel.
        try live(song.synth, 0x90, 72, 100)
        render(4_800)
        try live(song.synth, 0xB0, 64, 127)
        try live(song.synth, 0x80, 72, 0)
        render(4_800)
        try live(song.synth, 0x90, 74, 90)
        try live(song.synth, 0x90, 74, 0)
        try live(song.synth, 0xE0, 0, 96)
        try live(song.synth, 0xB0, 1, 64)
        try live(song.synth, 0xB0, 64, 0)
        render(9_600)
        // The session takes the synth track over, stops, and hands it back.
        let slot = try XCTUnwrap(assigner.slots[song.synth])
        core.launch(slot: slot, .launch(song.loop))
        render(30_000)
        core.launch(slot: slot, .stop)
        render(9_600)
        core.launch(slot: slot, .backToArrangement)
        render(24_000)
        publish(1)
        render(16_000)
        publish(2)
        render(12_000)
        publish(3)
        render(16_000)
        publish(4)
        render(24_000)
        core.seek(toSample: 30_000)
        render(16_000)
        core.stop()
        render(9_600)
        // Live while stopped: held notes, all notes off, all sound off.
        try live(song.synth, 0x90, 60, 100)
        try live(song.sampler, 0x90, 62, 100)
        try live(song.late, 0x90, 65, 100)
        render(9_600)
        try live(song.synth, 0xB0, 123, 0)
        try live(song.sampler, 0xB0, 123, 0)
        render(9_600)
        try live(song.sampler, 0x90, 62, 100)
        try live(song.late, 0x90, 65, 100)
        render(4_800)
        try live(song.sampler, 0xB0, 120, 0)
        try live(song.late, 0xB0, 120, 0)
        render(4_800)
        core.play()
        render(24_000)
        core.stop()
        render(12_000)
        return out
    }

    func testTheKernelsSoundExactlyLikeTheVoicesTheyReplaced() throws {
        let song = try makeSong()
        for block in [64, 256, 1_000, 4_096] {
            let expected = try play(song, path: .legacy, block: block)
            let heard = try play(song, path: .kernels, block: block)
            XCTAssertGreaterThan(expected.reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }, 0.01, "the song sounds")
            XCTAssertEqual(heard.count, expected.count)
            if let first = heard.indices.first(where: { $0 < expected.count && heard[$0] != expected[$0] }) {
                XCTFail("block \(block): sample \(first) is \(heard[first]), the voices played \(expected[first])")
            }
        }
    }
}
