import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelEngine

/// How the three built-in instruments sound through the engine today, pinned before the engine
/// plays them through kernels (S-26, D2). Each expected output is the DSP voice driven directly
/// with the planned events at their samples, times the track's fader gain — never a pasted
/// recording, so the pin holds on every platform the DSP gives the same samples on.
final class InstrumentPathTests: XCTestCase {
    private let rate = 48_000.0
    private let bar = MusicalTime.ticksPerBar(.common)
    private var generation: UInt64 = 0

    private struct Tune {
        var project: Project
        var track: TrackID
        var samples: [MediaID: SampleBuffer] = [:]
    }

    /// One instrument track at 120 BPM with one clip of `notes` and `controls` placed at 0.
    private func tune(_ notes: [Note], device: InstrumentDevice = .synth, controls: [ControlChange] = []) throws -> Tune {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "T", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: 8 * bar).apply(to: &project)
        if !notes.isEmpty { try Command.addNotes(clip, notes).apply(to: &project) }
        if !controls.isEmpty { try Command.setControls(clip, controls).apply(to: &project) }
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        if device != .synth { try Command.setInstrumentDevice(track, device).apply(to: &project) }
        return Tune(project: project, track: track)
    }

    /// Gives a sampler track `samples` as its sample, under a new media file.
    private func load(_ samples: [Float], into tune: inout Tune) throws {
        let media = MediaFile(name: "Tone", path: "Media/tone\(tune.samples.count).wav", frameCount: samples.count,
                              sampleRate: rate)
        try Command.addMedia(media).apply(to: &tune.project)
        try Command.setInstrumentSample(tune.track, media.id).apply(to: &tune.project)
        tune.samples[media.id] = try XCTUnwrap(SampleBuffer(samples: samples, sampleRate: rate, rootPitch: 60))
    }

    private func engine() -> EngineCore {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        return core
    }

    private func publish(_ tune: Tune, to core: EngineCore) {
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: tune.project)
        generation += 1
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: tune.project), project: tune.project,
                                    slots: slots.slots, sampleRate: rate, generation: generation, samples: tune.samples))
    }

    private func render(_ core: EngineCore, frames: Int, block: Int = 256) -> [Float] {
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
        return left
    }

    private func firstSound(_ samples: [Float]) -> Int? {
        samples.firstIndex { Swift.abs($0) > 1e-6 }
    }

    private func peak(_ samples: [Float]) -> Float {
        samples.reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }
    }

    /// The left gain the mixer gives the track: centre pan, 0 dB, through the master.
    private func gain(_ tune: Tune) throws -> Float {
        let track = try XCTUnwrap(tune.project.track(tune.track))
        return EngineSnapshot.gains(track: track.mixer, master: tune.project.master).0
    }

    /// The DSP voice driven with the track's planned notes at their samples, then scaled by the
    /// track's gain. Bends and controllers are not sent: the drum and sampler tests check that
    /// the engine drops them, and the synth tests carry none.
    private func reference<Voice: Played>(_ voice: inout Voice, _ tune: Tune, frames: Int) throws -> [Float] {
        let plan = PlaybackPlan(compiling: tune.project)
        let events = try XCTUnwrap(plan.tracks.first { $0.track == tune.track }).events
        let perTick = rate * 60 / (120 * Double(MusicalTime.ticksPerBeat(.common)))
        var out = [Float](repeating: 0, count: frames)
        var at = 0
        for event in events {
            let sample = Int((Double(event.tick) * perTick).rounded())
            guard sample < frames else { break }
            if sample > at {
                let from = at
                out.withUnsafeMutableBufferPointer { all in
                    voice.render(into: UnsafeMutableBufferPointer(rebasing: all[from..<sample]))
                }
                at = sample
            }
            switch event.kind {
            case .noteOn(let velocity): voice.noteOn(pitch: event.pitch, velocity: velocity)
            case .noteOff: voice.noteOff(pitch: event.pitch)
            case .control, .pitchBend: break
            }
        }
        let from = at
        out.withUnsafeMutableBufferPointer { all in
            voice.render(into: UnsafeMutableBufferPointer(rebasing: all[from..<frames]))
        }
        let level = try gain(tune)
        return out.map { $0 * level }
    }

    /// Bit for bit, naming the first sample that differs instead of printing two long arrays.
    private func assertSame(_ heard: [Float], _ expected: [Float], _ what: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(heard.count, expected.count, what, file: file, line: line)
        guard let first = heard.indices.first(where: { $0 < expected.count && heard[$0] != expected[$0] }) else { return }
        XCTFail("\(what): sample \(first) is \(heard[first]), expected \(expected[first])", file: file, line: line)
    }

    // MARK: - Each instrument against its DSP voice

    func testTheSynthSoundsExactlyLikeItsVoicePlayedDirectly() throws {
        var t = try tune([Note(pitch: 48, velocity: 90, start: 0, length: 700),
                          Note(pitch: 55, velocity: 70, start: 333, length: 2_000),
                          Note(pitch: 48, velocity: 60, start: 600, length: 300),
                          Note(pitch: 62, velocity: 110, start: 1_920, length: 480)])
        // Every parameter away from its default, so a value the engine dropped would be heard.
        let values: [(SynthParameter, Double)] = [(.waveform, 2), (.cutoff, 1_500), (.resonance, 0.5),
                                                  (.filterAmount, 2), (.filterDecay, 0.15), (.attack, 0.01),
                                                  (.decay, 0.12), (.sustain, 0.5), (.release, 0.08), (.level, 0.6)]
        for (parameter, value) in values {
            XCTAssertNotEqual(value, parameter.defaultValue, parameter.title)
            try Command.setInstrumentParameter(t.track, key: parameter.key.rawValue, value: value).apply(to: &t.project)
        }
        let settings = try XCTUnwrap(t.project.track(t.track)).instrument
        var synth = PolySynth(sampleRate: Float(rate))
        let patch = SynthPatch(settings)
        if synth.patch != patch { synth.setPatch(patch) }
        let expected = try reference(&synth, t, frames: 72_000)
        XCTAssertGreaterThan(peak(expected), 0.01, "the reference sounds")
        for block in [64, 256, 4_096] {
            let core = engine()
            publish(t, to: core)
            core.play()
            assertSame(render(core, frames: 72_000, block: block), expected, "synth, block \(block)")
        }
    }

    func testTheDrumsSoundExactlyLikeTheKitPlayedDirectly() throws {
        // A kick, a snare, an open hat that a closed hat chokes, and a second, harder kick.
        let t = try tune([Note(pitch: 36, velocity: 100, start: 0, length: 240),
                          Note(pitch: 38, velocity: 90, start: 480, length: 240),
                          Note(pitch: 46, velocity: 80, start: 960, length: 960),
                          Note(pitch: 42, velocity: 100, start: 1_200, length: 120),
                          Note(pitch: 36, velocity: 127, start: 1_440, length: 240)], device: .drums)
        var kit = DrumKit(sampleRate: Float(rate))
        let expected = try reference(&kit, t, frames: 72_000)
        XCTAssertGreaterThan(peak(expected), 0.01, "the reference sounds")
        for block in [64, 256, 4_096] {
            let core = engine()
            publish(t, to: core)
            core.play()
            assertSame(render(core, frames: 72_000, block: block), expected, "drums, block \(block)")
        }
    }

    func testTheSamplerSoundsExactlyLikeItsSamplerPlayedDirectly() throws {
        // Two overlapping notes and a re-trigger of the first pitch while it is still held.
        var t = try tune([Note(pitch: 60, velocity: 100, start: 0, length: 960),
                          Note(pitch: 67, velocity: 80, start: 480, length: 960),
                          Note(pitch: 60, velocity: 120, start: 720, length: 480)], device: .sampler)
        let tone = (0..<24_000).map { Float(sin(2 * Double.pi * 220 * Double($0) / 48_000) * (1 - Double($0) / 24_000)) }
        try load(tone, into: &t)
        var sampler = Sampler(sampleRate: Float(rate))
        sampler.setSample(try XCTUnwrap(t.samples.values.first))
        let expected = try reference(&sampler, t, frames: 72_000)
        XCTAssertGreaterThan(peak(expected), 0.01, "the reference sounds")
        for block in [64, 256, 4_096] {
            let core = engine()
            publish(t, to: core)
            core.play()
            assertSame(render(core, frames: 72_000, block: block), expected, "sampler, block \(block)")
        }
    }

    // MARK: - What each instrument hears

    func testTheDrumsAndTheSamplerIgnoreAClipsBendsAndControllers() throws {
        let notes = [Note(pitch: 36, start: 0, length: 960), Note(pitch: 60, start: 480, length: 960)]
        let controls = [ControlChange(kind: .pitchBend, start: 100, value: 16_383),
                        ControlChange(kind: .controller(number: 64), start: 300, value: 127),
                        ControlChange(kind: .controller(number: 1), start: 500, value: 100),
                        ControlChange(kind: .controller(number: 7), start: 700, value: 20)]
        let tone = [Float](repeating: 0.5, count: 24_000)
        for device in [InstrumentDevice.drums, .sampler] {
            var outputs: [[Float]] = []
            for moves in [[], controls] {
                var t = try tune(notes, device: device, controls: moves)
                if device == .sampler { try load(tone, into: &t) }
                let core = engine()
                publish(t, to: core)
                core.play()
                outputs.append(render(core, frames: 72_000))
            }
            XCTAssertGreaterThan(peak(outputs[0]), 0.01, "\(device) sounds")
            assertSame(outputs[1], outputs[0], "\(device) with and without the clip's bends and controllers")
        }
    }

    /// A track that changes instrument cuts the sounding note at once, the new instrument stays
    /// silent until it is played, and switching back does not bring the old note back.
    func testSwitchingTheInstrumentInOneEngineCutsTheSoundingNoteForGood() throws {
        let synth = try tune([Note(pitch: 60, start: 0, length: 4 * bar)])
        var drums = synth
        try Command.setInstrumentDevice(drums.track, .drums).apply(to: &drums.project)
        let core = engine()
        publish(synth, to: core)
        core.play()
        XCTAssertGreaterThan(peak(Array(render(core, frames: 12_000).suffix(1_000))), 0.01, "the synth holds the note")
        publish(drums, to: core)
        XCTAssertNil(firstSound(render(core, frames: 4_800)), "middle C is not in the kit, and the held note is cut")
        publish(synth, to: core)
        XCTAssertNil(firstSound(render(core, frames: 24_000)), "the note that was cut does not come back")
    }

    func testASlotHandedToANewTrackStartsSilent() throws {
        let first = try tune([Note(pitch: 60, start: 0, length: 4 * bar)])
        var second = first
        let other = TrackID(), clip = ClipID()
        try Command.removeTrack(first.track).apply(to: &second.project)
        try Command.addTrack(id: other, name: "B", kind: .instrument, index: nil).apply(to: &second.project)
        try Command.createClip(track: other, id: clip, name: "C", length: bar).apply(to: &second.project)
        try Command.placeClip(track: other, id: PlacementID(), clip: clip, start: 0).apply(to: &second.project)
        second.track = other
        let core = engine()
        publish(first, to: core)
        core.play()
        XCTAssertGreaterThan(peak(Array(render(core, frames: 12_000).suffix(1_000))), 0.01, "track A holds the note")
        publish(second, to: core)
        XCTAssertNil(firstSound(render(core, frames: 4_800)), "track B does not inherit A's note")
        core.playLive(slot: 0, status: 0x90, 64, 100)
        XCTAssertNotNil(firstSound(render(core, frames: 4_800)), "and plays its own")
    }

    /// Drums are one-shots: stopping and seeking release held notes but let a hit ring out, and
    /// the hit goes on exactly as the kit plays it.
    func testADrumHitRingsOnThroughAStopAndASeek() throws {
        let t = try tune([Note(pitch: 36, velocity: 110, start: 0, length: 240)], device: .drums)
        var kit = DrumKit(sampleRate: Float(rate))
        let expected = try reference(&kit, t, frames: 7_200)
        let core = engine()
        publish(t, to: core)
        core.play()
        var heard = render(core, frames: 2_400)
        core.stop()
        heard += render(core, frames: 2_400)
        core.seek(toSample: 12_000)
        heard += render(core, frames: 2_400)
        XCTAssertGreaterThan(peak(Array(heard.suffix(1_000))), 0.001, "the kick still rings")
        assertSame(heard, expected, "a kick through stop and seek")
    }

    func testASamplerPlayedLiveReleasesOnAllNotesOffAndStopsOnAllSoundOff() throws {
        var t = try tune([], device: .sampler)
        try load([Float](repeating: 0.5, count: 96_000), into: &t)
        let core = engine()
        publish(t, to: core)
        _ = render(core, frames: 256)
        core.playLive(slot: 0, status: 0x90, 60, 100)
        XCTAssertNotNil(firstSound(render(core, frames: 4_800)), "the held note sounds")
        core.playLive(slot: 0, status: 0xB0, 123, 0)
        let releasing = render(core, frames: 24_000)
        XCTAssertNotNil(firstSound(releasing), "all notes off releases, it does not cut")
        XCTAssertNil(firstSound(Array(releasing.suffix(1_024))), "and the release ends")

        core.playLive(slot: 0, status: 0x90, 60, 100)
        XCTAssertNotNil(firstSound(render(core, frames: 4_800)))
        core.playLive(slot: 0, status: 0xB0, 120, 0)
        XCTAssertNil(firstSound(render(core, frames: 1_024)), "all sound off stops the voice at once")

        core.playLive(slot: 0, status: 0x90, 60, 100)
        XCTAssertNotNil(firstSound(render(core, frames: 4_800)))
        try load([Float](repeating: 0.25, count: 96_000), into: &t)
        publish(t, to: core)
        XCTAssertNil(firstSound(render(core, frames: 1_024)), "a new sample silences the note playing the old one")
    }

    /// A sound changed while nothing plays is the sound of the next note from its first sample.
    func testAPatchPublishedWhileSilentShapesTheNextNoteFromItsFirstSample() throws {
        let plain = try tune([])
        var bright = plain
        let changes: [(SynthParameter, Double)] = [(.waveform, 2), (.cutoff, 3_000)]
        for (parameter, value) in changes {
            try Command.setInstrumentParameter(bright.track, key: parameter.key.rawValue, value: value)
                .apply(to: &bright.project)
        }
        var synth = PolySynth(sampleRate: Float(rate))
        for settings in [plain, bright].map({ $0.project.track($0.track)?.instrument }) {
            let patch = SynthPatch(try XCTUnwrap(settings))
            if synth.patch != patch { synth.setPatch(patch) }
        }
        synth.noteOn(pitch: 60, velocity: 100)
        var expected = [Float](repeating: 0, count: 9_600)
        expected.withUnsafeMutableBufferPointer { synth.render(into: $0) }
        let level = try gain(bright)
        expected = expected.map { $0 * level }

        let core = engine()
        publish(plain, to: core)
        _ = render(core, frames: 256)
        publish(bright, to: core)
        core.playLive(slot: 0, status: 0x90, 60, 100)
        assertSame(render(core, frames: 9_600), expected, "the bright patch from the first sample")
    }
}

/// What the reference drives: the three DSP instruments answer the same three calls.
private protocol Played {
    mutating func noteOn(pitch: UInt8, velocity: UInt8)
    mutating func noteOff(pitch: UInt8)
    mutating func render(into buffer: UnsafeMutableBufferPointer<Float>)
}

extension PolySynth: Played {}
extension DrumKit: Played {}
extension Sampler: Played {}
