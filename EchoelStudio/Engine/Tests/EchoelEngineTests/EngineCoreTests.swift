import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelEngine

final class EngineCoreTests: XCTestCase {
    private let rate = 48_000.0
    private let bar = MusicalTime.ticksPerBar(.common)
    private var generation: UInt64 = 0

    private struct Song {
        var project: Project
        var tracks: [TrackID]
    }

    /// One instrument track per note list, each with one clip placed at 0.
    private func song(_ noteLists: [[Note]], tempo: Double = 120) throws -> Song {
        var project = Project(tempo: tempo)
        var ids: [TrackID] = []
        for (n, notes) in noteLists.enumerated() {
            let track = TrackID(), clip = ClipID()
            try Command.addTrack(id: track, name: "T\(n)", kind: .instrument, index: nil).apply(to: &project)
            try Command.createClip(track: track, id: clip, name: "C", length: 8 * bar).apply(to: &project)
            if !notes.isEmpty { try Command.addNotes(clip, notes).apply(to: &project) }
            try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
            ids.append(track)
        }
        return Song(project: project, tracks: ids)
    }

    private func publish(_ project: Project, to core: EngineCore, outputChannels: Int = 2) {
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        generation += 1
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project,
                                    slots: slots.slots, sampleRate: rate, generation: generation,
                                    outputChannels: outputChannels))
    }

    /// Renders `frames` into `count` separate channels.
    private func render(_ core: EngineCore, frames: Int, channels count: Int) -> [[Float]] {
        let buffers = (0..<count).map { _ in UnsafeMutablePointer<Float>.allocate(capacity: frames) }
        defer { buffers.forEach { $0.deallocate() } }
        buffers.withUnsafeBufferPointer { pointers in
            guard let base = pointers.baseAddress else { return }
            core.render(frameCount: frames, channels: base, channelCount: count)
        }
        return buffers.map { Array(UnsafeBufferPointer(start: $0, count: frames)) }
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

    private func firstSound(_ samples: [Float]) -> Int? {
        samples.firstIndex { Swift.abs($0) > 1e-6 }
    }

    private func core() -> EngineCore {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        return core
    }

    func testALiveNoteSoundsWhileStoppedAndAllNotesOffReleasesIt() throws {
        let tune = try song([[]])
        let engine = core()
        publish(tune.project, to: engine)
        _ = render(engine, frames: 256)
        XCTAssertNil(firstSound(render(engine, frames: 1_024).left), "silent before a key is played")
        engine.playLive(slot: 0, status: 0x90, 60, 100)
        XCTAssertNotNil(firstSound(render(engine, frames: 1_024).left))
        engine.playLive(slot: 0, status: 0x90, 60, 0)
        _ = render(engine, frames: 48_000)
        XCTAssertNil(firstSound(render(engine, frames: 1_024).left), "velocity 0 is a note off")
        engine.playLive(slot: 99, status: 0x90, 60, 100)
        XCTAssertNil(firstSound(render(engine, frames: 1_024).left), "a slot that does not exist plays nothing")
    }

    func testANoteStartsOnItsSample() throws {
        let s = try song([[Note(pitch: 60, start: 960, length: 960)]])
        let core = core()
        publish(s.project, to: core)
        core.play()
        let out = render(core, frames: 48_000)
        // Beat 2 at 120 BPM is 0.5 s = sample 24 000; a saw starts at zero, so allow two samples.
        let first = try XCTUnwrap(firstSound(out.left))
        XCTAssertTrue((24_000...24_002).contains(first), "\(first)")
    }

    func testTheOutputDoesNotDependOnTheBlockSize() throws {
        let notes = [Note(pitch: 48, start: 0, length: 700), Note(pitch: 55, start: 333, length: 2_000),
                     Note(pitch: 62, start: 1_920, length: 480)]
        var outputs: [[Float]] = []
        for block in [64, 256, 1_000, 4_096] {
            let s = try song([notes])
            let core = core()
            publish(s.project, to: core)
            core.play()
            outputs.append(render(core, frames: 72_000, block: block).left)
        }
        for other in outputs.dropFirst() {
            XCTAssertEqual(other, outputs[0])
        }
    }

    func testNothingPlaysUntilPlayAndStopRewinds() throws {
        let s = try song([[Note(pitch: 60, start: 0, length: 9_600)]])
        let core = core()
        publish(s.project, to: core)
        XCTAssertNil(firstSound(render(core, frames: 4_800).left))
        XCTAssertEqual(core.positionSample, 0)
        core.play()
        _ = render(core, frames: 4_800)
        XCTAssertEqual(core.positionSample, 4_800)
        core.stop()
        _ = render(core, frames: 48_000)               // the release rings out
        XCTAssertEqual(core.positionSample, 0)
        XCTAssertNil(firstSound(render(core, frames: 4_800).left))
    }

    func testMuteSoloAndPanShapeTheMix() throws {
        var s = try song([[Note(pitch: 60, start: 0, length: 9_600)], [Note(pitch: 67, start: 0, length: 9_600)]])
        let core = core()

        try Command.setMute(s.tracks[0], true).apply(to: &s.project)
        try Command.setMute(s.tracks[1], true).apply(to: &s.project)
        publish(s.project, to: core)
        core.play()
        XCTAssertNil(firstSound(render(core, frames: 9_600).left), "both muted")

        try Command.setMute(s.tracks[0], false).apply(to: &s.project)
        try Command.setMute(s.tracks[1], false).apply(to: &s.project)
        try Command.setSolo(s.tracks[0], true).apply(to: &s.project)
        try Command.setPan(.track(s.tracks[0]), pan: -1).apply(to: &s.project)
        core.stop()
        publish(s.project, to: core)
        core.play()
        let out = render(core, frames: 9_600)
        XCTAssertNotNil(firstSound(out.left), "the solo plays")
        XCTAssertNil(firstSound(out.right), "hard left, and the other track is not soloed")
    }

    func testARoutedTrackPlaysOnItsOwnPairPastTheMasterAndFallsBackWithoutOne() throws {
        var s = try song([[Note(pitch: 60, start: 0, length: 9_600)], [Note(pitch: 64, start: 0, length: 9_600)]])
        try Command.setOutput(s.tracks[1], channel: 2).apply(to: &s.project)
        try Command.setVolume(.master, db: MixerStrip.volumeRange.lowerBound).apply(to: &s.project)

        let routed = core()
        publish(s.project, to: routed, outputChannels: 4)
        routed.play()
        let out = render(routed, frames: 4_800, channels: 4)
        XCTAssertNil(firstSound(out[0]), "the master is down, and the routed track does not pass through it")
        XCTAssertNil(firstSound(out[1]))
        XCTAssertNotNil(firstSound(out[2]), "outputs 3/4 carry the routed track at its own fader")
        XCTAssertNotNil(firstSound(out[3]))

        let stereo = core()
        publish(s.project, to: stereo, outputChannels: 2)
        stereo.play()
        let folded = render(stereo, frames: 4_800, channels: 2)
        XCTAssertNil(firstSound(folded[0]), "without outputs 3/4 the track plays in the master mix, which is down")

        let mono = core()
        try Command.setVolume(.master, db: 0).apply(to: &s.project)
        publish(s.project, to: mono, outputChannels: 1)
        mono.play()
        XCTAssertNotNil(firstSound(render(mono, frames: 4_800, channels: 1)[0]), "one channel gets the mix")
    }

    func testMIDIClockStartsTicks24PerQuarterAndRepositionsOnASeek() throws {
        let s = try song([[]])
        let engine = core()
        publish(s.project, to: engine)
        _ = render(engine, frames: 4_800)
        XCTAssertNil(engine.clockOut.pop(), "nothing is timed until clock out is on")

        engine.setClockOutEnabled(true)
        engine.play()
        _ = render(engine, frames: 48_000, block: 48_000)
        var messages: [TimedMIDIMessage] = []
        while let message = engine.clockOut.pop() { messages.append(message) }
        XCTAssertEqual(messages.first?.status, 0xFA, "playing from the top is a Start")
        let clocks = messages.filter { $0.status == 0xF8 }
        // 120 BPM: a quarter is 24 000 samples, a clock every 1 000.
        XCTAssertEqual(clocks.count, 48)
        XCTAssertEqual(clocks.prefix(3).map(\.frame), [0, 1_000, 2_000])

        engine.seek(toSample: 96_000)                  // bar 2 = sixteenth 16
        _ = render(engine, frames: 256)
        let repositioned = Array(sequence(state: engine.clockOut) { $0.pop() }.prefix(3))
        XCTAssertEqual(repositioned.map(\.status), [0xFC, 0xF2, 0xFB])
        XCTAssertEqual(repositioned[1].bytes, [0xF2, 16, 0])

        engine.stop()
        while engine.clockOut.pop() != nil {}
        _ = render(engine, frames: 256)
        XCTAssertEqual(engine.clockOut.pop()?.status, 0xFC)
        XCTAssertNil(engine.clockOut.pop(), "no clock while stopped")
    }

    func testALaunchedClipLoopsFromTheNextBarAndStopsOnABar() throws {
        var s = try song([[]])
        let loop = ClipID()
        try Command.createClip(track: s.tracks[0], id: loop, name: "L", length: bar).apply(to: &s.project)
        try Command.addNotes(loop, [Note(pitch: 60, start: 0, length: 480)]).apply(to: &s.project)
        let engine = core()
        publish(s.project, to: engine)
        engine.play()
        _ = render(engine, frames: 256)

        // 120 BPM in 4/4: a bar is 96 000 samples.
        engine.launch(slot: 0, .launch(loop))
        let wait = render(engine, frames: 100_800 - 256)
        let start = try XCTUnwrap(firstSound(wait.left), "the clip starts on the next bar")
        XCTAssertTrue((96_000 - 256...96_002 - 256).contains(start), "\(start)")
        _ = render(engine, frames: 192_000 - 100_800)
        XCTAssertNotNil(firstSound(render(engine, frames: 4_800).left), "and plays again on the bar after: it loops")

        engine.launch(slot: 0, .stop)
        _ = render(engine, frames: 288_000 - 196_800)
        _ = render(engine, frames: 96_000)              // the last note rings out
        XCTAssertNil(firstSound(render(engine, frames: 4_800).left), "stopped on the bar: no further pass")

        engine.launch(slot: 0, .backToArrangement)
        _ = render(engine, frames: 256)
        let states = Array(sequence(state: engine.launchReports) { $0.pop() }).map(\.state)
        XCTAssertEqual(states, [.queued, .playing, .stopped, .arrangement])
    }

    func testANoteAfterATempoChangeLandsWhereTheMapSays() throws {
        var s = try song([[Note(pitch: 60, start: bar + 960, length: 480)]])
        try Command.setTempoChange(at: bar, bpm: 60).apply(to: &s.project)
        let core = core()
        publish(s.project, to: core)
        core.play()
        let out = render(core, frames: 160_000)
        // One bar at 120 (2 s = 96 000) plus one quarter at 60 (1 s = 48 000).
        let first = try XCTUnwrap(firstSound(out.left))
        XCTAssertTrue((144_000...144_002).contains(first), "\(first)")
    }

    func testTheClickFallsOnTheBeatsAndAccentsTheDownbeat() throws {
        let s = try song([[]])
        let core = EngineCore(sampleRate: rate)
        publish(s.project, to: core)
        core.play()
        let out = render(core, frames: 96_000).left
        func energy(_ range: Range<Int>) -> Float { out[range].reduce(0) { $0 + $1 * $1 } }
        XCTAssertGreaterThan(energy(0..<1_440), 1)
        XCTAssertGreaterThan(energy(24_000..<25_440), 0.1)
        XCTAssertEqual(energy(12_000..<23_990), 0)
        XCTAssertGreaterThan(energy(0..<1_440), energy(24_000..<25_440))
    }

    func testEditingWhilePlayingKeepsTimeAndNeverHangsANote() throws {
        var s = try song([[Note(pitch: 60, start: 0, length: 8 * bar)]])
        let core = core()
        publish(s.project, to: core)
        core.play()
        _ = render(core, frames: 24_000)
        // Delete the sounding note mid-way: it must release, and time must run on.
        let clip = try XCTUnwrap(s.project.tracks[0].clips.first)
        try Command.removeNotes(clip.id, clip.notes.map(\.id)).apply(to: &s.project)
        publish(s.project, to: core)
        _ = render(core, frames: 48_000)
        XCTAssertEqual(core.positionSample, 72_000)
        XCTAssertNil(firstSound(render(core, frames: 4_800).left))
    }

    func testATempoChangeWhilePlayingKeepsTheSongWhereItIs() throws {
        var s = try song([[Note(pitch: 60, start: 0, length: bar)]])
        let core = core()
        publish(s.project, to: core)
        core.play()
        _ = render(core, frames: 48_000)                  // one second at 120 BPM: beat 2
        let before = TimeConversion(tempoMap: s.project.tempoMap, sampleRate: rate).position(atSample: core.positionSample)
        try Command.setTempo(bpm: 90).apply(to: &s.project)
        publish(s.project, to: core)
        _ = render(core, frames: 256)
        let after = TimeConversion(tempoMap: s.project.tempoMap, sampleRate: rate).position(atSample: core.positionSample)
        let block = 256 * 90 * Double(MusicalTime.ticksPerQuarter) / (60 * rate)
        XCTAssertEqual(after - before, block, accuracy: 1, "the song moved on by one block, not by the tempo ratio")
    }

    func testANudgeMovesThePlayheadWithoutStoppingAHeldNote() throws {
        let s = try song([[Note(pitch: 48, start: 0, length: 8 * bar)]])
        let core = core()
        publish(s.project, to: core)
        core.play()
        _ = render(core, frames: 4_800)
        let before = core.positionSample
        core.nudge(bySamples: -24)
        let out = render(core, frames: 4_800)
        XCTAssertGreaterThan(rms(out.left[4_000...]), 0.001, "the held note sounds on")
        XCTAssertEqual(core.positionSample, before + 4_800 - 24)
        core.nudge(bySamples: -1_000_000)
        _ = render(core, frames: 256)
        XCTAssertEqual(core.positionSample, 256, "never before the top of the song")
    }

    func testAFaderMoveWhilePlayingKeepsAHeldNote() throws {
        var s = try song([[Note(pitch: 60, start: 0, length: 8 * bar)]])
        let engine = core()
        var revisions = EventRevisions()
        func publishKeepingNotes() {
            let plan = PlaybackPlan(compiling: s.project)
            var slots = SlotAssigner(capacity: engine.slotCapacity)
            slots.update(for: s.project)
            generation += 1
            engine.publish(EngineSnapshot(plan: plan, project: s.project, slots: slots.slots, sampleRate: rate,
                                          generation: generation, revisions: revisions.update(for: plan)))
        }
        publishKeepingNotes()
        engine.play()
        _ = render(engine, frames: 24_000)
        try Command.setVolume(.track(s.tracks[0]), db: -6).apply(to: &s.project)
        publishKeepingNotes()
        _ = render(engine, frames: 48_000)                // longer than the release: a cut note would be gone
        XCTAssertNotNil(firstSound(render(engine, frames: 4_800).left), "the note held through the fader move")

        let clip = try XCTUnwrap(s.project.tracks[0].clips.first)
        try Command.removeNotes(clip.id, clip.notes.map(\.id)).apply(to: &s.project)
        publishKeepingNotes()
        _ = render(engine, frames: 48_000)
        XCTAssertNil(firstSound(render(engine, frames: 4_800).left), "deleting the note still releases it")
    }

    private func rms(_ samples: ArraySlice<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        return (samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)).squareRoot()
    }

    func testAVolumeLaneFadesTheTrackOut() throws {
        var s = try song([[Note(pitch: 48, start: 0, length: 8 * bar)]])
        try Command.setAutomation(.volume(s.tracks[0]), points: [
            AutomationPoint(tick: 0, value: 0), AutomationPoint(tick: bar, value: MixerStrip.volumeRange.lowerBound),
        ]).apply(to: &s.project)
        let engine = core()
        publish(s.project, to: engine)
        engine.play()
        let out = render(engine, frames: 110_000).left   // a bar is 96 000 samples
        let early = rms(out[4_800..<14_400]), late = rms(out[80_000..<90_000]), after = rms(out[100_000..<110_000])
        XCTAssertGreaterThan(early, 0.01)
        XCTAssertLessThan(late, early * 0.5, "the level falls along the lane")
        XCTAssertEqual(after, 0, "and holds the lane's last value, silence")
    }

    func testACutoffLaneShapesTheSynth() throws {
        var open = try song([[Note(pitch: 48, start: 0, length: 4 * bar)]])
        var closed = open
        try Command.setAutomation(ParameterAddress(.track(closed.tracks[0]), SynthParameter.cutoff.key),
                                  points: [AutomationPoint(tick: 0, value: 20)]).apply(to: &closed.project)
        try Command.setInstrumentParameter(open.tracks[0], key: SynthParameter.cutoff.key.rawValue, value: 18_000)
            .apply(to: &open.project)
        var levels: [Float] = []
        for tune in [open, closed] {
            let engine = core()
            publish(tune.project, to: engine)
            engine.play()
            levels.append(rms(render(engine, frames: 48_000).left[24_000..<48_000]))
        }
        XCTAssertLessThan(levels[1], levels[0] * 0.5, "the lane, not the stored cutoff, sets the filter")
    }

    func testAMuteRampsDownOverOneChunkInsteadOfClicking() throws {
        var s = try song([[Note(pitch: 48, start: 0, length: 8 * bar)]])
        let engine = core()
        publish(s.project, to: engine)
        engine.play()
        _ = render(engine, frames: 24_000)
        try Command.setMute(s.tracks[0], true).apply(to: &s.project)
        publish(s.project, to: engine)
        let chunk = render(engine, frames: 512, block: 512).left
        XCTAssertGreaterThan(rms(chunk[0..<64]), rms(chunk[448..<512]) * 4, "the level falls across the chunk")
        XCTAssertNotNil(firstSound(chunk), "it does not vanish at the first sample")
        XCTAssertNil(firstSound(render(engine, frames: 512, block: 512).left), "and is silent after it")
    }

    func testFaderGainsFollowTheMixerLaw() {
        XCTAssertEqual(EngineSnapshot.linear(MixerStrip.volumeRange.lowerBound), 0)
        XCTAssertEqual(EngineSnapshot.linear(0), 1, accuracy: 1e-6)
        XCTAssertEqual(EngineSnapshot.linear(-6), 0.501, accuracy: 1e-3)
        XCTAssertEqual(EngineSnapshot.linear(.nan), 0)
        let (l, r) = EngineSnapshot.gains(track: MixerStrip(), master: MixerStrip())
        XCTAssertEqual(l, r, accuracy: 1e-6)
        XCTAssertEqual(l * l + r * r, 1, accuracy: 1e-5)   // constant power
    }

    func testSlotsStayWithTheirTrackAndAreReused() throws {
        var project = Project()
        let a = TrackID(), b = TrackID(), c = TrackID()
        for id in [a, b] { try Command.addTrack(id: id, name: "x", kind: .instrument, index: nil).apply(to: &project) }
        try Command.addTrack(id: TrackID(), name: "audio", kind: .audio, index: nil).apply(to: &project)
        var slots = SlotAssigner(capacity: 2)
        slots.update(for: project)
        let slotB = slots.slots[b]
        XCTAssertEqual(slots.slots.count, 2)

        try Command.removeTrack(a).apply(to: &project)
        try Command.addTrack(id: c, name: "y", kind: .instrument, index: 0).apply(to: &project)
        slots.update(for: project)
        XCTAssertEqual(slots.slots[b], slotB)
        XCTAssertNotNil(slots.slots[c])
        XCTAssertNotEqual(slots.slots[c], slotB)

        try Command.addTrack(id: TrackID(), name: "z", kind: .instrument, index: nil).apply(to: &project)
        slots.update(for: project)
        XCTAssertEqual(slots.slots.count, 2, "beyond capacity a track gets no slot")
    }

    func testALaneBeyondThePreallocatedSlotsIsDroppedNotIndexed() throws {
        let s = try song([[Note(pitch: 60, start: 0, length: 960)], [Note(pitch: 64, start: 0, length: 960)]])
        let engine = EngineCore(sampleRate: rate, slotCapacity: 1)
        engine.setClickEnabled(false)
        // Slots assigned for a larger engine: the second track gets slot 1, which this engine lacks.
        var slots = SlotAssigner(capacity: 8)
        slots.update(for: s.project)
        engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: s.project), project: s.project,
                                      slots: slots.slots, sampleRate: rate, generation: 1))
        engine.play()
        let out = render(engine, frames: 4_800).left
        XCTAssertNotNil(firstSound(out), "the track in slot 0 still plays")
        XCTAssertTrue(out.allSatisfy(\.isFinite))
    }

    func testADrumTrackPlaysTheKitAndOnlyKitNotes() throws {
        // Kick on the downbeat; middle C is not in the drum map and must stay silent.
        var s = try song([[Note(pitch: 36, start: 0, length: 240), Note(pitch: 60, start: bar, length: 240)]])
        try Command.setInstrumentDevice(s.tracks[0], .drums).apply(to: &s.project)
        let engine = core()
        publish(s.project, to: engine)
        engine.play()
        let beat = Int(rate / 2)
        let out = render(engine, frames: 8 * beat)
        XCTAssertEqual(firstSound(out.left), 0, "the kick starts on its sample")
        let kick = out.left[0..<beat].reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }
        XCTAssertGreaterThan(kick, 0.05)
        // The kick has died away (−60 dB) by 2.3 s; bar 2 from 2 s holds only a C.
        let afterKickTail = out.left[(5 * beat)...].reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }
        XCTAssertEqual(afterKickTail, 0, "the kit ignores a note outside the drum map")
    }

    func testSwitchingTheInstrumentChangesTheSoundOfTheSameNotes() throws {
        var s = try song([[Note(pitch: 38, start: 0, length: 960)]])
        let synth = core()
        publish(s.project, to: synth)
        synth.play()
        let synthOut = render(synth, frames: 9_600).left
        try Command.setInstrumentDevice(s.tracks[0], .drums).apply(to: &s.project)
        let drums = core()
        publish(s.project, to: drums)
        drums.play()
        let drumOut = render(drums, frames: 9_600).left
        XCTAssertNotNil(firstSound(drumOut))
        XCTAssertNotEqual(synthOut, drumOut)
    }

    func testASamplerTrackPlaysItsLoadedSampleAndIsSilentWithoutOne() throws {
        var s = try song([[Note(pitch: 60, start: 0, length: 960)]])
        let media = MediaFile(name: "Tone", path: "Media/tone.wav", frameCount: 4_800, sampleRate: rate)
        try Command.addMedia(media).apply(to: &s.project)
        try Command.setInstrumentDevice(s.tracks[0], .sampler).apply(to: &s.project)
        try Command.setInstrumentSample(s.tracks[0], media.id).apply(to: &s.project)
        let buffer = try XCTUnwrap(SampleBuffer(samples: Array(repeating: 0.5, count: 4_800), sampleRate: rate, rootPitch: 60))

        var slots = SlotAssigner(capacity: 32)
        slots.update(for: s.project)
        let plan = PlaybackPlan(compiling: s.project)

        let loaded = core()
        loaded.publish(EngineSnapshot(plan: plan, project: s.project, slots: slots.slots, sampleRate: rate,
                                      generation: 1, samples: [media.id: buffer]))
        loaded.play()
        let out = render(loaded, frames: 9_600).left
        XCTAssertEqual(firstSound(out), 0)
        XCTAssertGreaterThan(out[2_000], 0.05, "the sample sounds while the note is held")
        XCTAssertEqual(out[6_000], 0, "a 0.1 s sample ends after 0.1 s")

        let missing = core()
        missing.publish(EngineSnapshot(plan: plan, project: s.project, slots: slots.slots, sampleRate: rate, generation: 1))
        missing.play()
        XCTAssertNil(firstSound(render(missing, frames: 4_800).left), "a file that is not loaded stays silent")
    }
}

