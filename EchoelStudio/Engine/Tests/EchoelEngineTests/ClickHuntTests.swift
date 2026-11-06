import EchoelCore
import EchoelDSP
@testable import EchoelKernels
import XCTest
@testable import EchoelEngine

/// The click hunt (AUD, founder 2026-11-01: "Tendenziell ist der Sound noch verknackst"). Each
/// test renders one place where a sound starts, stops, moves or is handed over — offline, through
/// the same `EngineCore` the app plays — and asks the detector for steps the sound cannot carry.
final class ClickHuntTests: XCTestCase {
    private let rate = 48_000.0
    private let quarter = MusicalTime.ticksPerQuarter
    private let bar = MusicalTime.ticksPerBar(.common)
    private var generation: UInt64 = 0

    private func core() -> EngineCore {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        return core
    }

    private func publish(_ project: Project, to core: EngineCore, samples: [MediaID: SampleBuffer] = [:],
                         modulation: ModulationInputs? = nil) {
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        generation += 1
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                    sampleRate: rate, generation: generation, samples: samples, modulation: modulation))
    }

    private func render(_ core: EngineCore, frames: Int, block: Int = 256) -> (left: [Float], right: [Float]) {
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
        return (left, right)
    }

    /// One instrument track with one clip of `notes` at bar 1, `settings` set on its instrument.
    private func instrumentSong(_ notes: [Note], device: InstrumentDevice = .synth,
                                settings: [(SynthParameter, Double)] = [], tempo: Double = 120,
                                length: Tick? = nil) throws -> (project: Project, track: TrackID) {
        var project = Project(tempo: tempo)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "T", kind: .instrument, index: nil).apply(to: &project)
        if device != .synth { try Command.setInstrumentDevice(track, device).apply(to: &project) }
        for (parameter, value) in settings {
            try Command.setInstrumentParameter(track, key: parameter.key.rawValue, value: value).apply(to: &project)
        }
        try Command.createClip(track: track, id: clip, name: "C", length: length ?? 8 * bar).apply(to: &project)
        if !notes.isEmpty { try Command.addNotes(clip, notes).apply(to: &project) }
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        return (project, track)
    }

    private func report(_ clicks: [ClickDetector.Click], _ what: String) -> String {
        "\(what): \(clicks.count) click(s) — " + clicks.prefix(6).map(\.description).joined(separator: "; ")
    }

    private func assertNoClicks(_ signal: (left: [Float], right: [Float]), _ what: String,
                                detector: ClickDetector = ClickDetector(),
                                file: StaticString = #filePath, line: UInt = #line) {
        let left = detector.clicks(in: signal.left)
        let right = detector.clicks(in: signal.right)
        XCTAssertEqual(left, [], report(left, what + " (left)"), file: file, line: line)
        XCTAssertEqual(right, [], report(right, what + " (right)"), file: file, line: line)
    }

    // MARK: - Exploration

    /// A phrase every engine plays: single notes with gaps, overlapping notes, a repeated key, a
    /// short staccato run and a chord.
    private var phrase: [Note] {
        let sixteenth = quarter / 4
        var notes: [Note] = [
            Note(pitch: 60, velocity: 100, start: 0, length: quarter),
            Note(pitch: 64, velocity: 60, start: quarter + sixteenth, length: quarter),
            Note(pitch: 67, velocity: 120, start: 2 * quarter, length: 2 * quarter),
            Note(pitch: 67, velocity: 40, start: 3 * quarter, length: quarter),
        ]
        for k in 0..<8 {
            notes.append(Note(pitch: 72 + k % 3, velocity: 90, start: bar + Tick(k) * sixteenth, length: sixteenth / 2))
        }
        for pitch in [48, 55, 60, 64, 67] {
            notes.append(Note(pitch: pitch, velocity: 100, start: 2 * bar, length: bar))
        }
        return notes
    }

    func testEverySynthEnginePlaysAPhraseWithoutAClick() throws {
        for engine in 0..<SynthEngine.allCases.count {
            let song = try instrumentSong(phrase, settings: [(.engine, Double(engine))], tempo: 240)
            let core = core()
            publish(song.project, to: core)
            core.play()
            // The DDSP's sixty-four partials a voice are slow in a debug build: its first two bars.
            let frames = SynthEngine.allCases[engine] == .ddsp ? 96_000 : 168_000
            assertNoClicks(render(core, frames: frames), "engine \(SynthEngine.allCases[engine])")
        }
    }

    func testEveryWaveformPlaysAPhraseWithoutAClick() throws {
        for waveform in 0..<4 {
            let song = try instrumentSong(phrase, settings: [(.waveform, Double(waveform)), (.cutoff, 12_000)], tempo: 240)
            let core = core()
            publish(song.project, to: core)
            core.play()
            assertNoClicks(render(core, frames: 168_000), "waveform \(waveform)")
        }
    }

    /// The phrase on a sine with the filter open, measured against what a sine can carry, so a
    /// click at every block would show.
    func testASineVoicePlaysAPhraseWithoutAClickAtAnyBlock() throws {
        let song = try instrumentSong(phrase, settings: [(.waveform, 0), (.cutoff, 18_000), (.filterAmount, 0)], tempo: 240)
        let core = core()
        publish(song.project, to: core)
        core.play()
        assertNoClicks(render(core, frames: 168_000, block: 192), "sine phrase",
                       detector: .forSine(hertz: 600, amplitude: 1))
    }

    func testStealingAtFullPolyphonyDoesNotClick() throws {
        // Twenty-four keys pressed one after another and held: the last eight take voices that
        // still sound.
        let notes = (0..<24).map { (k: Int) -> Note in
            Note(pitch: 36 + k * 2, velocity: 100, start: Tick(k) * quarter / 4, length: 2 * bar)
        }
        for engine in [0, 2] {
            let song = try instrumentSong(notes, settings: [(.engine, Double(engine)), (.level, 0.05)], tempo: 240)
            let core = core()
            publish(song.project, to: core)
            core.play()
            assertNoClicks(render(core, frames: 96_000), "stealing, engine \(engine)")
        }
    }


    // MARK: - Audio regions

    /// A sine long enough to play inside: 220 Hz on the left, 330 Hz on the right when stereo.
    private func sineBuffer(seconds: Double, stereo: Bool) throws -> SampleBuffer {
        let count = Int(seconds * rate)
        let left = (0..<count).map { (i: Int) -> Float in Float(0.5 * sin(2 * Double.pi * 220 * Double(i) / 48_000)) }
        guard stereo else { return try XCTUnwrap(SampleBuffer(samples: left, sampleRate: rate)) }
        let right = (0..<count).map { (i: Int) -> Float in Float(0.5 * sin(2 * Double.pi * 330 * Double(i) / 48_000)) }
        return try XCTUnwrap(SampleBuffer(left: left, right: right, sampleRate: rate))
    }

    /// One audio track with one region of `buffer` at `start`.
    private func audioSong(_ buffer: SampleBuffer, start: Tick = 0)
        throws -> (project: Project, track: TrackID, samples: [MediaID: SampleBuffer]) {
        var project = Project(tempo: 120)
        let track = TrackID(), region = RegionID()
        let media = MediaFile(name: "Tone", path: "Media/tone.wav", frameCount: buffer.frameCount, sampleRate: rate)
        try Command.addTrack(id: track, name: "Audio", kind: .audio, index: nil).apply(to: &project)
        try Command.addMedia(media).apply(to: &project)
        try Command.placeAudio(track: track, id: region, media: media.id, start: start).apply(to: &project)
        return (project, track, [media.id: buffer])
    }

    /// The regions' sines are 220 and 330 Hz at 0.5.
    private var smooth: ClickDetector { .forSine(hertz: 330, amplitude: 0.5) }

    func testPlayStartingInsideARegionDoesNotClick() throws {
        for stereo in [false, true] {
            let song = try audioSong(try sineBuffer(seconds: 4, stereo: stereo))
            let core = core()
            publish(song.project, to: core, samples: song.samples)
            _ = render(core, frames: 512)
            core.seek(toSample: 48_037)                 // a second in, mid-waveform
            var out = render(core, frames: 4_800)        // stopped: silence before the start
            core.play()
            let played = render(core, frames: 24_000)
            out.left += played.left
            out.right += played.right
            assertNoClicks(out, "play inside a region, stereo \(stereo)", detector: smooth)
        }
    }

    /// A start at a region's first frame is no start inside it: the region rises by its own edge
    /// fade and plays as it is from there. So an export or a bake of a region at the song's start
    /// stays the region — the start's fade is for a start inside a sounding region only.
    func testAStartAtARegionsFirstFrameLeavesTheRegionAsItIs() throws {
        let song = try audioSong(try sineBuffer(seconds: 1, stereo: false))
        let core = core()
        publish(song.project, to: core, samples: song.samples)
        core.play()
        let out = render(core, frames: 2_048)
        let centre = Float(0.5.squareRoot())
        var worst: Float = 0
        for i in Int(EngineCore.regionFadeFrames)..<2_048 {
            let file = Float(0.5 * sin(2 * Double.pi * 220 * Double(i) / 48_000))
            worst = Swift.max(worst, Swift.abs(out.left[i] - file * centre))
        }
        XCTAssertLessThan(worst, 1e-5, "after its own edge, the region as it is")
    }

    func testASeekWhilePlayingDoesNotClick() throws {
        let song = try audioSong(try sineBuffer(seconds: 4, stereo: true))
        let core = core()
        publish(song.project, to: core, samples: song.samples)
        core.play()
        var out = render(core, frames: 24_000)
        core.seek(toSample: 96_011)
        let after = render(core, frames: 24_000)
        out.left += after.left
        out.right += after.right
        assertNoClicks(out, "seek while playing", detector: smooth)
    }

    func testPauseAndPlayAgainInsideARegionDoNotClick() throws {
        let song = try audioSong(try sineBuffer(seconds: 4, stereo: false))
        let core = core()
        publish(song.project, to: core, samples: song.samples)
        core.play()
        var out = render(core, frames: 24_000)
        core.pause()
        let paused = render(core, frames: 4_800)
        core.play()
        let again = render(core, frames: 24_000)
        out.left += paused.left + again.left
        out.right += paused.right + again.right
        assertNoClicks(out, "pause and play inside a region", detector: smooth)
    }

    func testTheSongLoopWrapsWithoutAClick() throws {
        // A region a bar long under a one-bar loop, and a held synth note across the wrap.
        let song = try audioSong(try sineBuffer(seconds: 2, stereo: false))
        let core = core()
        publish(song.project, to: core, samples: song.samples)
        core.setLoop(0..<bar)
        core.play()
        assertNoClicks(render(core, frames: 3 * 96_000 + 1_000, block: 333), "audio loop", detector: smooth)

        let held = try instrumentSong([Note(pitch: 57, velocity: 100, start: 0, length: 2 * bar)],
                                      settings: [(.waveform, 0), (.release, 0.3)])
        let synth = self.core()
        publish(held.project, to: synth)
        synth.setLoop(0..<bar)
        synth.play()
        assertNoClicks(render(synth, frames: 3 * 96_000, block: 333), "synth loop",
                       detector: .forSine(hertz: 230, amplitude: 0.5))
    }

    /// Renders `project` with `source` jumping to each of `values` in turn, 4,800 samples apart,
    /// and once more with the source absent, so a test can tell the route was heard at all.
    private func routeRender(_ project: Project, source: ModulationSource, values: [Double])
        -> (stepped: (left: [Float], right: [Float]), difference: Float) {
        func run(_ readings: [Double?]) -> (left: [Float], right: [Float]) {
            let inputs = ModulationInputs()
            let core = core()
            publish(project, to: core, modulation: inputs)
            core.play()
            var out = render(core, frames: 4_800)
            for reading in readings {
                inputs.set(source, reading)
                let piece = render(core, frames: 4_800)
                out.left += piece.left
                out.right += piece.right
            }
            return out
        }
        let stepped = run(values)
        let absent = run(values.map { _ in nil })
        let difference = zip(stepped.left, absent.left).map { Swift.abs($0 - $1) }.max() ?? 0
        return (stepped, difference)
    }

    // MARK: - Moving values

    /// A route on the instrument's character, its source stepping as the body's glide steps it
    /// (30 times a second) and as a stand-in source would jump (once a second).
    func testCharacterMovedByARouteDoesNotClick() throws {
        for engine in [SynthEngine.fm, .morph, .sub, .supersaw] {
            guard let index = SynthEngine.allCases.firstIndex(of: engine) else { continue }
            // The filter open, so nothing after the source smooths what it does.
            var song = try instrumentSong([Note(pitch: 57, velocity: 100, start: 0, length: 4 * bar)],
                                          settings: [(.engine, Double(index)), (.cutoff, 18_000), (.filterAmount, 0),
                                                     (.character, 0.3)])
            let target = ParameterAddress(.track(song.track), SynthParameter.character.key)
            try Command.setModRoute(ModulationRoute(source: .coherence, target: target, depth: 0.6))
                .apply(to: &song.project)
            let moved = routeRender(song.project, source: .coherence, values: [0.1, 0.9, 0.2, 0.8, 0.1, 1, 0])
            assertNoClicks(moved.stepped, "character route, \(engine)")
            XCTAssertGreaterThan(moved.difference, 0.01, "the route is heard, \(engine)")
        }
    }

    /// Routes on the level, the cutoff and the vibrato, their sources jumping.
    func testLevelCutoffAndVibratoMovedByRoutesDoNotClick() throws {
        var song = try instrumentSong([Note(pitch: 57, velocity: 100, start: 0, length: 4 * bar)],
                                      settings: [(.waveform, 0), (.cutoff, 2_000)])
        let level = ParameterAddress(.track(song.track), SynthParameter.level.key)
        let cutoff = ParameterAddress(.track(song.track), SynthParameter.cutoff.key)
        let vibrato = ParameterAddress(.track(song.track), SynthParameter.vibrato.key)
        try Command.setModRoute(ModulationRoute(source: .breath, target: level, depth: 0.6)).apply(to: &song.project)
        try Command.setModRoute(ModulationRoute(source: .coherence, target: cutoff, depth: 0.5)).apply(to: &song.project)
        try Command.setModRoute(ModulationRoute(source: .heartRate, target: vibrato, depth: 1)).apply(to: &song.project)
        for source in [ModulationSource.breath, .coherence, .heartRate] {
            let moved = routeRender(song.project, source: source, values: [0.1, 0.9, 0.2, 0.8, 0, 1, 0.3])
            assertNoClicks(moved.stepped, "route from \(source)", detector: .forSine(hertz: 240, amplitude: 0.5))
            // 0.003: the classic engine plays 4.2 dB under its patch level since its loudness trim.
            XCTAssertGreaterThan(moved.difference, 0.003, "the route from \(source) is heard")
        }
    }

    /// A route on the track's volume, its source jumping.
    func testATrackVolumeMovedByARouteDoesNotClick() throws {
        var song = try instrumentSong([Note(pitch: 45, velocity: 100, start: 0, length: 4 * bar)],
                                      settings: [(.waveform, 0)])
        try Command.setModRoute(ModulationRoute(source: .breath, target: .volume(song.track), depth: 0.8))
            .apply(to: &song.project)
        let moved = routeRender(song.project, source: .breath, values: [0, 1, 0, 1, 0.2, 0.9, 0])
        assertNoClicks(moved.stepped, "volume route", detector: .forSine(hertz: 115, amplitude: 0.5))
        XCTAssertGreaterThan(moved.difference, 0.01, "the route is heard")
    }

    /// The volume route's jumps again, now off the song's 64-frame gain grid: device buffers of 470
    /// frames, the jumps 4,863 samples apart (one frame short of the grid each time, so each lands
    /// later on it), and a moving master pan, so every lane follows the grid. Each jump still ramps
    /// over 64 frames, wherever on the grid it falls.
    func testAVolumeJumpOffTheGainGridDoesNotClick() throws {
        var song = try instrumentSong([Note(pitch: 45, velocity: 100, start: 0, length: 4 * bar)],
                                      settings: [(.waveform, 0)])
        try Command.setModRoute(ModulationRoute(source: .breath, target: .volume(song.track), depth: 0.8))
            .apply(to: &song.project)
        try Command.setModRoute(ModulationRoute(source: .lfo1, target: .masterPan, depth: 0.3, polarity: .bipolar))
            .apply(to: &song.project)
        let inputs = ModulationInputs()
        let engine = self.core()
        publish(song.project, to: engine, modulation: inputs)
        engine.play()
        var out = render(engine, frames: 4_863, block: 470)
        for value in [1.0, 0, 1, 0, 0.2, 0.9, 0, 1] {
            inputs.set(.breath, value)
            let piece = render(engine, frames: 4_863, block: 470)
            out.left += piece.left
            out.right += piece.right
        }
        assertNoClicks(out, "volume jumps off the gain grid", detector: .forSine(hertz: 115, amplitude: 0.5))
    }

    /// A loop whose end falls off the gain grid (one bar at 140 BPM), the track's volume falling
    /// one tick after it: the loop never plays the fall, so it plays exactly as without it.
    func testALoopEndingOffTheGainGridNeverHearsTheVolumeAfterIt() throws {
        let notes = [Note(pitch: 45, velocity: 100, start: 0, length: 4 * bar)]
        let plain = try instrumentSong(notes, settings: [(.waveform, 0)], tempo: 140)
        var falling = try instrumentSong(notes, settings: [(.waveform, 0)], tempo: 140)
        try Command.setAutomation(.volume(falling.track), points: [AutomationPoint(tick: 0, value: 0),
                                                                   AutomationPoint(tick: bar, value: 0),
                                                                   AutomationPoint(tick: bar + 1, value: -60)])
            .apply(to: &falling.project)
        func looped(_ project: Project) -> (left: [Float], right: [Float]) {
            let engine = self.core()
            publish(project, to: engine)
            engine.setLoop(0..<bar)
            engine.play()
            return render(engine, frames: 3 * 82_286 + 1_000, block: 470)
        }
        let heard = looped(falling.project), expected = looped(plain.project)
        var worst: Float = 0
        for i in heard.left.indices {
            worst = Swift.max(worst, Swift.abs(heard.left[i] - expected.left[i]), Swift.abs(heard.right[i] - expected.right[i]))
        }
        XCTAssertGreaterThan(expected.left.map { Swift.abs($0) }.max() ?? 0, 0.01, "the note sounds")
        XCTAssertLessThan(worst, 1e-5, "the loop plays its own bar only")
    }

    /// A seek onto a place the volume has just fallen to −60 dB, from a place at the same level,
    /// off the gain grid with the fall inside the grid cell: the gain never leaves the levels it
    /// moves between — no swell, no turn of polarity while the held gain is ramped out.
    func testASeekNextToAVolumeFallNeverOvershoots() throws {
        var song = try audioSong(try sineBuffer(seconds: 4, stereo: false))
        // 120 BPM: 25 samples a tick. 0 dB to tick 2,000 (sample 50,000), −60 dB from tick 2,001.
        try Command.setAutomation(.volume(song.track), points: [AutomationPoint(tick: 0, value: 0),
                                                                AutomationPoint(tick: 2_000, value: 0),
                                                                AutomationPoint(tick: 2_001, value: -60)])
            .apply(to: &song.project)
        let engine = self.core()
        publish(song.project, to: engine, samples: song.samples)
        engine.play()
        engine.seek(toSample: 100_000)
        _ = render(engine, frames: 4_800, block: 470)
        // 50,029 = 64 · 781 + 45: the grid point before it is still at 0 dB, the one after at −60.
        engine.seek(toSample: 50_029)
        let after = render(engine, frames: 1_000, block: 470)
        let quiet: Float = 0.5 * 0.001   // the region's 0.5 at −60 dB
        let worst = after.left.map { Swift.abs($0) }.max() ?? 0
        XCTAssertLessThan(worst, 2 * quiet, "the gain stays at −60 dB across the seek")
    }

    /// The Bar Weave on the track's volume at full depth: its value changes on every bar line,
    /// by up to most of the fader's travel, and glides there — no click at a bar line.
    func testTheBarWeaveOnTheVolumeDoesNotClick() throws {
        var song = try instrumentSong([Note(pitch: 45, velocity: 100, start: 0, length: 8 * bar)],
                                      settings: [(.waveform, 0)])
        song.project.context = MusicalContext(root: 0, scale: .major)
        try Command.setModRoute(ModulationRoute(source: .weave1, target: .volume(song.track), depth: 1))
            .apply(to: &song.project)
        let engine = self.core()
        publish(song.project, to: engine)
        engine.play()
        let out = render(engine, frames: 8 * 96_000, block: 470)
        assertNoClicks(out, "Bar Weave on the volume", detector: .forSine(hertz: 115, amplitude: 0.5))
        var quiet = try instrumentSong([Note(pitch: 45, velocity: 100, start: 0, length: 8 * bar)], settings: [(.waveform, 0)])
        quiet.project.context = song.project.context
        let still = self.core()
        publish(quiet.project, to: still)
        still.play()
        let plain = render(still, frames: 8 * 96_000, block: 470)
        let difference = zip(out.left, plain.left).map { Swift.abs($0 - $1) }.max() ?? 0
        XCTAssertGreaterThan(difference, 0.01, "the route is heard")
    }

    /// Steep automation on the level and the cutoff: a ramp and a jump between two points.
    func testSteepInstrumentAutomationDoesNotClick() throws {
        var song = try instrumentSong([Note(pitch: 45, velocity: 100, start: 0, length: 4 * bar)],
                                      settings: [(.waveform, 0)])
        let level = ParameterAddress(.track(song.track), SynthParameter.level.key)
        let cutoff = ParameterAddress(.track(song.track), SynthParameter.cutoff.key)
        try Command.setAutomation(level, points: [AutomationPoint(tick: 0, value: 0.3),
                                                  AutomationPoint(tick: quarter, value: 0.3),
                                                  AutomationPoint(tick: quarter + 1, value: 0.05),
                                                  AutomationPoint(tick: 2 * quarter, value: 0.3)])
            .apply(to: &song.project)
        try Command.setAutomation(cutoff, points: [AutomationPoint(tick: 0, value: 300),
                                                   AutomationPoint(tick: 3 * quarter, value: 300),
                                                   AutomationPoint(tick: 3 * quarter + 1, value: 8_000)])
            .apply(to: &song.project)
        let core = core()
        publish(song.project, to: core)
        core.play()
        assertNoClicks(render(core, frames: 2 * 96_000), "level and cutoff automation",
                       detector: .forSine(hertz: 115, amplitude: 0.5))
    }

    /// The tempo moving as Flow moves it: a new snapshot thirty times a second, the tempo a
    /// little further each time, under a held note and a region.
    func testATempoGlidingAsFlowGlidesItDoesNotClick() throws {
        var song = try audioSong(try sineBuffer(seconds: 6, stereo: false))
        let synth = TrackID(), clip = ClipID()
        try Command.addTrack(id: synth, name: "S", kind: .instrument, index: nil).apply(to: &song.project)
        try Command.setInstrumentParameter(synth, key: SynthParameter.waveform.key.rawValue, value: 0).apply(to: &song.project)
        try Command.createClip(track: synth, id: clip, name: "C", length: 4 * bar).apply(to: &song.project)
        try Command.addNotes(clip, [Note(pitch: 64, velocity: 90, start: 0, length: 4 * bar)]).apply(to: &song.project)
        try Command.placeClip(track: synth, id: PlacementID(), clip: clip, start: 0).apply(to: &song.project)
        let core = core()
        publish(song.project, to: core, samples: song.samples)
        core.play()
        var out = render(core, frames: 4_800)
        for step in 0..<45 {
            try Command.setTempo(bpm: 120 + Double(step) * 0.4).apply(to: &song.project)
            publish(song.project, to: core, samples: song.samples)
            let piece = render(core, frames: 1_600)
            out.left += piece.left
            out.right += piece.right
        }
        assertNoClicks(out, "flow glide", detector: .forSine(hertz: 420, amplitude: 0.8))
    }

    /// A region sounding while the tempo moves reads on from where it was in its file: what it
    /// plays after three tempo changes is, sample for sample, what it plays without them — until
    /// a seek puts it back on the grid.
    func testARegionReadsOnAcrossTempoChangesAndASeekPutsItBackOnTheGrid() throws {
        var song = try audioSong(try sineBuffer(seconds: 6, stereo: false))
        let steady = core()
        publish(song.project, to: steady, samples: song.samples)
        steady.play()
        let reference = render(steady, frames: 72_000)

        let moving = core()
        publish(song.project, to: moving, samples: song.samples)
        moving.play()
        var out = render(moving, frames: 24_000)
        for bpm in [124.0, 131, 127] {
            try Command.setTempo(bpm: bpm).apply(to: &song.project)
            publish(song.project, to: moving, samples: song.samples)
            let piece = render(moving, frames: 16_000)
            out.left += piece.left
            out.right += piece.right
        }
        let largest = zip(out.left, reference.left).map { Swift.abs($0 - $1) }.max() ?? 1
        XCTAssertLessThan(largest, 1e-6, "the region read on across every change")

        // At 127 BPM bar 1 beat 3 lies at 45,354 samples; after a seek there the region plays
        // the file from its own beat 3 under the new tempo, not where it had read on to.
        moving.seek(toSample: 45_354)
        let after = render(moving, frames: 4_800)
        let expected = (0..<4_800).map { (i: Int) -> Float in
            Float(0.5 * sin(2 * Double.pi * 220 * Double(45_354 + i) / 48_000)) * Float(0.5).squareRoot()
        }
        let settled = zip(after.left[256...], expected[256...]).map { Swift.abs($0 - $1) }.max() ?? 1
        XCTAssertLessThan(settled, 1e-4, "back on the grid after the seek")
    }

    /// The sampler on a sine: notes, a repeated key, overlapping notes, more notes than voices,
    /// notes held past the sample's end, and the same as one-shots.
    func testTheSamplerPlaysWithoutAClick() throws {
        let tone = (0..<24_000).map { (i: Int) -> Float in Float(0.4 * sin(2 * Double.pi * 261.63 * Double(i) / 48_000)) }
        let buffer = try XCTUnwrap(SampleBuffer(samples: tone, sampleRate: rate))
        let sixteenth = quarter / 4
        var notes: [Note] = []
        for k in 0..<20 {
            notes.append(Note(pitch: 60 + (k % 5), velocity: 100, start: Tick(k) * sixteenth, length: 3 * sixteenth))
        }
        notes.append(Note(pitch: 60, velocity: 100, start: bar, length: 2 * bar))
        for mode in [0.0, 1.0] {
            var song = try instrumentSong(notes, device: .sampler,
                                          settings: [(.samplerRoot, 60), (.samplerMode, mode)], tempo: 240)
            let media = MediaFile(name: "Tone", path: "Media/tone.wav", frameCount: buffer.frameCount, sampleRate: rate)
            try Command.addMedia(media).apply(to: &song.project)
            try Command.setInstrumentSample(song.track, media.id).apply(to: &song.project)
            let core = core()
            publish(song.project, to: core, samples: [media.id: buffer])
            core.play()
            assertNoClicks(render(core, frames: 3 * 48_000), "sampler, mode \(mode)")
        }
    }

    func testTheKitPlaysAPatternWithoutAClick() throws {
        let sixteenth = quarter / 4
        var notes: [Note] = []
        for step in 0..<32 {
            let at = Tick(step) * sixteenth
            if step % 4 == 0 { notes.append(Note(pitch: 36, velocity: 110, start: at, length: sixteenth)) }
            if step % 8 == 4 { notes.append(Note(pitch: 38, velocity: 100, start: at, length: sixteenth)) }
            notes.append(Note(pitch: step % 8 == 6 ? 46 : 42, velocity: 80, start: at, length: sixteenth))
            if step % 2 == 1 { notes.append(Note(pitch: 45, velocity: 70, start: at, length: sixteenth)) }
        }
        let song = try instrumentSong(notes, device: .drums)
        let core = core()
        publish(song.project, to: core)
        core.play()
        assertNoClicks(render(core, frames: 3 * 96_000), "kit")
    }
}