final class InstrumentPatchTests: XCTestCase {
    func testTheDefaultSettingsGiveTheDefaultSoundAndAPresetChangesIt() throws {
        let initial = SynthPatch(InstrumentSettings())
        XCTAssertEqual(initial.waveform, .saw)
        XCTAssertEqual(initial.cutoff, 800)
        let preset = try XCTUnwrap(InstrumentPreset.named("Sub Bass"))
        let bass = SynthPatch(InstrumentSettings(preset: preset.name, values: preset.values))
        XCTAssertEqual(bass.waveform, .sine)
        XCTAssertEqual(bass.cutoff, 300)
        XCTAssertNotEqual(bass, initial)
    }

    func testEachTrackPlaysItsOwnSound() throws {
        var project = Project()
        let a = TrackID(), b = TrackID()
        for (id, preset) in [(a, "Sub Bass"), (b, "Square Lead")] {
            let clip = ClipID()
            try Command.addTrack(id: id, name: preset, kind: .instrument, index: nil).apply(to: &project)
            try Command.loadInstrumentPreset(id, name: preset).apply(to: &project)
            try Command.createClip(track: id, id: clip, name: "C", length: 3_840).apply(to: &project)
            try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 960)]).apply(to: &project)
            try Command.placeClip(track: id, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        }
        let snapshot = EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project,
                                      slots: { var s = SlotAssigner(capacity: 4); s.update(for: project); return s.slots }(),
                                      sampleRate: 48_000, generation: 1)
        XCTAssertEqual(snapshot.lanes.map(\.patch.waveform), [.sine, .square])
    }
}
